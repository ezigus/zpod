//
//  SettingsScreen.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Page Object for Settings screen and feature navigation
//
//  Replaces: 6-8 element fallback chains duplicated across test files
//

import Foundation
import XCTest

/// Page Object for the Settings screen.
///
/// **Responsibilities**:
/// - Navigate to specific settings features (Swipe Actions, Download Policies, etc.)
/// - Encapsulate complex element fallback chains (6-8 variants per row)
/// - Verify settings screen state
///
/// **Usage**:
/// ```swift
/// let settings = SettingsScreen(app: app)
///
/// // Navigate to a feature
/// XCTAssertTrue(settings.navigateToSwipeActions())
/// XCTAssertTrue(settings.navigateToDownloadPolicies())
/// ```
///
/// **Before** (6-8 element fallback chain, duplicated):
/// ```swift
/// let candidates: [XCUIElement] = [
///     app.buttons.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
///     app.otherElements.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
///     app.cells.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
///     app.buttons.matching(identifier: "Swipe Actions").firstMatch,
///     app.staticTexts.matching(identifier: "Settings.Feature.Label.swipeActions").firstMatch,
///     app.staticTexts.matching(identifier: "Swipe Actions").firstMatch,
///     // ... repeated across 5+ test files
/// ]
/// guard let row = waitForAnyElement(candidates, ...) else { ... }
/// row.tap()
/// ```
///
/// **After** (encapsulated, one line):
/// ```swift
/// let settings = SettingsScreen(app: app)
/// settings.navigateToSwipeActions()
/// ```
///
/// **Issue**: #12.3 - Test Infrastructure Cleanup
@MainActor
public struct SettingsScreen: BaseScreen {
  public let app: XCUIApplication

  // MARK: - Elements (with encapsulated fallback chains)

  /// Swipe Actions settings row.
  ///
  /// **Fallback chain**: Tries 6 element types to handle SwiftUI hierarchy variations.
  private var swipeActionsRow: XCUIElement? {
    findSettingsRow(
      identifiers: [
        "Settings.Feature.swipeActions",
        "Settings.Feature.Label.swipeActions",
        "Swipe Actions"
      ]
    )
  }

  /// Download Policies settings row.
  ///
  /// **Fallback chain**: Tries 6 element types to handle SwiftUI hierarchy variations.
  private var downloadPoliciesRow: XCUIElement? {
    findSettingsRow(
      identifiers: [
        "Settings.Feature.downloadPolicies",
        "Settings.Feature.Label.downloadPolicies",
        "Download Policies"
      ]
    )
  }

  /// Playback Preferences settings row.
  ///
  /// **Fallback chain**: Tries 6 element types to handle SwiftUI hierarchy variations.
  private var playbackPreferencesRow: XCUIElement? {
    findSettingsRow(
      identifiers: [
        "Settings.Feature.playbackPreferences",
        "Settings.Feature.Label.playbackPreferences",
        "Playback Preferences"
      ]
    )
  }

  // MARK: - Navigation Actions

  /// Navigate to Swipe Actions configuration.
  ///
  /// **Steps**:
  /// 1. Find Swipe Actions row (using fallback chain)
  /// 2. Tap row
  /// 3. Verify Swipe Actions list appeared
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToSwipeActions() -> Bool {
    guard let row = swipeActionsRow else {
      return false
    }

    guard tap(row) else {
      return false
    }

    // Verify Swipe Actions configuration screen appeared
    let swipeActionsList = findSwipeActionsList()
    return wait(for: swipeActionsList, until: .exists)
  }

  /// Navigate to Download Policies configuration.
  ///
  /// **Steps**:
  /// 1. Find Download Policies row
  /// 2. Tap row
  /// 3. Verify Download toggle appeared
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToDownloadPolicies() -> Bool {
    guard let row = downloadPoliciesRow else {
      return false
    }

    guard tap(row) else {
      return false
    }

    // Verify Download configuration screen appeared
    let downloadToggle = app.switches.matching(identifier: "Download.AutoToggle").firstMatch
    return wait(for: downloadToggle, until: .exists)
  }

  /// Navigate to Playback Preferences configuration.
  ///
  /// **Steps**:
  /// 1. Find Playback Preferences row
  /// 2. Tap row
  /// 3. Verify Playback toggle appeared
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToPlaybackPreferences() -> Bool {
    guard let row = playbackPreferencesRow else {
      return false
    }

    guard tap(row) else {
      return false
    }

    // Verify Playback configuration screen appeared
    let playbackToggle = app.switches.matching(identifier: "Playback.ContinuousToggle").firstMatch
    return wait(for: playbackToggle, until: .exists)
  }

  // MARK: - Helpers

  /// Finds a settings row using multiple identifier/label fallbacks.
  ///
  /// **Why this exists**: SwiftUI hierarchy changes cause rows to appear as different
  /// element types (button, cell, otherElement, staticText). This tries all variants.
  ///
  /// **Element types tried** (in order):
  /// 1. Button with identifier
  /// 2. OtherElement with identifier
  /// 3. Cell with identifier
  /// 4. StaticText with identifier
  ///
  /// - Parameter identifiers: Identifiers/labels to try (in order)
  /// - Returns: First matching element, or nil if none found
  private func findSettingsRow(identifiers: [String]) -> XCUIElement? {
    for identifier in identifiers {
      // Try button
      let button = app.buttons.matching(identifier: identifier).firstMatch
      if button.exists { return button }

      // Try otherElement
      let other = app.otherElements.matching(identifier: identifier).firstMatch
      if other.exists { return other }

      // Try cell
      let cell = app.cells.matching(identifier: identifier).firstMatch
      if cell.exists { return cell }

      // Try staticText
      let text = app.staticTexts.matching(identifier: identifier).firstMatch
      if text.exists { return text }
    }

    return nil
  }

  /// Finds the Swipe Actions configuration list.
  ///
  /// **Why fallbacks needed**: SwiftUI List can appear as different element types
  /// (otherElement, scrollView, table, collectionView) depending on backing implementation.
  ///
  /// - Returns: Swipe Actions list element
  private func findSwipeActionsList() -> XCUIElement {
    let candidates = [
      app.otherElements.matching(identifier: "SwipeActions.List").firstMatch,
      app.scrollViews.matching(identifier: "SwipeActions.List").firstMatch,
      app.tables.matching(identifier: "SwipeActions.List").firstMatch,
      app.collectionViews.matching(identifier: "SwipeActions.List").firstMatch
    ]

    // Return first that exists, or first candidate as fallback
    return candidates.first(where: { $0.exists }) ?? candidates[0]
  }
}
