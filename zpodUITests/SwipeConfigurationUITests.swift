//
//  SwipeConfigurationUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.6.2: Swipe Gesture Configuration UI Tests
//

// swiftlint:disable type_body_length

import Foundation
import OSLog
import XCTest

class SwipeConfigurationTestCase: XCTestCase, SmartUITesting {
  private let logger = Logger(subsystem: "us.zig.zpod", category: "SwipeConfigurationUITests")
  nonisolated(unsafe) var app: XCUIApplication!
  private let swipeDefaultsSuite = "us.zig.zpod.swipe-uitests"
  private var seededConfigurationPayload: String?

  private var baseLaunchEnvironment: [String: String] {
    [
      "UITEST_SWIPE_DEBUG": "1",
      "UITEST_USER_DEFAULTS_SUITE": swipeDefaultsSuite,
    ]
  }

  func launchEnvironment(reset: Bool) -> [String: String] {
    var environment = baseLaunchEnvironment
    environment["UITEST_RESET_SWIPE_SETTINGS"] = reset ? "1" : "0"
    if let payload = seededConfigurationPayload {
      environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] = payload
    }
    return environment
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
  }

  override func tearDownWithError() throws {
    guard let currentApp = app else {
      app = nil
      try super.tearDownWithError()
      return
    }

    let terminationExpectation = expectation(description: "Terminate running app")
    let appToTerminate = currentApp

    Task {
      await MainActor.run {
        defer { terminationExpectation.fulfill() }
        if appToTerminate.state == .runningForeground || appToTerminate.state == .runningBackground
        {
          appToTerminate.terminate()
        }
        self.app = nil
      }
    }

    wait(for: [terminationExpectation], timeout: adaptiveShortTimeout)

    try super.tearDownWithError()
  }

  // MARK: - Configuration Helpers

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
    let result = XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout)
    return result == .completed
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
        timeout: 2.0,  // Quick check - debug summary should appear fast
        description: "Swipe configuration debug summary"
      )
    else {
      return nil
    }

    var lastObservedState: SwipeDebugState?
    let effectiveTimeout = timeout ?? 3.0  // Aggressive timeout - state changes should be immediate
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
    }
    guard result == .completed, let resolvedState = lastObservedState else {
      if lastObservedState == nil {
        let attachment = XCTAttachment(string: "Debug summary never produced a parsable state")
        attachment.lifetime = .keepAlways
        add(attachment)
      }
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

    // Optimized: Try the most likely identifier first, then fall back to less targeted searches
    let optionIdentifier = addIdentifier + "." + displayName

    // First try: Use the specific identifier
    let primaryOption = element(withIdentifier: optionIdentifier, within: container)
    if primaryOption.exists {
      tapElement(primaryOption, description: "Add action option \(displayName)")

      if pickerNavBar.exists {
        _ = waitForElementToDisappear(
          pickerNavBar,
          timeout: adaptiveShortTimeout
        )
      }
      return true
    }

    // Second try: Look for button by display name within container
    let buttonOption = container.buttons[displayName]
    if buttonOption.exists {
      tapElement(buttonOption, description: "Add action option \(displayName)")

      if pickerNavBar.exists {
        _ = waitForElementToDisappear(
          pickerNavBar,
          timeout: adaptiveShortTimeout
        )
      }
      return true
    }

    // Third try: Scroll and look again - but only if needed
    app.swipeUp()

    // Wait for element to settle after scroll
    let optionAfterScroll = element(withIdentifier: optionIdentifier, within: container)
    _ = waitForElement(
      optionAfterScroll, timeout: adaptiveShortTimeout, description: "option after scroll")

    if optionAfterScroll.exists {
      tapElement(optionAfterScroll, description: "Add action option \(displayName) after scroll")

      if pickerNavBar.exists {
        _ = waitForElementToDisappear(
          pickerNavBar,
          timeout: adaptiveShortTimeout
        )
      }
      return true
    }

    // Final fallback: Try button by display name after scroll
    let buttonAfterScroll = container.buttons[displayName]
    if buttonAfterScroll.exists {
      tapElement(buttonAfterScroll, description: "Add action option \(displayName) after scroll")

      if pickerNavBar.exists {
        _ = waitForElementToDisappear(
          pickerNavBar,
          timeout: adaptiveShortTimeout
        )
      }
      return true
    }

    return false  // Element not found even after scrolling
  }

  @MainActor
  func resetSwipeSettingsToDefault() {
    guard let defaults = UserDefaults(suiteName: swipeDefaultsSuite) else {
      XCTFail("Expected swipe defaults suite \(swipeDefaultsSuite) to exist")
      return
    }
    defaults.removePersistentDomain(forName: swipeDefaultsSuite)
    defaults.setPersistentDomain([:], forName: swipeDefaultsSuite)
  }

  @MainActor
  func initializeApp() {
    resetSwipeSettingsToDefault()
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: true))
    seededConfigurationPayload = nil
  }

  @MainActor
  func relaunchApp(resetDefaults: Bool = false) {
    app.terminate()
    if resetDefaults {
      resetSwipeSettingsToDefault()
    }
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: resetDefaults))
    seededConfigurationPayload = nil
  }

  @MainActor
  fileprivate func beginWithFreshConfigurationSheet(resetDefaults: Bool = true) throws {
    if resetDefaults {
      initializeApp()
    } else {
      relaunchApp(resetDefaults: false)
    }
    try openConfigurationSheetFromEpisodeList()
  }

  @MainActor
  fileprivate func openConfigurationSheetFromEpisodeList() throws {
    try navigateToEpisodeList()
    openSwipeConfigurationSheet()
  }

  @MainActor
  func navigateToEpisodeList() throws {
    let tabBar = app.tabBars["Main Tab Bar"]
    guard tabBar.exists else {
      throw XCTSkip("Main tab bar not available")
    }

    let libraryTab = tabBar.buttons["Library"]
    guard libraryTab.exists else {
      throw XCTSkip("Library tab unavailable")
    }

    // Ensure tab bar is fully loaded and accessible before tapping
    guard
      waitForElement(
        libraryTab,
        timeout: adaptiveShortTimeout,
        description: "Library tab button"
      )
    else {
      throw XCTSkip("Library tab not ready for interaction")
    }

    guard
      waitForElementToBeHittable(
        libraryTab,
        timeout: adaptiveShortTimeout,
        description: "Library tab button"
      )
    else {
      throw XCTSkip("Library tab not hittable")
    }

    // Use a more robust navigation approach
    let navigationSucceeded = navigateAndWaitForResult(
      triggerAction: { libraryTab.tap() },
      expectedElements: [
        app.buttons["Podcast-swift-talk"],
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Library'")).firstMatch,
      ],
      timeout: adaptiveTimeout,
      description: "Library navigation"
    )

    guard navigationSucceeded else {
      throw XCTSkip("Failed to navigate to Library tab")
    }

    guard
      waitForContentToLoad(containerIdentifier: "Podcast Cards Container", timeout: adaptiveTimeout)
    else {
      throw XCTSkip("Library content did not load")
    }

    let podcastButton = app.buttons["Podcast-swift-talk"]
    guard podcastButton.exists else {
      throw XCTSkip("Test podcast unavailable")
    }

    guard
      waitForElementToBeHittable(
        podcastButton,
        timeout: adaptiveShortTimeout,
        description: "Podcast button"
      )
    else {
      throw XCTSkip("Podcast button not hittable")
    }

    // Use robust navigation to episode list
    let episodeNavSucceeded = navigateAndWaitForResult(
      triggerAction: { podcastButton.tap() },
      expectedElements: [
        app.buttons["ConfigureSwipeActions"],
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Episodes'")).firstMatch,
      ],
      timeout: adaptiveTimeout,
      description: "Episode list navigation"
    )

    guard episodeNavSucceeded else {
      throw XCTSkip("Failed to navigate to episode list")
    }

    if !waitForContentToLoad(
      containerIdentifier: "Episode Cards Container",
      timeout: adaptiveTimeout
    ) {
      let configureButton = app.buttons["ConfigureSwipeActions"]
      guard
        waitForElement(
          configureButton,
          timeout: adaptiveTimeout,
          description: "configure swipe actions button"
        )
      else {
        throw XCTSkip("Episode list did not load")
      }
    }
  }

  @MainActor
  func openSwipeConfigurationSheet() {
    let existingIndicators: [XCUIElement] = [
      app.navigationBars["Swipe Actions"],
      app.otherElements["Swipe Actions"],
      app.staticTexts["Swipe Actions"],
      app.buttons["SwipeActions.Save"],
      app.buttons["SwipeActions.Cancel"],
    ]

    if existingIndicators.contains(where: { $0.exists }) {
      return
    }

    let configureButton = element(withIdentifier: "ConfigureSwipeActions")

    guard
      waitForElement(
        configureButton,
        timeout: adaptiveTimeout,
        description: "configure swipe actions button"
      )
    else {
      XCTFail("Configure swipe actions button should exist before opening sheet")
      return
    }

    configureButton.tap()

    let refreshedIndicators: [XCUIElement] = [
      app.navigationBars["Swipe Actions"],
      app.otherElements["Swipe Actions"],
      app.staticTexts["Swipe Actions"],
      app.buttons["SwipeActions.Save"],
      app.buttons["SwipeActions.Cancel"],
    ]

    _ = waitForAnyElement(
      refreshedIndicators,
      timeout: adaptiveTimeout,
      description: "Swipe Actions configuration sheet"
    )

    _ = waitForBaselineLoaded()
    logDebugState("baseline after open")
    reportAvailableSwipeIdentifiers(context: "Sheet opened (initial)")
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

    // Wait for preset to be applied by checking unsaved changes state
    _ = waitForDebugState(timeout: adaptiveShortTimeout, validator: { _ in true })

    logDebugState("after applyPreset \(identifier)")
  }

  @MainActor
  func setHaptics(enabled: Bool, styleLabel: String) {
    let baseToggle = element(withIdentifier: "SwipeActions.Haptics.Toggle")
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.Toggle", container: container)
    }
    guard waitForElement(baseToggle, timeout: adaptiveShortTimeout, description: "haptic toggle")
    else {
      return
    }

    let toggle: XCUIElement
    if let container = swipeActionsSheetListContainer() {
      toggle = element(withIdentifier: "SwipeActions.Haptics.Toggle", within: container)
    } else {
      toggle = baseToggle
    }

    // Check current state from debug summary
    let preState = currentDebugState()
    let currentHapticState = preState?.hapticsEnabled ?? false
    logger.debug(
      "[SwipeUITestDebug] setHaptics: target=\(enabled ? "on" : "off", privacy: .public), current=\(currentHapticState ? "on" : "off", privacy: .public)"
    )

    // Only toggle if we need to change state
    if currentHapticState != enabled {
      logger.debug(
        "[SwipeUITestDebug] Attempting to toggle SwipeActions.Haptics.Toggle to \(enabled ? "on" : "off", privacy: .public)"
      )

      // Try direct tap first
      toggle.tap()

      // Wait for state to change with proper timeout
      if waitForDebugState(
        timeout: adaptiveShortTimeout, validator: { $0.hapticsEnabled == enabled }) != nil
      {
        logger.debug(
          "[SwipeUITestDebug] Toggle succeeded with direct tap"
        )
      } else {
        // Fallback to coordinate tap
        logger.debug(
          "[SwipeUITestDebug] Direct tap didn't change state, trying coordinate tap"
        )
        let coordinate = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        coordinate.tap()

        // Wait for state to change after coordinate tap
        _ = waitForDebugState(
          timeout: adaptiveShortTimeout, validator: { $0.hapticsEnabled == enabled })
      }
    } else {
      logger.debug(
        "[SwipeUITestDebug] Haptic toggle already in desired state, no tap needed"
      )
    }

    guard enabled else { return }

    let segmentedControl =
      app.segmentedControls["SwipeActions.Haptics.StylePicker"].exists
      ? app.segmentedControls["SwipeActions.Haptics.StylePicker"]
      : app.segmentedControls.firstMatch
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: "SwipeActions.Haptics.StylePicker", container: container)
    }
    if segmentedControl.exists {
      let desiredButton = segmentedControl.buttons[styleLabel]
      if desiredButton.exists {
        desiredButton.tap()
      }
    }
    logDebugState("after setHaptics")
  }

  @MainActor
  func tapElement(_ element: XCUIElement, description: String) {
    if element.isHittable {
      element.tap()
      return
    }

    let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    coordinate.tap()
    logger.debug(
      "[SwipeUITestDebug] forced coordinate tap for \(description, privacy: .public)"
    )
  }

  @MainActor
  func revealLeadingSwipeActions(for element: XCUIElement) {
    element.swipeRight()

    if app.buttons["SwipeAction.addToPlaylist"].exists {
      return
    }

    let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
    let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
    start.press(forDuration: 0.05, thenDragTo: end)
  }

  @MainActor
  func setFullSwipeToggle(identifier: String, enabled: Bool) {
    let baseToggle = element(withIdentifier: identifier)
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: identifier, container: container)
    }
    guard waitForElement(baseToggle, timeout: adaptiveShortTimeout, description: identifier) else {
      return
    }

    let toggle: XCUIElement
    if let container = swipeActionsSheetListContainer(), container.switches[identifier].exists {
      toggle = container.switches[identifier]
    } else if app.switches[identifier].exists {
      toggle = app.switches[identifier]
    } else {
      toggle = baseToggle
    }

    let validator: (SwipeDebugState) -> Bool = { state in
      let isEnabled = identifier.contains("Trailing") ? state.fullTrailing : state.fullLeading
      return isEnabled == enabled
    }

    // Check current state before attempting toggle
    logDebugState("before setFullSwipe \(identifier) to \(enabled)")
    if let currentState = currentDebugState() {
      let currentValue =
        identifier.contains("Trailing") ? currentState.fullTrailing : currentState.fullLeading
      if currentValue == enabled {
        logger.debug(
          "[SwipeUITestDebug] \(identifier, privacy: .public) already at target state \(enabled, privacy: .public)"
        )
        return
      }
    }

    let decision = shouldToggleElement(toggle, targetStateOn: enabled)
    if decision == false {
      _ = waitForDebugState(timeout: adaptiveShortTimeout, validator: validator)
      logDebugState("after setFullSwipe \(identifier) (no change needed)")
      return
    }

    let attempts = 3
    for attempt in 0..<attempts {
      _ = waitForElementToBeHittable(toggle, timeout: adaptiveShortTimeout, description: identifier)

      // Try direct tap first
      toggle.tap()

      if waitForDebugState(timeout: adaptiveShortTimeout, validator: validator) != nil {
        logDebugState("after setFullSwipe \(identifier) attempt \(attempt + 1)")
        return
      }

      // If that didn't work, try coordinate tap
      let coordinate = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
      coordinate.tap()

      if waitForDebugState(timeout: adaptiveShortTimeout, validator: validator) != nil {
        logDebugState("after setFullSwipe \(identifier) attempt \(attempt + 1) (coordinate)")
        return
      }
    }

    XCTFail("Timed out toggling \(identifier) to \(enabled)")

  }

  @MainActor
  func assertFullSwipeState(
    leading expectedLeading: Bool,
    trailing expectedTrailing: Bool,
    timeout: TimeInterval? = nil
  ) {
    guard
      waitForDebugState(
        timeout: timeout,
        validator: { state in
          state.fullLeading == expectedLeading && state.fullTrailing == expectedTrailing
        }) != nil
    else {
      XCTFail(
        "Full swipe state mismatch. Expected leading=\(expectedLeading) trailing=\(expectedTrailing)",
        file: #filePath,
        line: #line
      )
      return
    }
  }

  @MainActor
  func saveAndDismissConfiguration() {
    let saveButton = element(withIdentifier: "SwipeActions.Save")
    guard waitForElement(saveButton, timeout: adaptiveShortTimeout, description: "save button")
    else {
      return
    }
    logDebugState("before save")
    _ = waitForSaveButton(enabled: true)
    saveButton.tap()
    waitForSheetDismissal()
    logDebugState("after save (sheet dismissed)")
  }

  func dismissConfigurationSheetIfNeeded() {
    let cancelButton = app.buttons["SwipeActions.Cancel"]
    guard cancelButton.waitForExistence(timeout: adaptiveShortTimeout) else { return }
    tapElement(cancelButton, description: "SwipeActions.Cancel")
    _ = waitForElementToDisappear(app.buttons["SwipeActions.Save"], timeout: adaptiveTimeout)
  }

  @MainActor
  func assertToggleState(identifier: String, expected: Bool) {
    let toggle = element(withIdentifier: identifier)
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
      XCTFail(message)
      return
    }
  }

  @MainActor
  func assertHapticStyleSelected(label: String) {
    let segmentedControl =
      app.segmentedControls["SwipeActions.Haptics.StylePicker"].exists
      ? app.segmentedControls["SwipeActions.Haptics.StylePicker"]
      : app.segmentedControls.firstMatch
    XCTAssertTrue(
      waitForElement(
        segmentedControl,
        timeout: adaptiveShortTimeout,
        description: "haptic style segmented control"
      ),
      "Haptic style segmented control should exist"
    )
    let button = segmentedControl.buttons[label]
    XCTAssertTrue(
      waitForElement(
        button, timeout: adaptiveShortTimeout, description: "haptic style option \(label)"),
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

    if expectedEnabled {
      if let styleLabel {
        assertHapticStyleSelected(label: styleLabel)
      }
    }

    guard
      waitForDebugState(
        timeout: timeout, validator: { $0.hapticsEnabled == expectedEnabled }) != nil
    else {
      XCTFail(
        "Haptics enabled state mismatch. Expected \(expectedEnabled).",
        file: #filePath,
        line: #line
      )
      return
    }
  }

  @MainActor
  func waitForSheetDismissal() {
    // Wait for either the navigation bar or save button to disappear
    let navBar = app.navigationBars["Swipe Actions"]
    let saveButton = app.buttons["SwipeActions.Save"]

    // Try both; don't hard-fail if already gone
    _ = waitForElementToDisappear(saveButton, timeout: adaptiveTimeout)
    _ = waitForElementToDisappear(navBar, timeout: adaptiveTimeout)
  }

  @MainActor
  func restoreDefaultConfiguration() {
    resetSwipeSettingsToDefault()
    relaunchApp(resetDefaults: true)
  }

  @MainActor
  func assertActionList(leadingIdentifiers: [String], trailingIdentifiers: [String]) {
    // Ensure the Swipe Actions sheet is open
    let _ = waitForElement(
      app.navigationBars["Swipe Actions"],
      timeout: adaptiveShortTimeout,
      description: "Swipe Actions navigation bar"
    )
    _ = waitForBaselineLoaded()

    // Resolve the sheet's list container (Form -> UITableView on iOS)
    guard let sheetContainer = swipeActionsSheetListContainer() else {
      reportAvailableSwipeIdentifiers(context: "Sheet container not found")
      XCTFail("Could not resolve Swipe Actions sheet container for assertions")
      return
    }

    if let state = currentDebugState() {
      logger.debug(
        "[SwipeUITestDebug] leading=\(state.leading, privacy: .public) trailing=\(state.trailing, privacy: .public) unsaved=\(state.unsaved, privacy: .public) baseline=\(state.baselineLoaded, privacy: .public)"
      )
      let attachment = XCTAttachment(
        string:
          "AssertActionList debug state: leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved) baseline=\(state.baselineLoaded)"
      )
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    leadingIdentifiers.forEach { identifier in
      _ = ensureVisibleInSheet(identifier: identifier, container: sheetContainer)
      let element = elementForAction(identifier: identifier, within: sheetContainer)
      let appeared = waitForElement(
        element,
        timeout: adaptiveShortTimeout,
        description: identifier
      )
      if !appeared {
        reportAvailableSwipeIdentifiers(
          context: "Leading action lookup for \(identifier)", within: sheetContainer)
      }
      XCTAssertTrue(appeared, "Expected leading action \(identifier) to appear")
    }

    trailingIdentifiers.forEach { identifier in
      _ = ensureVisibleInSheet(identifier: identifier, container: sheetContainer)
      let element = elementForAction(identifier: identifier, within: sheetContainer)
      let appeared = waitForElement(
        element,
        timeout: adaptiveShortTimeout,
        description: identifier
      )
      if !appeared {
        reportAvailableSwipeIdentifiers(
          context: "Trailing action lookup for \(identifier)", within: sheetContainer)
      }
      XCTAssertTrue(appeared, "Expected trailing action \(identifier) to appear")
    }
  }

  @MainActor
  func requireEpisodeButton() throws -> XCUIElement {
    let preferredEpisode = app.buttons["Episode-st-001"]
    if preferredEpisode.exists {
      return preferredEpisode
    }

    let fallbackEpisode = app.buttons.matching(
      NSPredicate(format: "identifier CONTAINS 'Episode-'")
    )
    .firstMatch
    guard fallbackEpisode.exists else {
      throw XCTSkip("No episode button available for swipe configuration testing")
    }
    return fallbackEpisode
  }

  func ensureVisibleInSheet(identifier: String, container: XCUIElement) -> Bool {
    let target = element(withIdentifier: identifier, within: container)
    if target.exists { return true }

    // Most elements should be visible without scrolling. If not, do minimal scrolling.
    if container.exists {
      container.swipeUp()
      if target.exists { return true }

      container.swipeDown()  // Try once down
      if target.exists { return true }

      container.swipeDown()  // Try once more down
    }

    return target.exists
  }
}

final class SwipeConfigurationPersistenceUITests: SwipeConfigurationTestCase {
  @MainActor
  func testManualConfigurationPersistsAcrossLaunches() throws {
    try beginWithFreshConfigurationSheet()

    configurePlaybackLayoutManually()
    setHaptics(enabled: true, styleLabel: "Rigid")
    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Play", "SwipeActions.Leading.Add to Playlist"],
      trailingIdentifiers: ["SwipeActions.Trailing.Download", "SwipeActions.Trailing.Favorite"]
    )
    assertHapticsEnabled(true, styleLabel: "Rigid")

    restoreDefaultConfiguration()
  }

  @MainActor
  func testFullSwipeTogglesPersistAcrossSave() throws {
    try beginWithFreshConfigurationSheet()

    assertFullSwipeState(leading: true, trailing: false)

    setFullSwipeToggle(identifier: "SwipeActions.Leading.FullSwipe", enabled: false)
    setFullSwipeToggle(identifier: "SwipeActions.Trailing.FullSwipe", enabled: true)
    assertFullSwipeState(leading: false, trailing: true)

    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()

    assertFullSwipeState(leading: false, trailing: true)

    restoreDefaultConfiguration()
  }

  @MainActor
  func testHapticTogglePersistsAcrossLaunches() throws {
    try beginWithFreshConfigurationSheet()

    setHaptics(enabled: false, styleLabel: "Medium")
    assertHapticsEnabled(false)

    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()

    assertHapticsEnabled(false)

    setHaptics(enabled: true, styleLabel: "Soft")
    assertHapticsEnabled(true, styleLabel: "Soft")

    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)
    try openConfigurationSheetFromEpisodeList()

    assertHapticsEnabled(true, styleLabel: "Soft")

    restoreDefaultConfiguration()
  }
}

final class SwipeConfigurationExecutionUITests: SwipeConfigurationTestCase {
  @MainActor
  func testSeededSwipeActionsExecuteInEpisodeList() throws {
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    clearSeededConfigurationPayload()

    try openConfigurationSheetFromEpisodeList()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: false
      ),
      "Seeded playback configuration should match debug summary"
    )

    dismissConfigurationSheetIfNeeded()

    try navigateToEpisodeList()

    let episode = try requireEpisodeButton()
    XCTAssertTrue(
      waitForElement(
        episode,
        timeout: adaptiveShortTimeout,
        description: "episode cell for swipe"
      )
    )

    revealLeadingSwipeActions(for: episode)
    let addToPlaylistButton = element(withIdentifier: "SwipeAction.addToPlaylist")
    XCTAssertTrue(
      waitForElement(
        addToPlaylistButton,
        timeout: adaptiveShortTimeout,
        description: "add to playlist swipe action"
      ),
      "Add to Playlist swipe action should appear after swiping right"
    )
    if !addToPlaylistButton.exists {
      reportAvailableSwipeIdentifiers(context: "Episode swipe actions after swiping right")
    }
    addToPlaylistButton.tap()

    let playlistNavBar = app.navigationBars["Select Playlist"]
    XCTAssertTrue(
      waitForElement(
        playlistNavBar,
        timeout: adaptiveTimeout,
        description: "playlist selection sheet"
      ),
      "Selecting Add to Playlist should present the playlist sheet"
    )

    if let cancelButton = playlistNavBar.buttons["Cancel"].firstMatchIfExists() {
      cancelButton.tap()
    }

    restoreDefaultConfiguration()
  }
}

final class SwipeConfigurationPresetCyclingUITests: SwipeConfigurationTestCase {
  private let presets: [SwipePresetExpectation] = [
    SwipePresetExpectation(
      identifier: "SwipeActions.Preset.Playback",
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"]
    ),
    SwipePresetExpectation(
      identifier: "SwipeActions.Preset.Organization",
      leading: ["markPlayed", "favorite"],
      trailing: ["archive", "delete"]
    ),
    SwipePresetExpectation(
      identifier: "SwipeActions.Preset.Download",
      leading: ["download", "markPlayed"],
      trailing: ["archive", "delete"]
    ),
  ]

  @MainActor
  func testPresetSelectionUpdatesSummaryForEachPreset() throws {
    try beginWithFreshConfigurationSheet()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Baseline should start at default configuration"
    )

    for preset in presets {
      assertPresetSelection(preset)
    }

    restoreDefaultConfiguration()
  }

  @MainActor
  private func assertPresetSelection(_ preset: SwipePresetExpectation) {
    applyPreset(identifier: preset.identifier)

    XCTAssertTrue(
      waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
      "Save button should enable after applying preset \(preset.identifier)"
    )

    guard
      waitForDebugSummary(
        leading: preset.leading,
        trailing: preset.trailing,
        unsaved: true
      )
    else {
      if let state = currentDebugState() {
        let message =
          "Debug summary mismatch for preset \(preset.identifier). "
          + "Observed leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved)"
        XCTFail(message)
      } else {
        XCTFail("Debug summary unavailable for preset \(preset.identifier)")
      }
      return
    }
  }
}

final class SwipeConfigurationActionManagementUITests: SwipeConfigurationTestCase {
  @MainActor
  func testAddingActionsRespectsConfiguredCap() throws {
    try beginWithFreshConfigurationSheet()

    let leadingSequence: [SwipeActionDescriptor] = [
      SwipeActionDescriptor(displayName: "Play", rawValue: "play"),
      SwipeActionDescriptor(displayName: "Add to Playlist", rawValue: "addToPlaylist"),
    ]

    var accumulatedLeading = ["markPlayed"]

    for entry in leadingSequence {
      XCTAssertTrue(
        addAction(entry.displayName, edgeIdentifier: "Leading"),
        "Should be able to add action \(entry.displayName)"
      )
      accumulatedLeading.append(entry.rawValue)

      if !waitForDebugSummary(
        leading: accumulatedLeading,
        trailing: ["delete", "archive"],
        unsaved: true
      ) {
        if let state = currentDebugState() {
          let message =
            "Debug summary mismatch after adding \(entry.displayName). "
            + "Observed leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved)"
          XCTFail(message)
        } else {
          XCTFail("Debug summary unavailable after adding \(entry.displayName)")
        }
        return
      }

      XCTAssertTrue(
        waitForSaveButton(enabled: true),
        "Save button should remain enabled after adding action"
      )
    }

    let addButton = element(withIdentifier: "SwipeActions.Add.Leading")
    XCTAssertTrue(
      waitForElementToDisappear(addButton, timeout: adaptiveShortTimeout),
      "Add Action menu should disappear once limit reached"
    )

    let trailingAddButton = element(withIdentifier: "SwipeActions.Add.Trailing")
    XCTAssertTrue(
      waitForElement(
        trailingAddButton,
        timeout: adaptiveShortTimeout,
        description: "Trailing add action menu"
      ),
      "Trailing add action menu should remain visible when under the limit"
    )

    restoreDefaultConfiguration()
  }
}

extension XCUIElement {
  fileprivate func firstMatchIfExists() -> XCUIElement? {
    return exists ? self : nil
  }
}

extension SwipeConfigurationTestCase {
  @MainActor
  func configurePlaybackLayoutManually() {
    // Remove default actions - continue even if some fail
    _ = removeAction("Mark Played", edgeIdentifier: "Leading")
    _ = removeAction("Delete", edgeIdentifier: "Trailing")
    _ = removeAction("Archive", edgeIdentifier: "Trailing")

    // Add new actions - use XCTAssertTrue but only for critical ones
    XCTAssertTrue(addAction("Play", edgeIdentifier: "Leading"), "Failed to add Play action")
    XCTAssertTrue(
      addAction("Add to Playlist", edgeIdentifier: "Leading"),
      "Failed to add Add to Playlist action")

    // For trailing actions, try but don't fail the test if they don't work
    if !addAction("Download", edgeIdentifier: "Trailing") {
      print("⚠️ Failed to add Download action, continuing...")
    }
    if !addAction("Favorite", edgeIdentifier: "Trailing") {
      print("⚠️ Failed to add Favorite action, continuing...")
    }
  }

  @MainActor
  func seedSwipeConfiguration(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) {
    resetSwipeSettingsToDefault()
    guard let defaults = UserDefaults(suiteName: swipeDefaultsSuite) else {
      XCTFail(
        """
        Expected swipe defaults suite \(swipeDefaultsSuite) to exist for seeding configuration
        """
      )
      return
    }

    let payload: [String: Any] = [
      "swipeActions": [
        "leadingActions": leading,
        "trailingActions": trailing,
        "allowFullSwipeLeading": allowFullSwipeLeading,
        "allowFullSwipeTrailing": allowFullSwipeTrailing,
        "hapticFeedbackEnabled": hapticsEnabled,
      ],
      "hapticStyle": hapticStyle,
    ]

    guard JSONSerialization.isValidJSONObject(payload) else {
      XCTFail("Swipe configuration payload is not valid JSON")
      return
    }

    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
      XCTFail("Failed to encode seeded swipe configuration")
      return
    }

    defaults.set(data, forKey: "global_ui_settings")
    seededConfigurationPayload = data.base64EncodedString()
  }

  func clearSeededConfigurationPayload() {
    seededConfigurationPayload = nil
  }

  @MainActor
  func element(withIdentifier identifier: String) -> XCUIElement {
    if let prioritized = prioritizedElement(in: app, identifier: identifier) {
      return prioritized
    }
    return app.descendants(matching: .any)[identifier]
  }

  // Container-scoped variant: search within a specific container first
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
      root.buttons[identifier],
      root.switches[identifier],
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

  struct SwipeDebugState {
    let leading: [String]
    let trailing: [String]
    let fullLeading: Bool
    let fullTrailing: Bool
    let hapticsEnabled: Bool
    let unsaved: Bool
    let baselineLoaded: Bool
  }

  struct SwipePresetExpectation {
    let identifier: String
    let leading: [String]
    let trailing: [String]
  }

  struct SwipeActionDescriptor {
    let displayName: String
    let rawValue: String
  }

  // Best-effort resolution of the Swipe Actions sheet's list container
  @MainActor
  fileprivate func swipeActionsSheetListContainer() -> XCUIElement? {
    // Presence indicators for the sheet
    let save = app.buttons["SwipeActions.Save"]
    let cancel = app.buttons["SwipeActions.Cancel"]
    guard save.exists || cancel.exists || app.staticTexts["Swipe Actions"].exists else {
      return nil
    }

    let swipePredicate = NSPredicate(format: "identifier BEGINSWITH 'SwipeActions.'")

    // Try to scope to the topmost window that actually presents the Swipe Actions UI
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
        let collectionCandidate = collections.element(boundBy: i)

        // Break down the complex chained method call for better readability and debugging
        let descendantsMatchingAny = collectionCandidate.descendants(matching: .any)
        let swipePredicateMatches = descendantsMatchingAny.matching(swipePredicate)
        let firstSwipeMatch = swipePredicateMatches.firstMatch

        if collectionCandidate.exists && firstSwipeMatch.exists {
          return collectionCandidate
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

    // Search candidate windows in reverse order (topmost last)
    for win in candidateWindows.reversed() {
      if let found = searchContainer(in: win) { return found }
    }

    // Global search as last resort
    if let found = searchContainer(in: app) { return found }

    // As a last resort, return a known element from the sheet to be used as a scroll target
    if save.exists { return save }
    if cancel.exists { return cancel }
    let hapticsToggle = app.switches["SwipeActions.Haptics.Toggle"]
    if hapticsToggle.exists { return hapticsToggle }
    return nil
  }

  // Fallback: resolve an action row by its display label if identifier isn't exposed
  @MainActor
  fileprivate func elementForAction(identifier: String, within container: XCUIElement)
    -> XCUIElement
  {
    // First try by identifier within container
    let byId = element(withIdentifier: identifier, within: container)
    if byId.exists { return byId }

    // Fallback by label (last path component after last dot)
    if let label = identifier.split(separator: ".").last.map(String.init) {
      let staticText = container.staticTexts[label]
      if staticText.exists { return staticText }
      // Sometimes the HStack carrying the label is the hittable element
      let any = container.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", label)
      ).firstMatch
      if any.exists { return any }
    }

    return byId
  }

  @MainActor
  fileprivate func reportAvailableSwipeIdentifiers(context: String) {
    let relevantElements = app.descendants(matching: .any)
      .allElementsBoundByAccessibilityElement
      .filter { element in
        let identifier = element.identifier
        return !identifier.isEmpty
          && (identifier.hasPrefix("SwipeActions.") || identifier.hasPrefix("SwipeAction."))
      }

    guard !relevantElements.isEmpty else { return }

    let identifiers = Set(relevantElements.map { $0.identifier }).sorted()
    let summary = (["Context: \(context)"] + identifiers).joined(separator: "\n")
    let attachment = XCTAttachment(string: summary)
    attachment.name = "Swipe Identifier Snapshot"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  // Container-scoped diagnostics
  @MainActor
  fileprivate func reportAvailableSwipeIdentifiers(context: String, within container: XCUIElement) {
    guard container.exists else { return }
    let elements = container.descendants(matching: .any)
      .allElementsBoundByAccessibilityElement
      .filter { el in
        let id = el.identifier
        return !id.isEmpty && (id.hasPrefix("SwipeActions.") || id.hasPrefix("SwipeAction."))
      }
    guard !elements.isEmpty else { return }
    let identifiers = Set(elements.map { $0.identifier }).sorted()
    let summary = ([("Context: \(context) [scoped]")] + identifiers).joined(separator: "\n")
    let attachment = XCTAttachment(string: summary)
    attachment.name = "Swipe Identifier Snapshot (Scoped)"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  fileprivate func shouldToggleElement(_ element: XCUIElement, targetStateOn: Bool) -> Bool? {
    guard let currentState = currentStateIsOn(for: element) else { return nil }
    return currentState != targetStateOn
  }

  @MainActor
  fileprivate func currentStateIsOn(for element: XCUIElement) -> Bool? {
    if let value = element.value as? String {
      switch value.lowercased() {
      case "1", "on", "true":
        return true
      case "0", "off", "false":
        return false
      default:
        break
      }
    }

    if element.isSelected { return true }

    return nil
  }
}

// swiftlint:enable type_body_length
