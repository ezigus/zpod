//
//  UITestWait.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Unified wait API - single entry point for all waiting operations
//
//  Replaces 14+ scattered wait methods with one clear API
//

import Foundation
import XCTest

// MARK: - Unified Wait API

/// Conditions that can be waited for on UI elements.
///
/// **Philosophy**: Instead of choosing from 14+ wait methods, use one API with clear conditions.
///
/// **Example**:
/// ```swift
/// // Old way (confusing - which wait method do I use?)
/// element.waitForExistence(timeout: 5.0)
/// element.waitForHittable(timeout: 5.0)
/// element.waitForStable(timeout: 5.0)
/// element.waitForAnimationComplete()
///
/// // New way (clear intent)
/// element.waitUntil(.exists, timeout: 5.0)
/// element.waitUntil(.hittable, timeout: 5.0)
/// element.waitUntil(.stable(), timeout: 5.0)
/// element.waitUntil(.stable(window: 0.3), timeout: 2.0)  // animation complete
/// ```
public enum WaitCondition {
  /// Wait for element to exist in accessibility hierarchy.
  /// Most common condition - use this unless you need something more specific.
  case exists

  /// Wait for element to be hittable (exists, visible, not obscured, and stable).
  /// Use before tapping to ensure interaction succeeds.
  case hittable

  /// Wait for element's frame to stabilize (not animating).
  /// - Parameter window: Duration element must remain stable (default: 0.3s for animations)
  case stable(window: TimeInterval = 0.3)

  /// Wait for element's value to match expected value.
  /// Useful for labels/text fields that update asynchronously.
  case value(String)

  /// Wait for element to disappear (no longer exists or not hittable).
  /// Use after dismissing modals or completing transitions.
  case disappeared
}

extension XCUIElement {

  /// Unified wait API - single entry point for all waiting operations.
  ///
  /// **Why this exists**: Eliminates confusion from 14+ wait methods scattered across 4 files.
  /// Instead of remembering which helper to import and which method to call, use one API.
  ///
  /// **How it works**: Delegates to existing wait primitives rather than reimplementing.
  /// This means you get the same battle-tested wait logic, just with a cleaner interface.
  ///
  /// **Usage**:
  /// ```swift
  /// // Wait for existence (most common)
  /// guard button.waitUntil(.exists) else {
  ///     XCTFail("Button not found")
  ///     return
  /// }
  ///
  /// // Wait for hittability before tapping
  /// XCTAssertTrue(button.waitUntil(.hittable))
  /// button.tap()
  ///
  /// // Wait for animation to complete
  /// sheet.waitUntil(.stable(window: 0.3))
  ///
  /// // Wait for value to update
  /// label.waitUntil(.value("Complete"))
  ///
  /// // Wait for element to disappear
  /// loadingIndicator.waitUntil(.disappeared)
  /// ```
  ///
  /// **Default timeout**: Uses test foundation defaults if not specified
  /// - CI: 12s for exists/hittable, 6s for short operations
  /// - Local: 8s for exists/hittable, 4s for short operations
  ///
  /// - Parameters:
  ///   - condition: What to wait for
  ///   - timeout: Maximum time to wait (nil = use defaults)
  /// - Returns: True if condition met within timeout
  @MainActor
  @discardableResult
  public func waitUntil(_ condition: WaitCondition, timeout: TimeInterval? = nil) -> Bool {
    switch condition {

    case .exists:
      // Delegates to XCUITest's built-in event-based waiting
      let effectiveTimeout = timeout ?? defaultTimeout()
      return self.waitForExistence(timeout: effectiveTimeout)

    case .hittable:
      // Delegates to UITestStableWaitHelpers.waitForHittable()
      // (Waits for exists + isHittable + optional frame stability)
      let effectiveTimeout = timeout ?? defaultTimeout()
      return self.waitForHittable(timeout: effectiveTimeout, requireStability: true)

    case .stable(let stabilityWindow):
      // Delegates to UITestStableWaitHelpers.waitForStable()
      // (Polls frame changes until stable for specified window)
      let effectiveTimeout = timeout ?? defaultShortTimeout()
      return self.waitForStable(timeout: effectiveTimeout, stabilityWindow: stabilityWindow)

    case .value(let expectedValue):
      // Delegates to UITestStableWaitHelpers.waitForValueStable()
      // then checks if value matches
      let effectiveTimeout = timeout ?? defaultShortTimeout()

      // First wait for value to stabilize
      guard self.waitForValueStable(timeout: effectiveTimeout) else {
        return false
      }

      // Then check if it matches expected value
      return (self.value as? String) == expectedValue

    case .disappeared:
      // Delegates to UITestHelpers.waitForElementToDisappear()
      // (Uses predicate-based waiting for !exists)
      let effectiveTimeout = timeout ?? defaultShortTimeout()

      // waitForElementToDisappear is a free function, not an instance method
      if !self.exists { return true }

      let predicate = NSPredicate { _, _ in
        !self.exists
      }

      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
      expectation.expectationDescription = "Wait for element to disappear"

      let result = XCTWaiter().wait(for: [expectation], timeout: effectiveTimeout)
      return result == .completed
    }
  }

  // MARK: - Default Timeouts

  /// Returns default timeout for standard wait operations.
  /// CI gets longer timeouts to handle slower execution.
  private func defaultTimeout() -> TimeInterval {
    let isCI = ProcessInfo.processInfo.environment["CI"] != nil
    let baseTimeout = isCI ? 12.0 : 8.0

    // Apply timeout scale if set (for debugging)
    if let scaleString = ProcessInfo.processInfo.environment["UITEST_TIMEOUT_SCALE"],
       let scale = TimeInterval(scaleString), scale > 0 {
      return baseTimeout * scale
    }

    return baseTimeout
  }

  /// Returns default timeout for short wait operations.
  /// CI gets longer timeouts to handle slower execution.
  private func defaultShortTimeout() -> TimeInterval {
    let isCI = ProcessInfo.processInfo.environment["CI"] != nil
    let baseTimeout = isCI ? 6.0 : 4.0

    // Apply timeout scale if set (for debugging)
    if let scaleString = ProcessInfo.processInfo.environment["UITEST_TIMEOUT_SCALE"],
       let scale = TimeInterval(scaleString), scale > 0 {
      return baseTimeout * scale
    }

    return baseTimeout
  }
}

// MARK: - Convenience Extensions

extension XCUIElement {

  /// Waits for element to exist and be hittable, then taps it.
  ///
  /// **Convenience method** for the common pattern:
  /// ```swift
  /// guard element.waitUntil(.hittable) else { return }
  /// element.tap()
  /// ```
  ///
  /// **Usage**:
  /// ```swift
  /// // Old way
  /// if button.waitUntil(.hittable, timeout: 5.0) {
  ///     button.tap()
  /// } else {
  ///     XCTFail("Button not hittable")
  /// }
  ///
  /// // New way
  /// try button.tapWhenReady(timeout: 5.0)
  /// ```
  ///
  /// - Parameter timeout: Maximum time to wait for hittability
  /// - Throws: `XCTestError` if element not hittable within timeout
  @MainActor
  public func tapWhenReady(timeout: TimeInterval? = nil) throws {
    guard waitUntil(.hittable, timeout: timeout) else {
      throw XCTestError(_nsError: NSError(
        domain: "UITestWait",
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "Element '\(self.identifier)' not hittable within \(timeout ?? defaultTimeout())s"
        ]
      ))
    }
    tap()
  }
}

// MARK: - Migration Guide
//
// UITestWait provides a unified API to replace 14+ scattered wait methods.
//
// **Migration from existing helpers**:
//
// Old: element.waitBriefly(timeout: 0.5)
// New: element.waitUntil(.exists, timeout: 0.5)
//
// Old: element.waitForPageLoad(timeout: 2.0)
// New: element.waitUntil(.exists, timeout: 2.0)
//
// Old: element.waitForAnimationComplete()
// New: element.waitUntil(.stable(window: 0.3))
//
// Old: waitForElementToDisappear(element, timeout: 5.0)
// New: element.waitUntil(.disappeared, timeout: 5.0)
//
// **Note**: Existing helper methods remain available for backward compatibility.
// Gradually migrate to the unified API as code is touched.
