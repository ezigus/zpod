//
//  DiscoverScreen.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//
//  Page object describing the Discover tab UI surface
//

import Foundation
import XCTest

/// Encapsulates the Discover tab so tests can reuse the search field discovery logic.
///
/// This keeps the Discover-heavy tests focused on user intent instead of SwiftUI selectors.
@MainActor
public struct DiscoverScreen: BaseScreen {
  public let app: XCUIApplication

  /// Common selectors used to determine if the Discover tab is ready.
  private var searchFieldCandidates: [XCUIElement] {
    [
      app.textFields.matching(identifier: "Discover.SearchField").firstMatch,
      app.descendants(matching: .any)
        .matching(identifier: "Discover.SearchField")
        .firstMatch,
      app.searchFields.firstMatch,
      app.textFields.matching(
        NSPredicate(format: "placeholderValue CONTAINS[cd] 'search'"))
        .firstMatch,
      app.descendants(matching: .any).matching(identifier: "Discover.Root").firstMatch
    ]
  }

  /// Waits for the search field (or related root) to appear so tests know the tab finished rendering.
  ///
  /// - Parameter timeout: Optional override for the default wait.
  /// - Returns: The first matching element that was discovered.
  public func waitForSearchField(timeout: TimeInterval? = nil) -> XCUIElement? {
    waitForAny(searchFieldCandidates, timeout: timeout)
  }

  /// Validates that the Discover tab is ready for interaction.
  /// This mirrors the previous navigation checks that waited for the search field.
  public func discoverTabReady(timeout: TimeInterval? = nil) -> Bool {
    waitForSearchField(timeout: timeout) != nil
  }
}
