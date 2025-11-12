//
//  SwipeComplexIntegrationTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition (Hybrid Tier 2)
//  Complex integration tests that verify action management, persistence, and execution
//  Combined into single suite to run sequentially with shared app build
//

import Foundation
import OSLog
import XCTest

/// Complex integration tests for swipe configuration (action management, persistence, execution)
/// These tests involve app relaunches, seeding, and multi-step workflows
final class SwipeComplexIntegrationTests: SwipeConfigurationTestCase {

  // MARK: - Action Management Tests

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

  // MARK: - Persistence Tests

  @MainActor
  func testSeededConfigurationPersistsAcrossControls() throws {
    launchAppWithSeed(
      leading: ["play", "addToPlaylist"],
      trailing: ["delete", "archive"],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticsEnabled: true,
      hapticStyle: "soft"
    )

    try openConfigurationSheetFromEpisodeList()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Seeded configuration should match debug summary"
    )

    assertActionList(
      leadingIdentifiers: [
        "SwipeActions.Leading.Play",
        "SwipeActions.Leading.Add to Playlist",
      ],
      trailingIdentifiers: [
        "SwipeActions.Trailing.Delete",
        "SwipeActions.Trailing.Archive",
      ]
    )

    assertHapticsEnabled(true, styleLabel: "Soft")
    assertFullSwipeState(leading: false, trailing: true)
  }

  // MARK: - Execution Tests

  @MainActor
  func testLeadingAndTrailingSwipesExecute() throws {
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    try openConfigurationSheetFromEpisodeList()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: false
      )
    )

    dismissConfigurationSheetIfNeeded()
    waitForEpisodeListReady()

    let episode = try requireEpisodeButton()
    XCTAssertTrue(
      waitForElement(
        episode,
        timeout: adaptiveShortTimeout,
        description: "episode cell for swipe"
      )
    )

    exerciseLeadingSwipe(on: episode)
    exerciseTrailingSwipe(on: episode)
    episode.tap()
  }

  // MARK: - Private Helpers

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
      // Reduced from 16: trailing section is materialized upfront
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
        timeout: adaptiveShortTimeout,
        description: "Trailing add action button"
      ),
      "Trailing add action button should remain visible when under the limit"
    )
  }

  private func waitForEpisodeListReady() {
    if !waitForContentToLoad(
      containerIdentifier: "Episode Cards Container",
      timeout: adaptiveTimeout
    ) {
      if let first = try? requireEpisodeButton() {
        _ = waitForElement(first, timeout: adaptiveTimeout, description: "episode list ready")
      }
    }
  }

  private func exerciseLeadingSwipe(on episode: XCUIElement) {
    revealLeadingSwipeActions(for: episode)
    let addToPlaylistButton = element(withIdentifier: "SwipeAction.addToPlaylist")
    XCTAssertTrue(
      waitForElement(
        addToPlaylistButton, timeout: adaptiveShortTimeout, description: "add to playlist")
    )
    tapElement(addToPlaylistButton, description: "add to playlist swipe action")
    if let record = waitForSwipeExecution(action: "addToPlaylist", timeout: adaptiveShortTimeout) {
      XCTAssertEqual(record.episodeID, episodeIdentifier(from: episode))
    }
  }

  private func exerciseTrailingSwipe(on episode: XCUIElement) {
    episode.swipeLeft()
    let favoriteButton = element(withIdentifier: "SwipeAction.favorite")
    XCTAssertTrue(
      waitForElement(
        favoriteButton, timeout: adaptiveShortTimeout, description: "favorite swipe action")
    )
    tapElement(favoriteButton, description: "favorite swipe action")
    if let record = waitForSwipeExecution(action: "favorite", timeout: adaptiveShortTimeout) {
      XCTAssertEqual(record.episodeID, episodeIdentifier(from: episode))
    }
  }

  private func episodeIdentifier(from element: XCUIElement) -> String {
    let identifier = element.identifier
    guard let range = identifier.range(of: "Episode-") else {
      return identifier
    }
    let suffix = identifier[range.upperBound...]
    return String(suffix)
  }
}
