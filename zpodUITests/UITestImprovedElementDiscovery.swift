//
//  UITestImprovedElementDiscovery.swift
//  zpodUITests
//
//  Created for Issue 02.7.3 - CI Test Flakiness: Phase 3 - Infrastructure Improvements
//  Provides enhanced element discovery with scroll support for lazy-loaded SwiftUI views
//
//  Addresses: SwiftUI lazy materialization causing "element not found" errors
//

import Foundation
import XCTest

// MARK: - Scroll-Based Element Discovery

extension XCUIElement {

  /// Discovers element with automatic scrolling if needed
  ///
  /// SwiftUI often uses lazy rendering - elements don't exist in the accessibility
  /// tree until scrolled into view. This helper automatically scrolls to reveal
  /// elements that aren't immediately visible.
  ///
  /// Example:
  /// ```swift
  /// let episodeList = app.scrollViews["Episode.List"]
  /// let episode = app.buttons["Episode-123"]
  /// XCTAssertTrue(episode.discoverWithScrolling(in: episodeList, timeout: 5.0))
  /// episode.tap()
  /// ```
  ///
  /// - Parameters:
  ///   - scrollView: The scroll container to search within
  ///   - timeout: Maximum time to search (default: 5.0)
  ///   - maxScrollAttempts: Maximum number of scroll gestures (default: 10)
  ///   - scrollDirection: Direction to scroll (default: .up for downward scrolling)
  /// - Returns: True if element was discovered
  @MainActor
  func discoverWithScrolling(
    in scrollView: XCUIElement,
    timeout: TimeInterval = 5.0,
    maxScrollAttempts: Int = 10,
    scrollDirection: ScrollDirection = .up
  ) -> Bool {
    // Fast path: element already exists
    if self.waitForExistence(timeout: 1.0) {
      return true
    }

    // Element doesn't exist - try scrolling to reveal it
    let deadline = Date().addingTimeInterval(timeout)

    for attempt in 1...maxScrollAttempts {
      // Check if we've run out of time
      guard Date() < deadline else {
        print("⚠️ Timed out searching for element after \(attempt-1) scroll attempts")
        return false
      }

      // Perform scroll gesture based on direction
      switch scrollDirection {
      case .up:
        scrollView.swipeUp()
      case .down:
        scrollView.swipeDown()
      case .left:
        scrollView.swipeLeft()
      case .right:
        scrollView.swipeRight()
      }

      // Check if element appeared after scroll
      let remainingTimeout = min(1.0, deadline.timeIntervalSinceNow)
      if self.waitForExistence(timeout: remainingTimeout) {
        print("✅ Found element after \(attempt) scroll(s)")
        return true
      }
    }

    print("⚠️ Element not found after \(maxScrollAttempts) scroll attempts")
    return false
  }

  /// Scroll direction for element discovery
  enum ScrollDirection {
    case up      // Swipe up (scrolls content downward)
    case down    // Swipe down (scrolls content upward)
    case left    // Swipe left (scrolls content rightward)
    case right   // Swipe right (scrolls content leftward)
  }

  /// Waits for element with automatic retry and detailed logging
  ///
  /// Enhanced version of `waitForExistence` that provides better debugging output
  /// when elements aren't found. Helps diagnose "element not found" failures.
  ///
  /// Example:
  /// ```swift
  /// let button = app.buttons["Submit"]
  /// XCTAssertTrue(button.waitWithRetry(
  ///   timeout: 5.0,
  ///   description: "Submit button in checkout flow"
  /// ))
  /// ```
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait (default: 5.0)
  ///   - description: Human-readable description for logging
  ///   - logHierarchyOnFailure: Whether to log view hierarchy on failure (default: false)
  /// - Returns: True if element appeared within timeout
  @MainActor
  func waitWithRetry(
    timeout: TimeInterval = 5.0,
    description: String? = nil,
    logHierarchyOnFailure: Bool = false
  ) -> Bool {
    let success = self.waitForExistence(timeout: timeout)

    if !success {
      let desc = description ?? self.identifier
      print("⚠️ Element not found: '\(desc)'")
      print("   - Identifier: '\(self.identifier)'")
      print("   - Element type: \(self.elementType.rawValue)")
      print("   - Timeout: \(timeout)s")

      if logHierarchyOnFailure {
        // Note: Accessing debugDescription can be expensive and may cause issues
        // if app has crashed. Use sparingly.
        print("   - Exists: \(self.exists)")
        print("   - Hittable: \(self.isHittable)")
      }
    }

    return success
  }

  /// Discovers element by scrolling with custom scroll amount
  ///
  /// Provides more control over scrolling by allowing custom scroll distances.
  /// Useful when elements are far off-screen or when you need precise control.
  ///
  /// - Parameters:
  ///   - scrollView: The scroll container
  ///   - timeout: Maximum time to search (default: 5.0)
  ///   - scrollOffset: Normalized scroll offset (0.0 to 1.0, default: 0.5)
  ///   - maxAttempts: Maximum scroll attempts (default: 10)
  ///   - direction: Scroll direction (default: .up)
  /// - Returns: True if element was discovered
  @MainActor
  func discoverWithCustomScroll(
    in scrollView: XCUIElement,
    timeout: TimeInterval = 5.0,
    scrollOffset: CGFloat = 0.5,
    maxAttempts: Int = 10,
    direction: ScrollDirection = .up
  ) -> Bool {
    // Fast path: element already exists
    if self.waitForExistence(timeout: 1.0) {
      return true
    }

    let deadline = Date().addingTimeInterval(timeout)

    for attempt in 1...maxAttempts {
      guard Date() < deadline else { return false }

      // Calculate start and end coordinates based on direction
      let bounds = scrollView.frame
      let startPoint: CGPoint
      let endPoint: CGPoint

      switch direction {
      case .up:
        startPoint = CGPoint(
          x: bounds.midX,
          y: bounds.maxY - (bounds.height * scrollOffset)
        )
        endPoint = CGPoint(
          x: bounds.midX,
          y: bounds.minY + (bounds.height * scrollOffset)
        )

      case .down:
        startPoint = CGPoint(
          x: bounds.midX,
          y: bounds.minY + (bounds.height * scrollOffset)
        )
        endPoint = CGPoint(
          x: bounds.midX,
          y: bounds.maxY - (bounds.height * scrollOffset)
        )

      case .left:
        startPoint = CGPoint(
          x: bounds.maxX - (bounds.width * scrollOffset),
          y: bounds.midY
        )
        endPoint = CGPoint(
          x: bounds.minX + (bounds.width * scrollOffset),
          y: bounds.midY
        )

      case .right:
        startPoint = CGPoint(
          x: bounds.minX + (bounds.width * scrollOffset),
          y: bounds.midY
        )
        endPoint = CGPoint(
          x: bounds.maxX - (bounds.width * scrollOffset),
          y: bounds.midY
        )
      }

      // Perform drag gesture
      let start = scrollView.coordinate(withNormalizedOffset: .zero)
        .withOffset(CGVector(dx: startPoint.x - bounds.minX, dy: startPoint.y - bounds.minY))
      let end = scrollView.coordinate(withNormalizedOffset: .zero)
        .withOffset(CGVector(dx: endPoint.x - bounds.minX, dy: endPoint.y - bounds.minY))

      start.press(forDuration: 0.1, thenDragTo: end)

      // Check if element appeared
      let remainingTimeout = min(1.0, deadline.timeIntervalSinceNow)
      if self.waitForExistence(timeout: remainingTimeout) {
        print("✅ Found element after \(attempt) custom scroll(s)")
        return true
      }
    }

    return false
  }
}

// MARK: - Smart Element Queries

extension XCTestCase {

  /// Finds element using multiple query strategies
  ///
  /// Tries multiple approaches to find an element, increasing chances of success
  /// when dealing with dynamic SwiftUI hierarchies.
  ///
  /// Example:
  /// ```swift
  /// let button = findElementWithFallback(
  ///   in: app,
  ///   identifier: "Submit.Button",
  ///   label: "Submit",
  ///   type: .button
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - app: The application
  ///   - identifier: Primary accessibility identifier
  ///   - label: Fallback label to search for
  ///   - type: Element type (default: .any)
  ///   - timeout: Time to wait for each strategy (default: 2.0)
  /// - Returns: The found element, or nil
  @MainActor
  func findElementWithFallback(
    in app: XCUIApplication,
    identifier: String? = nil,
    label: String? = nil,
    type: XCUIElement.ElementType = .any,
    timeout: TimeInterval = 2.0
  ) -> XCUIElement? {

    // Strategy 1: Direct identifier match
    if let identifier = identifier {
      let element = app.descendants(matching: type)
        .matching(identifier: identifier)
        .firstMatch

      if element.waitForExistence(timeout: timeout) {
        return element
      }
    }

    // Strategy 2: Label match
    if let label = label {
      let labelPredicate = NSPredicate(format: "label == %@", label)
      let element = app.descendants(matching: type)
        .matching(labelPredicate)
        .firstMatch

      if element.waitForExistence(timeout: timeout) {
        return element
      }
    }

    // Strategy 3: Partial label match
    if let label = label {
      let partialPredicate = NSPredicate(format: "label CONTAINS[c] %@", label)
      let element = app.descendants(matching: type)
        .matching(partialPredicate)
        .firstMatch

      if element.waitForExistence(timeout: timeout) {
        return element
      }
    }

    return nil
  }

  /// Waits for any of multiple elements to appear (first match wins)
  ///
  /// Useful when UI can be in multiple valid states (e.g., loading vs content vs error).
  ///
  /// Example:
  /// ```swift
  /// let result = waitForAnyElementToAppear(
  ///   elements: [
  ///     app.staticTexts["Content.Loaded"],
  ///     app.staticTexts["Content.Error"],
  ///     app.activityIndicators["Loading"]
  ///   ],
  ///   timeout: 5.0
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - elements: Array of elements to watch
  ///   - timeout: Maximum time to wait (default: 5.0)
  /// - Returns: The first element that appeared, or nil
  @MainActor
  func waitForAnyElementToAppear(
    elements: [XCUIElement],
    timeout: TimeInterval = 5.0
  ) -> XCUIElement? {
    // Quick check: any already exist?
    for element in elements where element.exists {
      return element
    }

    // Wait using predicate
    var foundElement: XCUIElement?

    let predicate = NSPredicate { _, _ in
      for element in elements where element.exists {
        foundElement = element
        return true
      }
      return false
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

    return result == .completed ? foundElement : nil
  }
}

// MARK: - Collection Discovery

extension XCUIElement {

  /// Discovers element within a collection (table/collection view) by scrolling
  ///
  /// Specialized for finding cells within tables or collection views. Automatically
  /// handles the scroll-to-discover pattern common in list UIs.
  ///
  /// Example:
  /// ```swift
  /// let table = app.tables["Episode.List"]
  /// let cell = app.cells["Episode-123"]
  /// XCTAssertTrue(cell.discoverInCollection(table, timeout: 5.0))
  /// ```
  ///
  /// - Parameters:
  ///   - collection: The table or collection view
  ///   - timeout: Maximum search time (default: 5.0)
  ///   - maxScrolls: Maximum scroll attempts (default: 15)
  /// - Returns: True if element was found
  @MainActor
  func discoverInCollection(
    _ collection: XCUIElement,
    timeout: TimeInterval = 5.0,
    maxScrolls: Int = 15
  ) -> Bool {
    // Verify collection exists
    guard collection.exists else {
      print("⚠️ Collection doesn't exist")
      return false
    }

    // Fast path: element already visible
    if self.waitForExistence(timeout: 0.5) {
      return true
    }

    // Scroll to find element
    return self.discoverWithScrolling(
      in: collection,
      timeout: timeout,
      maxScrollAttempts: maxScrolls,
      scrollDirection: .up
    )
  }
}
