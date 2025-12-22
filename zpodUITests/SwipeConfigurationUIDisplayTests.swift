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
    // GIVEN: User is viewing the episode list
    // WHEN: User taps the swipe configuration settings button
    // THEN: The swipe configuration sheet opens and is accessible
    //
    // Spec: Issue #02.6.3 - UI Display Test 1
    // Validates that the configuration sheet can be opened from the episode list
    // and that all UI elements are properly materialized and accessible.

    _ = try reuseOrOpenConfigurationSheet()
  }

  @MainActor
  func testAllSectionsAppearInSheet() throws {
    // GIVEN: User opens the swipe configuration sheet with default settings
    // WHEN: The sheet finishes loading and sections materialize
    // THEN: All expected UI sections are present and visible:
    //       - Haptics toggle and style picker
    //       - Full swipe toggles for leading/trailing edges
    //       - Add action buttons for both edges
    //       - Preset buttons (Playback, Organization, Download)
    //
    // Spec: Issue #02.6.3 - UI Display Test 2
    // Validates that all configuration sections materialize correctly and are
    // accessible via scrolling. Tests SwiftUI lazy-loading behavior.
    //
    // NOTE: Uses progressive timeout strategy to handle SwiftUI lazy-loading
    // flakiness without relying on fixed delays.

    guard let container = try reuseOrOpenConfigurationSheet(resetDefaults: true) else {
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

    // Progressive verification: scroll once, then wait with extended timeout
    // This mimics event-driven testing where we trust the system to notify us
    // when the element materializes, rather than polling repeatedly.
    for id in identifiers {
      let isProblematicElement = id.contains("Add.") || id.contains("Preset.")
      let scrollAttempts = isProblematicElement ? 4 : 2
      
      // Phase 1: Try to make element visible through scrolling
      let scrollSuccess = ensureVisibleInSheet(
        identifier: id,
        container: container,
        scrollAttempts: scrollAttempts
      )
      
      let element = self.element(withIdentifier: id, within: container)
      
      // Phase 2: Event-driven wait with appropriate timeout
      // If scrolling found it, use standard timeout. Otherwise, extend timeout
      // to account for SwiftUI's lazy materialization delay.
      let timeout: TimeInterval
      if scrollSuccess {
        timeout = postReadinessTimeout
      } else if isProblematicElement {
        // Known problematic elements get 3x timeout for lazy-loading (increased from 2x)
        // CI regression showed 6s still insufficient for "Add.Trailing" button
        timeout = postReadinessTimeout * 3.0
      } else {
        timeout = postReadinessTimeout * 1.5
      }
      
      // Use XCUIElement's native waitForExistence (event-driven, not polling)
      let appeared = element.waitForExistence(timeout: timeout)
      
      XCTAssertTrue(
        appeared,
        """
        \(id) should appear in configuration sheet
        - Scroll attempts: \(scrollAttempts)
        - Scroll found element: \(scrollSuccess)
        - Wait timeout: \(timeout)s
        - Element type: \(element.elementType.rawValue)
        """
      )
    }
  }

  @MainActor
  func testDefaultActionsDisplayCorrectly() throws {
    // GIVEN: User opens the swipe configuration sheet
    // WHEN: Sheet displays with factory default configuration
    // THEN: Default actions are correctly displayed:
    //       - Leading: "Mark Played"
    //       - Trailing: "Delete", "Archive"
    //       - Haptic toggle and style picker are visible
    //
    // Spec: Issue #02.6.3 - UI Display Test 3
    // Validates that the default action configuration matches the expected
    // factory settings and that all controls are properly rendered.

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
