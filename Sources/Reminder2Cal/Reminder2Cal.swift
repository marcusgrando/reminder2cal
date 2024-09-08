import Cocoa
import EventKit
import ServiceManagement
import AppConfig
import Reminder2CalSync
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    var timer: Timer?
    var accessTimer: Timer?
    var statusItem: NSStatusItem?
    var appConfig = AppConfig()
    var syncManager: Reminder2CalSync?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuIcon")
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

        // Set login item status
        appConfig.loginItemEnabled = (SMAppService.mainApp.status == .enabled)
    }
    
    @objc func showMenu() {
        let menu = NSMenu()
        
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menuItem.attributedTitle = NSAttributedString(string: "Reminder2Cal", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
        ])
        menu.addItem(menuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)
    }

    func createSettingsWindow() {
        let settingsView = SettingsView(appConfig: appConfig, onSave: { [weak self] in
            self?.settingsWindow?.close()
            self?.settingsWindow = nil
        }, onCancel: { [weak self] in
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
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: settingsWindow)
        
        // Mantém uma referência forte ao settingsWindow enquanto estiver visível
        settingsWindow?.isReleasedWhenClosed = false
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
        self.syncManager?.performSync()
    }

    func startSyncTimer() {
        timer = Timer.scheduledTimer(timeInterval: appConfig.timerInterval, target: self, selector: #selector(syncRemindersWithCalendar), userInfo: nil, repeats: true)
    }

    @objc func windowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            NSApp.setActivationPolicy(.accessory)
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