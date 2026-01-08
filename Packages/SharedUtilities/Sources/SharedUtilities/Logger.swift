@preconcurrency import Foundation
#if canImport(os)
import os.log
#endif

/// A lightweight, actor-neutral logging helper.
///
/// Use this enum when logging from background threads, detached tasks, or actors that do not require MainActor isolation.
/// It is intentionally simple so that it can be called from anywhere without awaiting.
public enum LogLevel: String, Sendable {
    case debug, info, warning, error

    #if canImport(os)
    @usableFromInline
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .error // OSLogType doesn't have warning, using error
        case .error: return .fault
        }
    }
    #endif
}

public enum Logger {
    // Use an availability-gated accessor to avoid referencing os.Logger on older platforms at compile time
    #if canImport(os)
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    @inline(__always)
    private static func makeOSLogger() -> os.Logger { os.Logger(subsystem: "com.zpod.app", category: "general") }
    #endif
    
    /// Logs a message at the provided `level` with contextual metadata.
    public static func log(_ message: String, level: LogLevel = .info, file: String = #fileID, function: String = #function, line: Int = #line) {
        let logMessage = "[\(level.rawValue.uppercased())] \(file):\(line) \(function) — \(message)"
        
        #if canImport(os)
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            let logger = makeOSLogger()
            logger.log(level: level.osLogType, "\(logMessage)")
            return
        }
        #endif
        
        // Fallback for non-Apple platforms or older Apple OS versions
        #if DEBUG
        print(logMessage)
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

/// A MainActor-isolated facade over `Logger`.
///
/// Use this helper when you are already on the MainActor (e.g., UI controllers, view models) and you want
/// to keep the logging work on that actor without hopping to a detached context. It simply forwards to the
/// actor-neutral `Logger` so the implementations remain consistent.
@MainActor
public final class MainActorLogger {
    public static let shared = MainActorLogger()

    private init() {}
    
    public func log(_ message: String, level: LogLevel = .info, file: String = #fileID, function: String = #function, line: Int = #line) {
        Logger.log(message, level: level, file: file, function: function, line: line)
    }

    public func debug(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        Logger.debug(message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        Logger.info(message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        Logger.warning(message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        Logger.error(message, file: file, function: function, line: line)
    }
}
