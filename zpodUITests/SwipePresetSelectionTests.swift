//
//  SwipePresetSelectionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe action preset selection and application
//
//  MIGRATION EXAMPLE (Issue #148 - Phase 3):
//  This test suite demonstrates iterative infrastructure fixes that improved pass rate from 66.7% → 100%.
//
//  PHASE 1: Infrastructure Improvements (Nov 28, 2025)
//    - Problem: settle() timeout too short (50ms) + missing cleanup
//    - Fix: Infrastructure changes only (no test code changes)
//      1. Cleanup: performSwipeConfigurationCleanup() now runs in tearDown
//      2. Scroll timing: settle() increased from 50ms → 300ms
//    - Result: Improved stability but still ~33% failure in full regression runs
//
//  PHASE 2: Container Race Condition Fix (Nov 29, 2025)
//    - Problem: applyPreset() rediscovered container immediately after app relaunch
//    - Root cause: In full regression with resetDefaults=true, UI still settling from relaunch
//    - Symptom: testOrganizationPresetAppliesCorrectly failed randomly (66.7% pass rate)
//    - Error: "Swipe configuration sheet not found. Sheet may have been dismissed or not yet opened."
//    - Fix: Minimal test changes (3 lines per test):
//      1. Updated applyPreset() to accept optional container parameter
//      2. Tests now pass already-verified container instead of rediscovering
//    - Result: 100% pass rate (3/3 tests)
//    - Improvement: +33.3% pass rate from container fix
//
//  FINAL METRICS:
//    - Before all fixes: 66.7% pass rate (2/3)
//    - After Phase 1: ~67-80% pass rate (infrastructure only)
//    - After Phase 2: 100% pass rate (3/3)
//    - Total code changes: 3 lines per test (capture + pass container)
//    - Philosophy: Deterministic testing - reuse verified state instead of adding waits
//
//  Key Insights:
//    1. Infrastructure fixes benefit ALL tests automatically via base class
//    2. Minimal test changes (reusing verified container) eliminate race conditions
//    3. Proper settle() timing critical for SwiftUI lazy loading after scroll
//    4. Container reuse avoids timing dependencies after app relaunch
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

    let container = try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Playback", container: container)
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

    let container = try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Organization", container: container)
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

    let container = try reuseOrOpenConfigurationSheet(resetDefaults: true)
    applyPreset(identifier: "SwipeActions.Preset.Download", container: container)
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
