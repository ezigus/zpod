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
    // Get fresh container
    // Note: UI fix ensures preset buttons are pre-materialized by materializeSections()
    guard let freshContainer = swipeActionsSheetListContainer() else {
      XCTFail("Swipe configuration sheet not found before applying preset")
      return
    }

    // With UI fix (materializeSections scrolls to actual preset buttons),
    // preset buttons should be pre-materialized. Use a light sweep, then
    // fall back to a deeper scroll if the target is still not visible.
    var scrollSuccess = ensureVisibleInSheet(
      identifier: identifier,
      container: freshContainer,
      scrollAttempts: 2
    )

    // Find and tap preset button (should be immediately available after UI fix)
    var presetButton = element(withIdentifier: identifier, within: freshContainer)
    if !presetButton.waitForExistence(timeout: postReadinessTimeout) {
      scrollSuccess = ensureVisibleInSheet(
        identifier: identifier,
        container: freshContainer,
        scrollAttempts: 6
      )
      let refreshedContainer = swipeActionsSheetListContainer() ?? freshContainer
      presetButton = element(withIdentifier: identifier, within: refreshedContainer)
    }

    guard waitForElement(
      presetButton,
      timeout: adaptiveTimeout,
      description: "preset button \(identifier)"
    ) else {
      XCTFail(
        "Preset button \(identifier) not found. Pre-materialization may have failed. Scroll success: \(scrollSuccess)"
      )
      return
    }

    tapElement(presetButton, description: identifier)
  }
}
