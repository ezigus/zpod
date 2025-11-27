//
//  SwipeToggleInteractionTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify toggle interactions (haptics, full swipe)
//

import Foundation
import OSLog
import XCTest

/// Tests that verify toggle switch interactions in swipe configuration
final class SwipeToggleInteractionTests: SwipeConfigurationTestCase {
  
  // MARK: - Toggle Interaction Tests

  @MainActor
  func testHapticToggleEnablesDisables() throws {
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User toggles the haptic feedback switch on/off
    // THEN: Haptic feedback state updates correctly:
    //       - Toggle switches to opposite state
    //       - Debug summary reflects new state
    //       - Toggle can be switched back to original state
    //
    // Spec: Issue #02.6.3 - Toggle Interaction Test 1
    // Validates that the haptic feedback toggle correctly updates the draft
    // configuration state and persists across multiple toggle operations.

    try reuseOrOpenConfigurationSheet(resetDefaults: true)

    guard let toggle = requireToggleSwitch(
      identifier: "SwipeActions.Haptics.Toggle",
      context: "initial toggle load"
    ) else { return }

    let initialToggleState = currentStateIsOn(for: toggle)
    guard let initialSummary = currentDebugState() else {
      XCTFail("Failed to read initial debug state")
      return
    }

    // Toggle haptics to opposite state
    let target = !(initialToggleState ?? initialSummary.hapticsEnabled)
    setHaptics(enabled: target, styleLabel: "Medium")

    assertHapticsToggleState(expected: target)
    XCTAssertNotNil(
      waitForDebugState(
        timeout: debugStateTimeout,
        validator: { $0.hapticsEnabled == target }
      ),
      "Haptic state should toggle to \(target)"
    )

    // Toggle back to original state
    setHaptics(enabled: initialSummary.hapticsEnabled, styleLabel: "Medium")
    assertHapticsToggleState(expected: initialSummary.hapticsEnabled)
    XCTAssertNotNil(
      waitForDebugState(
        timeout: debugStateTimeout,
        validator: { $0.hapticsEnabled == initialSummary.hapticsEnabled }
      ),
      "Haptic state should toggle back to \(initialSummary.hapticsEnabled)"
    )
  }
  
  @MainActor
  func testHapticStylePickerChangesValue() throws {
    // GIVEN: User opens swipe configuration sheet with haptics enabled
    // WHEN: User changes the haptic style using the segmented control picker
    // THEN: Haptic style picker responds to taps and allows switching between:
    //       - Soft, Medium, Rigid styles
    //       - Picker is only visible when haptics are enabled
    //
    // Spec: Issue #02.6.3 - Toggle Interaction Test 2
    // Validates that the haptic style picker control works correctly and
    // that style changes can be made when haptics are enabled.

    try reuseOrOpenConfigurationSheet(resetDefaults: true)

    _ = requireToggleSwitch(
      identifier: "SwipeActions.Haptics.Toggle",
      context: "style picker precondition"
    )

    // Enable haptics first (style picker only visible when haptics enabled)
    setHaptics(enabled: true, styleLabel: "Soft")

    // Verify haptics enabled
    guard
      waitForDebugState(
        timeout: debugStateTimeout,
        validator: { $0.hapticsEnabled == true }
      ) != nil
    else {
      XCTFail("Failed to enable haptics")
      return
    }

    // Verify style picker is visible
    let stylePicker = app.segmentedControls.matching(identifier: "SwipeActions.Haptics.StylePicker").firstMatch
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.StylePicker", container: container)
    }

    XCTAssertTrue(
      waitForElement(
        stylePicker,
        timeout: postReadinessTimeout,
        description: "haptic style picker"
      ),
      "Haptic style picker should be visible when haptics are enabled"
    )

    // Change to Rigid style
    let rigidButton = stylePicker.buttons.matching(identifier: "Rigid").firstMatch
    if rigidButton.waitForExistence(timeout: postReadinessTimeout) {
      rigidButton.tap()
    }

    // Verify we can change to Medium style
    let mediumButton = stylePicker.buttons.matching(identifier: "Medium").firstMatch
    XCTAssertTrue(
      mediumButton.waitForExistence(timeout: postReadinessTimeout),
      "Medium style button should exist in picker"
    )
    // Assertion above guarantees existence, tap directly
    mediumButton.tap()
  }
  
  @MainActor
  func testFullSwipeToggleLeadingTrailing() throws {
    // GIVEN: User opens swipe configuration sheet with default settings
    // WHEN: User toggles full swipe options for leading/trailing edges
    // THEN: Full swipe state updates independently for each edge:
    //       - Default: Leading=ON, Trailing=OFF
    //       - Can toggle leading OFF while trailing stays OFF
    //       - Can toggle trailing ON while leading stays OFF
    //       - Can toggle both ON simultaneously
    //
    // Spec: Issue #02.6.3 - Toggle Interaction Test 3
    // Validates that full swipe toggles operate independently for each
    // edge and correctly update the draft configuration state.

    try reuseOrOpenConfigurationSheet(resetDefaults: true)

    // Verify default full swipe state
    assertFullSwipeState(leading: true, trailing: false)

    // Toggle leading full swipe off
    setFullSwipeToggle(identifier: "SwipeActions.Leading.FullSwipe", enabled: false)

    // Verify state changed
    assertFullSwipeState(leading: false, trailing: false)

    // Toggle trailing full swipe on
    setFullSwipeToggle(identifier: "SwipeActions.Trailing.FullSwipe", enabled: true)

    // Verify state changed
    assertFullSwipeState(leading: false, trailing: true)

    // Toggle leading back on
    setFullSwipeToggle(identifier: "SwipeActions.Leading.FullSwipe", enabled: true)

    // Verify state changed
    assertFullSwipeState(leading: true, trailing: true)
  }
}
