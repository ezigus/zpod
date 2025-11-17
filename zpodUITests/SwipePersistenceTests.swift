//
//  SwipePersistenceTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Persistence scenarios split from the prior complex suite.
//

import XCTest

/// Tests that verify seeded swipe configurations persist and surface correctly.
final class SwipePersistenceTests: SwipeConfigurationTestCase {

  @MainActor
  func testSeededConfigurationPersistsAcrossControls() throws {
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["delete", "favorite"],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    try openConfigurationSheetFromEpisodeList()

    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "favorite"],
        unsaved: false
      ) != nil
    else { return }

    assertActionList(
      leadingIdentifiers: [
        "SwipeActions.Leading.Play",
        "SwipeActions.Leading.Add to Playlist",
      ],
      trailingIdentifiers: [
        "SwipeActions.Trailing.Delete",
        "SwipeActions.Trailing.Favorite",
      ]
    )

    assertHapticsEnabled(true, styleLabel: "Rigid")
    assertFullSwipeState(leading: false, trailing: true)
  }
}
