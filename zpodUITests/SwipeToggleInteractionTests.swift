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
        timeout: postReadinessTimeout,
        validator: { $0.hapticsEnabled == target }
      ),
      "Haptic state should toggle to \(target)"
    )

    // Toggle back to original state
    setHaptics(enabled: initialSummary.hapticsEnabled, styleLabel: "Medium")
    assertHapticsToggleState(expected: initialSummary.hapticsEnabled)
    XCTAssertNotNil(
      waitForDebugState(
        timeout: postReadinessTimeout,
        validator: { $0.hapticsEnabled == initialSummary.hapticsEnabled }
      ),
      "Haptic state should toggle back to \(initialSummary.hapticsEnabled)"
    )
  }
  
  @MainActor
  func testHapticStylePickerChangesValue() throws {
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
        timeout: postReadinessTimeout,
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
    if rigidButton.exists {
      rigidButton.tap()
    }
    
    // Verify we can change to Medium style
    let mediumButton = stylePicker.buttons.matching(identifier: "Medium").firstMatch
    XCTAssertTrue(
      mediumButton.exists,
      "Medium style button should exist in picker"
    )
    
    if mediumButton.exists {
      mediumButton.tap()
    }
  }
  
  @MainActor
  func testFullSwipeToggleLeadingTrailing() throws {
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
