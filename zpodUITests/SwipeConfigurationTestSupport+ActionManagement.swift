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
    let scopedButton = container.buttons["Remove " + displayName]
    let removeButton = scopedButton.exists ? scopedButton : app.buttons["Remove " + displayName]
    guard removeButton.waitForExistence(timeout: adaptiveShortTimeout) else {
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

    let pickerNavBar = app.navigationBars[pickerTitle]
    let fallbackPickerNavBar = app.navigationBars["Add Action"]

    let optionIdentifier = addIdentifier + "." + displayName
    let primaryOption = element(withIdentifier: optionIdentifier, within: container)
    let buttonOption = container.buttons[displayName]

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
        _ = waitForElementToDisappear(pickerNavBar, timeout: adaptiveShortTimeout)
      }
      return true
    }

    if buttonOption.exists {
      tapElement(buttonOption, description: "Add action option \(displayName)")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: adaptiveShortTimeout)
      }
      return true
    }

    app.swipeUp()
    let optionAfterScroll = element(withIdentifier: optionIdentifier, within: container)
    _ = waitForElement(
      optionAfterScroll, timeout: adaptiveShortTimeout, description: "option after scroll")

    if optionAfterScroll.exists {
      tapElement(optionAfterScroll, description: "Add action option \(displayName) after scroll")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: adaptiveShortTimeout)
      }
      return true
    }

    let buttonAfterScroll = container.buttons[displayName]
    if buttonAfterScroll.exists {
      tapElement(buttonAfterScroll, description: "Add action option \(displayName) after scroll")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: adaptiveShortTimeout)
      }
      return true
    }

    return false
  }

  @MainActor
  func applyPreset(identifier: String) {
    let presetButton = element(withIdentifier: identifier)
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: identifier, container: container)
    }
    XCTAssertTrue(
      waitForElement(
        presetButton, timeout: adaptiveShortTimeout, description: "preset button \(identifier)"),
      "Preset button \(identifier) should exist"
    )
    logger.debug(
      "[SwipeUITestDebug] preset button description: \(presetButton.debugDescription, privacy: .public)"
    )
    tapElement(presetButton, description: identifier)
    _ = waitForDebugState(timeout: adaptiveShortTimeout, validator: { _ in true })
    logDebugState("after applyPreset \(identifier)")
  }

  // MARK: - Sheet Utilities

  @MainActor
  func swipeActionsSheetListContainer() -> XCUIElement? {
    let save = app.buttons["SwipeActions.Save"]
    let cancel = app.buttons["SwipeActions.Cancel"]
    guard save.exists || cancel.exists || app.staticTexts["Swipe Actions"].exists else {
      return nil
    }

    let swipePredicate = NSPredicate(format: "identifier BEGINSWITH 'SwipeActions.'")

    let windows = app.windows.matching(NSPredicate(value: true))
    var candidateWindows: [XCUIElement] = []
    for i in 0..<windows.count {
      let win = windows.element(boundBy: i)
      if win.descendants(matching: .any)["Swipe Actions"].exists
        || win.descendants(matching: .any)["SwipeActions.Save"].exists
        || win.descendants(matching: .any)["SwipeActions.Cancel"].exists
      {
        candidateWindows.append(win)
      }
    }

    func searchContainer(in root: XCUIElement) -> XCUIElement? {
      let tables = root.tables.matching(NSPredicate(value: true))
      for i in 0..<tables.count {
        let table = tables.element(boundBy: i)
        if table.exists
          && table.descendants(matching: .any).matching(swipePredicate).firstMatch.exists
        {
          return table
        }
      }

      let collections = root.collectionViews.matching(NSPredicate(value: true))
      for i in 0..<collections.count {
        let candidate = collections.element(boundBy: i)
        let firstMatch = candidate.descendants(matching: .any).matching(swipePredicate).firstMatch
        if candidate.exists && firstMatch.exists {
          return candidate
        }
      }

      let scrolls = root.scrollViews.matching(NSPredicate(value: true))
      for i in 0..<scrolls.count {
        let scrollCandidate = scrolls.element(boundBy: i)
        if scrollCandidate.exists
          && scrollCandidate.descendants(matching: .any).matching(swipePredicate).firstMatch.exists
        {
          return scrollCandidate
        }
      }
      return nil
    }

    for win in candidateWindows.reversed() {
      if let found = searchContainer(in: win) { return found }
    }

    if let found = searchContainer(in: app) { return found }
    if save.exists { return save }
    if cancel.exists { return cancel }
    let hapticsToggle = app.switches["SwipeActions.Haptics.Toggle"]
    if hapticsToggle.exists { return hapticsToggle }
    return nil
  }

  @MainActor
  func elementForAction(identifier: String, within container: XCUIElement) -> XCUIElement {
    let byId = element(withIdentifier: identifier, within: container)
    if byId.exists { return byId }

    if let label = identifier.split(separator: ".").last.map(String.init) {
      let staticText = container.staticTexts[label]
      if staticText.exists { return staticText }
      let any = container.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", label)
      ).firstMatch
      if any.exists { return any }
    }

    return byId
  }

  @MainActor
  func ensureVisibleInSheet(identifier: String, container: XCUIElement) -> Bool {
    let target = element(withIdentifier: identifier, within: container)
    if target.exists { return true }

    if container.exists {
      container.swipeUp()
      if target.exists { return true }
      container.swipeDown()
      if target.exists { return true }
      container.swipeDown()
    }

    return target.exists
  }
}
