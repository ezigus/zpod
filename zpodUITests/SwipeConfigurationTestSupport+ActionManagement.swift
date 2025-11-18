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
    let scopedButton = container.buttons.matching(identifier: "Remove " + displayName).firstMatch
    let removeButton =
      scopedButton.exists
      ? scopedButton
      : app.buttons.matching(identifier: "Remove " + displayName).firstMatch
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

    let buttonAfterScroll = container.buttons.matching(identifier: displayName).firstMatch
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
    if tapDebugOverlayButton(for: identifier) {
      logDebugState("Applied \(identifier) via overlay buttons")
      return
    }

    if tapDebugToolbarButton(for: identifier) {
      logDebugState("Applied \(identifier) via debug toolbar buttons")
      return
    }

    if tapDebugPresetSectionButton(for: identifier) {
      logDebugState("Applied \(identifier) via debug section buttons")
      return
    }

    if tapDebugPresetFromMenu(for: identifier) {
      logDebugState("Applied \(identifier) via debug menu")
      return
    }

    _ = waitForSectionIfNeeded(timeout: adaptiveTimeout, failOnTimeout: false)
    cachedSwipeContainer = nil  // Re-discover the sheet container with materialized sections

    guard let container = swipeActionsSheetListContainer() else {
      XCTFail("Swipe configuration sheet container unavailable while applying preset \(identifier)")
      return
    }

    _ = ensureVisibleInSheet(identifier: identifier, container: container, scrollAttempts: 6)
    var presetButton = app.buttons.matching(identifier: identifier).firstMatch
    if !presetButton.exists {
      presetButton = element(withIdentifier: identifier, within: container)
    }
    var scrollAttempts = 0
    while !presetButton.exists && scrollAttempts < 6 {
      if container.isHittable {
        container.swipeUp()
      } else {
        app.swipeUp()
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
      scrollAttempts += 1
      var refreshed = app.buttons.matching(identifier: identifier).firstMatch
      if !refreshed.exists {
        refreshed = element(withIdentifier: identifier, within: container)
      }
      presetButton = refreshed
    }

    XCTAssertTrue(
      waitForElement(
        presetButton,
        timeout: adaptiveTimeout,
        description: "preset button \(identifier)"
      ),
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
    if let cached = cachedSwipeContainer, cached.exists {
      return cached
    }
    let save = app.buttons.matching(identifier: "SwipeActions.Save").firstMatch
    let cancel = app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch
    guard
      save.exists || cancel.exists
        || app.staticTexts.matching(identifier: "Swipe Actions").firstMatch.exists
    else {
      return nil
    }

    let swipePredicate = NSPredicate(format: "identifier BEGINSWITH 'SwipeActions.'")
    let explicitList =
      app.descendants(matching: .any).matching(identifier: "SwipeActions.List").firstMatch
    if explicitList.exists {
      return explicitList
    }

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

    func locateContainer() -> XCUIElement? {
      for win in candidateWindows.reversed() {
        if let found = searchContainer(in: win) { return found }
      }

      if let found = searchContainer(in: app) { return found }
      if save.exists { return save }
      if cancel.exists { return cancel }
      let hapticsToggle = app.switches.matching(identifier: "SwipeActions.Haptics.Toggle")
        .firstMatch
      if hapticsToggle.exists { return hapticsToggle }
      return nil
    }

    let deadline = Date().addingTimeInterval(5.0)
    while Date() < deadline {
      if let container = locateContainer() {
        cachedSwipeContainer = container
        return container
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    logger.warning("[SwipeUITestDebug] swipeActionsSheetListContainer timed out")
    reportAvailableSwipeIdentifiers(context: "swipeActionsSheetListContainer timeout")
    let fallbackCollection = app.collectionViews.firstMatch
    if fallbackCollection.exists {
      logger.warning("[SwipeUITestDebug] Falling back to first collection view for swipe sheet")
      cachedSwipeContainer = fallbackCollection
      return fallbackCollection
    }
    let fallbackTable = app.tables.firstMatch
    if fallbackTable.exists {
      logger.warning("[SwipeUITestDebug] Falling back to first table view for swipe sheet")
      cachedSwipeContainer = fallbackTable
      return fallbackTable
    }
    let container = locateContainer()
    cachedSwipeContainer = container
    return container
  }

  @MainActor
  func elementForAction(identifier: String, within container: XCUIElement) -> XCUIElement {
    // element(withIdentifier:within:) already uses descendants(matching: .any)
    // No need for additional fallback queries
    return element(withIdentifier: identifier, within: container)
  }

  @MainActor
  func ensureVisibleInSheet(
    identifier: String,
    container: XCUIElement,
    scrollAttempts: Int = 1  // Reduced: materialization happens upfront, minimal scroll needed
  ) -> Bool {
    if !container.exists {
      logger.debug(
        "[SwipeUITestDebug] ensureVisibleInSheet container missing for \(identifier, privacy: .public)"
      )
      print("[SwipeUITestDebug] ensureVisibleInSheet container missing for \(identifier)")
    }
    let target = element(withIdentifier: identifier, within: container)
    if target.exists { return true }

    guard container.exists else { return target.exists }

    logger.debug(
      "[SwipeUITestDebug] ensureVisibleInSheet container: \(container.debugDescription, privacy: .public)"
    )
    print("[SwipeUITestDebug] ensureVisibleInSheet container debug: \(container.debugDescription)")

    let attempts = max(scrollAttempts, 1)  // At least 1, but default is now 1
    func settle() {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    enum ScrollDirection {
      case towardsBottom
      case towardsTop
    }

    func scroll(_ direction: ScrollDirection) {
      if container.isHittable {
        switch direction {
        case .towardsBottom:
          container.swipeUp()
        case .towardsTop:
          container.swipeDown()
        }
        return
      }

      let startVector: CGVector
      let endVector: CGVector
      switch direction {
      case .towardsBottom:
        startVector = CGVector(dx: 0.5, dy: 0.8)
        endVector = CGVector(dx: 0.5, dy: 0.2)
      case .towardsTop:
        startVector = CGVector(dx: 0.5, dy: 0.2)
        endVector = CGVector(dx: 0.5, dy: 0.8)
      }
      let startCoord = container.coordinate(withNormalizedOffset: startVector)
      let endCoord = container.coordinate(withNormalizedOffset: endVector)
      startCoord.press(forDuration: 0.01, thenDragTo: endCoord)

      switch direction {
      case .towardsBottom:
        app.swipeUp()
      case .towardsTop:
        app.swipeDown()
      }
    }

    // Nudge to the top first so we have a deterministic starting point.
    for _ in 0..<2 {
      scroll(.towardsTop)
      settle()
      if target.exists { return true }
    }

    // Scan downward through the sheet (swipe up) to materialize lazy rows.
    for _ in 0..<attempts {
      scroll(.towardsBottom)
      settle()
      if target.exists { return true }
    }

    // Walk back upward in case the element lives near the top and the first sweep missed it.
    for _ in 0..<attempts {
      scroll(.towardsTop)
      settle()
      if target.exists { return true }
    }

    if !target.exists {
      reportAvailableSwipeIdentifiers(
        context: "ensureVisibleInSheet missing \(identifier)",
        scoped: true
      )
      logger.debug(
        "[SwipeUITestDebug] unable to surface \(identifier, privacy: .public) after \(attempts) attempts"
      )
      print("[SwipeUITestDebug] unable to surface \(identifier) after \(attempts) attempts")
    }

    return target.exists
  }

  @MainActor
  private func tapDebugPresetFromMenu(for identifier: String) -> Bool {
    guard let debugIdentifier = debugIdentifier(from: identifier) else { return false }
    let menuButton = app.buttons.matching(identifier: "SwipeActions.Debug.Menu").firstMatch
    guard menuButton.waitForExistence(timeout: adaptiveShortTimeout) else { return false }
    tapElement(menuButton, description: "SwipeActions.Debug.Menu")
    guard let menuIdentifier = menuIdentifier(from: identifier) else { return false }
    let debugButton = app.buttons.matching(identifier: menuIdentifier).firstMatch
    guard
      waitForElement(
        debugButton,
        timeout: adaptiveShortTimeout,
        description: "debug preset \(debugIdentifier)"
      )
    else {
      app.tap()  // dismiss menu to avoid blocking subsequent interactions
      return false
    }
    tapElement(debugButton, description: debugIdentifier)
    return true
  }

  @MainActor
  private func tapDebugPresetSectionButton(for identifier: String) -> Bool {
    guard let debugIdentifier = debugIdentifier(from: identifier) else { return false }
    let container = swipeActionsSheetListContainer()
    if let container {
      _ = ensureVisibleInSheet(identifier: debugIdentifier, container: container, scrollAttempts: 2)
    } else {
      app.swipeDown()
    }
    let scopedButton = container?
      .buttons
      .matching(identifier: debugIdentifier)
      .firstMatch
    let debugButton = scopedButton ?? app.buttons.matching(identifier: debugIdentifier).firstMatch
    guard debugButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      attachDebugDescription(
        for: debugButton, label: "Missing debug section button \(debugIdentifier)")
      return false
    }
    tapElement(debugButton, description: debugIdentifier)
    return true
  }

  @MainActor
  private func tapDebugToolbarButton(for identifier: String) -> Bool {
    guard let toolbarIdentifier = toolbarIdentifier(from: identifier) else { return false }
    let toolbarButton = app.buttons.matching(identifier: toolbarIdentifier).firstMatch
    guard toolbarButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      return false
    }
    tapElement(toolbarButton, description: toolbarIdentifier)
    return true
  }

  @MainActor
  private func tapDebugOverlayButton(for identifier: String) -> Bool {
    guard let overlayIdentifier = overlayIdentifier(from: identifier) else { return false }
    let overlayButton = app.buttons.matching(identifier: overlayIdentifier).firstMatch
    guard overlayButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      return false
    }
    tapElement(overlayButton, description: overlayIdentifier)
    return true
  }

  private func debugIdentifier(from presetIdentifier: String) -> String? {
    guard let range = presetIdentifier.range(of: "SwipeActions.Preset.") else { return nil }
    let suffix = presetIdentifier[range.upperBound...]
    return "SwipeActions.Debug.ApplyPreset." + suffix
  }

  private func menuIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Menu"
  }

  private func toolbarIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Toolbar"
  }

  private func overlayIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Overlay"
  }

  @MainActor
  private func attachDebugDescription(for element: XCUIElement, label: String) {
    let description = element.debugDescription
    let attachment = XCTAttachment(string: description)
    attachment.name = label
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
