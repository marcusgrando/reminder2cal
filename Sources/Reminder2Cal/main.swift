import Cocoa
import EventKit
import ServiceManagement
import AppConfig
import Reminder2CalSync

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    let lockFilePath = "/tmp/Reminder2Cal.lock"
    var lockFileHandle: FileHandle?
    var appConfig = AppConfig()
    var syncManager: Reminder2CalSync?

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
        
        syncManager = Reminder2CalSync(appConfig: appConfig) { [weak self] granted in
            guard let self = self, granted else {
                return
            }
            self.startSyncTimer()
            self.observeEventStoreChanges()
            self.syncManager?.performSync()
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
    
    @objc func syncRemindersWithCalendar() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.syncManager?.performSync()
        }
    }

    func startSyncTimer() {
        timer = Timer.scheduledTimer(timeInterval: appConfig.timerInterval, target: self, selector: #selector(syncRemindersWithCalendar), userInfo: nil, repeats: true)
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