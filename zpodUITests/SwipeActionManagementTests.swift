//
//  SwipeActionManagementTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe action addition, removal, and limit enforcement
//

import Foundation
import OSLog
import XCTest

/// Tests that verify swipe action management (add, remove, limits)
final class SwipeActionManagementTests: SwipeConfigurationTestCase {
  @MainActor
  func testManagingActionsEndToEnd() throws {
    try beginWithFreshConfigurationSheet()
    assertDefaultConfiguration()

    // Add leading actions up to the limit
    XCTAssertTrue(addAction("Play", edgeIdentifier: "Leading"))
    XCTAssertTrue(addAction("Add to Playlist", edgeIdentifier: "Leading"))
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed", "play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: true
      )
    )
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout))

    // Verify add button disappears when cap reached and trailing add remains visible
    let leadingAdd = element(withIdentifier: "SwipeActions.Add.Leading")
    XCTAssertTrue(
      waitForElementToDisappear(leadingAdd, timeout: adaptiveShortTimeout),
      "Leading add button should disappear at cap"
    )
    assertTrailingAddVisible()

    // Remove leading action and verify state updates
    XCTAssertTrue(removeAction("Mark Played", edgeIdentifier: "Leading"))
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: true
      )
    )
    assertTrailingAddVisible()

    // Add trailing action and verify save enabled
    XCTAssertTrue(addAction("Download", edgeIdentifier: "Trailing"))
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive", "download"],
        unsaved: true
      )
    )
    XCTAssertTrue(waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout))
  }

  private func assertDefaultConfiguration() {
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
  }

  private func assertTrailingAddVisible() {
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(
        identifier: "SwipeActions.Add.Trailing",
        container: container,
        scrollAttempts: 16
      )
    }
    let trailingAddButton = element(withIdentifier: "SwipeActions.Add.Trailing")
    XCTAssertTrue(
      waitForElement(
        trailingAddButton,
        timeout: adaptiveShortTimeout,
        description: "Trailing add action button"
      ),
      "Trailing add action button should remain visible when under the limit"
    )
  }
}
