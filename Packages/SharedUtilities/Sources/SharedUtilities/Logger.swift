@preconcurrency import Foundation
#if canImport(os)
import os.log
#endif

public enum LogLevel: String, Sendable {
    case debug, info, warning, error
    
    #if canImport(os)
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .error // OSLogType doesn't have warning, using error
        case .error:
            return .fault
        }
    }
    #endif
}

public enum Logger {
    #if canImport(os)
    private static let logger = os.Logger(subsystem: "com.zpod.app", category: "general")
    #endif
    
    public static func log(_ message: String, level: LogLevel = .info, file: String = #fileID, function: String = #function, line: Int = #line) {
        let logMessage = "[\(level.rawValue.uppercased())] \(file):\(line) \(function) — \(message)"
        
        #if canImport(os)
        logger.log(level: level.osLogType, "\(logMessage)")
        #else
        // Fallback for non-Apple platforms
        #if DEBUG
        print(logMessage)
        #endif
        #endif
    }
    
    public static func debug(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    public static func info(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    public static func warning(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    public static func error(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}