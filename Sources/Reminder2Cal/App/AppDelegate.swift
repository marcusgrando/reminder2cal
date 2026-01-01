import Cocoa
import EventKit
import Reminder2CalCore
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    var appConfig = AppConfig()
    var syncManager: SyncService?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?

    // Sync control
    private var isSyncing = false
    private var syncDebounceTimer: Timer?
    private let syncDebounceInterval: TimeInterval = 1.5
    private var lastNotificationHash: Int?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize logger for AppConfig
        appConfig.logger = { message in
            Logger.shared.log(message)
        }
        Logger.shared.log("Application started")

        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuIcon")
            button.action = #selector(showMenu)
        }

        syncManager = SyncService(
            appConfig: appConfig,
            logger: { message in
                Logger.shared.log(message)
            },
            completion: { [weak self] granted in
                guard let self = self, granted else {
                    Logger.shared.log("Access to Reminders/Calendar denied or not determined.")
                    return
                }
                Logger.shared.log("Access granted. Starting sync timer.")
                self.startSyncTimer()
                self.observeEventStoreChanges()
                self.syncManager?.performSync()
            }
        )

        // Set login item status
        appConfig.loginItemEnabled = (SMAppService.mainApp.status == .enabled)
    }

    @objc func showMenu() {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(title: "About Reminder2Cal", action: #selector(showAbout), keyEquivalent: "")
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(
            NSMenuItem(title: "Open Log File", action: #selector(openLogFile), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    @objc func showSettings() {
        Logger.shared.log("Opening Settings window")
        if settingsWindow == nil {
            createSettingsWindow()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)
    }

    @objc func showAbout() {
        Logger.shared.log("Opening About window")
        if aboutWindow == nil {
            createAboutWindow()
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)
    }

    @objc func openLogFile() {
        let logURL = Logger.shared.getLogFileURL()
        NSWorkspace.shared.open(logURL)
    }

    func createSettingsWindow() {
        let settingsView = SettingsView(
            appConfig: appConfig,
            onSave: { [weak self] in
                Logger.shared.log("Settings saved")
                self?.settingsWindow?.close()
            },
            onCancel: { [weak self] in
                Logger.shared.log("Settings cancelled")
                self?.settingsWindow?.close()
            })

        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Settings"
        window.center()
        window.setFrameAutosaveName("Settings")
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false

        settingsWindow = window

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
            object: settingsWindow)
    }

    func createAboutWindow() {
        let aboutView = AboutView(onClose: { [weak self] in
            DispatchQueue.main.async {
                self?.aboutWindow?.close()
            }
        })
        aboutWindow = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        aboutWindow?.title = "About"
        aboutWindow?.center()
        aboutWindow?.contentView = NSHostingView(rootView: aboutView)

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
            object: aboutWindow)
        aboutWindow?.isReleasedWhenClosed = false
    }

    @objc func quit() {
        Logger.shared.log("Quitting application")
        appConfig.saveConfig()
        NSApp.terminate(nil)
    }

    @objc func eventStoreChanged(notification: Notification) {
        // Ignore changes made by our own sync
        guard syncManager?.isMakingChanges != true else {
            return
        }

        // Create a hash of the notification to detect duplicates
        // We use a combination of userInfo and timestamp rounded to 100ms
        let timeHash = Int(Date().timeIntervalSince1970 * 10)  // Round to 100ms
        var notificationHash = timeHash

        // Add userInfo to hash if available
        if let userInfo = notification.userInfo {
            let userInfoString = String(describing: userInfo)
            notificationHash = notificationHash ^ userInfoString.hashValue
        }

        // Check if this is a duplicate notification (same hash within a short time)
        if let lastHash = lastNotificationHash, lastHash == notificationHash {
            return
        }

        lastNotificationHash = notificationHash
        Logger.shared.log("EventStore change detected, scheduling sync...")

        // Debounce: Cancel any pending sync and schedule a new one
        syncDebounceTimer?.invalidate()
        syncDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: syncDebounceInterval, repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }

            let reminderCalendars = self.eventStore.calendars(for: .reminder).filter {
                self.appConfig.reminderListName.contains($0.title)
                    && $0.source.title == self.appConfig.accountName
            }

            for calendar in reminderCalendars {
                if self.eventStore.calendar(withIdentifier: calendar.calendarIdentifier) != nil {
                    self.syncRemindersWithCalendar()
                    break
                }
            }

            // Clear the hash after processing to allow future legitimate notifications
            self.lastNotificationHash = nil
        }
    }

    func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(eventStoreChanged(notification:)), name: .EKEventStoreChanged,
            object: nil)
    }

    @objc func syncRemindersWithCalendar() {
        // Prevent concurrent syncs
        guard !isSyncing else {
            Logger.shared.log("Sync already in progress, skipping duplicate request")
            return
        }

        isSyncing = true
        self.syncManager?.performSync { [weak self] in
            // Reset sync flag when sync completes
            DispatchQueue.main.async {
                self?.isSyncing = false
            }
        }
    }

    func startSyncTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: appConfig.timerInterval, target: self,
            selector: #selector(syncRemindersWithCalendar), userInfo: nil, repeats: true)
    }

    @objc func windowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == settingsWindow {
                settingsWindow = nil
            } else if window == aboutWindow {
                aboutWindow = nil
            }

            if settingsWindow == nil && aboutWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
