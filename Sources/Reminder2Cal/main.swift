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
    let appConfig = AppConfig()
    var syncManager: Reminder2CalSync?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
        
        let loginItemTitle = appConfig.loginItemEnabled ? "Remove from Login Items" : "Start with Login"
        let loginItemMenuItem = NSMenuItem(title: loginItemTitle, action: #selector(toggleLoginItem), keyEquivalent: "")
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

    // New method to toggle login item
    @objc func toggleLoginItem() {
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
            if let loginItemMenuItem = menu.item(at: 0) {
                loginItemMenuItem.title = appConfig.loginItemEnabled ? "Remove from Login Items" : "Start with Login"
            }
        }
    }

    // New method to check login item status
    func checkLoginItemStatus() {
        let appService = SMAppService.mainApp
        appConfig.loginItemEnabled = (appService.status == .enabled)
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