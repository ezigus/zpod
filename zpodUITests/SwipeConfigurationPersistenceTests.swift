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
    configurePlaybackLayoutManually()
    setHaptics(enabled: true, styleLabel: "Rigid")
    
    // Save and dismiss
    saveAndDismissConfiguration()
    
    // Relaunch app without resetting defaults
    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()
    
    // Verify configuration persisted
    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Play", "SwipeActions.Leading.Add to Playlist"],
      trailingIdentifiers: ["SwipeActions.Trailing.Download", "SwipeActions.Trailing.Favorite"]
    )
    assertHapticsEnabled(true, styleLabel: "Rigid")
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testHapticSettingPersists() throws {
    try beginWithFreshConfigurationSheet()
    
    // Disable haptics and select Soft style
    setHaptics(enabled: false, styleLabel: "Medium")
    assertHapticsEnabled(false)
    
    // Save and dismiss
    saveAndDismissConfiguration()
    
    // Seed configuration for relaunch (avoiding UserDefaults cross-launch issues)
    seedSwipeConfiguration(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      allowFullSwipeLeading: true,
      allowFullSwipeTrailing: false,
      hapticsEnabled: false,
      hapticStyle: "medium"
    )
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    
    try openConfigurationSheetFromEpisodeList()
    
    // Verify haptics remain disabled
    assertHapticsEnabled(false)
    
    // Now enable haptics with Soft style
    setHaptics(enabled: true, styleLabel: "Soft")
    assertHapticsEnabled(true, styleLabel: "Soft")
    
    // Save and dismiss
    saveAndDismissConfiguration()
    
    // Seed configuration with haptics enabled for second relaunch
    seedSwipeConfiguration(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      allowFullSwipeLeading: true,
      allowFullSwipeTrailing: false,
      hapticsEnabled: true,
      hapticStyle: "soft"
    )
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    
    try openConfigurationSheetFromEpisodeList()
    
    // Verify haptics enabled with Soft style persisted
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
    
    // Save and dismiss
    saveAndDismissConfiguration()
    
    // Seed configuration for relaunch
    seedSwipeConfiguration(
      leading: ["markPlayed"],
      trailing: ["delete", "archive"],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticsEnabled: true,
      hapticStyle: "medium"
    )
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    
    try openConfigurationSheetFromEpisodeList()
    
    // Verify full swipe settings persisted
    assertFullSwipeState(leading: false, trailing: true)
    
    restoreDefaultConfiguration()
  }
}
