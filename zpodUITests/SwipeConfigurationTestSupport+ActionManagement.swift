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
    if tapDebugOverlayButton(for: identifier) { return }

    if tapDebugToolbarButton(for: identifier) { return }

    if tapDebugPresetSectionButton(for: identifier) { return }

    if tapDebugPresetFromMenu(for: identifier) { return }

    // Use provided container or re-discover if not provided
    // Providing container avoids race condition after app relaunch
    let sheetContainer: XCUIElement
    if let providedContainer = container {
      sheetContainer = providedContainer
    } else {
      guard let discoveredContainer = swipeActionsSheetListContainer() else {
        XCTFail(
          "Swipe configuration sheet not found. Sheet may have been dismissed or not yet opened.")
        return
      }
      sheetContainer = discoveredContainer
    }

    // Presets are at bottom of sheet, so increase scroll attempts from 6 to 10
    // to ensure we can reach them even from the top of a long sheet
    _ = ensureVisibleInSheet(identifier: identifier, container: sheetContainer, scrollAttempts: 10)
    let presetButton = element(withIdentifier: identifier, within: sheetContainer)

    XCTAssertTrue(
      waitForElement(
        presetButton,
        timeout: postReadinessTimeout,
        description: "preset button \(identifier)"
      ),
      "Preset button \(identifier) should exist"
    )
    tapElement(presetButton, description: identifier)
  }
}
