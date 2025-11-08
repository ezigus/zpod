//
//  SwipeActionManagementTests.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Tests that verify swipe action addition, removal, and limit enforcement
//

import Foundation
import OSLog
import XCTest

/// Tests that verify swipe action management (add, remove, limits)
final class SwipeActionManagementTests: SwipeConfigurationTestCase {
  
  // MARK: - Action Management Tests
  
  @MainActor
  func testAddingSingleLeadingAction() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
    
    // Add Play action to leading
    XCTAssertTrue(
      addAction("Play", edgeIdentifier: "Leading"),
      "Should be able to add Play action to leading edge"
    )
    
    // Verify action was added
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed", "play"],
        trailing: ["delete", "archive"],
        unsaved: true
      ),
      "Play action should be added to leading edge"
    )
    
    // Verify save button enabled
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after adding action"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testAddingSingleTrailingAction() throws {
    try beginWithFreshConfigurationSheet()
    
    // Verify baseline
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Should start with default configuration"
    )
    
    // Add Download action to trailing
    XCTAssertTrue(
      addAction("Download", edgeIdentifier: "Trailing"),
      "Should be able to add Download action to trailing edge"
    )
    
    // Verify action was added
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive", "download"],
        unsaved: true
      ),
      "Download action should be added to trailing edge"
    )
    
    // Verify save button enabled
    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after adding action"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testRemovingLeadingAction() throws {
    try beginWithFreshConfigurationSheet()
    
    // First add an action so we have multiple to remove from
    _ = addAction("Play", edgeIdentifier: "Leading")
    
    // Wait for it to be added
    guard
      waitForDebugSummary(
        leading: ["markPlayed", "play"],
        trailing: ["delete", "archive"],
        unsaved: true
      )
    else {
      XCTFail("Failed to add Play action as setup step")
      return
    }
    
    // Now remove Mark Played action
    XCTAssertTrue(
      removeAction("Mark Played", edgeIdentifier: "Leading"),
      "Should be able to remove Mark Played action from leading edge"
    )
    
    // Verify action was removed
    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play"],
        trailing: ["delete", "archive"],
        unsaved: true
      ),
      "Mark Played action should be removed from leading edge"
    )
    
    restoreDefaultConfiguration()
  }
  
  @MainActor
  func testActionLimitEnforcementLeading() throws {
    try beginWithFreshConfigurationSheet()
    
    // Default has 1 leading action ["markPlayed"]
    // Add 2 more to reach the cap of 3
    let actionsToAdd: [(displayName: String, rawValue: String)] = [
      ("Play", "play"),
      ("Add to Playlist", "addToPlaylist"),
    ]
    
    var expectedLeading = ["markPlayed"]
    
    for action in actionsToAdd {
      XCTAssertTrue(
        addAction(action.displayName, edgeIdentifier: "Leading"),
        "Should be able to add action \(action.displayName)"
      )
      expectedLeading.append(action.rawValue)
      
      guard
        waitForDebugSummary(
          leading: expectedLeading,
          trailing: ["delete", "archive"],
          unsaved: true
        )
      else {
        XCTFail("Failed to add \(action.displayName) action")
        return
      }
    }
    
    // Verify we're at the cap (3 actions)
    XCTAssertEqual(expectedLeading.count, 3, "Should have 3 leading actions at cap")
    
    // Verify add button disappears when limit reached
    let addButton = element(withIdentifier: "SwipeActions.Add.Leading")
    XCTAssertTrue(
      waitForElementToDisappear(addButton, timeout: adaptiveShortTimeout),
      "Add Action button should disappear once leading action limit (3) is reached"
    )
    
    // Verify trailing add button still exists (not at limit)
    let trailingAddButton = element(withIdentifier: "SwipeActions.Add.Trailing")
    XCTAssertTrue(
      waitForElement(
        trailingAddButton,
        timeout: adaptiveShortTimeout,
        description: "Trailing add action button"
      ),
      "Trailing add action button should remain visible when under the limit"
    )
    
    restoreDefaultConfiguration()
  }
}
