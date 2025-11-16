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
    try beginWithFreshConfigurationSheet()

    // Verify sheet opened with multiple indicators
    let sheetIndicators: [XCUIElement] = [
      app.navigationBars.matching(identifier: "Swipe Actions").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Save").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch,
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
      waitForSectionMaterialization(timeout: adaptiveShortTimeout),
      "Swipe sections should materialize after sheet opens"
    )

    XCTAssertTrue(
      waitForBaselineLoaded(timeout: adaptiveTimeout),
      "Configuration baseline should load"
    )

    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    XCTAssertTrue(
      waitForElement(summaryElement, timeout: adaptiveShortTimeout, description: "debug summary"),
      "Debug summary should exist"
    )
    if let raw = summaryElement.value as? String {
      XCTAssertTrue(
        raw.contains("Controller="),
        "Debug summary should include controller identifier for fast-fail navigation checks"
      )
    }

    XCTAssertNotNil(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Default configuration should show markPlayed leading, delete+archive trailing"
    )

    guard let container = swipeActionsSheetListContainer() else {
      XCTFail("Swipe configuration sheet container should be discoverable")
      reportAvailableSwipeIdentifiers(context: "Missing sheet container", scoped: true)
      return
    }

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Mark Played"],
      trailingIdentifiers: ["SwipeActions.Trailing.Delete", "SwipeActions.Trailing.Archive"]
    )

    verifyHapticControlsVisible(container: container)
  }

  @MainActor
  private func verifyHapticControlsVisible(container: XCUIElement) {
    let hapticToggle = resolveToggleSwitch(identifier: "SwipeActions.Haptics.Toggle")
    XCTAssertNotNil(
      hapticToggle,
      "Haptic feedback toggle should be present in configuration sheet"
    )

    _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.Toggle", container: container)

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

    let stylePicker = app.segmentedControls.matching(identifier: "SwipeActions.Haptics.StylePicker").firstMatch
    XCTAssertTrue(
      waitForElement(stylePicker, timeout: adaptiveShortTimeout, description: "haptic style picker"),
      "Haptic style picker should exist"
    )
  }
}
