//
//  SwipeActionManagementTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Action management scenarios split from the prior complex suite.
//

import XCTest

/// Tests that verify adding/removing swipe actions and enforcing limits.
final class SwipeActionManagementTests: SwipeConfigurationTestCase {

  @MainActor
  func testManagingActionsEndToEnd() throws {
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User performs action management operations:
    //       1. Adds actions to leading edge until cap is reached (3 max)
    //       2. Verifies leading add button disappears at cap
    //       3. Removes an action from leading edge
    //       4. Adds an action to trailing edge
    // THEN: Action management behaves correctly:
    //       - Actions are added/removed successfully
    //       - Debug state reflects changes after each operation
    //       - Add buttons appear/disappear based on cap limits
    //       - Save button enables when unsaved changes exist
    //       - Trailing add button remains visible when under limit
    //
    // Spec: Issue #02.6.3 - Action Management Test (Consolidated)
    // Validates the complete action management workflow including add, remove,
    // and limit enforcement behaviors.

    try reuseOrOpenConfigurationSheet(resetDefaults: true)
    assertDefaultConfiguration()

    // Add leading actions up to the limit
    XCTAssertTrue(addAction("Play", edgeIdentifier: "Leading"))
    XCTAssertTrue(addAction("Add to Playlist", edgeIdentifier: "Leading"))
    guard
      expectDebugState(
        leading: ["markPlayed", "play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: true
      ) != nil
    else { return }
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: adaptiveTimeout))

    // Verify add button disappears when cap reached and trailing add remains visible
    let leadingAdd = element(withIdentifier: "SwipeActions.Add.Leading")
    XCTAssertTrue(
      waitForElementToDisappear(leadingAdd, timeout: postReadinessTimeout),
      "Leading add button should disappear at cap"
    )
    assertTrailingAddVisible()

    // Remove leading action and verify state updates
    XCTAssertTrue(removeAction("Mark Played", edgeIdentifier: "Leading"))
    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: true
      ) != nil
    else { return }
    assertTrailingAddVisible()

    // Add trailing action and verify save enabled
    XCTAssertTrue(addAction("Download", edgeIdentifier: "Trailing"))
    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive", "download"],
        unsaved: true
      ) != nil
    else { return }
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: adaptiveTimeout))
  }

  // MARK: - Private Helpers

  private func assertDefaultConfiguration() {
    guard
      expectDebugState(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ) != nil
    else { return }
  }

  private func assertTrailingAddVisible() {
    // After adding leading actions, the Trailing section may be outside the SwiftUI materialization zone.
    // Wait for section materialization before attempting to access trailing elements.
    waitForSectionMaterialization(timeout: postReadinessTimeout)

    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(
        identifier: "SwipeActions.Add.Trailing",
        container: container,
        scrollAttempts: 4
      )
    }
    let trailingAddButton = element(withIdentifier: "SwipeActions.Add.Trailing")
    XCTAssertTrue(
      waitForElement(
        trailingAddButton,
        timeout: postReadinessTimeout,
        description: "Trailing add action button"
      ),
      "Trailing add action button should remain visible when under the limit"
    )
  }
}
