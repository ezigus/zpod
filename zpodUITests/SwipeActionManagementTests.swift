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
    try reuseOrOpenConfigurationSheet()
    assertDefaultConfiguration()

    // Add leading actions up to the limit
    XCTAssertTrue(addAction("Play", edgeIdentifier: "Leading"))
    XCTAssertTrue(addAction("Add to Playlist", edgeIdentifier: "Leading"))
    guard
      expectDebugState(
        leading: ["markPlayed", "play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: true,
        timeout: postReadinessTimeout
      ) != nil
    else { return }
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: postReadinessTimeout))

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
        unsaved: true,
        timeout: postReadinessTimeout
      ) != nil
    else { return }
    assertTrailingAddVisible()

    // Add trailing action and verify save enabled
    XCTAssertTrue(addAction("Download", edgeIdentifier: "Trailing"))
    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive", "download"],
        unsaved: true,
        timeout: postReadinessTimeout
      ) != nil
    else { return }
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: postReadinessTimeout))
  }

  // MARK: - Private Helpers

  private func assertDefaultConfiguration() {
    guard
      expectDebugState(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false,
        timeout: postReadinessTimeout
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
        scrollAttempts: 1
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
