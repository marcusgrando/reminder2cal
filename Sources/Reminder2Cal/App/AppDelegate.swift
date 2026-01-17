import Cocoa
import EventKit
import Reminder2CalCore
import ServiceManagement
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    var appConfig = AppConfig()
    var syncManager: SyncService?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    var paywallWindow: NSWindow?

    // Sync control
    private var isSyncing = false
    private var syncDebounceTimer: Timer?
    private let syncDebounceInterval: TimeInterval = 1.5
    private var lastNotificationHash: Int?

    nonisolated func applicationDidFinishLaunching(_ aNotification: Notification) {
        Task { @MainActor in
            await setupApplication()
        }
    }

    private func setupApplication() async {
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

        // Set login item status
        appConfig.loginItemEnabled = (SMAppService.mainApp.status == .enabled)

        // Check subscription status before starting sync
        await SubscriptionManager.shared.refreshStatus()
        checkAccessAndStart()
    }

    private func checkAccessAndStart() {
        let manager = SubscriptionManager.shared

        if manager.hasAccess {
            Logger.shared.log(
                "Access granted: \(manager.isSubscribed ? "Subscribed" : "Trial active")")
            startApp()
        } else {
            Logger.shared.log("No access - showing paywall")
            showSubscription()
        }
    }

    private func startApp() {
        syncManager = SyncService(
            appConfig: appConfig,
            logger: { message in
                Logger.shared.log(message)
            },
            completion: { [weak self] granted in
                Task { @MainActor in
                    guard let self = self, granted else {
                        Logger.shared.log("Access to Reminders/Calendar denied or not determined.")
                        return
                    }
                    Logger.shared.log("Access granted. Starting sync timer.")
                    self.startSyncTimer()
                    self.observeEventStoreChanges()
                    self.syncManager?.performSync()
                }
            }
        )
    }

    @objc func showMenu() {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(
                title: "About Reminder2Cal", action: #selector(showAbout), keyEquivalent: "")
        )
        menu.addItem(NSMenuItem.separator())

        // Show subscription status
        let mgr = SubscriptionManager.shared
        let isSubscribed = mgr.isSubscribed
        let isTrialActive = mgr.isTrialActive
        let trialDaysRemaining = mgr.trialDaysRemaining
        
        let subscriptionMenuItem: NSMenuItem
        if isSubscribed {
            subscriptionMenuItem = NSMenuItem(title: "Subscribed", action: #selector(showSubscription), keyEquivalent: "")
        } else if isTrialActive {
            subscriptionMenuItem = NSMenuItem(
                title: "Trial: \(trialDaysRemaining) days left",
                action: #selector(showSubscription),
                keyEquivalent: ""
            )
        } else {
            subscriptionMenuItem = NSMenuItem(title: "Subscribe...", action: #selector(showSubscription), keyEquivalent: "")
        }
        menu.addItem(subscriptionMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(
            NSMenuItem(title: "Open Log File", action: #selector(openLogFile), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        // Show menu at the status item location (rebuilds every time)
        statusItem?.menu = nil  // Clear any existing menu
        if let button = statusItem?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        }
    }

    @objc func showSubscription() {
        Logger.shared.log("Opening Subscription window")
        if paywallWindow == nil {
            createPaywallWindow()
        }

        paywallWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)
    }

    func createPaywallWindow() {
        let paywallView = PaywallView(onSubscribed: { [weak self] in
            Logger.shared.log("Subscription completed")
            Task { @MainActor in
                self?.paywallWindow?.close()
                self?.startApp()
            }
        })

        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Subscription"
        window.center()
        window.contentView = NSHostingView(rootView: paywallView)
        window.isReleasedWhenClosed = false

        paywallWindow = window

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
            object: paywallWindow)
    }

    @objc func showSettings() {
        // Check access before showing settings
        let manager = SubscriptionManager.shared
        guard manager.hasAccess else {
            showSubscription()
            return
        }

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
                Task { @MainActor in
                    self?.settingsWindow?.close()
                }
            },
            onCancel: { [weak self] in
                Logger.shared.log("Settings cancelled")
                Task { @MainActor in
                    self?.settingsWindow?.close()
                }
            })

        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 770),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Settings"
        window.minSize = NSSize(width: 450, height: 750)
        window.center()
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false

        settingsWindow = window

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
            object: settingsWindow)
    }

    func createAboutWindow() {
        let aboutView = AboutView(onClose: { [weak self] in
            Task { @MainActor in
                self?.aboutWindow?.close()
            }
        })
        aboutWindow = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.titled, .closable],
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

    nonisolated func eventStoreChanged(notification: Notification) {
        Task { @MainActor in
            handleEventStoreChange(notification: notification)
        }
    }

    private func handleEventStoreChange(notification: Notification) {
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
            Task { @MainActor in
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
    }

    func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(eventStoreChangedObjc), name: .EKEventStoreChanged,
            object: nil)
    }

    @objc nonisolated func eventStoreChangedObjc(_ notification: Notification) {
        eventStoreChanged(notification: notification)
    }

    func syncRemindersWithCalendar() {
        // Check subscription before syncing
        let manager = SubscriptionManager.shared
        guard manager.hasAccess else {
            Logger.shared.log("Sync blocked - no active subscription or trial")
            return
        }

        // Prevent concurrent syncs
        guard !isSyncing else {
            Logger.shared.log("Sync already in progress, skipping duplicate request")
            return
        }

        isSyncing = true
        self.syncManager?.performSync { [weak self] in
            Task { @MainActor in
                self?.isSyncing = false
            }
        }
    }

    func startSyncTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: appConfig.timerInterval, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncRemindersWithCalendar()
            }
        }
    }

    @objc func windowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == settingsWindow {
                settingsWindow = nil
            } else if window == aboutWindow {
                aboutWindow = nil
            } else if window == paywallWindow {
                paywallWindow = nil
            }

            if settingsWindow == nil && aboutWindow == nil && paywallWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
