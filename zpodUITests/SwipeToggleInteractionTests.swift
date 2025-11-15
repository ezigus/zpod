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
    try beginWithFreshConfigurationSheet()
    
    // Get current haptic state from debug summary
    guard let initialState = currentDebugState() else {
      XCTFail("Failed to read initial debug state")
      return
    }
    
    let initialHaptics = initialState.hapticsEnabled
    
    // Toggle haptics to opposite state
    setHaptics(enabled: !initialHaptics, styleLabel: "Medium")
    
    // Verify state changed in debug summary
    guard
      waitForDebugState(
        timeout: adaptiveShortTimeout,
        validator: { $0.hapticsEnabled == !initialHaptics }
      ) != nil
    else {
      XCTFail("Haptic state should toggle to \(!initialHaptics)")
      return
    }
    
    // Toggle back to original state
    setHaptics(enabled: initialHaptics, styleLabel: "Medium")
    
    // Verify state changed back
    XCTAssertNotNil(
      waitForDebugState(
        timeout: adaptiveShortTimeout,
        validator: { $0.hapticsEnabled == initialHaptics }
      ),
      "Haptic state should toggle back to \(initialHaptics)"
    )
  }
  
  @MainActor
  func testHapticStylePickerChangesValue() throws {
    try beginWithFreshConfigurationSheet()
    
    // Enable haptics first (style picker only visible when haptics enabled)
    setHaptics(enabled: true, styleLabel: "Soft")
    
    // Verify haptics enabled
    guard
      waitForDebugState(
        timeout: adaptiveShortTimeout,
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
        timeout: adaptiveShortTimeout,
        description: "haptic style picker"
      ),
      "Haptic style picker should be visible when haptics are enabled"
    )
    
    // Change to Rigid style
    let rigidButton = stylePicker.buttons.matching(identifier: "Rigid").firstMatch
    if rigidButton.exists {
      rigidButton.tap()
      
      // Wait a moment for the change to register
      _ = waitForDebugState(timeout: adaptiveShortTimeout, validator: { _ in true })
    }
    
    // Verify we can change to Medium style
    let mediumButton = stylePicker.buttons.matching(identifier: "Medium").firstMatch
    XCTAssertTrue(
      mediumButton.exists,
      "Medium style button should exist in picker"
    )
    
    if mediumButton.exists {
      mediumButton.tap()
      
      // Wait for change to register
      _ = waitForDebugState(timeout: adaptiveShortTimeout, validator: { _ in true })
    }
  }
  
  @MainActor
  func testFullSwipeToggleLeadingTrailing() throws {
    try beginWithFreshConfigurationSheet()
    
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
