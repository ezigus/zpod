//
//  SwipeConfigurationTestSupport+Toggle.swift
//  zpodUITests
//
//  Toggle, haptics, and debug instrumentation helpers for swipe configuration tests.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  // MARK: - Configuration Toggles

  @MainActor
  func setHaptics(enabled: Bool, styleLabel: String) {
    guard let toggle = resolveToggleSwitch(identifier: "SwipeActions.Haptics.Toggle") else {
      attachToggleDiagnostics(
        identifier: "SwipeActions.Haptics.Toggle",
        context: "setHaptics missing toggle"
      )
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
  }

  @MainActor
  func setFullSwipeToggle(identifier: String, enabled: Bool) {
    // Both toggles are now positioned before their respective "Add Action" buttons
    // and both sections are visible without scrolling
    guard let toggle = resolveToggleSwitch(identifier: identifier) else {
      attachToggleDiagnostics(identifier: identifier, context: "setFullSwipeToggle missing toggle")
      XCTFail("Toggle \(identifier) not found")
      return
    }

    if shouldToggleElement(toggle, targetStateOn: enabled) == true {
      tapToggle(toggle, identifier: identifier, targetOn: enabled)
    } else if shouldToggleElement(toggle, targetStateOn: enabled) == nil {
      // If state is unknown, perform a best-effort toggle to reach the target.
      tapToggle(toggle, identifier: identifier, targetOn: enabled)
    }
  }

  // MARK: - Assertions

  @MainActor
  func assertFullSwipeState(leading: Bool, trailing: Bool, timeout: TimeInterval? = nil) {
    let readinessTimeout = timeout ?? postReadinessTimeout
    _ = waitForSectionIfNeeded(timeout: readinessTimeout)
    let leadingToggle = "SwipeActions.Leading.FullSwipe"
    let trailingToggle = "SwipeActions.Trailing.FullSwipe"
    let stateTimeout = timeout ?? debugStateTimeout
    guard
      let state = waitForDebugState(
        timeout: stateTimeout,
        validator: { $0.matchesFullSwipe(leading: leading, trailing: trailing) }
      )
    else {
      XCTFail("Debug state unavailable or mismatched for full swipe assertion")
      return
    }

    let toggleTimeout = timeout ?? postReadinessTimeout
    assertToggleState(identifier: leadingToggle, expected: state.fullLeading, timeout: toggleTimeout)
    assertToggleState(
      identifier: trailingToggle,
      expected: state.fullTrailing,
      timeout: toggleTimeout
    )
  }

  @MainActor
  func assertToggleState(identifier: String, expected: Bool, timeout: TimeInterval? = nil) {
    let effectiveTimeout = timeout ?? postReadinessTimeout
    guard let toggle = requireToggleSwitch(identifier: identifier, context: "assertToggleState") else {
      return
    }
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

    let result = XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout)
    guard result == .completed else {
      if retryToggleStateResolution(
        toggle: toggle,
        identifier: identifier,
        expected: expected,
        timeout: effectiveTimeout
      ) {
        return
      }
      let debugSummary = app.staticTexts["SwipeActions.Debug.StateSummary"].value as? String
      let message: String
      if let debugSummary {
        message = "Toggle \(identifier) state mismatch. Debug: \(debugSummary)"
      } else {
        message = "Toggle \(identifier) state mismatch (debug summary unavailable)"
      }
      attachToggleDiagnostics(
        identifier: identifier, context: "assertToggleState mismatch", element: toggle)
      XCTFail(message)
      return
    }
  }

  @MainActor
  private func retryToggleStateResolution(
    toggle: XCUIElement,
    identifier: String,
    expected: Bool,
    timeout: TimeInterval
  ) -> Bool {
    // Event-based shortcut: if the debug summary already reports the target state, treat as success.
    if debugStateMatchesToggle(identifier: identifier, expected: expected, timeout: timeout) {
      logger.debug(
        "[SwipeUITestDebug] Toggle \(identifier, privacy: .public) matched via debug state fallback (expected=\(expected, privacy: .public))"
      )
      return true
    }

    // Retry a few quick reads without inflating the global timeout.
    for _ in 0..<3 {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
      if let current = currentStateIsOn(for: toggle), current == expected {
        return true
      }
      if debugStateMatchesToggle(identifier: identifier, expected: expected, timeout: 0.5) {
        return true
      }
    }
    return false
  }

  @MainActor
  private func debugStateMatchesToggle(
    identifier: String,
    expected: Bool,
    timeout: TimeInterval
  ) -> Bool {
    let validator: (SwipeDebugState) -> Bool
    switch identifier {
    case "SwipeActions.Leading.FullSwipe":
      validator = { $0.fullLeading == expected }
    case "SwipeActions.Trailing.FullSwipe":
      validator = { $0.fullTrailing == expected }
    case "SwipeActions.Haptics.Toggle":
      validator = { $0.hapticsEnabled == expected }
    default:
      return false
    }
    return waitForDebugState(timeout: timeout, validator: validator) != nil
  }

  @MainActor
  func assertHapticStyleSelected(label: String, timeout: TimeInterval? = nil) {
    let effectiveTimeout = timeout ?? postReadinessTimeout
    let segmentedControl = app.segmentedControls
      .matching(identifier: "SwipeActions.Haptics.StylePicker")
      .firstMatch
    XCTAssertTrue(
      waitForElement(
        segmentedControl,
        timeout: effectiveTimeout,
        description: "haptic style segmented control"
      ),
      "Haptic style segmented control should exist"
    )
    let button = segmentedControl.buttons[label]
    XCTAssertTrue(
      waitForElement(
        button, timeout: effectiveTimeout, description: "haptic style option \(label)"),
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
    let effectiveTimeout = timeout ?? debugStateTimeout
    assertToggleState(
      identifier: "SwipeActions.Haptics.Toggle",
      expected: expectedEnabled,
      timeout: timeout
    )
    if expectedEnabled, let styleLabel {
      assertHapticStyleSelected(label: styleLabel, timeout: timeout)
    }

    guard
      waitForDebugState(
        timeout: effectiveTimeout, validator: { $0.hapticsEnabled == expectedEnabled }) != nil
    else {
      XCTFail("Haptics enabled state mismatch. Expected \(expectedEnabled).")
      return
    }
  }
}
