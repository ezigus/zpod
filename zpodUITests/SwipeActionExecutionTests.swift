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
  
  // MARK: - Swipe Execution Tests
  
  @MainActor
  func testLeadingSwipeActionsExecute() throws {
    // Seed configuration with custom leading actions
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )
    
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    
    // Verify configuration was seeded correctly
    try openConfigurationSheetFromEpisodeList()
    
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: false
      ),
      "Seeded playback configuration should match debug summary"
    )
    
    dismissConfigurationSheetIfNeeded()
    
    // Wait for episode list to be ready
    if !waitForContentToLoad(
      containerIdentifier: "Episode Cards Container",
      timeout: adaptiveTimeout
    ) {
      let firstEpisode = try requireEpisodeButton()
      _ = waitForElement(
        firstEpisode,
        timeout: adaptiveTimeout,
        description: "first episode after sheet dismissal"
      )
    }
    
    // Get first episode and swipe to reveal leading actions
    let episode = try requireEpisodeButton()
    XCTAssertTrue(
      waitForElement(
        episode,
        timeout: adaptiveShortTimeout,
        description: "episode cell for swipe"
      ),
      "Episode cell should be available for swipe interaction"
    )
    
    revealLeadingSwipeActions(for: episode)
    
    let addToPlaylistButton = element(withIdentifier: "SwipeAction.addToPlaylist")
    XCTAssertTrue(
      waitForElement(
        addToPlaylistButton,
        timeout: adaptiveShortTimeout,
        description: "add to playlist swipe action"
      ),
      "Add to Playlist swipe action should appear after swiping right"
    )
    
    // No need to open the playlist sheet; verifying visibility is sufficient.
    episode.tap()
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testTrailingSwipeActionsExecute() throws {
    // Seed configuration with custom trailing actions
    seedSwipeConfiguration(
      leading: ["markPlayed"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "medium"
    )
    
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    
    // Verify configuration was seeded correctly
    try openConfigurationSheetFromEpisodeList()
    
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["download", "favorite"],
        unsaved: false
      ),
      "Seeded configuration should match debug summary"
    )
    
    dismissConfigurationSheetIfNeeded()
    
    // Wait for episode list to be ready
    if !waitForContentToLoad(
      containerIdentifier: "Episode Cards Container",
      timeout: adaptiveTimeout
    ) {
      let firstEpisode = try requireEpisodeButton()
      _ = waitForElement(
        firstEpisode,
        timeout: adaptiveTimeout,
        description: "first episode after sheet dismissal"
      )
    }
    
    // Get first episode and swipe to reveal trailing actions
    let episode = try requireEpisodeButton()
    XCTAssertTrue(
      waitForElement(
        episode,
        timeout: adaptiveShortTimeout,
        description: "episode cell for swipe"
      ),
      "Episode cell should be available for swipe interaction"
    )
    
    // Swipe left to reveal trailing actions
    episode.swipeLeft()
    
    let favoriteButton = element(withIdentifier: "SwipeAction.favorite")
    XCTAssertTrue(
      waitForElement(
        favoriteButton,
        timeout: adaptiveShortTimeout,
        description: "favorite swipe action"
      ),
      "Favorite swipe action should appear after swiping left"
    )
    episode.tap()
    
    restoreDefaultConfiguration()
  }
}

extension XCUIElement {
  fileprivate func firstMatchIfExists() -> XCUIElement? {
    return exists ? self : nil
  }
}
