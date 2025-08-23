import XCTest
@preconcurrency import Foundation
@testable import SharedUtilities

final class ComprehensiveSharedErrorTests: XCTestCase {
    
    // MARK: - Error Case Creation Tests
    
    func testSharedError_NetworkErrorCreation() {
        // Given: A network error message
        let message = "Connection timeout"
        
        // When: Creating a network error
        let error = SharedError.networkError(message)
        
        // Then: Should create correct error case
        switch error {
        case .networkError(let errorMessage):
            XCTAssertEqual(errorMessage, message)
        default:
            XCTFail("Expected networkError case")
        }
    }
    
    func testSharedError_PersistenceErrorCreation() {
        // Given: A persistence error message
        let message = "Database write failed"
        
        // When: Creating a persistence error
        let error = SharedError.persistenceError(message)
        
        // Then: Should create correct error case
        switch error {
        case .persistenceError(let errorMessage):
            XCTAssertEqual(errorMessage, message)
        default:
            XCTFail("Expected persistenceError case")
        }
    }
    
    func testSharedError_InvalidInputErrorCreation() {
        // Given: An invalid input error message
        let message = "URL format is invalid"
        
        // When: Creating an invalid input error
        let error = SharedError.invalidInput(message)
        
        // Then: Should create correct error case
        switch error {
        case .invalidInput(let errorMessage):
            XCTAssertEqual(errorMessage, message)
        default:
            XCTFail("Expected invalidInput case")
        }
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    func testSharedError_NetworkErrorDescription() {
        // Given: A network error with specific message
        let message = "Server unreachable"
        let error = SharedError.networkError(message)
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should format properly with prefix
        XCTAssertEqual(description, "Network error: \(message)")
        XCTAssertNotNil(description)
    }
    
    func testSharedError_PersistenceErrorDescription() {
        // Given: A persistence error with specific message
        let message = "Disk full"
        let error = SharedError.persistenceError(message)
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should format properly with prefix
        XCTAssertEqual(description, "Persistence error: \(message)")
        XCTAssertNotNil(description)
    }
    
    func testSharedError_InvalidInputErrorDescription() {
        // Given: An invalid input error with specific message
        let message = "Missing required field"
        let error = SharedError.invalidInput(message)
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should format properly with prefix
        XCTAssertEqual(description, "Invalid input: \(message)")
        XCTAssertNotNil(description)
    }
    
    // MARK: - Edge Case Tests
    
    func testSharedError_EmptyMessageHandling() {
        // Given: Errors with empty messages
        let networkError = SharedError.networkError("")
        let persistenceError = SharedError.persistenceError("")
        let invalidInputError = SharedError.invalidInput("")
        
        // When: Getting error descriptions
        // Then: Should handle empty messages gracefully
        XCTAssertEqual(networkError.errorDescription, "Network error: ")
        XCTAssertEqual(persistenceError.errorDescription, "Persistence error: ")
        XCTAssertEqual(invalidInputError.errorDescription, "Invalid input: ")
    }
    
    func testSharedError_UnicodeMessageHandling() {
        // Given: Errors with Unicode messages
        let unicodeMessage = "🚨 连接失败: réseau indisponible 📡"
        let networkError = SharedError.networkError(unicodeMessage)
        let persistenceError = SharedError.persistenceError(unicodeMessage)
        let invalidInputError = SharedError.invalidInput(unicodeMessage)
        
        // When: Getting error descriptions
        // Then: Should preserve Unicode characters
        XCTAssertEqual(networkError.errorDescription, "Network error: \(unicodeMessage)")
        XCTAssertEqual(persistenceError.errorDescription, "Persistence error: \(unicodeMessage)")
        XCTAssertEqual(invalidInputError.errorDescription, "Invalid input: \(unicodeMessage)")
    }
    
    func testSharedError_LongMessageHandling() {
        // Given: Errors with very long messages
        let longMessage = String(repeating: "This is a very long error message that should be handled properly regardless of length. ", count: 50)
        let networkError = SharedError.networkError(longMessage)
        
        // When: Getting error description
        let description = networkError.errorDescription
        
        // Then: Should handle long messages without truncation
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Network error:"))
        XCTAssertTrue(description!.contains(longMessage))
        XCTAssertGreaterThan(description!.count, 1000)
    }
    
    func testSharedError_SpecialCharacterHandling() {
        // Given: Errors with special characters
        let specialMessage = "Error with\nnewlines\tand\ttabs and \"quotes\" and 'apostrophes' and % symbols"
        let errors = [
            SharedError.networkError(specialMessage),
            SharedError.persistenceError(specialMessage),
            SharedError.invalidInput(specialMessage)
        ]
        
        // When: Getting error descriptions
        // Then: Should preserve special characters
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertTrue(description!.contains(specialMessage))
        }
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSharedError_SendableConformance() async {
        // Given: SharedError instances
        let errors: [SharedError] = [
            .networkError("Network test"),
            .persistenceError("Persistence test"),
            .invalidInput("Input test")
        ]
        
        // When: Using errors across concurrency boundaries
        await withTaskGroup(of: Void.self) { group in
            for error in errors {
                group.addTask {
                    // This should compile without warnings if SharedError is properly Sendable
                    let _ = error.errorDescription
                }
            }
        }
        
        // Then: Should compile and execute without issues
        XCTAssertEqual(errors.count, 3)
    }
    
    // MARK: - Error Equality Tests
    
    func testSharedError_CaseEquality() {
        // Given: Same error cases with same messages
        let networkError1 = SharedError.networkError("Connection failed")
        let networkError2 = SharedError.networkError("Connection failed")
        let _ = SharedError.persistenceError("Write failed")
        let _ = SharedError.persistenceError("Write failed")
        
        // When: Comparing errors
        // Then: Same case and message should be considered equal (if Equatable)
        // Note: SharedError doesn't currently implement Equatable, so we test via switch patterns
        
        switch networkError1 {
        case .networkError(let msg1):
            switch networkError2 {
            case .networkError(let msg2):
                XCTAssertEqual(msg1, msg2)
            default:
                XCTFail("Expected matching network error")
            }
        default:
            XCTFail("Expected network error")
        }
    }
    
    func testSharedError_CaseInequality() {
        // Given: Different error cases
        let networkError = SharedError.networkError("Connection failed")
        let persistenceError = SharedError.persistenceError("Connection failed")
        let invalidInputError = SharedError.invalidInput("Connection failed")
        
        // When: Comparing different error types
        // Then: Should be different cases even with same message
        var networkMatched = false
        var persistenceMatched = false
        var inputMatched = false
        
        switch networkError {
        case .networkError: networkMatched = true
        default: break
        }
        
        switch persistenceError {
        case .persistenceError: persistenceMatched = true
        default: break
        }
        
        switch invalidInputError {
        case .invalidInput: inputMatched = true
        default: break
        }
        
        XCTAssertTrue(networkMatched)
        XCTAssertTrue(persistenceMatched)
        XCTAssertTrue(inputMatched)
    }
    
    // MARK: - Real-World Usage Tests
    
    func testSharedError_NetworkErrorUsageCases() {
        // Given: Common network error scenarios
        let scenarios = [
            "Connection timeout",
            "Server returned 404",
            "No internet connection",
            "SSL certificate invalid",
            "Request rate limit exceeded"
        ]
        
        // When: Creating network errors for each scenario
        let errors = scenarios.map { SharedError.networkError($0) }
        
        // Then: Should create valid errors with appropriate descriptions
        for (error, scenario) in zip(errors, scenarios) {
            XCTAssertEqual(error.errorDescription, "Network error: \(scenario)")
        }
    }
    
    func testSharedError_PersistenceErrorUsageCases() {
        // Given: Common persistence error scenarios
        let scenarios = [
            "Database locked",
            "Disk full",
            "Permission denied",
            "Corrupted data",
            "Transaction failed"
        ]
        
        // When: Creating persistence errors for each scenario
        let errors = scenarios.map { SharedError.persistenceError($0) }
        
        // Then: Should create valid errors with appropriate descriptions
        for (error, scenario) in zip(errors, scenarios) {
            XCTAssertEqual(error.errorDescription, "Persistence error: \(scenario)")
        }
    }
    
    func testSharedError_InvalidInputErrorUsageCases() {
        // Given: Common invalid input error scenarios
        let scenarios = [
            "URL format invalid",
            "Required field missing",
            "Value out of range",
            "Invalid character in input",
            "Malformed JSON"
        ]
        
        // When: Creating invalid input errors for each scenario
        let errors = scenarios.map { SharedError.invalidInput($0) }
        
        // Then: Should create valid errors with appropriate descriptions
        for (error, scenario) in zip(errors, scenarios) {
            XCTAssertEqual(error.errorDescription, "Invalid input: \(scenario)")
        }
    }
    
    // MARK: - Error Throwing and Catching Tests
    
    func testSharedError_ThrowingAndCatching() {
        // Given: Functions that throw SharedError
        func throwNetworkError() throws {
            throw SharedError.networkError("Test network error")
        }
        
        func throwPersistenceError() throws {
            throw SharedError.persistenceError("Test persistence error")
        }
        
        func throwInvalidInputError() throws {
            throw SharedError.invalidInput("Test invalid input error")
        }
        
        // When: Catching thrown errors
        // Then: Should properly catch and identify error types
        
        do {
            try throwNetworkError()
            XCTFail("Expected error to be thrown")
        } catch let error as SharedError {
            switch error {
            case .networkError(let message):
                XCTAssertEqual(message, "Test network error")
            default:
                XCTFail("Expected network error")
            }
        } catch {
            XCTFail("Expected SharedError")
        }
        
        do {
            try throwPersistenceError()
            XCTFail("Expected error to be thrown")
        } catch SharedError.persistenceError(let message) {
            XCTAssertEqual(message, "Test persistence error")
        } catch {
            XCTFail("Expected SharedError.persistenceError")
        }
        
        do {
            try throwInvalidInputError()
            XCTFail("Expected error to be thrown")
        } catch SharedError.invalidInput(let message) {
            XCTAssertEqual(message, "Test invalid input error")
        } catch {
            XCTFail("Expected SharedError.invalidInput")
        }
    }
}