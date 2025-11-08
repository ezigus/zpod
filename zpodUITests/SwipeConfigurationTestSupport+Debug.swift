//
//  SwipeConfigurationTestSupport+Debug.swift
//  zpodUITests
//
//  Extracted helpers for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  @MainActor
  @discardableResult
  func waitForSaveButton(enabled: Bool, timeout: TimeInterval? = nil) -> Bool {
    let effectiveTimeout = timeout ?? adaptiveTimeout
    let saveButton = app.buttons["SwipeActions.Save"]
    let predicate = NSPredicate { [weak saveButton] _, _ in
      guard let button = saveButton else { return false }
      return button.exists && button.isEnabled == enabled
    }
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for save button enabled=\(enabled)"
    return XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout) == .completed
  }

  @MainActor
  @discardableResult
  func waitForBaselineLoaded(timeout: TimeInterval = 5.0) -> Bool {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard
      waitForElement(
        summaryElement,
        timeout: adaptiveShortTimeout,
        description: "Swipe configuration debug summary"
      )
    else {
      return false
    }

    let predicate = NSPredicate { [weak summaryElement] _, _ in
      guard
        let element = summaryElement,
        let value = element.value as? String
      else {
        return false
      }
      return value.contains("Baseline=1")
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for baseline to load"
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  @MainActor
  @discardableResult
  func waitForDebugState(
    timeout: TimeInterval? = nil,
    validator: ((SwipeDebugState) -> Bool)? = nil
  ) -> SwipeDebugState? {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard
      waitForElement(
        summaryElement,
        timeout: 2.0,
        description: "Swipe configuration debug summary"
      )
    else {
      return nil
    }

    var lastObservedState: SwipeDebugState?
    let effectiveTimeout = timeout ?? 3.0
    let predicate = NSPredicate { [weak self, weak summaryElement] _, _ in
      guard
        let element = summaryElement,
        let rawValue = element.value as? String,
        let state = self?.parseDebugState(from: rawValue)
      else {
        return false
      }
      lastObservedState = state
      guard state.baselineLoaded else { return false }
      if let validator {
        return validator(state)
      }
      return true
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for debug state"
    let result = XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout)

    if result != .completed, let observed = lastObservedState {
      let attachment = XCTAttachment(
        string:
          "Observed debug state: leading=\(observed.leading) trailing=\(observed.trailing) unsaved=\(observed.unsaved) baseline=\(observed.baselineLoaded)"
      )
      attachment.lifetime = .keepAlways
      add(attachment)
    } else if result != .completed, lastObservedState == nil {
      let attachment = XCTAttachment(string: "Debug summary never produced a parsable state")
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    guard result == .completed, let resolvedState = lastObservedState else {
      return nil
    }
    return resolvedState
  }

  @MainActor
  @discardableResult
  func waitForDebugSummary(
    leading expectedLeading: [String],
    trailing expectedTrailing: [String],
    unsaved expectedUnsaved: Bool? = nil,
    timeout: TimeInterval? = nil
  ) -> Bool {
    let state = waitForDebugState(timeout: timeout) { state in
      guard state.leading == expectedLeading, state.trailing == expectedTrailing else {
        return false
      }
      if let expectedUnsaved, state.unsaved != expectedUnsaved {
        return false
      }
      return true
    }
    return state != nil
  }

  @MainActor
  func logDebugState(_ label: String) {
    if let state = currentDebugState() {
      logger.debug(
        "[SwipeUITestDebug] \(label, privacy: .public): leading=\(state.leading, privacy: .public) trailing=\(state.trailing, privacy: .public) unsaved=\(state.unsaved, privacy: .public) baseline=\(state.baselineLoaded, privacy: .public)"
      )
    } else {
      logger.debug("[SwipeUITestDebug] \(label, privacy: .public): state unavailable")
    }
  }

  func currentDebugState() -> SwipeDebugState? {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard summaryElement.exists, let raw = summaryElement.value as? String else {
      return nil
    }
    return parseDebugState(from: raw)
  }

  func parseDebugState(from raw: String) -> SwipeDebugState? {
    var leading: [String] = []
    var trailing: [String] = []
    var fullLeading = false
    var fullTrailing = false
    var hapticsEnabled = false
    var unsaved = false
    var baselineLoaded = false

    for component in raw.split(separator: ";") {
      let parts = component.split(separator: "=", maxSplits: 1).map {
        String($0).trimmingCharacters(in: .whitespaces)
      }
      guard parts.count == 2 else { continue }
      switch parts[0] {
      case "Leading":
        leading = parts[1].isEmpty ? [] : parts[1].split(separator: ",").map { String($0) }
      case "Trailing":
        trailing = parts[1].isEmpty ? [] : parts[1].split(separator: ",").map { String($0) }
      case "Full":
        let fullParts = parts[1].split(separator: "/")
        if fullParts.count == 2 {
          fullLeading = fullParts[0] == "1"
          fullTrailing = fullParts[1] == "1"
        }
      case "Haptics":
        hapticsEnabled = parts[1] == "1"
      case "Unsaved":
        unsaved = parts[1] == "1"
      case "Baseline":
        baselineLoaded = parts[1] == "1"
      default:
        continue
      }
    }

    return SwipeDebugState(
      leading: leading,
      trailing: trailing,
      fullLeading: fullLeading,
      fullTrailing: fullTrailing,
      hapticsEnabled: hapticsEnabled,
      unsaved: unsaved,
      baselineLoaded: baselineLoaded
    )
  }

  @MainActor
  func reportAvailableSwipeIdentifiers(context: String, scoped: Bool = false) {
    let root: XCUIElement = scoped ? (swipeActionsSheetListContainer() ?? app) : app
    let descendants = root.descendants(matching: .any).allElementsBoundByAccessibilityElement
    let filtered = descendants.filter { element in
      let id = element.identifier
      return !id.isEmpty && (id.hasPrefix("SwipeActions.") || id.hasPrefix("SwipeAction."))
    }
    guard !filtered.isEmpty else { return }

    let identifiers = Set(filtered.map { $0.identifier }).sorted()
    let summary = (["Context: \(context)\(scoped ? " [scoped]" : "")"] + identifiers).joined(
      separator: "\n")
    let attachment = XCTAttachment(string: summary)
    attachment.name = "Swipe Identifier Snapshot\(scoped ? " (Scoped)" : "")"
    attachment.lifetime = XCTAttachment.Lifetime.keepAlways
    add(attachment)
  }

  @MainActor
  func reportAvailableSwipeIdentifiers(context: String, within container: XCUIElement?) {
    guard let container else { return }
    let descendants = container.descendants(matching: .any).allElementsBoundByAccessibilityElement
    let filtered = descendants.filter { element in
      let id = element.identifier
      return !id.isEmpty && (id.hasPrefix("SwipeActions.") || id.hasPrefix("SwipeAction."))
    }
    guard !filtered.isEmpty else { return }

    let identifiers = Set(filtered.map { $0.identifier }).sorted()
    let summary = (["Context: \(context) [scoped]"] + identifiers).joined(separator: "\n")
    let attachment = XCTAttachment(string: summary)
    attachment.name = "Swipe Identifier Snapshot (Scoped)"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

struct SwipeDebugState {
  let leading: [String]
  let trailing: [String]
  let fullLeading: Bool
  let fullTrailing: Bool
  let hapticsEnabled: Bool
  let unsaved: Bool
  let baselineLoaded: Bool
}
