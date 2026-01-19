//
//  TabBarNavigation.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Page Object for main tab bar navigation
//
//  Used by: All UI tests (every test needs tab navigation)
//

import Foundation
import XCTest

/// Page Object for the main tab bar.
///
/// **Responsibilities**:
/// - Find and interact with tab bar buttons
/// - Navigate between main app sections (Library, Discover, Player, Settings)
/// - Verify tab selection state
///
/// **Usage**:
/// ```swift
/// let tabs = TabBarNavigation(app: app)
///
/// // Navigate to a tab
/// XCTAssertTrue(tabs.navigateToLibrary())
///
/// // Check if tab is selected
/// XCTAssertTrue(tabs.isLibrarySelected)
/// ```
///
/// **Before** (ad-hoc, duplicated across tests):
/// ```swift
/// let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
/// let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
/// libraryTab.tap()
/// // ... repeated in 10+ test files
/// ```
///
/// **After** (encapsulated, reusable):
/// ```swift
/// let tabs = TabBarNavigation(app: app)
/// tabs.navigateToLibrary()
/// ```
///
/// **Issue**: #12.3 - Test Infrastructure Cleanup
@MainActor
public struct TabBarNavigation: BaseScreen {
  public let app: XCUIApplication

  // MARK: - Elements

  /// The main tab bar container.
  private var tabBar: XCUIElement {
    app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
  }

  /// Library tab button.
  private var libraryTab: XCUIElement {
    tabBar.buttons.matching(identifier: "Library").firstMatch
  }

  /// Discover tab button.
  private var discoverTab: XCUIElement {
    tabBar.buttons.matching(identifier: "Discover").firstMatch
  }

  /// Exposed Discover tab element for diagnostics or manual logging.
  public var discoverTabElement: XCUIElement {
    discoverTab
  }

  /// Player tab button.
  private var playerTab: XCUIElement {
    tabBar.buttons.matching(identifier: "Player").firstMatch
  }

  /// Settings tab button (uses label predicate since tab buttons have empty identifiers).
  private var settingsTab: XCUIElement {
    let predicate = NSPredicate(format: "label == 'Settings'")
    return tabBar.buttons.matching(predicate).firstMatch
  }

  // MARK: - State Queries

  /// Whether Library tab is currently selected.
  public var isLibrarySelected: Bool {
    libraryTab.isSelected
  }

  /// Whether Discover tab is currently selected.
  public var isDiscoverSelected: Bool {
    discoverTab.isSelected
  }

  /// Whether Player tab is currently selected.
  public var isPlayerSelected: Bool {
    playerTab.isSelected
  }

  /// Whether Settings tab is currently selected.
  public var isSettingsSelected: Bool {
    settingsTab.isSelected
  }

  // MARK: - Navigation Actions

  /// Navigate to Library tab.
  ///
  /// Waits for tab to be hittable, taps it, then verifies Library content appeared.
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToLibrary() -> Bool {
    guard tap(libraryTab) else { return false }

    // Verify Library content appeared (table or Library label)
    let libraryContent = [
      app.tables.firstMatch,
      app.staticTexts.matching(identifier: "Library").firstMatch
    ]

    return waitForAny(libraryContent) != nil
  }

  /// Navigate to Discover tab.
  ///
  /// Waits for tab to be hittable, taps it, then verifies Discover search field appeared.
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToDiscover() -> Bool {
    guard tap(discoverTab) else { return false }

    // Verify Discover search field appeared (multiple fallbacks for SwiftUI variants)
    let searchFieldCandidates = [
      app.textFields.matching(identifier: "Discover.SearchField").firstMatch,
      app.descendants(matching: .any).matching(identifier: "Discover.SearchField").firstMatch,
      app.searchFields.firstMatch,
      app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[cd] 'search'")).firstMatch,
      app.descendants(matching: .any).matching(identifier: "Discover.Root").firstMatch
    ]

    return waitForAny(searchFieldCandidates) != nil
  }

  /// Navigate to Player tab.
  ///
  /// Waits for tab to be hittable, taps it, then verifies Player interface appeared.
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToPlayer() -> Bool {
    guard tap(playerTab) else { return false }

    // Verify Player interface appeared
    let playerContent = [
      app.otherElements.matching(identifier: "Player Interface").firstMatch,
      app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Now Playing'")).firstMatch
    ]

    return waitForAny(playerContent) != nil
  }

  /// Navigate to Settings tab.
  ///
  /// Waits for tab to be hittable, taps it, then verifies Settings content appeared.
  ///
  /// - Returns: True if navigation succeeded
  @discardableResult
  public func navigateToSettings() -> Bool {
    guard tap(settingsTab) else { return false }

    // Wait for Settings to load (feature rows or loading indicator)
    guard waitForSettingsLoad() else { return false }

    // Verify Settings content appeared (feature rows or empty state)
    let settingsContent = [
      app.buttons.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
      app.buttons.matching(identifier: "Settings.Feature.downloadPolicies").firstMatch,
      app.buttons.matching(identifier: "Settings.Feature.playbackPreferences").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Feature.Label.swipeActions").firstMatch,
      app.otherElements.matching(identifier: "Settings.EmptyState").firstMatch
    ]

    return waitForAny(settingsContent) != nil
  }

  // MARK: - Helpers

  /// Wait for Settings to finish loading.
  ///
  /// Settings descriptors load asynchronously. This waits for loading indicator
  /// to disappear or for rows to appear.
  @discardableResult
  private func waitForSettingsLoad() -> Bool {
    // Wait for loading indicator to appear, then disappear if it shows up
    let loadingCandidates = [
      app.activityIndicators.matching(identifier: "Settings.Loading").firstMatch,
      app.otherElements.matching(identifier: "Settings.Loading").firstMatch,
      app.images.matching(identifier: "Settings.Loading").firstMatch
    ]

    if let loadingIndicator = waitForAny(loadingCandidates, timeout: 1.0) {
      _ = loadingIndicator.waitUntil(.disappeared)
    }

    // Wait for any feature row or empty state to appear
    let rowCandidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Settings.Feature.downloadPolicies").firstMatch,
      app.buttons.matching(identifier: "Settings.Feature.playbackPreferences").firstMatch,
      app.buttons.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Feature.Label.downloadPolicies").firstMatch,
      app.otherElements.matching(identifier: "Settings.EmptyState").firstMatch
    ]

    return waitForAny(rowCandidates, timeout: 4.0) != nil
  }
}
