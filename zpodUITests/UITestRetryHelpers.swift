//
//  UITestRetryHelpers.swift
//  zpodUITests
//
//  Created for Issue #148 - CI Test Flakiness: Phase 3 - Infrastructure Improvements
//  Provides diagnostic helpers and minimal wait utilities
//
//  Philosophy: UI elements appear "immediately or not at all" - if element isn't there,
//  fix the root cause (scroll, verify state, clean setup) instead of retrying.
//

import Foundation
import XCTest

// MARK: - Test Errors

/// Errors that can occur during test operations
enum TestError: Error, CustomStringConvertible {
  case elementNotFound(identifier: String, context: String? = nil)
  case elementNotHittable(identifier: String, context: String? = nil)
  case stateNotReady(description: String)
  case preconditionFailed(condition: String)

  var description: String {
    switch self {
    case .elementNotFound(let id, let context):
      if let context = context {
        return "Element not found: '\(id)' - \(context)"
      }
      return "Element not found: '\(id)'"
    case .elementNotHittable(let id, let context):
      if let context = context {
        return "Element not hittable: '\(id)' - \(context)"
      }
      return "Element not hittable: '\(id)'"
    case .stateNotReady(let description):
      return "State not ready: \(description)"
    case .preconditionFailed(let condition):
      return "Precondition failed: \(condition)"
    }
  }
}

// MARK: - Minimal Wait Helpers

extension XCUIElement {

  /// Waits briefly for element after page load or scroll
  ///
  /// Use ONLY for:
  /// 1. Initial page load (things settling)
  /// 2. Immediately after scroll (SwiftUI lazy materialization)
  ///
  /// If element doesn't appear within short timeout, it won't appear - fix the root cause:
  /// - Scroll to reveal it (discoverWithScrolling)
  /// - Verify state is correct (diagnoseElementAbsence)
  /// - Check preconditions (data loaded, modal dismissed, etc.)
  ///
  /// Example:
  /// ```swift
  /// scrollView.swipeUp()
  /// // Wait briefly for SwiftUI to materialize newly visible elements
  /// XCTAssertTrue(element.waitBriefly(timeout: 0.5))
  /// ```
  ///
  /// - Parameter timeout: Short timeout (default: 0.5s, max recommended: 1.0s)
  /// - Returns: True if element appeared
  @MainActor
  func waitBriefly(timeout: TimeInterval = 0.5) -> Bool {
    return self.waitForExistence(timeout: timeout)
  }

  /// Waits for element to appear after page/view loads
  ///
  /// Use when transitioning to a new view and waiting for initial elements to settle.
  /// Longer than waitBriefly but still short - if element doesn't appear, something is wrong.
  ///
  /// Example:
  /// ```swift
  /// app.buttons["Settings"].tap()
  /// let settingsView = app.otherElements["Settings.Container"]
  /// XCTAssertTrue(settingsView.waitForPageLoad(timeout: 2.0))
  /// ```
  ///
  /// - Parameter timeout: Page load timeout (default: 2.0s, max recommended: 3.0s)
  /// - Returns: True if element appeared
  @MainActor
  func waitForPageLoad(timeout: TimeInterval = 2.0) -> Bool {
    return self.waitForExistence(timeout: timeout)
  }
}

// MARK: - Diagnostic Helpers

extension XCTestCase {

  /// Diagnoses element state and provides actionable feedback
  ///
  /// Instead of retrying, understand the root cause. Checks preconditions and provides
  /// diagnostic information whether element exists or not. Most commonly used to diagnose
  /// why an element isn't appearing.
  ///
  /// Example:
  /// ```swift
  /// let button = app.buttons["Submit"]
  /// guard button.exists else {
  ///   let diagnosis = diagnoseElementState(button, preconditions: [
  ///     "Data loaded": { !app.activityIndicators.firstMatch.exists },
  ///     "Modal dismissed": { !app.sheets.firstMatch.exists },
  ///     "Scrolled into view": { /* check scroll position */ }
  ///   ])
  ///   XCTFail("Submit button not found:\n\(diagnosis)")
  ///   return
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - element: The element to diagnose
  ///   - preconditions: Dictionary of condition name -> check closure
  /// - Returns: Diagnostic message explaining element state
  @MainActor
  func diagnoseElementState(
    _ element: XCUIElement,
    preconditions: [String: () -> Bool] = [:]
  ) -> String {
    guard !element.exists else {
      return "✅ Element exists (identifier: '\(element.identifier)')"
    }

    var diagnosis = "❌ Element not found: '\(element.identifier)'"
    diagnosis += "\n   Type: \(element.elementType.rawValue)"

    // Check preconditions
    if !preconditions.isEmpty {
      diagnosis += "\n\n📋 Preconditions:"
      for (condition, check) in preconditions.sorted(by: { $0.key < $1.key }) {
        let passed = check()
        diagnosis += "\n   \(passed ? "✅" : "❌") \(condition)"
      }
    }

    // Suggestions
    diagnosis += "\n\n💡 Possible fixes:"
    diagnosis += "\n   • Use discoverWithScrolling() if element is off-screen"
    diagnosis += "\n   • Verify state setup (seed applied, data loaded, etc.)"
    diagnosis += "\n   • Check if modal/alert is blocking element"
    diagnosis += "\n   • Ensure cleanup ran (no state pollution from previous test)"

    return diagnosis
  }

  /// Verifies preconditions before proceeding with test
  ///
  /// Fail fast if preconditions aren't met instead of retrying operations.
  ///
  /// Example:
  /// ```swift
  /// verifyPreconditions([
  ///   "Seed applied": { verifySwipeSeedApplied() },
  ///   "App launched": { app.state == .runningForeground },
  ///   "No modals": { !app.sheets.firstMatch.exists }
  /// ])
  /// ```
  ///
  /// - Parameter conditions: Dictionary of condition name -> check closure
  @MainActor
  func verifyPreconditions(_ conditions: [String: () -> Bool]) {
    var failures: [String] = []

    for (condition, check) in conditions.sorted(by: { $0.key < $1.key }) {
      if !check() {
        failures.append("❌ \(condition)")
      }
    }

    guard failures.isEmpty else {
      XCTFail("Preconditions failed:\n" + failures.joined(separator: "\n"))
      return
    }
  }
}

// MARK: - Safe Tap Helper

extension XCUIElement {

  /// Taps element after verifying it's hittable (no retry)
  ///
  /// Deterministic tap - either works immediately or fails with diagnostic message.
  /// If tap fails, fix the root cause instead of retrying.
  ///
  /// Example:
  /// ```swift
  /// try element.tapSafely(
  ///   waitForStability: true,
  ///   context: "Submit button in checkout flow"
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - waitForStability: Whether to wait for frame stability first (default: false)
  ///   - stabilityTimeout: Timeout for stability check (default: 1.0s)
  ///   - context: Description for error messages
  /// - Throws: TestError if element not hittable
  @MainActor
  func tapSafely(
    waitForStability: Bool = false,
    stabilityTimeout: TimeInterval = 1.0,
    context: String? = nil
  ) throws {
    // Optional: wait for stability (animation complete)
    if waitForStability {
      guard self.waitForStable(timeout: stabilityTimeout) else {
        throw TestError.elementNotHittable(
          identifier: self.identifier,
          context: context.map { "\($0) - frame never stabilized" }
        )
      }
      // Note: waitForStable() checks exists at line 43, so element is guaranteed to exist here
    } else {
      // Verify element exists (only needed when stability check was skipped)
      guard self.exists else {
        throw TestError.elementNotFound(
          identifier: self.identifier,
          context: context
        )
      }
    }

    // Verify element is hittable
    guard self.isHittable else {
      throw TestError.elementNotHittable(
        identifier: self.identifier,
        context: context
      )
    }

    // Tap (should succeed immediately)
    self.tap()
  }
}
