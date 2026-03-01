import AppKit
import EventKit

public class SyncService {
    private let eventStore = EKEventStore()
    private var appConfig: AppConfig

    private var logger: (String) -> Void
    public private(set) var isMakingChanges = false
    public private(set) var isRequestingAccess = false

    public init(
        appConfig: AppConfig, logger: @escaping (String) -> Void = { NSLog($0) },
        completion: @escaping (Bool) -> Void
    ) {
        self.appConfig = appConfig
        self.logger = logger

        requestReminderAccess { [self] reminderGranted in
            self.logger("Reminder access: \(reminderGranted)")

            let calendarStatus = EKEventStore.authorizationStatus(for: .event)
            self.logger("Calendar authorization status: \(calendarStatus.rawValue)")

            // If Calendar already determined, skip request (avoids hanging callback)
            guard calendarStatus == .notDetermined else {
                let calendarGranted = SyncService.isAccessGranted(calendarStatus)
                let allGranted = reminderGranted && calendarGranted
                if !allGranted {
                    self.handleDeniedPermissions(completion: completion)
                    return
                }
                completion(true)
                return
            }

            // Calendar is .notDetermined — delay to let macOS dismiss the
            // Reminders dialog before presenting the Calendar dialog
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestCalendarAccess { calendarGranted in
                    self.logger("Calendar access: \(calendarGranted)")
                    let allGranted = reminderGranted && calendarGranted
                    if !allGranted {
                        self.handleDeniedPermissions(completion: completion)
                        return
                    }
                    completion(true)
                }
            }
        }
    }

    private static func isAccessGranted(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    private func requestReminderAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    /// Shows alert for all missing permissions.
    /// Returns true if user chose "Open System Preferences", false if "Quit".
    private func showAccessAlert() -> Bool {
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)

        var missing = [String]()
        if !SyncService.isAccessGranted(reminderStatus) { missing.append("Reminders") }
        if !SyncService.isAccessGranted(calendarStatus) { missing.append("Calendar") }

        guard !missing.isEmpty else { return false }

        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText =
            "Please grant access to \(missing.joined(separator: " and ")) in System Preferences to use Reminder2Cal."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let privacyPane: String
            if missing.count > 1 {
                privacyPane = "Privacy"
            } else if missing.contains("Reminders") {
                privacyPane = "Privacy_Reminders"
            } else {
                privacyPane = "Privacy_Calendars"
            }
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyPane)") {
                NSWorkspace.shared.open(url)
            }
            return true
        }
        return false
    }

    private func handleDeniedPermissions(completion: @escaping (Bool) -> Void) {
        let userWantsToWait = self.showAccessAlert()
        if userWantsToWait {
            self.logger("Waiting for user to grant permissions in System Preferences...")
            self.pollForPermissions(completion: completion)
        } else {
            completion(false)
        }
    }

    private static let maxPollAttempts = 150  // 5 minutes at 2s intervals

    private func pollForPermissions(attempt: Int = 0, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }

            let reminderGranted = SyncService.isAccessGranted(EKEventStore.authorizationStatus(for: .reminder))
            let calendarGranted = SyncService.isAccessGranted(EKEventStore.authorizationStatus(for: .event))

            self.logger("Polling permissions - Reminders: \(reminderGranted), Calendar: \(calendarGranted)")

            if reminderGranted && calendarGranted {
                self.logger("All permissions granted")
                completion(true)
            } else if attempt >= SyncService.maxPollAttempts {
                self.logger("Permission polling timed out after \(SyncService.maxPollAttempts) attempts")
                completion(false)
            } else {
                self.pollForPermissions(attempt: attempt + 1, completion: completion)
            }
        }
    }

    public func performSync(completion: (() -> Void)? = nil) {
        self.logger("Starting synchronization process...")

        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                self.executeSyncAfterAccess(completion: completion)
                return
            case .writeOnly:
                self.logger(
                    "Synchronization aborted: Full calendar access required (currently write-only)")
                completion?()
                return
            case .denied, .restricted, .notDetermined:
                break
            @unknown default:
                self.logger("Unknown calendar authorization status: \(status.rawValue)")
                break
            }
        } else {
            if status == .authorized {
                self.executeSyncAfterAccess(completion: completion)
                return
            }
        }

        if status == .notDetermined {
            isRequestingAccess = true
            requestCalendarAccess { [weak self] granted in
                self?.isRequestingAccess = false
                guard let self = self, granted else {
                    self?.logger("Synchronization aborted: Calendar access not granted")
                    completion?()
                    return
                }
                self.executeSyncAfterAccess(completion: completion)
            }
        } else {
            self.logger(
                "Synchronization aborted: Calendar access denied (status: \(status.rawValue))")
            completion?()
        }
    }

    private func executeSyncAfterAccess(completion: (() -> Void)? = nil) {
        let startDate = Calendar.current.date(
            byAdding: .day, value: -self.appConfig.numberOfDaysForSearch, to: Date())!
        let endDate = Calendar.current.date(
            byAdding: .day, value: self.appConfig.numberOfDaysForSearch, to: Date())!

        self.fetchReminders(startDate: startDate, endDate: endDate) { [weak self] reminders in
            guard let self = self else { return }
            guard
                let calendar = self.eventStore.calendars(for: .event).first(where: {
                    $0.title == self.appConfig.calendarName
                        && $0.source.title == self.appConfig.accountName
                })
            else {
                self.logger(
                    "Synchronization failed: Could not find calendar '\(self.appConfig.calendarName)' in account '\(self.appConfig.accountName)'"
                )
                self.showSyncAlert(
                    message:
                        "Calendar '\(self.appConfig.calendarName)' not found in account '\(self.appConfig.accountName)'."
                )
                completion?()
                return
            }

            let events = self.fetchEvents(in: calendar, startDate: startDate, endDate: endDate)
            self.logger(
                "Found \(events.count) existing events in calendar '\(calendar.title)' and \(reminders.count) reminders to sync from account '\(self.appConfig.accountName)'"
            )

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            var changesMade = false
            var eventsToRemove = [EKEvent]()

            let reminderKeys = Set(
                reminders.compactMap { reminder -> String? in
                    guard let reminderDate = reminder.dueDateComponents?.date else {
                        return nil
                    }
                    let reminderKey =
                        "\(reminder.title ?? "") [\(reminder.calendar.title)] - R2C|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
                    return reminderKey
                })

            // Remove events that don't have a matching reminder (only R2C events)
            for event in events {
                // Only consider events created by R2C (have the suffix)
                guard let title = event.title, title.hasSuffix(" - R2C") else {
                    continue
                }
                let eventKey =
                    "\(title)|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")|\((event.alarms?.isEmpty == true))"
                if !reminderKeys.contains(eventKey) {
                    eventsToRemove.append(event)
                }
            }

            // Check if we'll need to create any new events
            var willCreateEvents = false
            for reminder in reminders {
                if let reminderDate = reminder.dueDateComponents?.date {
                    let reminderKey =
                        "\(reminder.title ?? "") [\(reminder.calendar.title)] - R2C|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
                    if !events.contains(where: { event in
                        let eventKey =
                            "\(event.title ?? "")|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")|\((event.alarms?.isEmpty == true))"
                        return eventKey == reminderKey
                    }) {
                        willCreateEvents = true
                        break
                    }
                }
            }

            // Set flag BEFORE making any changes (sync dispatch to ensure visibility before mutations)
            if eventsToRemove.count > 0 || willCreateEvents {
                DispatchQueue.main.sync {
                    self.isMakingChanges = true
                }
            }

            if eventsToRemove.count > 0 {
                if eventsToRemove.count >= self.appConfig.maxDeletionsWithoutConfirmation {
                    DispatchQueue.main.sync { [weak self] in
                        guard let self = self else { return }
                        let alert = NSAlert()
                        alert.messageText = "Confirmation required"
                        alert.informativeText =
                            "You are about to delete \(eventsToRemove.count) events from calendar '\(self.appConfig.calendarName)' in account '\(self.appConfig.accountName)'. Do you want to continue?"
                        alert.addButton(withTitle: "Close")
                        alert.addButton(withTitle: "Yes")
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            self.logger(
                                "Synchronization cancelled: User declined to delete \(eventsToRemove.count) events"
                            )
                            NSApp.terminate(nil)
                        } else {
                            self.removeEvents(eventsToRemove)
                            changesMade = true
                        }
                    }
                } else {
                    self.removeEvents(eventsToRemove)
                    changesMade = true
                }
            }

            // Create events for reminders that don't have a matching event
            for reminder in reminders {
                if let reminderDate = reminder.dueDateComponents?.date {
                    let reminderKey =
                        "\(reminder.title ?? "") [\(reminder.calendar.title)] - R2C|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
                    if !events.contains(where: { event in
                        let eventKey =
                            "\(event.title ?? "")|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")|\((event.alarms?.isEmpty == true))"
                        return eventKey == reminderKey
                    }) {
                        self.createEvent(for: reminder, in: calendar)
                        changesMade = true
                    }
                }
            }

            // Force sync with Apple server if changes were made
            if changesMade {
                do {
                    try self.eventStore.commit()
                    self.logger("All changes saved successfully to EventStore")

                    // Reset flag after delay - long enough to catch all related notifications
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.isMakingChanges = false
                    }
                } catch {
                    self.logger("Error saving changes to EventStore: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isMakingChanges = false
                    }
                }
            } else {
                self.logger("Calendar is already up to date - no changes needed")
            }
            self.logger("Synchronization completed")
            completion?()
        }
    }

    private func fetchReminders(
        startDate: Date, endDate: Date, completion: @escaping ([EKReminder]) -> Void
    ) {
        let predicate = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            guard let self = self else { return }
            let reminders =
                fetchedReminders?.filter { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else { return false }
                    return self.appConfig.reminderListName.contains(reminder.calendar.title)
                        && reminder.calendar.source.title == self.appConfig.accountName
                        && (startDate...endDate).contains(dueDate)
                } ?? []

            for reminder in reminders {
                if reminder.dueDateComponents?.hour == nil {
                    reminder.dueDateComponents?.hour = self.appConfig.defaultHour
                    reminder.dueDateComponents?.minute = self.appConfig.defaultMinute
                }
            }
            completion(reminders)
        }
    }

    private func fetchEvents(in calendar: EKCalendar, startDate: Date, endDate: Date) -> [EKEvent] {
        guard calendar.title == appConfig.calendarName else { return [] }
        let predicate = eventStore.predicateForEvents(
            withStart: startDate, end: endDate, calendars: [calendar])
        return eventStore.events(matching: predicate)
    }

    private func createEvent(for reminder: EKReminder, in calendar: EKCalendar) {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = "\(reminder.title ?? "") [\(reminder.calendar.title)] - R2C"
        event.startDate =
            reminder.dueDateComponents?.date
            ?? DateComponents(hour: appConfig.defaultHour, minute: appConfig.defaultMinute).date
        event.endDate = event.startDate.addingTimeInterval(
            TimeInterval(appConfig.eventDurationMinutes * 60))
        event.notes = reminder.notes
        if !reminder.isCompleted {
            event.addAlarm(
                EKAlarm(relativeOffset: TimeInterval(-appConfig.alarmOffsetMinutes * 60)))
        }
        saveEvent(event)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateStr = dateFormatter.string(from: event.startDate)

        self.logger(
            "  Created event in '\(calendar.title)': \"\(event.title ?? "")\" | \(dateStr) | Notes: \(event.notes ?? "none") | Alarm: \(!reminder.isCompleted ? "yes" : "no")"
        )
    }

    private func removeEvent(_ event: EKEvent) {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateStr = dateFormatter.string(from: event.startDate)

            try eventStore.remove(event, span: .thisEvent)
            self.logger(
                "  Deleted event from '\(event.calendar?.title ?? "unknown")': \"\(event.title ?? "")\" | \(dateStr) | Notes: \(event.notes ?? "none")"
            )
        } catch {
            self.logger("  Error deleting event '\(event.title ?? "")': \(error.localizedDescription)")
        }
    }

    private func removeEvents(_ events: [EKEvent]) {
        for event in events {
            self.removeEvent(event)
        }
    }

    private func saveEvent(_ event: EKEvent) {
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            self.logger("  Error creating event '\(event.title ?? "")': \(error.localizedDescription)")
        }
    }

    private func showSyncAlert(message: String) {
        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "Close")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSApp.terminate(nil)
            }
        }
    }
}
