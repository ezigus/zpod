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
    // GIVEN: App launches with seeded configuration via environment variable:
    //        - Leading: "Play", "Add to Playlist"
    //        - Trailing: "Delete", "Favorite"
    //        - Full swipe: Leading=OFF, Trailing=ON
    //        - Haptics: Enabled with "Rigid" style
    // WHEN: User opens the swipe configuration sheet
    // THEN: Seeded configuration is persisted and displayed correctly:
    //       - All seeded actions appear in correct order
    //       - Full swipe toggles match seeded values
    //       - Haptic settings match seeded values
    //       - Debug state shows unsaved=false (persisted from seed)
    //
    // Spec: Issue #02.6.3 - Persistence Test (Consolidated)
    // Validates that seeded configurations via UserDefaults are correctly
    // persisted, loaded, and displayed across all configuration controls.

    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["delete", "favorite"],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    try reuseOrOpenConfigurationSheet(resetDefaults: true)

    guard
      expectDebugState(
        leading: ["play", "addToPlaylist"],
        trailing: ["delete", "favorite"],
        unsaved: false,
        timeout: adaptiveTimeout
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

    assertHapticsEnabled(true, styleLabel: "Rigid", timeout: adaptiveTimeout)
    assertFullSwipeState(leading: false, trailing: true, timeout: adaptiveTimeout)
  }
}
