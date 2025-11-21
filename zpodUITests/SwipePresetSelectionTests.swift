//
//  SwipePresetSelectionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe action preset selection and application
//

import Foundation
import OSLog
import XCTest

/// Tests that verify swipe action presets apply correct configurations
final class SwipePresetSelectionTests: SwipeConfigurationTestCase {

  // MARK: - Preset Selection Tests

  @MainActor
  func testPlaybackPresetAppliesCorrectly() throws {
    try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Playback")
    assertSaveEnabledAfterPreset()
    assertConfiguration(
      leadingActions: ["Play", "Add to Playlist"],
      trailingActions: ["Download", "Favorite"]
    )
  }

  @MainActor
  func testOrganizationPresetAppliesCorrectly() throws {
    try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Organization")
    assertSaveEnabledAfterPreset()
    assertConfiguration(
      leadingActions: ["Mark Played", "Favorite"],
      trailingActions: ["Archive", "Delete"]
    )
  }

  @MainActor
  func testDownloadPresetAppliesCorrectly() throws {
    try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Download")
    assertSaveEnabledAfterPreset()
    assertConfiguration(
      leadingActions: ["Download", "Mark Played"],
      trailingActions: ["Archive", "Delete"]
    )
  }

  @MainActor
  private func assertConfiguration(
    leadingActions: [String],
    trailingActions: [String]
  ) {
    // Verify preset applied to draft configuration (UI state)
    assertActionList(
      leadingIdentifiers: leadingActions.map { "SwipeActions.Leading.\($0)" },
      trailingIdentifiers: trailingActions.map { "SwipeActions.Trailing.\($0)" }
    )
    // Note: Persistence validation happens in SwipeConfigurationPersistenceTests
    // after Save button is tapped. These preset tests only verify draft state.
  }

  @MainActor
  private func assertSaveEnabledAfterPreset() {
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveTimeout),
      "Save button did not enable after applying preset."
    )
  }
}
