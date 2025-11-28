import AppConfig
import AppKit
import EventKit

public class Reminder2CalSync {
    private let eventStore = EKEventStore()
    private var appConfig: AppConfig

    private var logger: (String) -> Void
    public private(set) var isMakingChanges = false
    private var lastCommitTime: Date?

    public init(
        appConfig: AppConfig, logger: @escaping (String) -> Void = { NSLog($0) },
        completion: @escaping (Bool) -> Void
    ) {
        self.appConfig = appConfig
        self.logger = logger
        requestReminderAccess { granted in
            if !granted {
                self.showAccessAlert()
            }
            completion(granted)
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

    private func showCalendarAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Access to Calendar is required."
        alert.informativeText = "Please grant access in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showRemindersAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Access to Reminders is required."
        alert.informativeText = "Please grant access in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
            {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func showAccessAlert() {
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            if reminderStatus != .fullAccess && reminderStatus != .writeOnly {
                showRemindersAccessAlert()
            } else if calendarStatus != .fullAccess && calendarStatus != .writeOnly {
                showCalendarAccessAlert()
            }
        } else {
            if reminderStatus != .authorized {
                showRemindersAccessAlert()
            } else if calendarStatus != .authorized {
                showCalendarAccessAlert()
            }
        }
    }

    public func performSync(completion: (() -> Void)? = nil) {
        self.logger("Starting synchronization process...")
        requestCalendarAccess { [weak self] granted in
            guard let self = self, granted else {
                self?.logger("Synchronization aborted: Calendar access not granted")
                completion?()
                return
            }

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
                    self.logger("Synchronization failed: Could not find calendar '\(self.appConfig.calendarName)' in account '\(self.appConfig.accountName)'")
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
                            "\(reminder.title ?? "") [\(reminder.calendar.title)]|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
                        return reminderKey
                    })

                // Remove events that don't have a matching reminder
                for event in events {
                    let eventKey =
                        "\(event.title ?? "")|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")|\((event.alarms?.isEmpty == true))"
                    if !reminderKeys.contains(eventKey) {
                        eventsToRemove.append(event)
                    }
                }

                // Check if we'll need to create any new events
                var willCreateEvents = false
                for reminder in reminders {
                    if let reminderDate = reminder.dueDateComponents?.date {
                        let reminderKey =
                            "\(reminder.title ?? "") [\(reminder.calendar.title)]|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
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

                // Set flag BEFORE making any changes
                if eventsToRemove.count > 0 || willCreateEvents {
                    self.isMakingChanges = true
                    self.lastCommitTime = Date()
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
                            "\(reminder.title ?? "") [\(reminder.calendar.title)]|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")|\(reminder.isCompleted)"
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
                        self.isMakingChanges = false
                    }
                } else {
                    self.logger("Calendar is already up to date - no changes needed")
                }
                self.logger("Synchronization completed")
                completion?()
            }
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
        event.title = "\(reminder.title ?? "") [\(reminder.calendar.title)]"
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
            "  Created event in '\(calendar.title)': \"\(reminder.title ?? "")\" [from '\(reminder.calendar.title)'] | \(dateStr) | Notes: \(event.notes ?? "none") | Alarm: \(!reminder.isCompleted ? "yes" : "no")"
        )
    }

    private func removeEvent(_ event: EKEvent) {
        do {

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateStr = dateFormatter.string(from: event.startDate)

            // Extract reminder list name from title (format: "Title [ReminderList]")
            var displayTitle = event.title ?? ""
            var reminderListName = "unknown"
            if let match = displayTitle.range(of: "\\[(.+?)\\]$", options: .regularExpression) {
                reminderListName = String(displayTitle[match]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                displayTitle = displayTitle.replacingOccurrences(of: " \(displayTitle[match])", with: "")
            }

            try eventStore.remove(event, span: .thisEvent)
            self.logger(
                "  Deleted event from '\(event.calendar?.title ?? "unknown")': \"\(displayTitle)\" [from '\(reminderListName)'] | \(dateStr) | Notes: \(event.notes ?? "none")"
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
