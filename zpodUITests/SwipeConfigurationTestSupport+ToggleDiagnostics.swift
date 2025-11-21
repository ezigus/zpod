//
//  SwipeConfigurationTestSupport+ToggleDiagnostics.swift
//  zpodUITests
//
//  Toggle plumbing + diagnostics split from Toggle support.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  // MARK: - Toggle Plumbing

  @MainActor
  func requireToggleSwitch(identifier: String, context: String) -> XCUIElement? {
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: identifier, container: container)
    }

    guard let toggle = resolveToggleSwitch(identifier: identifier) else {
      reportAvailableSwipeIdentifiers(context: "Missing \(identifier) - \(context)", scoped: true)
      attachToggleDiagnostics(identifier: identifier, context: "requireToggleSwitch missing toggle")
      XCTFail("Toggle \(identifier) should exist (\(context))")
      return nil
    }

    XCTAssertTrue(
      waitForElement(toggle, timeout: postReadinessTimeout, description: identifier),
      "Toggle \(identifier) should exist (\(context))"
    )
    return toggle
  }

  @MainActor
  func assertHapticsToggleState(expected: Bool) {
    guard
      let toggle = requireToggleSwitch(
        identifier: "SwipeActions.Haptics.Toggle",
        context: "assertHapticsToggleState"
      )
    else { return }
    let state = currentStateIsOn(for: toggle)
    XCTAssertEqual(state, expected, "Haptics toggle should be \(expected)")
  }

  @MainActor
  func shouldToggleElement(_ element: XCUIElement, targetStateOn: Bool) -> Bool? {
    guard let currentState = currentStateIsOn(for: element) else { return nil }
    return currentState != targetStateOn
  }

  @MainActor
  func currentStateIsOn(for element: XCUIElement) -> Bool? {
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
      candidate = String(candidate.dropFirst("Optional(".count).dropLast()).trimmingCharacters(
        in: .whitespacesAndNewlines)
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
  func resolveToggleSwitch(identifier: String) -> XCUIElement? {
    if let container = swipeActionsSheetListContainer() {
      let directSwitch = container.switches.matching(identifier: identifier).firstMatch
      if directSwitch.exists { return directSwitch }

      let scoped = container.switches.matching(identifier: identifier).firstMatch
      if scoped.exists { return scoped }

      let descendant = container.descendants(matching: .switch).matching(identifier: identifier)
        .firstMatch
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
  func tapToggle(_ toggle: XCUIElement, identifier: String, targetOn: Bool) {
    _ = waitForElementToBeHittable(toggle, timeout: postReadinessTimeout, description: identifier)

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
    let coordinate = interactiveToggle.coordinate(
      withNormalizedOffset: CGVector(dx: offsetX, dy: 0.5))
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
  func attachToggleDiagnostics(
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

extension SwipeDebugState {
  func matchesFullSwipe(leading: Bool, trailing: Bool) -> Bool {
    return fullLeading == leading && fullTrailing == trailing
  }
}
