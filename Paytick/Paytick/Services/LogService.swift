import Foundation
import CocoaLumberjackSwift

// Custom log file manager that creates files named by app launch time
final class PaytickLogFileManager: DDLogFileManagerDefault {
    private let launchTimestamp: String
    
    init(logsDir: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        self.launchTimestamp = formatter.string(from: Date())
        super.init(logsDirectory: logsDir)
    }
    
    override var newLogFileName: String {
        return "paytick_\(launchTimestamp).log"
    }
    
    override func isLogFile(withName fileName: String) -> Bool {
        return fileName.hasPrefix("paytick_") && fileName.hasSuffix(".log")
    }
}

enum LogService {
    private static var configured = false
    
    private static let logDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupport?.appendingPathComponent("Paytick", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Paytick", isDirectory: true)
        return baseURL.appendingPathComponent("Logs", isDirectory: true)
    }()
    
    private static var fileLogger: DDFileLogger?
    
    static var logDirectoryPath: String {
        return logDirectoryURL.path
    }
    
    static func configure() {
        guard !configured else { return }
        configured = true
        
        do {
            try FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        } catch {
            return
        }
        
        // Clean up old logs if total size exceeds 50MB
        cleanupOldLogs()
        
        // Create custom file manager with launch-time naming
        let manager = PaytickLogFileManager(logsDir: logDirectoryURL.path)
        manager.maximumNumberOfLogFiles = 20
        
        let logger = DDFileLogger(logFileManager: manager)
        // Each log file max 5MB, will create new file on next launch anyway
        logger.maximumFileSize = 5 * 1024 * 1024
        // Don't roll by time, only by app launch
        logger.rollingFrequency = 0
        // Force create new file on each launch
        logger.doNotReuseLogFiles = true
        
        fileLogger = logger
        
        if let ttyLogger = DDTTYLogger.sharedInstance {
            DDLog.add(ttyLogger, with: .info)
        }
        DDLog.add(logger, with: .info)
    }
    
    private static func cleanupOldLogs() {
        let maxTotalSize: UInt64 = 50 * 1024 * 1024 // 50MB
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return
        }
        
        // Get log files sorted by creation date (oldest first)
        let logFiles = files
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date, UInt64)? in
                guard let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                      let size = attrs.fileSize,
                      let date = attrs.creationDate else { return nil }
                return (url, date, UInt64(size))
            }
            .sorted { $0.1 < $1.1 }
        
        var totalSize = logFiles.reduce(0) { $0 + $1.2 }
        
        // Delete oldest files until under limit
        for (url, _, size) in logFiles {
            if totalSize <= maxTotalSize { break }
            try? FileManager.default.removeItem(at: url)
            totalSize -= size
        }
    }
    
    static func info(_ message: String, metadata: [String: String] = [:]) {
        let suffix = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let output = suffix.isEmpty ? message : "\(message) \(suffix)"
        DDLogInfo("\(output)")
    }
}
