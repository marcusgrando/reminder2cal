import SwiftUI

public class AppConfig: ObservableObject {
    @Published public var accountName: String
    @Published public var calendarName: String
    @Published public var reminderListName: [String]
    @Published public var numberOfDaysForSearch: Int
    @Published public var maxDeletionsWithoutConfirmation: Int
    @Published public var timerInterval: TimeInterval
    @Published public var requestAccessInterval: TimeInterval
    @Published public var eventDurationMinutes: Int
    @Published public var alarmOffsetMinutes: Int
    @Published public var loginItemEnabled: Bool
    @Published public var defaultHour: Int
    @Published public var defaultMinute: Int

    public var logger: ((String) -> Void)?

    public init() {
        let config = AppConfig.loadConfig()
        self.accountName = config["accountName"] as? String ?? "iCloud"
        self.calendarName = config["calendarName"] as? String ?? "Reminders"
        self.reminderListName = config["reminderListName"] as? [String] ?? ["Inbox"]
        self.numberOfDaysForSearch = config["numberOfDaysForSearch"] as? Int ?? 14
        self.maxDeletionsWithoutConfirmation =
            config["maxDeletionsWithoutConfirmation"] as? Int ?? 5
        self.timerInterval = config["timerInterval"] as? TimeInterval ?? 1800
        self.requestAccessInterval = config["requestAccessInterval"] as? TimeInterval ?? 60
        self.eventDurationMinutes = config["eventDurationMinutes"] as? Int ?? 15
        self.alarmOffsetMinutes = config["alarmOffsetMinutes"] as? Int ?? 0
        self.loginItemEnabled = config["loginItemEnabled"] as? Bool ?? false
        self.defaultHour = config["defaultHour"] as? Int ?? 9
        self.defaultMinute = config["defaultMinute"] as? Int ?? 0
    }

    private func log(_ message: String) {
        if let logger = logger {
            logger(message)
        } else {
            NSLog("[R2CLog] \(message)")
        }
    }

    static func loadConfig() -> [String: Any] {
        guard
            let appSupportDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first,
            let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        else {
            return [:]
        }

        let appDirectory = appSupportDirectory.appendingPathComponent(appName)
        try? FileManager.default.createDirectory(
            at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        let configFile = appDirectory.appendingPathComponent("Config.plist")

        if let xml = FileManager.default.contents(atPath: configFile.path),
            let config = try? PropertyListSerialization.propertyList(
                from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any]
        {
            return config
        }

        NSLog("[R2CLog] Failed to read or deserialize the config file at path: \(configFile.path).")
        return [:]
    }

    public func saveConfig() {
        guard
            let appSupportDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first,
            let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        else {
            return
        }

        let appDirectory = appSupportDirectory.appendingPathComponent(appName)
        try? FileManager.default.createDirectory(
            at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        let configFile = appDirectory.appendingPathComponent("Config.plist")

        let config: [String: Any] = [
            "accountName": self.accountName,
            "calendarName": self.calendarName,
            "reminderListName": self.reminderListName,
            "numberOfDaysForSearch": self.numberOfDaysForSearch,
            "maxDeletionsWithoutConfirmation": self.maxDeletionsWithoutConfirmation,
            "timerInterval": self.timerInterval,
            "requestAccessInterval": self.requestAccessInterval,
            "eventDurationMinutes": self.eventDurationMinutes,
            "alarmOffsetMinutes": self.alarmOffsetMinutes,
            "loginItemEnabled": self.loginItemEnabled,
            "defaultHour": self.defaultHour,
            "defaultMinute": self.defaultMinute,
        ]

        guard !config.isEmpty,
            let xml = try? PropertyListSerialization.data(
                fromPropertyList: config, format: .xml, options: 0)
        else {
            self.log("Config is empty or serialization failed at path: \(configFile.path).")
            return
        }

        do {
            try xml.write(to: configFile)
            self.log("Configuration saved successfully.")
        } catch {
            self.log("Failed to save configuration: \(error)")
        }
    }
}
