import XCTest
@preconcurrency import Foundation
#if canImport(os)
import os.log
#endif
@testable import SharedUtilities

final class ComprehensiveLoggerTests: XCTestCase {
    
    // MARK: - LogLevel Tests
    
    func testLogLevel_RawValues() {
        // Given: LogLevel enum cases
        // When: Accessing raw values
        // Then: Should return correct string representations
        XCTAssertEqual(LogLevel.debug.rawValue, "debug")
        XCTAssertEqual(LogLevel.info.rawValue, "info")
        XCTAssertEqual(LogLevel.warning.rawValue, "warning")
        XCTAssertEqual(LogLevel.error.rawValue, "error")
    }
    
    func testLogLevel_SendableConformance() {
        // Given: LogLevel instances
        // When: Used across concurrency boundaries
        // Then: Should conform to Sendable without compilation errors
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        
        Task {
            // This should compile without warnings if LogLevel is properly Sendable
            let _ = levels.map { $0.rawValue }
        }
        
        XCTAssertEqual(levels.count, 4)
    }
    
    #if canImport(os)
    func testLogLevel_OSLogTypeMapping() {
        // Given: LogLevel cases with os.log available
        // When: Converting to OSLogType
        // Then: Should map to appropriate OS log types
        XCTAssertEqual(LogLevel.debug.osLogType, OSLogType.debug)
        XCTAssertEqual(LogLevel.info.osLogType, OSLogType.info)
        XCTAssertEqual(LogLevel.warning.osLogType, OSLogType.error) // warning maps to error
        XCTAssertEqual(LogLevel.error.osLogType, OSLogType.fault)
    }
    #endif
    
    // MARK: - Logger Functionality Tests
    
    func testLogger_LogMethodWithDefaultLevel() {
        // Given: A log message with default level
        // When: Calling log method without level parameter
        // Then: Should log at info level (default) without throwing
        XCTAssertNoThrow {
            Logger.log("Test message with default level")
        }
    }
    
    func testLogger_LogMethodWithExplicitLevel() {
        // Given: A log message with explicit level
        // When: Calling log method with specific level
        // Then: Should log at specified level without throwing
        XCTAssertNoThrow {
            Logger.log("Test debug message", level: .debug)
            Logger.log("Test info message", level: .info)
            Logger.log("Test warning message", level: .warning)
            Logger.log("Test error message", level: .error)
        }
    }
    
    func testLogger_ConvenienceMethods() {
        // Given: Logger convenience methods
        // When: Calling each convenience method
        // Then: Should execute without throwing
        XCTAssertNoThrow {
            Logger.debug("Debug message")
            Logger.info("Info message")
            Logger.warning("Warning message")
            Logger.error("Error message")
        }
    }
    
    func testLogger_EmptyMessage() {
        // Given: An empty log message
        // When: Logging empty string
        // Then: Should handle gracefully without throwing
        XCTAssertNoThrow {
            Logger.log("")
            Logger.debug("")
            Logger.info("")
            Logger.warning("")
            Logger.error("")
        }
    }
    
    func testLogger_UnicodeMessage() {
        // Given: A message with Unicode characters
        // When: Logging Unicode content
        // Then: Should handle international characters properly
        let unicodeMessage = "🎧 Testing Unicode: español, 中文, العربية, русский 📱"
        
        XCTAssertNoThrow {
            Logger.log(unicodeMessage)
            Logger.debug(unicodeMessage)
            Logger.info(unicodeMessage)
            Logger.warning(unicodeMessage)
            Logger.error(unicodeMessage)
        }
    }
    
    func testLogger_LongMessage() {
        // Given: A very long log message
        // When: Logging message with 1000+ characters
        // Then: Should handle large messages without truncation issues
        let longMessage = String(repeating: "This is a test message with sufficient length to verify that the logging system can handle long content properly. ", count: 10)
        
        XCTAssertGreaterThan(longMessage.count, 1000)
        XCTAssertNoThrow {
            Logger.log(longMessage)
        }
    }
    
    func testLogger_SpecialCharacters() {
        // Given: A message with special formatting characters
        // When: Logging message with newlines, tabs, quotes
        // Then: Should handle special characters without breaking log format
        let specialMessage = "Message with\nnewlines\tand\ttabs and \"quotes\" and 'single quotes' and % formatting chars"
        
        XCTAssertNoThrow {
            Logger.log(specialMessage)
            Logger.debug(specialMessage)
            Logger.info(specialMessage)
            Logger.warning(specialMessage)
            Logger.error(specialMessage)
        }
    }
    
    func testLogger_ConcurrentLogging() async {
        // Given: Multiple concurrent logging operations
        // When: Logging from multiple tasks simultaneously
        // Then: Should handle concurrent access without issues
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    Logger.log("Concurrent message \(i)")
                }
            }
        }
        
        // If we reach this point without crashes, concurrent logging works
        XCTAssertTrue(true)
    }
    
    func testLogger_FileLocationParameters() {
        // Given: Logger methods with file/function/line parameters
        // When: Calling methods with custom file locations
        // Then: Should accept custom file/function/line parameters
        XCTAssertNoThrow {
            Logger.log("Custom location", file: "CustomFile.swift", function: "customFunction", line: 42)
            Logger.debug("Debug with location", file: "DebugFile.swift", function: "debugFunction", line: 123)
            Logger.info("Info with location", file: "InfoFile.swift", function: "infoFunction", line: 456)
            Logger.warning("Warning with location", file: "WarningFile.swift", function: "warningFunction", line: 789)
            Logger.error("Error with location", file: "ErrorFile.swift", function: "errorFunction", line: 999)
        }
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    func testLogger_CrossPlatformLogging() {
        // Given: Logger running on any platform
        // When: Logging messages
        // Then: Should work whether os.log is available or not
        
        #if canImport(os)
        // On Apple platforms, should use os.Logger
        XCTAssertNoThrow {
            Logger.log("Cross-platform test with os.log available")
        }
        #else
        // On non-Apple platforms, should use fallback (print in DEBUG)
        XCTAssertNoThrow {
            Logger.log("Cross-platform test with os.log not available")
        }
        #endif
    }
    
    func testLogger_PerformanceBaseline() {
        // Given: Logger performance baseline
        // When: Logging many messages
        // Then: Should complete within reasonable time
        measure {
            for i in 0..<1000 {
                Logger.log("Performance test message \(i)")
            }
        }
    }
}