//
//  SwipeConfigurationTestSupport+ActionManagement.swift
//  zpodUITests
//
//  Action management helpers split out from Interactions to keep helper files lean.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  // MARK: - Action Management

  @MainActor
  @discardableResult
  func removeAction(_ displayName: String, edgeIdentifier: String) -> Bool {
    guard let container = swipeActionsSheetListContainer() else { return false }
    let rowIdentifier = "SwipeActions." + edgeIdentifier + "." + displayName
    _ = ensureVisibleInSheet(identifier: rowIdentifier, container: container)

    // Fallback pattern: Try scoped search first (faster, more precise), then app-wide.
    // Scoped search limits query to container's accessibility tree, reducing search time
    // and avoiding matches in other UI elements. Falls back to app-wide search if scoped
    // search fails (e.g., due to SwiftUI view hierarchy quirks).
    let scopedButton = container.buttons.matching(identifier: "Remove " + displayName).firstMatch
    let removeButton =
      scopedButton.exists
      ? scopedButton
      : app.buttons.matching(identifier: "Remove " + displayName).firstMatch
    guard removeButton.waitForExistence(timeout: postReadinessTimeout) else {
      return false
    }
    removeButton.tap()
    return true
  }

  @MainActor
  @discardableResult
  func addAction(_ displayName: String, edgeIdentifier: String) -> Bool {
    guard let container = swipeActionsSheetListContainer() else {
      return false
    }

    let addIdentifier = "SwipeActions.Add." + edgeIdentifier
    _ = ensureVisibleInSheet(identifier: addIdentifier, container: container)
    let addMenu = element(withIdentifier: addIdentifier, within: container)
    guard addMenu.exists else { return false }
    addMenu.tap()

    let pickerTitle: String
    switch edgeIdentifier {
    case "Leading":
      pickerTitle = String(localized: "Add Leading Action", bundle: .main)
    case "Trailing":
      pickerTitle = String(localized: "Add Trailing Action", bundle: .main)
    default:
      pickerTitle = "Add Action"
    }

    let pickerNavBar = app.navigationBars.matching(identifier: pickerTitle).firstMatch
    let fallbackPickerNavBar = app.navigationBars.matching(identifier: "Add Action").firstMatch

    let optionIdentifier = addIdentifier + "." + displayName
    let primaryOption = element(withIdentifier: optionIdentifier, within: container)
    let buttonOption = container.buttons.matching(identifier: displayName).firstMatch

    _ = waitForAnyElement(
      [
        pickerNavBar,
        fallbackPickerNavBar,
        primaryOption,
        buttonOption,
      ],
      timeout: adaptiveTimeout,
      description: "Add action picker components"
    )

    if primaryOption.exists {
      tapElement(primaryOption, description: "Add action option \(displayName)")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: postReadinessTimeout)
      }
      return true
    }

    if buttonOption.exists {
      tapElement(buttonOption, description: "Add action option \(displayName)")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: postReadinessTimeout)
      }
      return true
    }

    app.swipeUp()
    let optionAfterScroll = element(withIdentifier: optionIdentifier, within: container)
    _ = waitForElement(
      optionAfterScroll, timeout: postReadinessTimeout, description: "option after scroll")

    if optionAfterScroll.exists {
      tapElement(optionAfterScroll, description: "Add action option \(displayName) after scroll")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: postReadinessTimeout)
      }
      return true
    }

    let buttonAfterScroll = container.buttons.matching(identifier: displayName).firstMatch
    if buttonAfterScroll.exists {
      tapElement(buttonAfterScroll, description: "Add action option \(displayName) after scroll")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: postReadinessTimeout)
      }
      return true
    }

    return false
  }

  @MainActor
  func applyPreset(identifier: String, container: XCUIElement? = nil) {
    // Try debug entrypoints first (fast path - overlay, toolbar, menu, section)
    if tapDebugOverlayButton(for: identifier) { return }
    if tapDebugToolbarButton(for: identifier) { return }
    if tapDebugPresetSectionButton(for: identifier) { return }
    if tapDebugPresetFromMenu(for: identifier) { return }

    // DEFENSIVE FIX #1: Always refresh container before scrolling
    // Even caller-provided containers may be stale after previous interactions
    // SwiftUI can recreate sheet hierarchy between test steps
    guard let freshContainer = swipeActionsSheetListContainer() else {
      XCTFail(
        "Swipe configuration sheet not found before scrolling. " +
        "Sheet may have been dismissed or not yet opened.")
      return
    }

    // DEFENSIVE FIX #2: Increase scroll attempts for bottom-most presets
    // Download preset (position 4) requires maximum scroll distance
    // Previous limit (10) was insufficient; 12 provides safety margin
    let scrollSuccess = ensureVisibleInSheet(
      identifier: identifier,
      container: freshContainer,
      scrollAttempts: 12  // Increased from 10
    )

    // DEFENSIVE FIX #3: Refresh container AFTER scrolling
    // Problem: 12 scroll attempts × 300-500ms = 3.6-6s total
    // SwiftUI may recreate view hierarchy during long scroll sequences
    // Solution: Re-query container to get fresh reference
    guard let postScrollContainer = swipeActionsSheetListContainer() else {
      XCTFail(
        "Swipe configuration sheet disappeared during scroll. " +
        "SwiftUI may have recreated the view. Scroll success: \(scrollSuccess)")
      return
    }

    // DEFENSIVE FIX #4: Query element from FRESH container (post-scroll)
    let presetButton = element(withIdentifier: identifier, within: postScrollContainer)

    // DEFENSIVE FIX #5: Dedicated post-scroll timeout
    // Problem: postReadinessTimeout (3s local, 5s CI) consumed by scrolling
    // Solution: Separate budget for post-scroll element verification
    let postScrollTimeout: TimeInterval = ProcessInfo.processInfo.environment["CI"] != nil
      ? 8.0  // CI needs extra time after heavy scroll (resource contention)
      : 5.0  // Local can verify faster (responsive simulator)

    XCTAssertTrue(
      waitForElement(
        presetButton,
        timeout: postScrollTimeout,
        description: "preset button \(identifier)"
      ),
      "Preset button \(identifier) should exist after scrolling. " +
      "Scroll success: \(scrollSuccess), Container refreshed: true, Timeout: \(postScrollTimeout)s"
    )

    tapElement(presetButton, description: identifier)
  }
}
