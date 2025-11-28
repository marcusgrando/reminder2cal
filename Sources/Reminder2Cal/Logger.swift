import Foundation

public class Logger {
    public static let shared = Logger()
    private let fileURL: URL
    private let dateFormatter: DateFormatter

    private init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appName =
            Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "Reminder2Cal"
        let appDirectory = appSupportURL.appendingPathComponent(appName)

        try? fileManager.createDirectory(
            at: appDirectory, withIntermediateDirectories: true, attributes: nil)

        self.fileURL = appDirectory.appendingPathComponent("app.log")

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }

        // Also print to console for debugging
        print(logMessage, terminator: "")
    }

    public func getLogFileURL() -> URL {
        return fileURL
    }
}
