//
//  SwipeActionExecutionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify configured swipe actions execute correctly in episode list
//

import Foundation
import OSLog
import XCTest

/// Tests that verify configured swipe actions execute in the episode list
final class SwipeActionExecutionTests: SwipeConfigurationTestCase {
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
      waitForElement(addToPlaylistButton, timeout: adaptiveShortTimeout, description: "add to playlist")
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
      waitForElement(favoriteButton, timeout: adaptiveShortTimeout, description: "favorite swipe action")
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

extension XCUIElement {
  fileprivate func firstMatchIfExists() -> XCUIElement? {
    return exists ? self : nil
  }
}

private extension SwipeActionExecutionTests {
  func episodeIdentifier(from element: XCUIElement) -> String {
    let identifier = element.identifier
    guard let range = identifier.range(of: "Episode-") else {
      return identifier
    }
    let suffix = identifier[range.upperBound...]
    return String(suffix)
  }
}
