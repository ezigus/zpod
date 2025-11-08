//
//  SwipeConfigurationTestSupport+Interactions.swift
//  zpodUITests
//
//  Gesture/action interaction helpers for Issue 02.6.3.
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
    guard
      waitForElement(
        pickerNavBar,
        timeout: adaptiveShortTimeout,
        description: "Add action picker navigation bar"
      )
    else {
      return false
    }

    let optionIdentifier = addIdentifier + "." + displayName

    let primaryOption = element(withIdentifier: optionIdentifier, within: container)
    if primaryOption.exists {
      tapElement(primaryOption, description: "Add action option \(displayName)")
      if pickerNavBar.exists {
        _ = waitForElementToDisappear(pickerNavBar, timeout: adaptiveShortTimeout)
      }
      return true
    }

    let buttonOption = container.buttons[displayName]
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

  // MARK: - Assertions

  @MainActor
  func assertActionList(leadingIdentifiers: [String], trailingIdentifiers: [String]) {
    _ = waitForElement(
      app.navigationBars["Swipe Actions"],
      timeout: adaptiveShortTimeout,
      description: "Swipe Actions navigation bar"
    )
    _ = waitForBaselineLoaded()

    guard let container = swipeActionsSheetListContainer() else {
      XCTFail("Expected swipe actions list container to exist")
      return
    }

    let leading = leadingIdentifiers.map { elementForAction(identifier: $0, within: container) }
    let trailing = trailingIdentifiers.map { elementForAction(identifier: $0, within: container) }

    for element in leading + trailing {
      XCTAssertTrue(
        waitForElement(
          element,
          timeout: adaptiveShortTimeout,
          description: "Swipe action row \(element.identifier)"
        ),
        "Expected \(element.identifier) to be visible in configuration sheet"
      )
    }
  }

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

  // MARK: - Toggle & Haptics Handling

  @MainActor
  func setHaptics(enabled: Bool, styleLabel: String) {
    guard let toggle = resolveToggleSwitch(identifier: "SwipeActions.Haptics.Toggle") else {
      attachToggleDiagnostics(identifier: "SwipeActions.Haptics.Toggle", context: "setHaptics missing toggle")
      XCTFail("Expected haptics toggle to exist")
      return
    }

    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.Toggle", container: container)
    }

    if shouldToggleElement(toggle, targetStateOn: enabled) == true {
      tapToggle(toggle, identifier: "SwipeActions.Haptics.Toggle", targetOn: enabled)
    }

    if enabled {
      let segmentedControl = app.segmentedControls["SwipeActions.Haptics.StylePicker"]
      if segmentedControl.exists {
        let button = segmentedControl.buttons[styleLabel]
        if button.exists {
          if !button.isSelected {
            tapElement(button, description: "haptic style \(styleLabel)")
          }
        } else {
          XCTFail("Haptic style option \(styleLabel) not available")
        }
      } else {
        XCTFail("Haptic style segmented control missing")
      }
    }

    logDebugState("after setHaptics")
  }

  @MainActor
  func setFullSwipeToggle(identifier: String, enabled: Bool) {
    guard let toggle = resolveToggleSwitch(identifier: identifier) else {
      attachToggleDiagnostics(identifier: identifier, context: "setFullSwipeToggle missing toggle")
      XCTFail("Toggle \(identifier) not found")
      return
    }

    if shouldToggleElement(toggle, targetStateOn: enabled) == true {
      tapToggle(toggle, identifier: identifier, targetOn: enabled)
    }
  }

  @MainActor
  func assertFullSwipeState(leading: Bool, trailing: Bool) {
    let leadingToggle = "SwipeActions.Leading.FullSwipe"
    let trailingToggle = "SwipeActions.Trailing.FullSwipe"
    assertToggleState(identifier: leadingToggle, expected: leading)
    assertToggleState(identifier: trailingToggle, expected: trailing)

    guard
      waitForDebugState(
        timeout: adaptiveShortTimeout,
        validator: { $0.fullLeading == leading && $0.fullTrailing == trailing }
      ) != nil
    else {
      XCTFail("Full swipe debug state mismatch. Expected leading=\(leading) trailing=\(trailing)")
      return
    }
  }

  @MainActor
  func assertToggleState(identifier: String, expected: Bool) {
    guard let toggle = resolveToggleSwitch(identifier: identifier) else {
      attachToggleDiagnostics(identifier: identifier, context: "assertToggleState missing toggle")
      XCTFail("Toggle \(identifier) should exist")
      return
    }
    XCTAssertTrue(
      waitForElement(toggle, timeout: adaptiveShortTimeout, description: identifier),
      "Toggle \(identifier) should exist"
    )
    let predicate = NSPredicate { [weak self] _, _ in
      guard let self else { return false }
      guard let currentState = self.currentStateIsOn(for: toggle) else { return false }
      return currentState == expected
    }

    let expectation = XCTNSPredicateExpectation(
      predicate: predicate,
      object: nil
    )
    expectation.expectationDescription = "Toggle \(identifier) matches expected state"

    let result = XCTWaiter.wait(for: [expectation], timeout: adaptiveShortTimeout)
    guard result == .completed else {
      let debugSummary = app.staticTexts["SwipeActions.Debug.StateSummary"].value as? String
      let message: String
      if let debugSummary {
        message = "Toggle \(identifier) state mismatch. Debug: \(debugSummary)"
      } else {
        message = "Toggle \(identifier) state mismatch (debug summary unavailable)"
      }
      attachToggleDiagnostics(identifier: identifier, context: "assertToggleState mismatch", element: toggle)
      XCTFail(message)
      return
    }
  }

  @MainActor
  func assertHapticStyleSelected(label: String) {
    let segmentedControl = app.segmentedControls
      .matching(identifier: "SwipeActions.Haptics.StylePicker")
      .firstMatch
    XCTAssertTrue(
      waitForElement(
        segmentedControl,
        timeout: adaptiveTimeout,
        description: "haptic style segmented control"
      ),
      "Haptic style segmented control should exist"
    )
    let button = segmentedControl.buttons[label]
    XCTAssertTrue(
      waitForElement(
        button, timeout: adaptiveTimeout, description: "haptic style option \(label)"),
      "Haptic style option \(label) should exist"
    )
    XCTAssertTrue(button.isSelected, "Haptic style option \(label) should remain selected")
  }

  @MainActor
  func assertHapticsEnabled(
    _ expectedEnabled: Bool,
    styleLabel: String? = nil,
    timeout: TimeInterval? = nil
  ) {
    assertToggleState(identifier: "SwipeActions.Haptics.Toggle", expected: expectedEnabled)
    if expectedEnabled, let styleLabel {
      assertHapticStyleSelected(label: styleLabel)
    }

    guard
      waitForDebugState(
        timeout: timeout, validator: { $0.hapticsEnabled == expectedEnabled }) != nil
    else {
      XCTFail("Haptics enabled state mismatch. Expected \(expectedEnabled).")
      return
    }
  }

  // MARK: - Element Resolution

  @MainActor
  func element(withIdentifier identifier: String, within container: XCUIElement)
    -> XCUIElement
  {
    if let prioritized = prioritizedElement(in: container, identifier: identifier) {
      return prioritized
    }
    return element(withIdentifier: identifier)
  }

  @MainActor
  private func prioritizedElement(in root: XCUIElement, identifier: String) -> XCUIElement? {
    let queries: [XCUIElement] = [
      root.switches.matching(identifier: identifier).firstMatch,
      root.buttons[identifier],
      root.segmentedControls[identifier],
      root.cells[identifier],
      root.sliders[identifier],
      root.textFields[identifier],
      root.secureTextFields[identifier],
      root.images[identifier],
      root.staticTexts[identifier],
      root.otherElements[identifier],
    ]

    for candidate in queries where candidate.exists {
      return candidate
    }

    let descendant = root.descendants(matching: .any)[identifier]
    return descendant.exists ? descendant : nil
  }

  // MARK: - Toggle Plumbing

  @MainActor
  fileprivate func shouldToggleElement(_ element: XCUIElement, targetStateOn: Bool) -> Bool? {
    guard let currentState = currentStateIsOn(for: element) else { return nil }
    return currentState != targetStateOn
  }

  @MainActor
  fileprivate func currentStateIsOn(for element: XCUIElement) -> Bool? {
    if let directResult = interpretToggleValue(element.value) {
      return directResult
    }

    if let raw = element.value(forKey: "value"), let interpreted = interpretToggleValue(raw) {
      return interpreted
    }

    if element.isSelected { return true }

    let signature: String
    if let rawValue = element.value {
      signature = "\(type(of: rawValue))::\(String(describing: rawValue))"
    } else {
      signature = "nil"
    }

    if Self.reportedToggleValueSignatures.insert(signature).inserted {
      let attachment = XCTAttachment(string: "Unrecognized toggle value signature: \(signature)")
      attachment.name = "Toggle Value Snapshot"
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    return nil
  }

  @MainActor
  private func interpretToggleValue(_ raw: Any?) -> Bool? {
    guard let raw else { return nil }

    if let boolValue = raw as? Bool {
      return boolValue
    }
    if let numberValue = raw as? NSNumber {
      return numberValue.boolValue
    }
    if let intValue = raw as? Int {
      return intValue != 0
    }
    if let doubleValue = raw as? Double {
      return doubleValue != 0.0
    }
    if let stringValue = raw as? String {
      return interpretToggleString(stringValue)
    }
    if let convertible = raw as? CustomStringConvertible {
      return interpretToggleString(convertible.description)
    }

    return nil
  }

  @MainActor
  private func interpretToggleString(_ raw: String) -> Bool? {
    var candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else { return nil }

    while candidate.hasPrefix("Optional(") && candidate.hasSuffix(")") {
      candidate = String(candidate.dropFirst("Optional(".count).dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let lowered = candidate.lowercased()
    switch lowered {
    case "1", "on", "true", "yes", "enabled":
      return true
    case "0", "off", "false", "no", "disabled":
      return false
    default:
      break
    }

    if let intValue = Int(candidate) {
      return intValue != 0
    }
    if let doubleValue = Double(candidate) {
      return doubleValue != 0.0
    }

    return nil
  }

  @MainActor
  fileprivate func resolveToggleSwitch(identifier: String) -> XCUIElement? {
    if let container = swipeActionsSheetListContainer() {
      let scoped = container.switches.matching(identifier: identifier).firstMatch
      if scoped.exists { return scoped }

      let descendant = container.descendants(matching: .switch).matching(identifier: identifier).firstMatch
      if descendant.exists { return descendant }
    }

    let global = app.switches.matching(identifier: identifier).firstMatch
    if global.exists { return global }

    let fallback = element(withIdentifier: identifier)
    if fallback.elementType == .switch { return fallback }

    let nested = fallback.switches.matching(identifier: identifier).firstMatch
    if nested.exists { return nested }

    let anySwitch = fallback.descendants(matching: .switch).firstMatch
    if anySwitch.exists { return anySwitch }

    return fallback.exists ? fallback : nil
  }

  @MainActor
  private func tapToggle(_ toggle: XCUIElement, identifier: String, targetOn: Bool) {
    _ = waitForElementToBeHittable(toggle, timeout: adaptiveShortTimeout, description: identifier)

    let interactiveToggle: XCUIElement = {
      let directChild = toggle.switches.element(boundBy: 0)
      if directChild.exists {
        return directChild
      }
      let descendant = toggle.descendants(matching: .switch).element(boundBy: 0)
      return descendant.exists ? descendant : toggle
    }()

    interactiveToggle.tap()

    if toggleIsInDesiredState(toggle, targetOn: targetOn) {
      return
    }

    let offsetX: CGFloat = targetOn ? 0.8 : 0.2
    let coordinate = interactiveToggle.coordinate(withNormalizedOffset: CGVector(dx: offsetX, dy: 0.5))
    coordinate.tap()

    if toggleIsInDesiredState(toggle, targetOn: targetOn) {
      return
    }

    interactiveToggle.press(forDuration: 0.05)
  }

  @MainActor
  private func toggleIsInDesiredState(_ toggle: XCUIElement, targetOn: Bool) -> Bool {
    guard let state = currentStateIsOn(for: toggle) else { return false }
    return state == targetOn
  }

  @MainActor
  private func attachToggleDiagnostics(
    identifier: String,
    context: String,
    element: XCUIElement? = nil
  ) {
    var lines: [String] = ["Context: \(context)", "Identifier: \(identifier)"]
    let element = element ?? resolveToggleSwitch(identifier: identifier)

    if let element {
      lines.append("exists: \(element.exists)")
      lines.append("isHittable: \(element.isHittable)")
      lines.append("isEnabled: \(element.isEnabled)")
      lines.append("elementType: \(element.elementType.rawValue)")
      if let value = element.value {
        lines.append("value: \(value)")
      }
      lines.append("frame: \(NSCoder.string(for: element.frame))")
      lines.append("debugDescription: \(element.debugDescription)")
    } else {
      lines.append("element: nil")
    }

    let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
    attachment.name = "Toggle Diagnostics"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
