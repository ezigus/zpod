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
  func testSeededCustomConfigurationPersists() throws {
    launchAppWithSeed(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      allowFullSwipeLeading: true,
      allowFullSwipeTrailing: false,
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )
    try openConfigurationSheetFromEpisodeList()
    assertActionList(
      leadingIdentifiers: [
        "SwipeActions.Leading.Play",
        "SwipeActions.Leading.Add to Playlist",
      ],
      trailingIdentifiers: [
        "SwipeActions.Trailing.Download",
        "SwipeActions.Trailing.Favorite",
      ]
    )
    assertHapticsEnabled(true, styleLabel: "Rigid")
    restoreDefaultConfiguration()
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
    restoreDefaultConfiguration()
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
    restoreDefaultConfiguration()
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
    restoreDefaultConfiguration()
  }
}
