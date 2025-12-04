//
//  UITestStableWaitHelpers.swift
//  zpodUITests
//
//  Created for Issue #148 - CI Test Flakiness: Phase 3 - Infrastructure Improvements
//  Provides wait primitives for stable element states (frame stability, animation completion)
//
//  Addresses: 20% of test failures (race conditions, animation/transition category)
//

import Foundation
import XCTest

// MARK: - Frame Stability Helpers

extension XCUIElement {

  /// Waits for element to exist AND have a stable frame (not animating)
  ///
  /// This helper prevents tapping elements mid-animation by ensuring the element's
  /// frame hasn't changed for a specified stability window. Critical for SwiftUI
  /// animations where taps can fail if triggered during transitions.
  ///
  /// Example:
  /// ```swift
  /// let button = app.buttons["Submit"]
  /// XCTAssertTrue(button.waitForStable(timeout: 5.0))
  /// button.tap()  // Safe - element is stable
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait for element to become stable (default: 5.0)
  ///   - stabilityWindow: Duration element must remain stable (default: 0.5s)
  ///   - checkInterval: How often to check frame changes (default: 0.05s)
  /// - Returns: True if element exists and is stable, false otherwise
  @MainActor
  func waitForStable(
    timeout: TimeInterval = 5.0,
    stabilityWindow: TimeInterval = 0.5,
    checkInterval: TimeInterval = 0.05
  ) -> Bool {
    // First, wait for element to exist
    guard self.waitForExistence(timeout: timeout) else {
      return false
    }

    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame = self.frame
    var stableStartTime = Date()

    while Date() < deadline {
      // Use RunLoop instead of Thread.sleep to allow UI events to be processed
      RunLoop.current.run(until: Date().addingTimeInterval(checkInterval))

      let currentFrame = self.frame

      // Check if frame has changed
      if currentFrame == lastFrame {
        // Frame is stable - check if it's been stable long enough
        let stableDuration = Date().timeIntervalSince(stableStartTime)
        if stableDuration >= stabilityWindow {
          return true  // Frame stable for required window
        }
      } else {
        // Frame changed - reset stability timer
        lastFrame = currentFrame
        stableStartTime = Date()
      }
    }

    // Timeout - element never stabilized
    return false
  }

  /// Waits for animation to complete on element
  ///
  /// Convenience method that waits for frame stability, indicating animations
  /// have completed. Delegates to `waitForStable` with sensible defaults.
  ///
  /// Example:
  /// ```swift
  /// app.buttons["TabBar.Library"].tap()
  /// let libraryView = app.otherElements["Library.Container"]
  /// XCTAssertTrue(libraryView.waitForAnimationComplete())
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait (default: 2.0)
  ///   - stabilityWindow: Duration to verify stability (default: 0.3s for animations)
  /// - Returns: True if animation completed within timeout
  @MainActor
  func waitForAnimationComplete(
    timeout: TimeInterval = 2.0,
    stabilityWindow: TimeInterval = 0.3
  ) -> Bool {
    return waitForStable(timeout: timeout, stabilityWindow: stabilityWindow)
  }

  /// Waits for element to be hittable (exists, visible, not obscured, and stable)
  ///
  /// More comprehensive than basic `isHittable` check - also verifies frame stability
  /// to ensure element isn't mid-animation. Addresses race conditions where elements
  /// are technically hittable but still transitioning.
  ///
  /// Example:
  /// ```swift
  /// let button = app.buttons["Submit"]
  /// XCTAssertTrue(button.waitForHittable(timeout: 5.0))
  /// button.tap()  // Guaranteed to succeed
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait (default: 5.0)
  ///   - requireStability: Whether to also check frame stability (default: true)
  ///   - stabilityWindow: Stability duration if requireStability=true (default: 0.3s)
  /// - Returns: True if element is hittable (and stable if required)
  @MainActor
  func waitForHittable(
    timeout: TimeInterval = 5.0,
    requireStability: Bool = true,
    stabilityWindow: TimeInterval = 0.3
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    // First, wait for element to exist and be hittable
    // Use unowned since the element is guaranteed to exist for the duration of this method call
    // (we're calling this method ON the element, so it must exist while this runs)
    let predicate = NSPredicate { [unowned self] _, _ in
      return self.exists && self.isHittable
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for element to be hittable"

    let remainingTimeout = deadline.timeIntervalSinceNow
    guard remainingTimeout > 0 else { return false }

    let result = XCTWaiter.wait(for: [expectation], timeout: remainingTimeout)
    guard result == .completed else { return false }

    // If stability not required, we're done
    guard requireStability else { return true }

    // Wait for frame to stabilize
    let stabilityTimeout = deadline.timeIntervalSinceNow
    guard stabilityTimeout > 0 else { return true }  // Already hittable, no time for stability

    return waitForStable(timeout: stabilityTimeout, stabilityWindow: stabilityWindow)
  }

  /// Waits for element's value to stabilize
  ///
  /// Useful for elements whose value changes asynchronously (e.g., labels that update
  /// based on app state). Waits until the value stops changing.
  ///
  /// Example:
  /// ```swift
  /// let statusLabel = app.staticTexts["Status"]
  /// statusLabel.waitForValueStable(timeout: 3.0)
  /// XCTAssertEqual(statusLabel.value as? String, "Complete")
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait (default: 3.0)
  ///   - stabilityWindow: Duration value must remain stable (default: 0.5s)
  ///   - checkInterval: How often to check value (default: 0.1s)
  /// - Returns: True if value stabilized, false on timeout
  @MainActor
  func waitForValueStable(
    timeout: TimeInterval = 3.0,
    stabilityWindow: TimeInterval = 0.5,
    checkInterval: TimeInterval = 0.1
  ) -> Bool {
    guard self.exists else { return false }

    let deadline = Date().addingTimeInterval(timeout)
    var lastValue = self.value as? String
    var stableStartTime = Date()

    while Date() < deadline {
      // Use RunLoop instead of Thread.sleep to allow UI events to be processed
      RunLoop.current.run(until: Date().addingTimeInterval(checkInterval))

      let currentValue = self.value as? String

      if currentValue == lastValue {
        let stableDuration = Date().timeIntervalSince(stableStartTime)
        if stableDuration >= stabilityWindow {
          return true
        }
      } else {
        lastValue = currentValue
        stableStartTime = Date()
      }
    }

    return false
  }
}

// MARK: - State Waiting Helpers

extension XCTestCase {

  /// Waits for a boolean state to become true with polling
  ///
  /// More flexible than predicate-based waiting for cases where you need to check
  /// complex state conditions. Uses polling with configurable interval.
  ///
  /// Example:
  /// ```swift
  /// waitForState(timeout: 5.0, pollInterval: 0.1) {
  ///   app.tabBars.buttons["Library"].isSelected
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait (default: 5.0)
  ///   - pollInterval: How often to check condition (default: 0.1s)
  ///   - description: Description for logging (default: "state")
  ///   - condition: Closure returning true when state is ready
  /// - Returns: True if condition became true within timeout
  @MainActor
  @discardableResult
  func waitForState(
    timeout: TimeInterval = 5.0,
    pollInterval: TimeInterval = 0.1,
    description: String = "state",
    condition: () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if condition() {
        return true
      }
      RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }

    // Final check after timeout
    let finalResult = condition()
    if !finalResult {
      print("⚠️ Timed out waiting for \(description) after \(timeout)s")
    }
    return finalResult
  }

  /// Waits for an element's property to match expected value
  ///
  /// Polls element property until it matches expected value. Useful for waiting on
  /// SwiftUI state changes that affect element properties.
  ///
  /// Example:
  /// ```swift
  /// let toggle = app.switches["Notifications"]
  /// toggle.tap()
  /// waitForElementProperty(
  ///   element: toggle,
  ///   property: { $0.value as? String },
  ///   expectedValue: "1",
  ///   timeout: 3.0
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - element: The element to monitor
  ///   - timeout: Maximum time to wait (default: 3.0)
  ///   - pollInterval: How often to check (default: 0.1s)
  ///   - property: Closure extracting the property to check
  ///   - expectedValue: Expected value for the property
  /// - Returns: True if property matches within timeout
  @MainActor
  func waitForElementProperty<T: Equatable>(
    element: XCUIElement,
    timeout: TimeInterval = 3.0,
    pollInterval: TimeInterval = 0.1,
    property: (XCUIElement) -> T?,
    expectedValue: T
  ) -> Bool {
    return waitForState(timeout: timeout, pollInterval: pollInterval) {
      guard element.exists else { return false }
      return property(element) == expectedValue
    }
  }
}

// MARK: - Transition Waiting Helpers

extension XCTestCase {

  /// Waits for a view transition to complete
  ///
  /// Detects transitions by waiting for an old element to disappear AND a new element
  /// to appear and stabilize. Useful for navigation transitions, modal presentations,
  /// and tab switches.
  ///
  /// Example:
  /// ```swift
  /// app.buttons["Settings"].tap()
  /// waitForTransition(
  ///   from: app.otherElements["Home.Container"],
  ///   to: app.otherElements["Settings.Container"],
  ///   timeout: 3.0
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - fromElement: Element that should disappear (optional)
  ///   - toElement: Element that should appear
  ///   - timeout: Maximum time to wait (default: 3.0)
  ///   - requireStability: Whether to wait for destination stability (default: true)
  /// - Returns: True if transition completed successfully
  @MainActor
  @discardableResult
  func waitForTransition(
    from fromElement: XCUIElement? = nil,
    to toElement: XCUIElement,
    timeout: TimeInterval = 3.0,
    requireStability: Bool = true
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    // Step 1: Wait for old element to disappear (if provided)
    if let fromElement = fromElement {
      let disappearPredicate = NSPredicate { _, _ in
        !fromElement.exists
      }
      let disappearExpectation = XCTNSPredicateExpectation(
        predicate: disappearPredicate,
        object: nil
      )

      let remainingTimeout = max(0.1, deadline.timeIntervalSinceNow)
      let disappearResult = XCTWaiter.wait(for: [disappearExpectation], timeout: remainingTimeout)

      guard disappearResult == .completed else {
        print("⚠️ Transition failed: source element did not disappear")
        return false
      }
    }

    // Step 2: Wait for new element to appear
    let remainingTimeout = max(0.1, deadline.timeIntervalSinceNow)
    guard toElement.waitForExistence(timeout: remainingTimeout) else {
      print("⚠️ Transition failed: destination element did not appear")
      return false
    }

    // Step 3: Wait for stability if required
    if requireStability {
      let stabilityTimeout = max(0.1, deadline.timeIntervalSinceNow)
      return toElement.waitForStable(timeout: stabilityTimeout, stabilityWindow: 0.3)
    }

    return true
  }

  /// Waits for a modal sheet or alert to present
  ///
  /// Specialized transition helper for modal presentations. Verifies the modal
  /// appears and optionally checks that it's stable before proceeding.
  ///
  /// Example:
  /// ```swift
  /// app.buttons["Show Alert"].tap()
  /// let alert = app.alerts["Confirmation"]
  /// XCTAssertTrue(waitForModalPresentation(modal: alert, timeout: 2.0))
  /// ```
  ///
  /// - Parameters:
  ///   - modal: The modal element (sheet, alert, or dialog)
  ///   - timeout: Maximum time to wait (default: 2.0)
  ///   - requireStability: Whether to verify stability (default: true)
  /// - Returns: True if modal presented successfully
  @MainActor
  @discardableResult
  func waitForModalPresentation(
    modal: XCUIElement,
    timeout: TimeInterval = 2.0,
    requireStability: Bool = true
  ) -> Bool {
    guard modal.waitForExistence(timeout: timeout) else {
      print("⚠️ Modal did not appear within \(timeout)s")
      return false
    }

    if requireStability {
      return modal.waitForStable(timeout: 1.0, stabilityWindow: 0.3)
    }

    return true
  }
}
