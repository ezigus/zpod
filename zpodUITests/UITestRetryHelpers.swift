//
//  UITestRetryHelpers.swift
//  zpodUITests
//
//  Created for Issue 02.7.3 - CI Test Flakiness: Phase 3 - Infrastructure Improvements
//  Provides retry mechanisms for operations that may fail due to timing/async issues
//
//  Addresses: 70% of test failures (timing/synchronization category)
//

import Foundation
import XCTest

// MARK: - Retry Errors

/// Errors that can occur during retry operations
enum TestRetryError: Error, CustomStringConvertible {
  case elementNotFound(identifier: String)
  case elementNotHittable(identifier: String)
  case operationFailed(reason: String)
  case maxAttemptsExceeded(attempts: Int, lastError: Error?)

  var description: String {
    switch self {
    case .elementNotFound(let id):
      return "Element not found: '\(id)'"
    case .elementNotHittable(let id):
      return "Element not hittable: '\(id)'"
    case .operationFailed(let reason):
      return "Operation failed: \(reason)"
    case .maxAttemptsExceeded(let attempts, let lastError):
      if let error = lastError {
        return "Max retry attempts (\(attempts)) exceeded. Last error: \(error)"
      }
      return "Max retry attempts (\(attempts)) exceeded"
    }
  }
}

// MARK: - Retry Mechanism

extension XCTestCase {

  /// Retries an operation that may fail due to timing or async issues
  ///
  /// This helper addresses timing/synchronization failures by automatically retrying
  /// operations with exponential backoff. Useful for operations that interact with
  /// async UI updates, network responses, or state transitions.
  ///
  /// Example:
  /// ```swift
  /// let value = try retryOnFailure(attempts: 3, delay: 0.5) {
  ///   guard someAsyncState.isReady else {
  ///     throw TestRetryError.operationFailed(reason: "State not ready")
  ///   }
  ///   return someAsyncState.value
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Initial delay between attempts in seconds (default: 0.5)
  ///   - useExponentialBackoff: Whether to use exponential backoff (default: true)
  ///   - operation: The operation to retry
  /// - Returns: The result of the operation if successful
  /// - Throws: `TestRetryError.maxAttemptsExceeded` if all attempts fail
  @MainActor
  func retryOnFailure<T>(
    attempts: Int = 3,
    delay: TimeInterval = 0.5,
    useExponentialBackoff: Bool = true,
    operation: () throws -> T
  ) rethrows -> T {
    var lastError: Error?
    var currentDelay = delay

    for attempt in 1...attempts {
      do {
        return try operation()
      } catch {
        lastError = error

        if attempt < attempts {
          // Sleep before retry
          Thread.sleep(forTimeInterval: currentDelay)

          // Exponential backoff: 0.5s -> 1.0s -> 2.0s
          if useExponentialBackoff {
            currentDelay *= 2
          }
        }
      }
    }

    // All attempts failed
    throw TestRetryError.maxAttemptsExceeded(attempts: attempts, lastError: lastError)
  }

  /// Retries element discovery with automatic existence checking
  ///
  /// This helper wraps element queries with automatic retry logic, addressing
  /// SwiftUI lazy materialization and async view updates that cause "element not found"
  /// failures.
  ///
  /// Example:
  /// ```swift
  /// let button = try retryElementDiscovery(attempts: 3) {
  ///   app.buttons["Submit"]
  /// } operation: { element in
  ///   XCTAssertTrue(element.exists, "Button should exist")
  ///   element.tap()
  ///   return element
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Delay between attempts in seconds (default: 0.5)
  ///   - query: Closure that returns the element to discover
  ///   - operation: Operation to perform on the discovered element
  /// - Returns: The result of the operation
  /// - Throws: `TestRetryError.elementNotFound` if element never appears
  @MainActor
  func retryElementDiscovery<T>(
    attempts: Int = 3,
    delay: TimeInterval = 0.5,
    query: () -> XCUIElement,
    operation: (XCUIElement) throws -> T
  ) rethrows -> T {
    return try retryOnFailure(attempts: attempts, delay: delay) {
      let element = query()
      guard element.exists else {
        throw TestRetryError.elementNotFound(identifier: element.identifier)
      }
      return try operation(element)
    }
  }

  /// Retries element tap with hittability checking
  ///
  /// Ensures element is both existent and hittable before attempting tap,
  /// with automatic retry on failure. Addresses race conditions where elements
  /// exist but aren't yet interactive.
  ///
  /// Example:
  /// ```swift
  /// try retryTap(on: app.buttons["Submit"], attempts: 3)
  /// ```
  ///
  /// - Parameters:
  ///   - element: The element to tap
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Delay between attempts in seconds (default: 0.5)
  ///   - description: Description for error messages
  /// - Throws: `TestRetryError.elementNotHittable` if element never becomes hittable
  @MainActor
  func retryTap(
    on element: XCUIElement,
    attempts: Int = 3,
    delay: TimeInterval = 0.5,
    description: String? = nil
  ) throws {
    try retryOnFailure(attempts: attempts, delay: delay) {
      guard element.exists else {
        let desc = description ?? element.identifier
        throw TestRetryError.elementNotFound(identifier: desc)
      }

      guard element.isHittable else {
        let desc = description ?? element.identifier
        throw TestRetryError.elementNotHittable(identifier: desc)
      }

      element.tap()
    }
  }

  /// Retries an assertion with automatic retry on failure
  ///
  /// Useful for assertions that depend on async state updates. Instead of failing
  /// immediately, retries the assertion multiple times to allow state to stabilize.
  ///
  /// Example:
  /// ```swift
  /// try retryAssertion(attempts: 3) {
  ///   XCTAssertTrue(element.isSelected, "Element should be selected")
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Delay between attempts in seconds (default: 0.5)
  ///   - assertion: The assertion to retry
  /// - Throws: The last assertion error if all attempts fail
  @MainActor
  func retryAssertion(
    attempts: Int = 3,
    delay: TimeInterval = 0.5,
    assertion: () throws -> Void
  ) rethrows {
    try retryOnFailure(attempts: attempts, delay: delay, operation: assertion)
  }
}

// MARK: - XCUIElement Retry Extensions

extension XCUIElement {

  /// Taps the element with automatic retry on failure
  ///
  /// Convenience method for retrying taps without explicitly calling retryTap.
  /// Automatically waits for element to be hittable before tapping.
  ///
  /// Example:
  /// ```swift
  /// try app.buttons["Submit"].tapWithRetry(attempts: 3)
  /// ```
  ///
  /// - Parameters:
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Delay between attempts in seconds (default: 0.5)
  /// - Throws: `TestRetryError` if tap never succeeds
  @MainActor
  func tapWithRetry(attempts: Int = 3, delay: TimeInterval = 0.5) throws {
    var lastError: Error?
    var currentDelay = delay

    for attempt in 1...attempts {
      do {
        // Check existence and hittability
        guard self.exists else {
          throw TestRetryError.elementNotFound(identifier: self.identifier)
        }
        guard self.isHittable else {
          throw TestRetryError.elementNotHittable(identifier: self.identifier)
        }

        // Attempt tap
        self.tap()
        return  // Success

      } catch {
        lastError = error

        if attempt < attempts {
          Thread.sleep(forTimeInterval: currentDelay)
          currentDelay *= 2  // Exponential backoff
        }
      }
    }

    // All attempts failed
    throw TestRetryError.maxAttemptsExceeded(attempts: attempts, lastError: lastError)
  }

  /// Waits for element to exist with retry logic
  ///
  /// Unlike `waitForExistence`, this method actively retries the query multiple times,
  /// which can be useful for elements that appear/disappear rapidly or have unstable
  /// view hierarchies.
  ///
  /// - Parameters:
  ///   - attempts: Maximum number of attempts (default: 3)
  ///   - delay: Delay between attempts in seconds (default: 0.5)
  /// - Returns: True if element exists within retry attempts
  @MainActor
  func existsWithRetry(attempts: Int = 3, delay: TimeInterval = 0.5) -> Bool {
    for attempt in 1...attempts {
      if self.exists {
        return true
      }
      if attempt < attempts {
        Thread.sleep(forTimeInterval: delay)
      }
    }
    return false
  }
}
