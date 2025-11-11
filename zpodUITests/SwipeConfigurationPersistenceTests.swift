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
}
