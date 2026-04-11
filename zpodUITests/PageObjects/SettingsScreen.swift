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

  private var orphanedEpisodesRow: XCUIElement? {
    findSettingsRow(
      identifiers: [
        "Settings.Orphaned",
        "Settings.Orphaned.Label",
        "Orphaned Episodes"
      ]
    )
  }

  /// Manage Storage settings row.
  ///
  /// **Fallback chain**: Tries 4 element types to handle SwiftUI hierarchy variations.
  private var manageStorageRow: XCUIElement? {
    findSettingsRow(
      identifiers: [
        "Settings.ManageStorage",
        "Settings.ManageStorage.Label",
        "Manage Storage"
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
    // Swipe Actions row may be below the initial viewport — use scrollToFindSettingsRow
    // so the element is hittable before tapping (same pattern as downloadPolicies).
    guard let row = scrollToFindSettingsRow(
      identifiers: [
        "Settings.Feature.swipeActions",
        "Settings.Feature.Label.swipeActions",
        "Swipe Actions"
      ]
    ) else {
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
  /// 1. Scroll Settings list to find Download Policies row (section 5, requires scroll)
  /// 2. Tap row
  /// 3. Verify Download toggle appeared
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToDownloadPolicies() -> Bool {
    // Download Policies is in section 5 — not materialized without scroll
    guard let row = scrollToFindSettingsRow(
      identifiers: [
        "Settings.Feature.downloadPolicies",
        "Settings.Feature.Label.downloadPolicies",
        "Download Policies"
      ]
    ) else {
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
  /// 1. Scroll Settings list to find Playback Preferences row (requires scroll)
  /// 2. Tap row
  /// 3. Verify Playback toggle appeared
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToPlaybackPreferences() -> Bool {
    // Playback Preferences is below the initial viewport — use scrollToFindSettingsRow
    // so the element is hittable before tapping (same pattern as swipeActions/downloadPolicies).
    guard let row = scrollToFindSettingsRow(
      identifiers: [
        "Settings.Feature.playbackPreferences",
        "Settings.Feature.Label.playbackPreferences",
        "Playback Preferences"
      ]
    ) else {
      return false
    }

    guard tap(row) else {
      return false
    }

    // Verify Playback configuration screen appeared
    let playbackToggle = app.switches.matching(identifier: "Playback.ContinuousToggle").firstMatch
    return wait(for: playbackToggle, until: .exists)
  }

  /// Navigate to Orphaned Episodes list.
  @discardableResult
  public func navigateToOrphanedEpisodes() -> Bool {
    guard let row = orphanedEpisodesRow else { return false }
    guard tap(row) else { return false }

    let listCandidates: [XCUIElement] = [
      app.tables.matching(identifier: "Orphaned.List").firstMatch,
      app.collectionViews.matching(identifier: "Orphaned.List").firstMatch,
      app.scrollViews.matching(identifier: "Orphaned.List").firstMatch,
      app.otherElements.matching(identifier: "Orphaned.List").firstMatch
    ]
    let empty = app.otherElements.matching(identifier: "Orphaned.EmptyState").firstMatch
    let title = app.navigationBars["Orphaned Episodes"].firstMatch
    let titleLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "Orphaned Episodes"))
      .firstMatch

    return waitForAny(listCandidates + [empty, title, titleLabel]) != nil
  }

  /// Navigate to Storage Management screen.
  ///
  /// **Steps**:
  /// 1. Find Manage Storage row (using fallback chain)
  /// 2. Tap row
  /// 3. Verify Storage screen appeared (by checking for Storage.Summary or nav title)
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToStorageManagement() -> Bool {
    guard let row = manageStorageRow else {
      return false
    }

    guard tap(row) else {
      return false
    }

    // Verify Storage Management screen appeared
    // Try multiple element types for Storage.Summary row
    let summaryCandidates: [XCUIElement] = [
      app.otherElements.matching(identifier: "Storage.Summary").firstMatch,
      app.cells.matching(identifier: "Storage.Summary").firstMatch,
      app.staticTexts.matching(identifier: "Storage.Summary.TotalSize").firstMatch
    ]
    let title = app.navigationBars["Manage Storage"].firstMatch

    return waitForAny(summaryCandidates + [title]) != nil
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
    var candidates: [XCUIElement] = []
    for identifier in identifiers {
      candidates += [
        app.buttons.matching(identifier: identifier).firstMatch,
        app.otherElements.matching(identifier: identifier).firstMatch,
        app.cells.matching(identifier: identifier).firstMatch,
        app.staticTexts.matching(identifier: identifier).firstMatch
      ]
    }

    return waitForAny(candidates)
  }

  /// Scrolls the Settings list until a row becomes hittable.
  ///
  /// SwiftUI lists register elements in the accessibility tree even when off-screen,
  /// so checking `exists` is insufficient — we must verify `isHittable` to confirm
  /// the element is in the visible viewport.
  ///
  /// - Parameter identifiers: Identifiers/labels to try (in order)
  /// - Parameter maxSwipes: Maximum number of swipe-up gestures (default: 6)
  /// - Returns: First matching hittable element after scrolling, or nil
  private func scrollToFindSettingsRow(
    identifiers: [String],
    maxSwipes: Int = 6
  ) -> XCUIElement? {
    // Build candidate list
    var candidates: [XCUIElement] = []
    for identifier in identifiers {
      candidates += [
        app.buttons.matching(identifier: identifier).firstMatch,
        app.otherElements.matching(identifier: identifier).firstMatch,
        app.cells.matching(identifier: identifier).firstMatch,
        app.staticTexts.matching(identifier: identifier).firstMatch
      ]
    }

    // Check if already hittable
    if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
      return hittable
    }

    // Scroll until hittable
    let settingsList = settingsListElement()
    for _ in 0..<maxSwipes {
      settingsList.swipeUp()

      if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
        return hittable
      }
    }

    return nil
  }

  /// Finds the Settings list container to perform scroll gestures on.
  private func settingsListElement() -> XCUIElement {
    let candidates = [
      app.collectionViews.matching(identifier: "Settings.Content").firstMatch,
      app.tables.matching(identifier: "Settings.Content").firstMatch,
      app.scrollViews.matching(identifier: "Settings.Content").firstMatch,
      app.otherElements.matching(identifier: "Settings.Content").firstMatch
    ]
    return candidates.first(where: { $0.exists }) ?? candidates[0]
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
