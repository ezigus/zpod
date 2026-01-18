//
//  BaseScreen.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Base protocol for Page Object pattern
//
//  Architecture Pattern: https://swiftwithmajid.com/2021/03/24/ui-testing-using-page-object-pattern-in-swift/
//

import Foundation
import XCTest

/// Base protocol for all Page Objects.
///
/// **Page Object Pattern**: Encapsulates screen-specific element queries and actions.
/// Instead of duplicating element discovery logic across tests, each screen has a dedicated
/// object that knows how to find its elements and perform its actions.
///
/// **Benefits**:
/// 1. **Single source of truth**: When UI changes, update one file instead of 19 test files
/// 2. **Reusable**: Share element queries across multiple tests
/// 3. **Readable**: Tests read like user stories instead of XCUIElement queries
/// 4. **Maintainable**: Encapsulated fallback chains instead of copy-paste
///
/// **Example**:
/// ```swift
/// // Without Page Objects (duplicated across 10 test files):
/// let candidates: [XCUIElement] = [
///     app.buttons.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
///     app.otherElements.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
///     // ... 6 more fallbacks
/// ]
/// guard let element = waitForAnyElement(candidates, ...) else { ... }
/// element.tap()
///
/// // With Page Objects (encapsulated, reusable):
/// let settings = SettingsScreen(app: app)
/// XCTAssertTrue(settings.navigateToSwipeActions())
/// ```
///
/// **Issue**: #12.3 - Test Infrastructure Cleanup
@MainActor
public protocol BaseScreen {
  /// The application instance this screen operates on.
  var app: XCUIApplication { get }
}

/// Default wait helpers for all Page Objects.
extension BaseScreen {

  /// Wait for an element using the unified wait API.
  ///
  /// Convenience method to avoid repeating `element.waitUntil()` in every screen.
  ///
  /// - Parameters:
  ///   - element: Element to wait for
  ///   - condition: What to wait for (default: .exists)
  ///   - timeout: Maximum time to wait (nil = use defaults)
  /// - Returns: True if condition met
  func wait(
    for element: XCUIElement,
    until condition: WaitCondition = .exists,
    timeout: TimeInterval? = nil
  ) -> Bool {
    return element.waitUntil(condition, timeout: timeout)
  }

  /// Wait for any of multiple elements to appear.
  ///
  /// Useful when UI can be in multiple valid states.
  ///
  /// - Parameters:
  ///   - elements: Elements to check
  ///   - timeout: Maximum time to wait
  /// - Returns: First element that appeared, or nil
  func waitForAny(
    _ elements: [XCUIElement],
    timeout: TimeInterval? = nil
  ) -> XCUIElement? {
    // Fast path: something already exists
    if let existing = elements.first(where: { $0.exists }) {
      return existing
    }

    // Wait using predicate
    var foundElement: XCUIElement?
    let effectiveTimeout = timeout ?? defaultTimeout()

    let predicate = NSPredicate { _, _ in
      for element in elements where element.exists {
        foundElement = element
        return true
      }
      return false
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    let result = XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout)

    return result == .completed ? foundElement : nil
  }

  /// Tap element after verifying it's hittable.
  ///
  /// - Parameters:
  ///   - element: Element to tap
  ///   - timeout: Maximum time to wait for hittability
  /// - Returns: True if tap succeeded
  @discardableResult
  func tap(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
    guard wait(for: element, until: .hittable, timeout: timeout) else {
      return false
    }
    element.tap()
    return true
  }

  // MARK: - Default Timeouts

  private func defaultTimeout() -> TimeInterval {
    let isCI = ProcessInfo.processInfo.environment["CI"] != nil
    return isCI ? 12.0 : 8.0
  }
}

/// Navigation helpers for Page Objects.
extension BaseScreen {

  /// Navigate using an action and wait for expected element.
  ///
  /// Common pattern: tap something, wait for destination to appear.
  ///
  /// - Parameters:
  ///   - action: Navigation action to perform
  ///   - expectedElement: Element that should appear after navigation
  ///   - timeout: Maximum time to wait
  /// - Returns: True if navigation succeeded
  @discardableResult
  func navigate(
    action: @MainActor () -> Void,
    expecting expectedElement: XCUIElement,
    timeout: TimeInterval? = nil
  ) -> Bool {
    action()
    return wait(for: expectedElement, until: .exists, timeout: timeout)
  }
}
