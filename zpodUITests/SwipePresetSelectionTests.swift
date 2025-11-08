//
//  SwipePresetSelectionTests.swift
//  zpodUITests
//
//  Created for Issue 12.8.1: SwipeConfiguration UI Test Decomposition
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
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline starts at default
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
    
    // Apply Playback preset
    applyPreset(identifier: "SwipeActions.Preset.Playback")
    
    // Verify save button enabled
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after applying Playback preset"
    )
    
    // Verify preset configuration via debug summary
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: true
      ),
      "Playback preset should configure play+addToPlaylist leading, download+favorite trailing"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testOrganizationPresetAppliesCorrectly() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline starts at default
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
    
    // Apply Organization preset
    applyPreset(identifier: "SwipeActions.Preset.Organization")
    
    // Verify save button enabled
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after applying Organization preset"
    )
    
    // Verify preset configuration via debug summary
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed", "favorite"],
        trailing: ["archive", "delete"],
        unsaved: true
      ),
      "Organization preset should configure markPlayed+favorite leading, archive+delete trailing"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testDownloadPresetAppliesCorrectly() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline starts at default
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
    
    // Apply Download preset
    applyPreset(identifier: "SwipeActions.Preset.Download")
    
    // Verify save button enabled
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after applying Download preset"
    )
    
    // Verify preset configuration via debug summary
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["download", "markPlayed"],
        trailing: ["archive", "delete"],
        unsaved: true
      ),
      "Download preset should configure download+markPlayed leading, archive+delete trailing"
    )
    
    restoreDefaultConfiguration()
  }
}
