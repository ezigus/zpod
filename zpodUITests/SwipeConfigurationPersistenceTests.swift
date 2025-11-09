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
  func testManualConfigurationPersists() throws {
    try beginWithFreshConfigurationSheet()
    
    // Configure custom layout manually
    configureMinimalCustomLayout()
    setHaptics(enabled: true, styleLabel: "Rigid")
    
    // Save and dismiss
    saveAndDismissConfiguration()
    
    // Relaunch app without resetting defaults
    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()
    
    // Verify configuration persisted
    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Mark Played", "SwipeActions.Leading.Play"],
      trailingIdentifiers: ["SwipeActions.Trailing.Delete", "SwipeActions.Trailing.Archive"]
    )
    assertHapticsEnabled(true, styleLabel: "Rigid")
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testHapticTogglePersistsAfterManualChange() throws {
    try beginWithFreshConfigurationSheet()
    setHaptics(enabled: false, styleLabel: "Medium")
    assertHapticsEnabled(false)
    saveAndDismissConfiguration()
    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()
    assertHapticsEnabled(false)
    restoreDefaultConfiguration()
  }

  @MainActor
  func testHapticStylePersistsAfterManualChange() throws {
    try beginWithFreshConfigurationSheet()
    setHaptics(enabled: true, styleLabel: "Soft")
    assertHapticsEnabled(true, styleLabel: "Soft")
    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()
    assertHapticsEnabled(true, styleLabel: "Soft")

    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testFullSwipeSettingPersists() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify default full swipe state
    assertFullSwipeState(leading: true, trailing: false)
    
    // Change full swipe toggles
    setFullSwipeToggle(identifier: "SwipeActions.Leading.FullSwipe", enabled: false)
    setFullSwipeToggle(identifier: "SwipeActions.Trailing.FullSwipe", enabled: true)
    assertFullSwipeState(leading: false, trailing: true)
    
    saveAndDismissConfiguration()
    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()
    assertFullSwipeState(leading: false, trailing: true)
    restoreDefaultConfiguration()
  }
}
