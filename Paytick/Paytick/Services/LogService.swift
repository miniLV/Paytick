import Foundation
import CocoaLumberjackSwift

enum LogService {
    private static var configured = false
    
    private static let logDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupport?.appendingPathComponent("Paytick", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Paytick", isDirectory: true)
        return baseURL.appendingPathComponent("Logs", isDirectory: true)
    }()
    
    private static let fileLogger: DDFileLogger = {
        let manager = DDLogFileManagerDefault(logsDirectory: logDirectoryURL.path)
        manager.maximumNumberOfLogFiles = 5
        
        let logger = DDFileLogger(logFileManager: manager)
        logger.maximumFileSize = 1_048_576
        logger.rollingFrequency = 60 * 60 * 24
        return logger
    }()
    
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
        
        if let ttyLogger = DDTTYLogger.sharedInstance {
            DDLog.add(ttyLogger, with: .info)
        }
        DDLog.add(fileLogger, with: .info)
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
