//
//  SwipeExecutionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Execution scenarios split from the prior complex suite.
//

import XCTest

/// Tests that verify seeded swipe actions execute from the episode list.
final class SwipeExecutionTests: SwipeConfigurationTestCase {

  @MainActor
  func testLeadingAndTrailingSwipesExecute() throws {
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    try reuseOrOpenConfigurationSheet(resetDefaults: true)

    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: false,
        timeout: adaptiveTimeout
      ) != nil
    else { return }

    dismissConfigurationSheetIfNeeded()
    waitForEpisodeListReady()

    let episode = try requireEpisodeButton()
    XCTAssertTrue(
      waitForElement(
        episode,
        timeout: postReadinessTimeout,
        description: "episode cell for swipe"
      )
    )

    exerciseLeadingSwipe(on: episode)
    exerciseTrailingSwipe(on: episode, expectedIdentifier: "favorite")
    episode.tap()
  }

  // MARK: - Private Helpers

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
        addToPlaylistButton, timeout: postReadinessTimeout, description: "add to playlist")
    )
    tapElement(addToPlaylistButton, description: "add to playlist swipe action")
    if let record = waitForSwipeExecution(action: "addToPlaylist", timeout: adaptiveTimeout) {
      XCTAssertEqual(record.episodeID, episodeIdentifier(from: episode))
    }
  }

  private func exerciseTrailingSwipe(on episode: XCUIElement, expectedIdentifier: String) {
    episode.swipeLeft()
    let actionButton = element(withIdentifier: "SwipeAction.\(expectedIdentifier)")
    XCTAssertTrue(
      waitForElement(
        actionButton,
        timeout: postReadinessTimeout,
        description: "\(expectedIdentifier) swipe action"
      )
    )
    tapElement(actionButton, description: "\(expectedIdentifier) swipe action")
    if let record = waitForSwipeExecution(action: expectedIdentifier, timeout: adaptiveTimeout) {
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
