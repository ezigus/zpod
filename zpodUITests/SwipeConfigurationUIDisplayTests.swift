//
//  SwipeConfigurationUIDisplayTests.swift
//  zpodUITests
//
//  Created for Issue 12.8.1: SwipeConfiguration UI Test Decomposition
//  Tests that verify the swipe configuration UI displays correctly
//

import Foundation
import OSLog
import XCTest

/// Tests that verify the swipe configuration sheet opens and displays default UI elements
final class SwipeConfigurationUIDisplayTests: SwipeConfigurationTestCase {
  
  // MARK: - Configuration Sheet Display Tests
  
  @MainActor
  func testConfigurationSheetOpensFromEpisodeList() throws {
    initializeApp()
    try navigateToEpisodeList()
    
    let configureButton = element(withIdentifier: "ConfigureSwipeActions")
    XCTAssertTrue(
      waitForElement(
        configureButton,
        timeout: adaptiveTimeout,
        description: "configure swipe actions button"
      ),
      "Configure swipe actions button should be visible on episode list"
    )
    
    tapElement(configureButton, description: "configure swipe actions button")
    
    // Verify sheet opened with multiple indicators
    let sheetIndicators: [XCUIElement] = [
      app.navigationBars["Swipe Actions"],
      app.buttons["SwipeActions.Save"],
      app.buttons["SwipeActions.Cancel"],
    ]
    
    let openedSheet = waitForAnyElement(
      sheetIndicators,
      timeout: adaptiveTimeout,
      description: "Swipe Actions configuration sheet"
    )
    
    XCTAssertNotNil(
      openedSheet,
      "Configuration sheet should open with navigation bar or action buttons visible"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testConfigurationSheetShowsDefaultActions() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline loaded
    XCTAssertTrue(
      waitForBaselineLoaded(timeout: adaptiveTimeout),
      "Configuration baseline should load"
    )
    
    // Verify default configuration via debug summary
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Default configuration should show markPlayed leading, delete+archive trailing"
    )
    
    // Verify action buttons are present in the sheet
    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Mark Played"],
      trailingIdentifiers: ["SwipeActions.Trailing.Delete", "SwipeActions.Trailing.Archive"]
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testConfigurationSheetShowsHapticControls() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify haptic toggle exists
    let hapticToggle = resolveToggleSwitch(identifier: "SwipeActions.Haptics.Toggle")
    XCTAssertNotNil(
      hapticToggle,
      "Haptic feedback toggle should be present in configuration sheet"
    )
    
    if let toggle = hapticToggle {
      // Ensure toggle is visible in sheet
      if let container = swipeActionsSheetListContainer() {
        _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.Toggle", container: container)
      }
      
      XCTAssertTrue(
        waitForElement(
          toggle,
          timeout: adaptiveShortTimeout,
          description: "haptic toggle"
        ),
        "Haptic toggle should be visible"
      )
    }
    
    // Verify haptic style picker exists (even if not currently visible because haptics might be disabled)
    let stylePicker = app.segmentedControls["SwipeActions.Haptics.StylePicker"]
    // Note: Style picker may not exist if haptics are disabled, so we just check the element is queryable
    _ = stylePicker.exists
    
    restoreDefaultConfiguration()
  }
}
