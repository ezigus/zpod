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

  // Override to disable debug overlay for basic display tests
  override var baseLaunchEnvironment: [String: String] {
    var env = super.baseLaunchEnvironment
    env["UITEST_SWIPE_DEBUG"] = "0"  // Display tests don't need debug overlay
    return env
  }

  @MainActor
  func testConfigurationSheetOpensFromEpisodeList() throws {
    _ = try reuseOrOpenConfigurationSheet()
  }

  @MainActor
  func testAllSectionsAppearInSheet() throws {
    guard let container = try reuseOrOpenConfigurationSheet() else {
      XCTFail("Swipe configuration sheet container should be discoverable")
      return
    }

    XCTAssertTrue(
      waitForSectionIfNeeded(timeout: postReadinessTimeout),
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
        waitForElement(element, timeout: postReadinessTimeout, description: id),
        "\(id) should be visible in configuration sheet"
      )
    }
  }

  @MainActor
  func testDefaultActionsDisplayCorrectly() throws {
    guard let container = try reuseOrOpenConfigurationSheet() else {
      XCTFail("Swipe configuration sheet container should be discoverable")
      return
    }

    // Display tests don't use debug overlay, skip debug summary check
    // Just verify the action list is visible

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Mark Played"],
      trailingIdentifiers: ["SwipeActions.Trailing.Delete", "SwipeActions.Trailing.Archive"]
    )

    verifyHapticControlsVisible(container: container)
  }

  // MARK: - Private Helpers

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
          timeout: postReadinessTimeout,
          description: "haptic toggle"
        ),
        "Haptic toggle should be visible"
      )
    }

    let stylePicker = app.segmentedControls.matching(identifier: "SwipeActions.Haptics.StylePicker")
      .firstMatch
    XCTAssertTrue(
      waitForElement(
        stylePicker, timeout: postReadinessTimeout, description: "haptic style picker"),
      "Haptic style picker should exist"
    )
  }
}
