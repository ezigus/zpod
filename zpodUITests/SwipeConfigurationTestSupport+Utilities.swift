//
//  SwipeConfigurationTestSupport+Utilities.swift
//  zpodUITests
//
//  Shared element utilities extracted from the former Interactions helper.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  // MARK: - Element Lookup

  @MainActor
  func element(withIdentifier identifier: String) -> XCUIElement {
    if let prioritized = prioritizedElement(in: app, identifier: identifier) {
      return prioritized
    }
    return app.descendants(matching: .any)[identifier]
  }

  @MainActor
  func element(withIdentifier identifier: String, within container: XCUIElement)
    -> XCUIElement
  {
    if let prioritized = prioritizedElement(in: container, identifier: identifier) {
      return prioritized
    }
    return element(withIdentifier: identifier)
  }

  @MainActor
  private func prioritizedElement(in root: XCUIElement, identifier: String) -> XCUIElement? {
    // Use descendants(matching: .any) with identifier - much faster than checking 10 element types
    let descendant = root.descendants(matching: .any)[identifier]
    return descendant.exists ? descendant : nil
  }

  // MARK: - Interaction Helpers

  @MainActor
  func tapElement(_ element: XCUIElement, description: String) {
    if element.isHittable {
      element.tap()
      return
    }

    let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    coordinate.tap()
    logger.debug(
      "[SwipeUITestDebug] forced coordinate tap for \(description, privacy: .public)"
    )
  }

  @MainActor
  func revealLeadingSwipeActions(for element: XCUIElement) {
    element.swipeRight()

    if app.buttons["SwipeAction.addToPlaylist"].exists {
      return
    }

    let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
    let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
    start.press(forDuration: 0.05, thenDragTo: end)
  }
}
