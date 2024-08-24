import Cocoa

public class AppConfig {
    public var accountName: String
    public var calendarName: String
    public var numberOfDaysForSearch: Int
    public var maxDeletionsWithoutConfirmation: Int
    public var timerInterval: TimeInterval
    public var requestAccessInterval: TimeInterval
    public var eventDurationMinutes: Int
    public var alarmOffsetMinutes: Int
    public var reminderListName: [String]
    public var loginItemEnabled: Bool
    public var defaultHour: Int
    public var defaultMinute: Int

    public init() {
        let config = AppConfig.loadConfig()
        self.accountName = config["accountName"] as? String ?? "iCloud"
        self.calendarName = config["calendarName"] as? String ?? "Reminders"
        self.numberOfDaysForSearch = config["numberOfDaysForSearch"] as? Int ?? 14
        self.maxDeletionsWithoutConfirmation = config["maxDeletionsWithoutConfirmation"] as? Int ?? 5
        self.timerInterval = config["timerInterval"] as? TimeInterval ?? 1800
        self.requestAccessInterval = config["requestAccessInterval"] as? TimeInterval ?? 60
        self.eventDurationMinutes = config["eventDurationMinutes"] as? Int ?? 15
        self.alarmOffsetMinutes = config["alarmOffsetMinutes"] as? Int ?? 0
        self.reminderListName = config["reminderListName"] as? [String] ?? ["Inbox"]
        self.loginItemEnabled = config["loginItemEnabled"] as? Bool ?? false
        self.defaultHour = config["defaultHour"] as? Int ?? 9
        self.defaultMinute = config["defaultMinute"] as? Int ?? 0
    }

    static func loadConfig() -> [String: Any] {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String else {
            return [:]
        }
        
        let appDirectory = appSupportDirectory.appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        let configFile = appDirectory.appendingPathComponent("Config.plist")
        
        if let xml = FileManager.default.contents(atPath: configFile.path),
           let config = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] {
            return config
        }
        
        NSLog("[R2CLog] Failed to read or deserialize the config file at path: \(configFile.path).")
        return [:]
    }

    public func saveConfig() {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String else {
            return
        }
        
        let appDirectory = appSupportDirectory.appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        let configFile = appDirectory.appendingPathComponent("Config.plist")
        
        let config: [String: Any] = [
            "accountName": self.accountName,
            "calendarName": self.calendarName,
            "numberOfDaysForSearch": self.numberOfDaysForSearch,
            "maxDeletionsWithoutConfirmation": self.maxDeletionsWithoutConfirmation,
            "timerInterval": self.timerInterval,
            "requestAccessInterval": self.requestAccessInterval,
            "eventDurationMinutes": self.eventDurationMinutes,
            "alarmOffsetMinutes": self.alarmOffsetMinutes,
            "reminderListName": self.reminderListName,
            "loginItemEnabled": self.loginItemEnabled,
            "defaultHour": self.defaultHour,
            "defaultMinute": self.defaultMinute
        ]
        
        guard !config.isEmpty, let xml = try? PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0) else {
            NSLog("[R2CLog] Config is empty or serialization failed at path: \(configFile.path).")
            return
        }
        
        try? xml.write(to: configFile)
    }
}