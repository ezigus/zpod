//
//  SwipeConfigurationUIDisplayTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify the swipe configuration UI displays correctly
//

import Foundation
import XCTest

/// Tests that verify the swipe configuration sheet opens and displays default UI elements
final class SwipeConfigurationUIDisplayTests: SwipeConfigurationTestCase {
  @MainActor
  func testConfigurationSheetOpensFromEpisodeList() throws {
    _ = try openConfigurationSheet()
  }

  @MainActor
  func testAllSectionsAppearInSheet() throws {
    guard let container = try openConfigurationSheet() else {
      XCTFail("Swipe configuration sheet container should be discoverable")
      return
    }

    XCTAssertTrue(
      waitForSectionIfNeeded(timeout: adaptiveShortTimeout),
      "Swipe sections should materialize after sheet opens"
    )

    let identifiers = [
      "SwipeActions.Haptics.Toggle",
      "SwipeActions.Leading.FullSwipe",
      "SwipeActions.Trailing.FullSwipe",
      "SwipeActions.Add.Leading",
      "SwipeActions.Add.Trailing",
      "SwipeActions.Preset.Playback",
    ]

    for id in identifiers {
      _ = ensureVisibleInSheet(identifier: id, container: container, scrollAttempts: 2)
      let element = self.element(withIdentifier: id, within: container)
      XCTAssertTrue(
        waitForElement(element, timeout: adaptiveShortTimeout, description: id),
        "\(id) should be visible in configuration sheet"
      )
    }
  }

  @MainActor
  func testDefaultActionsDisplayCorrectly() throws {
    guard let container = try openConfigurationSheet() else {
      XCTFail("Swipe configuration sheet container should be discoverable")
      return
    }

    XCTAssertNotNil(
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

    verifyHapticControlsVisible(container: container)
  }

  // MARK: - Private Helpers

  @MainActor
  private func openConfigurationSheet() throws -> XCUIElement? {
    try beginWithFreshConfigurationSheet()

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
      waitForBaselineLoaded(timeout: adaptiveTimeout),
      "Configuration baseline should load"
    )

    return swipeActionsSheetListContainer()
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

    let stylePicker = app.segmentedControls.matching(identifier: "SwipeActions.Haptics.StylePicker")
      .firstMatch
    XCTAssertTrue(
      waitForElement(stylePicker, timeout: adaptiveShortTimeout, description: "haptic style picker"),
      "Haptic style picker should exist"
    )
  }
}
