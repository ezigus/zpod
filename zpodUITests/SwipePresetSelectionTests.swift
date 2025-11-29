//
//  SwipePresetSelectionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe action preset selection and application
//
//  MIGRATION EXAMPLE (Issue #148 - Phase 3):
//  This test suite demonstrates successful infrastructure migration with ZERO test code changes.
//
//  Before Infrastructure Fixes (Nov 28, 2025):
//    - Pass rate: 66.7% (2/3 tests passing)
//    - testDownloadPresetAppliesCorrectly: FAILED
//    - Failure: "Element 'SwipeActions.Preset.Download' not found within 1.5s"
//    - Root cause: settle() only waited 50ms after scroll for SwiftUI materialization
//
//  After Infrastructure Fixes (Nov 29, 2025):
//    - Pass rate: 100% (3/3 tests passing)
//    - testDownloadPresetAppliesCorrectly: PASSES
//    - NO test code changes required
//    - Improvement: +33.3% pass rate from infrastructure alone
//
//  Infrastructure Improvements Applied:
//    1. Cleanup: performSwipeConfigurationCleanup() now runs in tearDown (prevents state pollution)
//    2. Scroll timing: settle() increased from 50ms → 300ms (deterministic SwiftUI materialization)
//    3. Both fixes applied automatically via SwipeConfigurationTestCase base class
//
//  Key Insight:
//    Infrastructure fixes in base class and shared utilities benefit ALL tests automatically.
//    Proper settle() timing after scroll is critical for SwiftUI lazy loading.
//
//  See: docs/testing/flakiness-migration-guide.md for detailed examples
//

import Foundation
import OSLog
import XCTest

/// Tests that verify swipe action presets apply correct configurations
///
/// INFRASTRUCTURE MIGRATION STATUS: ✅ COMPLETE
/// - Cleanup: ✅ Automatic (via SwipeConfigurationTestCase.tearDown)
/// - Scroll timing: ✅ Fixed (via settle() infrastructure)
/// - Pass rate: 100% (3/3 tests)
final class SwipePresetSelectionTests: SwipeConfigurationTestCase {

  // MARK: - Preset Selection Tests

  @MainActor
  func testPlaybackPresetAppliesCorrectly() throws {
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User taps the "Playback" preset button
    // THEN: Configuration updates to Playback preset:
    //       - Leading: "Play", "Add to Playlist"
    //       - Trailing: "Download", "Favorite"
    //       - Save button becomes enabled (draft has unsaved changes)
    //
    // Spec: Issue #02.6.3 - Preset Selection Test 1
    // Validates that the Playback preset applies the correct action configuration
    // optimized for playback control scenarios.

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
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User taps the "Organization" preset button
    // THEN: Configuration updates to Organization preset:
    //       - Leading: "Mark Played", "Favorite"
    //       - Trailing: "Archive", "Delete"
    //       - Save button becomes enabled (draft has unsaved changes)
    //
    // Spec: Issue #02.6.3 - Preset Selection Test 2
    // Validates that the Organization preset applies the correct action
    // configuration optimized for library organization workflows.

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
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User taps the "Download" preset button
    // THEN: Configuration updates to Download preset:
    //       - Leading: "Download", "Mark Played"
    //       - Trailing: "Archive", "Delete"
    //       - Save button becomes enabled (draft has unsaved changes)
    //
    // Spec: Issue #02.6.3 - Preset Selection Test 3
    // Validates that the Download preset applies the correct action
    // configuration optimized for offline listening workflows.

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
