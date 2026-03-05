//
//  SwipeConfigurationTestSupport+SheetUtilities.swift
//  zpodUITests
//
//  Sheet container + debug helpers extracted for Issue 02.6.3.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  // MARK: - Sheet Utilities

  @MainActor
  func swipeActionsSheetListContainer() -> XCUIElement? {
    guard let app, app.state != .notRunning, app.state != .unknown else {
      return nil
    }

    // Always re-discover instead of trusting cache - SwiftUI may recreate the sheet
    let save = app.buttons.matching(identifier: "SwipeActions.Save").firstMatch
    let cancel = app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch
    guard
      save.exists || cancel.exists
        || app.staticTexts.matching(identifier: "Swipe Actions").firstMatch.exists
    else {
      return nil
    }

    let swipePredicate = NSPredicate(format: "identifier BEGINSWITH 'SwipeActions.'")

    // OPTIMIZATION: SwipeActionConfigurationView.swift:64 sets accessibilityIdentifier("SwipeActions.List")
    // Use collectionViews (not .any) to get the actual UICollectionView backing the List.
    // After a SwiftUI state change (e.g. AddActionPicker dismissal), the new UICollectionView
    // can appear in the accessibility tree immediately but with a zero frame until layout
    // completes. Returning a zero-frame element causes coordinate-based drags to silently
    // resolve to (0,0) and produce no scroll effect. We wait for both existence AND a non-zero
    // frame before returning.
    let explicitList = app.collectionViews.matching(identifier: "SwipeActions.List").firstMatch
    if explicitList.waitForExistence(timeout: 2.0) {
      // If the frame is already valid, return immediately.
      if !explicitList.frame.isEmpty {
        return explicitList
      }
      // Frame is zero — wait up to 1.5s for layout to complete.
      let framePredicate = NSPredicate { _, _ in !explicitList.frame.isEmpty }
      let frameExpectation = XCTNSPredicateExpectation(predicate: framePredicate, object: nil)
      if XCTWaiter.wait(for: [frameExpectation], timeout: 1.5) == .completed {
        return explicitList
      }
      // Frame never became non-zero; fall through to window-scan fallback.
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
      let explicitList = root.descendants(matching: .any).matching(identifier: "SwipeActions.List")
        .firstMatch
      if explicitList.exists { return explicitList }

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

    // If explicit list didn't appear, try fallback container discovery
    // Use XCTWaiter instead of RunLoop blocking for better test reliability
    let maxAttempts = 10
    for attempt in 1...maxAttempts {
      if let container = locateContainer() {
        return container
      }
      if attempt < maxAttempts {
        // Brief wait between attempts (50ms * 10 = 500ms max vs previous 5s)
        let expectation = XCTestExpectation(description: "Container discovery wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          expectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: 0.1)
      }
    }

    logger.warning("[SwipeUITestDebug] swipeActionsSheetListContainer timed out")
    reportAvailableSwipeIdentifiers(context: "swipeActionsSheetListContainer timeout")
    return locateContainer()
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
    scrollAttempts: Int = 1  // Caller controls extra downward sweeps; defaults stay minimal
  ) -> Bool {
    var scrollContainer = container
    if !scrollContainer.exists {
      logger.debug(
        "[SwipeUITestDebug] ensureVisibleInSheet container missing for \(identifier, privacy: .public)"
      )
    }

    var target = element(withIdentifier: identifier, within: scrollContainer)
    if target.exists { return true }

    func refreshContainerIfNeeded() -> Bool {
      if scrollContainer.exists, scrollContainer.frame.isEmpty == false {
        return true
      }
      guard let refreshed = swipeActionsSheetListContainer() else { return false }
      scrollContainer = refreshed
      target = element(withIdentifier: identifier, within: scrollContainer)
      return true
    }

    guard refreshContainerIfNeeded() else { return target.exists }
    if target.exists { return true }

    let downwardSweeps = max(scrollAttempts, 1)
    // Symmetric upward sweeps so elements near the top are reachable after scanning down.
    // NOTE: upward sweeps (dragging DOWN = towardsTop) are only safe AFTER at least one
    // downward sweep has scrolled the list content offset above zero. When content offset
    // is zero the scroll view releases the downward pan gesture and the sheet's dismiss
    // UIPanGestureRecognizer claims it, dismissing the sheet. Do NOT add a separate
    // "initialTopNudges" phase — starting from the top means content offset is 0 and
    // every towardsTop drag will trigger sheet dismissal rather than list scrolling.
    let upwardSweeps = max(1, downwardSweeps / 2)

    enum ScrollDirection {
      case towardsBottom
      case towardsTop
    }

    func scroll(_ direction: ScrollDirection) {
      // Refresh only when the container is missing or empty.
      guard refreshContainerIfNeeded() else { return }

      // Always use coordinate-based drag instead of the isHittable swipeUp/swipeDown
      // shortcut. In some configurations (e.g. UITEST_SWIPE_DEBUG=0) the direct
      // element swipe is silently intercepted by the sheet presentation controller,
      // producing no scroll effect. Coordinate drags bypass this interception.
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
      let startCoord = scrollContainer.coordinate(withNormalizedOffset: startVector)
      let endCoord = scrollContainer.coordinate(withNormalizedOffset: endVector)
      startCoord.press(forDuration: 0.01, thenDragTo: endCoord)
    }

    func settle() {
      // Necessary accommodation for SwiftUI's lazy rendering after scroll
      // SwiftUI takes ~300ms to materialize elements in simulator after scroll gesture
      // CI environments (GitHub Actions) need longer due to resource contention
      // This is a minimal, targeted wait - NOT a retry pattern
      // Aligns with "minimal waits after scroll" philosophy (only used post-scroll)
      // Use RunLoop instead of Thread.sleep to allow UI events to be processed
      let settleTime: TimeInterval = ProcessInfo.processInfo.environment["CI"] != nil
        ? 0.5  // 500ms for CI (slower due to virtualization + resource contention)
        : 0.3  // 300ms for local (existing timing, proven sufficient)
      RunLoop.current.run(until: Date().addingTimeInterval(settleTime))
    }

    // Scan downward through the sheet to materialize lazy rows.
    for _ in 0..<downwardSweeps {
      scroll(.towardsBottom)
      settle()
      target = element(withIdentifier: identifier, within: scrollContainer)
      if target.exists { return true }
    }

    // Walk back upward in case the element lives near the top and was scrolled past.
    // Safe to use towardsTop here: the downward phase above has advanced content offset
    // above zero, so the scroll view — not the sheet dismiss gesture — claims the drag.
    for _ in 0..<upwardSweeps {
      scroll(.towardsTop)
      settle()
      target = element(withIdentifier: identifier, within: scrollContainer)
      if target.exists { return true }
    }

    if !target.exists {
      reportAvailableSwipeIdentifiers(
        context: "ensureVisibleInSheet missing \(identifier)",
        scoped: true
      )
      logger.debug(
        "[SwipeUITestDebug] unable to surface \(identifier, privacy: .public) after \(downwardSweeps) downward sweeps"
      )
    }

    return target.exists
  }

  @MainActor
  func tapDebugPresetFromMenu(for identifier: String) -> Bool {
    guard let debugIdentifier = debugIdentifier(from: identifier) else { return false }
    let menuButton = app.buttons.matching(identifier: "SwipeActions.Debug.Menu").firstMatch
    guard menuButton.waitForExistence(timeout: postReadinessTimeout) else { return false }
    tapElement(menuButton, description: "SwipeActions.Debug.Menu")
    guard let menuIdentifier = menuIdentifier(from: identifier) else { return false }
    let debugButton = app.buttons.matching(identifier: menuIdentifier).firstMatch
    guard
      waitForElement(
        debugButton,
        timeout: postReadinessTimeout,
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
  func tapDebugPresetSectionButton(for identifier: String) -> Bool {
    guard let debugIdentifier = debugIdentifier(from: identifier) else { return false }
    let container = swipeActionsSheetListContainer()
    guard let container else {
      // Container not found - return false without side effects
      // Previously did app.swipeDown() which harmfully scrolled sheet to top,
      // breaking the fallback logic in applyPreset that expects stable scroll position
      return false
    }

    _ = ensureVisibleInSheet(identifier: debugIdentifier, container: container, scrollAttempts: 2)
    let scopedButton = container
      .buttons
      .matching(identifier: debugIdentifier)
      .firstMatch
    let debugButton = scopedButton ?? app.buttons.matching(identifier: debugIdentifier).firstMatch
    guard debugButton.waitForExistence(timeout: postReadinessTimeout) else {
      attachDebugDescription(
        for: debugButton, label: "Missing debug section button \(debugIdentifier)")
      return false
    }
    tapElement(debugButton, description: debugIdentifier)
    return true
  }

  @MainActor
  func tapDebugToolbarButton(for identifier: String) -> Bool {
    guard let toolbarIdentifier = toolbarIdentifier(from: identifier) else { return false }
    let toolbarButton = app.buttons.matching(identifier: toolbarIdentifier).firstMatch
    guard toolbarButton.waitForExistence(timeout: postReadinessTimeout) else {
      return false
    }
    tapElement(toolbarButton, description: toolbarIdentifier)
    return true
  }

  @MainActor
  func tapDebugOverlayButton(for identifier: String) -> Bool {
    guard let overlayIdentifier = overlayIdentifier(from: identifier) else { return false }
    let overlayButton = app.buttons.matching(identifier: overlayIdentifier).firstMatch
    guard overlayButton.waitForExistence(timeout: postReadinessTimeout) else {
      return false
    }
    tapElement(overlayButton, description: overlayIdentifier)
    return true
  }

  func debugIdentifier(from presetIdentifier: String) -> String? {
    guard let range = presetIdentifier.range(of: "SwipeActions.Preset.") else { return nil }
    let suffix = presetIdentifier[range.upperBound...]
    return "SwipeActions.Debug.ApplyPreset." + suffix
  }

  func menuIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Menu"
  }

  func toolbarIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Toolbar"
  }

  func overlayIdentifier(from presetIdentifier: String) -> String? {
    guard let base = debugIdentifier(from: presetIdentifier) else { return nil }
    return base + ".Overlay"
  }

  @MainActor
  func attachDebugDescription(for element: XCUIElement, label: String) {
    let description = element.debugDescription
    let attachment = XCTAttachment(string: description)
    attachment.name = label
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
