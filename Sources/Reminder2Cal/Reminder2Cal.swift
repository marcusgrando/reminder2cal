import AppConfig
import Cocoa
import EventKit
import Reminder2CalSync
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    var appConfig = AppConfig()
    var syncManager: Reminder2CalSync?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?

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

        syncManager = Reminder2CalSync(
            appConfig: appConfig,
            logger: { message in
                Logger.shared.log(message)
            }
        ) { [weak self] granted in
            guard let self = self, granted else {
                Logger.shared.log("Access to Reminders/Calendar denied or not determined.")
                return
            }
            Logger.shared.log("Access granted. Starting sync timer.")
            self.startSyncTimer()
            self.observeEventStoreChanges()
            self.syncManager?.performSync()
        }

        // Set login item status
        appConfig.loginItemEnabled = (SMAppService.mainApp.status == .enabled)
    }

    @objc func showMenu() {
        let menu = NSMenu()

        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menuItem.attributedTitle = NSAttributedString(
            string: "Reminder2Cal",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold)
            ])
        menu.addItem(menuItem)
        menu.addItem(NSMenuItem.separator())
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
                self?.settingsWindow = nil
            },
            onCancel: { [weak self] in
                Logger.shared.log("Settings cancelled")
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            })
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        settingsWindow?.title = "Settings"
        settingsWindow?.center()
        settingsWindow?.setFrameAutosaveName("Settings")
        settingsWindow?.contentView = NSHostingView(rootView: settingsView)

        // Adiciona observador para o evento de fechamento da janela
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
            object: settingsWindow)

        // Mantém uma referência forte ao settingsWindow enquanto estiver visível
        settingsWindow?.isReleasedWhenClosed = false
    }

    func createAboutWindow() {
        let aboutView = AboutView(onClose: { [weak self] in
            self?.aboutWindow?.close()
            self?.aboutWindow = nil
        })
        aboutWindow = NSWindow(
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
        let reminderCalendars = eventStore.calendars(for: .reminder).filter {
            appConfig.reminderListName.contains($0.title)
                && $0.source.title == appConfig.accountName
        }

        for calendar in reminderCalendars {
            if eventStore.calendar(withIdentifier: calendar.calendarIdentifier) != nil {
                syncRemindersWithCalendar()
                break
            }
        }
    }

    func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(eventStoreChanged(notification:)), name: .EKEventStoreChanged,
            object: nil)
    }

    @objc func syncRemindersWithCalendar() {
        self.syncManager?.performSync()
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
