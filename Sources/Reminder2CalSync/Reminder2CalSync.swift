import AppConfig
import AppKit
import EventKit

public class Reminder2CalSync {
    private let eventStore = EKEventStore()
    private var appConfig: AppConfig

    private var logger: (String) -> Void

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
        eventStore.requestAccess(to: .reminder) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
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

        if reminderStatus != .authorized {
            showRemindersAccessAlert()
        } else if calendarStatus != .authorized {
            showCalendarAccessAlert()
        }
    }

    public func performSync() {
        self.logger("Sync started")
        requestCalendarAccess { [weak self] granted in
            guard let self = self, granted else {
                self?.logger("Sync aborted: Calendar access denied")
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
                    self.logger("Sync failed: Calendar '\(self.appConfig.calendarName)' not found")
                    self.showSyncAlert(
                        message:
                            "Calendar '\(self.appConfig.calendarName)' not found in account '\(self.appConfig.accountName)'."
                    )
                    return
                }

                let events = self.fetchEvents(in: calendar, startDate: startDate, endDate: endDate)
                self.logger(
                    "Fetched number of Calendar: \(events.count) and number of reminders: \(reminders.count)"
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
                                    "Sync aborted: User denied deletion of \(eventsToRemove.count) events"
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
                        self.logger("Changes committed to the event store.")
                    } catch {
                        self.logger("Failed to commit changes: \(error.localizedDescription)")
                    }
                } else {
                    self.logger("No changes detected")
                }
                self.logger("Sync finished")
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
        self.logger(
            "Created event: \(event.title ?? "") at \(String(describing: event.startDate)) with notes: \(event.notes ?? "")"
        )
    }

    private func removeEvent(_ event: EKEvent) {
        do {
            try eventStore.remove(event, span: .thisEvent)
            self.logger(
                "Removed event: \(event.title ?? "") at \(String(describing: event.startDate)) with notes: \(event.notes ?? "")"
            )
        } catch {
            self.logger("Failed to remove event: \(error.localizedDescription)")
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
            self.logger("Failed to save event: \(error.localizedDescription)")
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
