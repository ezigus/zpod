@preconcurrency import Foundation

public enum LogLevel: String, Sendable {
    case debug, info, warning, error
}

public enum Logger {
    public static func log(_ message: String, level: LogLevel = .info, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("[\(level.rawValue.uppercased())] \(file):\(line) \(function) — \(message)")
        #else
        _ = (message, level, file, function, line)
        #endif
    }
}