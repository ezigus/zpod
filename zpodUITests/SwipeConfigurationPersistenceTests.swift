//
//  SwipeConfigurationPersistenceTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe configuration persists across app relaunches
//

import Foundation
import OSLog
import XCTest

/// Tests that verify swipe configuration persistence across app relaunches
final class SwipeConfigurationPersistenceTests: SwipeConfigurationTestCase {
  
  // MARK: - Persistence Tests
  
  @MainActor
  func testLeadingActionsPersistFromSeed() throws {
    launchAppWithSeed(
      leading: ["play", "addToPlaylist"],
      trailing: ["delete", "archive"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )
    try openConfigurationSheetFromEpisodeList()
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Seeded leading actions should match debug summary"
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
  }

  @MainActor
  func testTrailingActionsPersistFromSeed() throws {
    launchAppWithSeed(
      leading: ["markPlayed"],
      trailing: ["download", "favorite"],
      allowFullSwipeTrailing: true
    )
    try openConfigurationSheetFromEpisodeList()
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["download", "favorite"],
        unsaved: false
      ),
      "Seeded trailing actions should match debug summary"
    )
    assertActionList(
      leadingIdentifiers: [
        "SwipeActions.Leading.Mark Played",
      ],
      trailingIdentifiers: [
        "SwipeActions.Trailing.Download",
        "SwipeActions.Trailing.Favorite",
      ]
    )
  }
  
  @MainActor
  func testHapticTogglePersistsFromSeed() throws {
    launchAppWithSeed(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      hapticsEnabled: false,
      hapticStyle: "medium"
    )
    try openConfigurationSheetFromEpisodeList()
    assertHapticsEnabled(false)
  }

  @MainActor
  func testHapticStylePersistsFromSeed() throws {
    launchAppWithSeed(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      hapticsEnabled: true,
      hapticStyle: "soft"
    )
    try openConfigurationSheetFromEpisodeList()
    assertHapticsEnabled(true, styleLabel: "Soft")
  }
  
  @MainActor
  func testFullSwipeSettingPersists() throws {
    launchAppWithSeed(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true
    )
    try openConfigurationSheetFromEpisodeList()
    assertFullSwipeState(leading: false, trailing: true)
  }
}
