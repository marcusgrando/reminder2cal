import Cocoa
import EventKit
import ServiceManagement
import AppConfig

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    let lockFilePath = "/tmp/Reminder2Cal.lock"
    var lockFileHandle: FileHandle?
    var appConfig = AppConfig()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !ensureSingleInstance() {
            NSApp.terminate(nil)
            return
        }
        
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: NSImage.Name("icon"))?.resized(to: NSSize(width: 28, height: 28))
            button.action = #selector(showMenu)
        }
        
        requestAccess { [weak self] granted in
            guard let self = self, granted else {
                self?.showAccessAlert()
                return
            }
            self.startSyncTimer()
            self.observeEventStoreChanges()
            self.performSync()
        }

        // Check login item status
        checkLoginItemStatus()
    }
    
    @objc func showMenu() {
        let menu = NSMenu()
        
        let loginItemMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        loginItemMenuItem.view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        
        let label = NSTextField(labelWithString: "Start at Login")
        label.frame = NSRect(x: 12, y: -3, width: 150, height: 24)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        
        let toggle = NSSwitch(frame: NSRect(x: 200, y: 0, width: 50, height: 24))
        toggle.state = appConfig.loginItemEnabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleLoginItem)
        
        loginItemMenuItem.view?.addSubview(label)
        loginItemMenuItem.view?.addSubview(toggle)
        
        menu.addItem(loginItemMenuItem)
        menu.addItem(NSMenuItem(title: "Configure", action: #selector(openConfiguration), keyEquivalent: "C"))        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "Q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func openConfiguration() {
        // Code to open the configuration window
    }
    
    @objc func quit() {
        appConfig.saveConfig()
        NSApp.terminate(nil)
    }
    
    @objc func requestAccess(completion: @escaping (Bool) -> Void) {
        requestReminderAccess { [weak self] reminderGranted in
            guard let self = self, reminderGranted else {
                self?.showRemindersAccessAlert()
                completion(false)
                return
            }
            self.requestCalendarAccess { calendarGranted in
                guard calendarGranted else {
                    self.showCalendarAccessAlert()
                    completion(false)
                    return
                }
                completion(true)
            }
        }
    }
    
    func requestReminderAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .reminder) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func showCalendarAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Access to Calendar is required."
        alert.informativeText = "Please grant access in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func showRemindersAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Access to Reminders is required."
        alert.informativeText = "Please grant access in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
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
    
    func startSyncTimer() {
        timer = Timer.scheduledTimer(timeInterval: appConfig.timerInterval, target: self, selector: #selector(syncRemindersWithCalendar), userInfo: nil, repeats: true)
    }
    
    @objc func syncRemindersWithCalendar() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.performSync()
        }
    }

    @objc func eventStoreChanged(notification: Notification) {
        let reminderCalendars = eventStore.calendars(for: .reminder).filter { appConfig.reminderListName.contains($0.title) && $0.source.title == appConfig.accountName }
        
        for calendar in reminderCalendars {
            if eventStore.calendar(withIdentifier: calendar.calendarIdentifier) != nil {
                syncRemindersWithCalendar()
                break
            }
        }
    }

    func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(eventStoreChanged(notification:)), name: .EKEventStoreChanged, object: nil)
    }
    
    func performSync() {
        requestAccess { [weak self] granted in
            guard let self = self, granted else {
                self?.showAccessAlert()
                return
            }

            let startDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
            let endDate = Calendar.current.date(byAdding: .day, value: self.appConfig.numberOfDaysForSearch, to: startDate)!

            self.fetchReminders(startDate: startDate, endDate: endDate) { [weak self] reminders in
                guard let self = self else { return }
                guard let calendar = self.eventStore.calendars(for: .event).first(where: { $0.title == self.appConfig.calendarName && $0.source.title == self.appConfig.accountName }) else {
                    self.showSyncAlert(message: "Calendar '\(self.appConfig.calendarName)' not found in account '\(self.appConfig.accountName)'.")
                    return
                }

                let events = self.fetchEvents(in: calendar, startDate: startDate, endDate: endDate)
                NSLog("[R2CLog] Fetched number of Calendar: \(events.count) and number of reminders: \(reminders.count)")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                var changesMade = false
                var eventsToRemove = [EKEvent]()

                for event in events {
                    let eventKey = "\(event.title ?? "")|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")"
                    var found = false
                    for reminder in reminders {
                        if let reminderDate = reminder.dueDateComponents?.date {
                            let reminderKey = "\(reminder.title ?? "")|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")"
                            if eventKey == reminderKey {
                                found = true
                                break
                            }
                        }
                    }
                    if !found {
                        eventsToRemove.append(event)
                    }
                }

                if eventsToRemove.count >= self.appConfig.maxDeletionsWithoutConfirmation {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let alert = NSAlert()
                        alert.messageText = "Confirmation required"
                        alert.informativeText = "You are about to delete \(eventsToRemove.count) events from calendar '\(self.appConfig.calendarName)' in account '\(self.appConfig.accountName)'. Do you want to continue?"
                        alert.addButton(withTitle: "Close")
                        alert.addButton(withTitle: "Yes")
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
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

                for reminder in reminders {
                    if let reminderDate = reminder.dueDateComponents?.date {
                        let reminderKey = "\(reminder.title ?? "")|\(dateFormatter.string(from: reminderDate))|\(reminder.notes ?? "")"
                        if !events.contains(where: { event in
                            let eventKey = "\(event.title ?? "")|\(dateFormatter.string(from: event.startDate))|\(event.notes ?? "")"
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
                        NSLog("[R2CLog] Changes committed to the event store.")
                    } catch {
                        NSLog("[R2CLog] Failed to commit changes: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func fetchReminders(startDate: Date, endDate: Date, completion: @escaping ([EKReminder]) -> Void) {
        let predicate = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            guard let self = self else { return }
            let reminders = fetchedReminders?.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return self.appConfig.reminderListName.contains(reminder.calendar.title) &&
                       reminder.calendar.source.title == self.appConfig.accountName &&
                       (startDate...endDate).contains(dueDate)
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
    
    func fetchEvents(in calendar: EKCalendar, startDate: Date, endDate: Date) -> [EKEvent] {
        guard calendar.title == appConfig.calendarName else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        return eventStore.events(matching: predicate)
    }
    
    func createEvent(for reminder: EKReminder, in calendar: EKCalendar) {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = reminder.title ?? ""
        event.startDate = reminder.dueDateComponents?.date ?? DateComponents(hour: appConfig.defaultHour, minute: appConfig.defaultMinute).date
        event.endDate = event.startDate.addingTimeInterval(TimeInterval(appConfig.eventDurationMinutes * 60))
        event.notes = reminder.notes
        event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-appConfig.alarmOffsetMinutes * 60)))
        saveEvent(event)        
        NSLog("[R2CLog] Created event: \(event.title ?? "") at \(String(describing: event.startDate)) with notes: \(event.notes ?? "")")
    }
    
    func removeEvent(_ event: EKEvent) {
        do {
            try eventStore.remove(event, span: .thisEvent)
            NSLog("[R2CLog] Removed event: \(event.title ?? "") at \(String(describing: event.startDate)) with notes: \(event.notes ?? "")")
        } catch {
            NSLog("[R2CLog] Failed to remove event: \(error.localizedDescription)")
        }
    }
    
    func removeEvents(_ events: [EKEvent]) {
        for event in events {
            self.removeEvent(event)
        }
    }
    
    func saveEvent(_ event: EKEvent) {
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            NSLog("[R2CLog] Failed to save event: \(error.localizedDescription)")
        }
    }
        
    func showSyncAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
        }
    }
    
    func ensureSingleInstance() -> Bool {
        let fm = FileManager.default
        
        if fm.fileExists(atPath: lockFilePath) {
            // Check if the previous process is still running
            if let fileHandle = FileHandle(forUpdatingAtPath: lockFilePath),
               let lockData = try? fileHandle.readToEnd(),
               let pidString = String(data: lockData, encoding: .utf8),
               let pid = Int32(pidString),
               kill(pid, 0) == 0 {
                NSLog("[R2CLog] An instance of Reminder2Cal is already running.")
                return false
            } else {
                // Previous process died, remove the old lock file
                try? fm.removeItem(atPath: lockFilePath)
            }
        }
        
        // Create the new lock file
        fm.createFile(atPath: lockFilePath, contents: nil, attributes: nil)
        
        // Write the current PID to the lock file
        if let fileHandle = FileHandle(forWritingAtPath: lockFilePath) {
            let pidString = String(ProcessInfo.processInfo.processIdentifier)
            fileHandle.write(pidString.data(using: .utf8)!)
            self.lockFileHandle = fileHandle
        }
        
        return true
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Close and remove the lock file
        lockFileHandle?.closeFile()
        try? FileManager.default.removeItem(atPath: lockFilePath)
    }

    // New method to toggle login item
    @objc func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            let isEnabled = appConfig.loginItemEnabled

            if isEnabled {
                do {
                    try appService.unregister()
                    appConfig.loginItemEnabled = false
                } catch {
                    NSLog("[R2CLog] Error removing from login items: \(error)")
                }
            } else {
                do {
                    try appService.register()
                    appConfig.loginItemEnabled = true
                } catch {
                    NSLog("[R2CLog] Error adding to login items: \(error)")
                }
            }

            if let menu = statusItem?.menu {
                if let loginItemMenuItem = menu.item(withTitle: "Add to Login Items") ?? menu.item(withTitle: "Remove from Login Items") {
                    loginItemMenuItem.title = appConfig.loginItemEnabled ? "Remove from Login Items" : "Add to Login Items"
                }
            }
        } else {
            NSLog("[R2CLog] SMAppService is only available on macOS 13.0 or newer.")
        }
    }

    // New method to check login item status
    func checkLoginItemStatus() {
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            if appService.status == .enabled {
                appConfig.loginItemEnabled = true
            } else {
                appConfig.loginItemEnabled = false
            }
        } else {
            NSLog("[R2CLog] SMAppService is only available on macOS 13.0 or newer.")
        }
    }
}

@main
struct MainApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        newImage.unlockFocus()
        return newImage
    }
}