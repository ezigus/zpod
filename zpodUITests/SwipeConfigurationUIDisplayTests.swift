//
//  SwipeConfigurationUIDisplayTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify the swipe configuration UI displays correctly
//

import Foundation
import OSLog
import XCTest

/// Tests that verify the swipe configuration sheet opens and displays default UI elements
final class SwipeConfigurationUIDisplayTests: SwipeConfigurationTestCase {
  @MainActor
  func testConfigurationSheetDisplaysDefaultUI() throws {
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

    XCTAssertTrue(
      waitForBaselineLoaded(timeout: adaptiveTimeout),
      "Configuration baseline should load"
    )

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Default configuration should show markPlayed leading, delete+archive trailing"
    )

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Mark Played"],
      trailingIdentifiers: ["SwipeActions.Trailing.Delete", "SwipeActions.Trailing.Archive"]
    )

    verifyHapticControlsVisible()
  }

  @MainActor
  private func verifyHapticControlsVisible() {
    let hapticToggle = resolveToggleSwitch(identifier: "SwipeActions.Haptics.Toggle")
    XCTAssertNotNil(
      hapticToggle,
      "Haptic feedback toggle should be present in configuration sheet"
    )

    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.Toggle", container: container)
    }

    if let toggle = hapticToggle {
      XCTAssertTrue(
        waitForElement(
          toggle,
          timeout: adaptiveShortTimeout,
          description: "haptic toggle"
        ),
        "Haptic toggle should be visible"
      )
    }

    let stylePicker = app.segmentedControls["SwipeActions.Haptics.StylePicker"]
    XCTAssertTrue(
      waitForElement(stylePicker, timeout: adaptiveShortTimeout, description: "haptic style picker"),
      "Haptic style picker should exist"
    )
  }
}
