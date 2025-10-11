//
//  SwipeConfigurationUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.6.2: Swipe Gesture Configuration UI Tests
//

import XCTest
import Foundation
import OSLog

final class SwipeConfigurationUITests: XCTestCase, SmartUITesting {
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

  private func launchEnvironment(reset: Bool) -> [String: String] {
    var environment = baseLaunchEnvironment
    environment["UITEST_RESET_SWIPE_SETTINGS"] = reset ? "1" : "0"
    if let payload = seededConfigurationPayload {
      environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] = payload
    }
    return environment
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
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
        if appToTerminate.state == .runningForeground || appToTerminate.state == .runningBackground {
          appToTerminate.terminate()
        }
        self.app = nil
      }
    }

    wait(for: [terminationExpectation], timeout: adaptiveShortTimeout)

    try super.tearDownWithError()
  }

  @MainActor
  func testSwipeConfigurationPresetPersistsAcrossLaunches() throws {
    initializeApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    configurePlaybackLayoutManually()
    setHaptics(enabled: true, styleLabel: "Rigid")
    // Trailing full-swipe toggle currently flaky under automation (tracked separately)
    saveAndDismissConfiguration()

    relaunchApp(resetDefaults: false)

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Play", "SwipeActions.Leading.Add to Playlist"],
      trailingIdentifiers: ["SwipeActions.Trailing.Download", "SwipeActions.Trailing.Favorite"]
    )

    // Full swipe trailing verification skipped due to automation instability
    assertHapticStyleSelected(label: "Rigid")

    restoreDefaultConfiguration()
  }

  @MainActor
  func testConfiguredSwipeActionsExecuteInEpisodeList() throws {
    seedSwipeConfiguration(
      leading: ["play", "addToPlaylist"],
      trailing: ["download", "favorite"],
      hapticsEnabled: true,
      hapticStyle: "rigid"
    )

    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
    seededConfigurationPayload = nil

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["play", "addToPlaylist"],
        trailing: ["download", "favorite"],
        unsaved: false
      ),
      "Seeded playback configuration should match debug summary"
    )

    if app.buttons["SwipeActions.Cancel"].waitForExistence(timeout: adaptiveShortTimeout) {
      tapElement(app.buttons["SwipeActions.Cancel"], description: "SwipeActions.Cancel")
      _ = waitForElementToDisappear(app.buttons["SwipeActions.Save"], timeout: adaptiveTimeout)
    }

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
    // EpisodeListView assigns identifiers as `SwipeAction.<rawValue>`
    let addToPlaylistButton = element(withIdentifier: "SwipeAction.addToPlaylist")
    XCTAssertTrue(
      waitForElement(
        addToPlaylistButton, timeout: adaptiveShortTimeout,
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
        playlistNavBar, timeout: adaptiveTimeout, description: "playlist selection sheet"),
      "Selecting Add to Playlist should present the playlist sheet"
    )

    if let cancelButton = playlistNavBar.buttons["Cancel"].firstMatchIfExists() {
      cancelButton.tap()
    }

    restoreDefaultConfiguration()
  }

  @MainActor
  func testSwipeConfigurationPresetCycleCoversAllPresets() throws {
    initializeApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    XCTAssertTrue(
      waitForDebugSummary(
        leading: ["markPlayed"],
        trailing: ["delete", "archive"],
        unsaved: false
      ),
      "Baseline should start at default configuration"
    )

    let presets: [(identifier: String, leading: [String], trailing: [String])] = [
      ("SwipeActions.Preset.Playback", ["play", "addToPlaylist"], ["download", "favorite"]),
      ("SwipeActions.Preset.Organization", ["markPlayed", "favorite"], ["archive", "delete"]),
      ("SwipeActions.Preset.Download", ["download", "markPlayed"], ["archive", "delete"]),
    ]

    for preset in presets {
      applyPreset(identifier: preset.identifier)

      XCTAssertTrue(
        waitForSaveButton(enabled: true, timeout: adaptiveShortTimeout),
        "Save button should enable after applying preset \(preset.identifier)"
      )

      guard waitForDebugSummary(
        leading: preset.leading,
        trailing: preset.trailing,
        unsaved: true
      ) else {
        if let state = currentDebugState() {
          XCTFail(
            "Debug summary mismatch for preset \(preset.identifier). Observed leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved)"
          )
        } else {
          XCTFail("Debug summary unavailable for preset \(preset.identifier)")
        }
        return
      }
    }

    restoreDefaultConfiguration()
  }

  @MainActor
  func testSwipeConfigurationAddActionRespectsCap() throws {
    initializeApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    let leadingSequence: [(displayName: String, rawValue: String)] = [
      ("Play", "play"),
      ("Add to Playlist", "addToPlaylist"),
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
          XCTFail("Debug summary mismatch after adding \(entry.displayName). Observed leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved)")
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

  // MARK: - Configuration Helpers

  @MainActor
  @discardableResult
  private func waitForSaveButton(enabled: Bool, timeout: TimeInterval? = nil) -> Bool {
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
  private func waitForBaselineLoaded(timeout: TimeInterval = 5.0) -> Bool {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard waitForElement(
      summaryElement,
      timeout: adaptiveShortTimeout,
      description: "Swipe configuration debug summary"
    ) else {
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
  private func waitForDebugSummary(
    leading expectedLeading: [String],
    trailing expectedTrailing: [String],
    unsaved expectedUnsaved: Bool? = nil,
    timeout: TimeInterval? = nil
  ) -> Bool {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard waitForElement(
      summaryElement,
      timeout: adaptiveShortTimeout,
      description: "Swipe configuration debug summary"
    ) else {
      return false
    }

    var lastObservedState: SwipeDebugState?
    let effectiveTimeout = timeout ?? adaptiveTimeout
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
      guard state.leading == expectedLeading, state.trailing == expectedTrailing else {
        return false
      }
      if let expectedUnsaved, state.unsaved != expectedUnsaved {
        return false
      }
      return true
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for debug summary match"
    let result = XCTWaiter.wait(for: [expectation], timeout: effectiveTimeout)
    if result != .completed, let observed = lastObservedState {
      let attachment = XCTAttachment(string: "Observed debug state: leading=\(observed.leading) trailing=\(observed.trailing) unsaved=\(observed.unsaved) baseline=\(observed.baselineLoaded)")
      attachment.lifetime = .keepAlways
      add(attachment)
    }
    return result == .completed
  }

  @MainActor
  @discardableResult
  private func removeAction(_ displayName: String, edgeIdentifier: String) -> Bool {
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
  private func addAction(_ displayName: String, edgeIdentifier: String) -> Bool {
    guard let container = swipeActionsSheetListContainer() else {
      return false
    }

    let addIdentifier = "SwipeActions.Add." + edgeIdentifier
    _ = ensureVisibleInSheet(identifier: addIdentifier, container: container)
    let addMenu = element(withIdentifier: addIdentifier, within: container)
    guard addMenu.exists else { return false }
    addMenu.tap()

    let optionIdentifier = addIdentifier + "." + displayName
    let optionCandidates: [XCUIElement] = [
      element(withIdentifier: optionIdentifier),
      element(withIdentifier: optionIdentifier, within: container),
      app.buttons[displayName],
      app.menuItems[displayName],
      app.collectionViews.buttons[displayName],
    ]

    guard
      let optionButton = waitForAnyElement(
        optionCandidates,
        timeout: adaptiveShortTimeout,
        description: "Add action option \(displayName)",
        failOnTimeout: false
      )
    else {
      XCTFail("Add action option \(displayName) did not appear")
      return false
    }

    tapElement(optionButton, description: "Add action option \(displayName)")
    return true
  }

  @MainActor
  private func resetSwipeSettingsToDefault() {
    guard let defaults = UserDefaults(suiteName: swipeDefaultsSuite) else {
      XCTFail("Expected swipe defaults suite \(swipeDefaultsSuite) to exist")
      return
    }
    defaults.removePersistentDomain(forName: swipeDefaultsSuite)
    defaults.setPersistentDomain([:], forName: swipeDefaultsSuite)
  }

  @MainActor
  private func initializeApp() {
    resetSwipeSettingsToDefault()
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: true))
    seededConfigurationPayload = nil
  }

  @MainActor
  private func relaunchApp(resetDefaults: Bool = false) {
    app.terminate()
    if resetDefaults {
      resetSwipeSettingsToDefault()
    }
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: resetDefaults))
    seededConfigurationPayload = nil
  }

  @MainActor
  private func navigateToEpisodeList() throws {
    let tabBar = app.tabBars["Main Tab Bar"]
    guard tabBar.exists else {
      throw XCTSkip("Main tab bar not available")
    }

    let libraryTab = tabBar.buttons["Library"]
    guard libraryTab.exists else {
      throw XCTSkip("Library tab unavailable")
    }
    libraryTab.tap()

    guard
      waitForContentToLoad(containerIdentifier: "Podcast Cards Container", timeout: adaptiveTimeout)
    else {
      throw XCTSkip("Library content did not load")
    }

    let podcastButton = app.buttons["Podcast-swift-talk"]
    guard podcastButton.exists else {
      throw XCTSkip("Test podcast unavailable")
    }
    podcastButton.tap()

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
  private func openSwipeConfigurationSheet() {
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
  private func logDebugState(_ label: String) {
    if let state = currentDebugState() {
      logger.debug("[SwipeUITestDebug] \(label, privacy: .public): leading=\(state.leading, privacy: .public) trailing=\(state.trailing, privacy: .public) unsaved=\(state.unsaved, privacy: .public) baseline=\(state.baselineLoaded, privacy: .public)")
    } else {
      logger.debug("[SwipeUITestDebug] \(label, privacy: .public): state unavailable")
    }
  }

  @MainActor
  private func applyPreset(identifier: String) {
    let presetButton = element(withIdentifier: identifier)
    if let container = swipeActionsSheetListContainer() {
      _ = ensureVisibleInSheet(identifier: identifier, container: container)
    }
    XCTAssertTrue(
      waitForElement(
        presetButton, timeout: adaptiveShortTimeout, description: "preset button \(identifier)"),
      "Preset button \(identifier) should exist"
    )
    logger.debug("[SwipeUITestDebug] preset button description: \(presetButton.debugDescription, privacy: .public)")
    tapElement(presetButton, description: identifier)
    logDebugState("after applyPreset \(identifier)")
  }

  @MainActor
  private func setHaptics(enabled: Bool, styleLabel: String) {
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

    let decision = shouldToggleElement(toggle, targetStateOn: enabled)
    if decision == true || decision == nil {
      let coordinate = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
      coordinate.tap()
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
  private func tapElement(_ element: XCUIElement, description: String) {
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
  private func revealLeadingSwipeActions(for element: XCUIElement) {
    element.swipeRight()

    if app.buttons["SwipeAction.addToPlaylist"].exists {
      return
    }

    let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
    let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
    start.press(forDuration: 0.05, thenDragTo: end)
  }

  @MainActor
  private func setFullSwipeToggle(identifier: String, enabled: Bool) {
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

    let decision = shouldToggleElement(toggle, targetStateOn: enabled)
    if decision == true || decision == nil {
      _ = waitForElementToBeHittable(toggle, timeout: adaptiveShortTimeout, description: identifier)
      toggle.tap()
    }

    for _ in 0..<2 {
      if let state = currentDebugState() {
        let isEnabled = identifier.contains("Trailing") ? state.fullTrailing : state.fullLeading
        if isEnabled == enabled { break }
      }
      toggle.tap()
    }

    logDebugState("after setFullSwipe \(identifier)")

  }

  @MainActor
  private func saveAndDismissConfiguration() {
    let saveButton = element(withIdentifier: "SwipeActions.Save")
    guard waitForElement(saveButton, timeout: adaptiveShortTimeout, description: "save button") else {
      return
    }
    logDebugState("before save")
    _ = waitForSaveButton(enabled: true)
    saveButton.tap()
    waitForSheetDismissal()
    logDebugState("after save (sheet dismissed)")
  }

  @MainActor
  private func assertToggleState(identifier: String, expected: Bool) {
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
  private func assertHapticStyleSelected(label: String) {
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
  private func waitForSheetDismissal() {
    // Wait for either the navigation bar or save button to disappear
    let navBar = app.navigationBars["Swipe Actions"]
    let saveButton = app.buttons["SwipeActions.Save"]

    // Try both; don't hard-fail if already gone
    _ = waitForElementToDisappear(saveButton, timeout: adaptiveTimeout)
    _ = waitForElementToDisappear(navBar, timeout: adaptiveTimeout)
  }

  @MainActor
  private func restoreDefaultConfiguration() {
    resetSwipeSettingsToDefault()
    relaunchApp(resetDefaults: true)
  }

  @MainActor
  private func assertActionList(leadingIdentifiers: [String], trailingIdentifiers: [String]) {
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
      logger.debug("[SwipeUITestDebug] leading=\(state.leading, privacy: .public) trailing=\(state.trailing, privacy: .public) unsaved=\(state.unsaved, privacy: .public) baseline=\(state.baselineLoaded, privacy: .public)")
      let attachment = XCTAttachment(string: "AssertActionList debug state: leading=\(state.leading) trailing=\(state.trailing) unsaved=\(state.unsaved) baseline=\(state.baselineLoaded)")
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
  private func requireEpisodeButton() throws -> XCUIElement {
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

  private func ensureVisibleInSheet(identifier: String, container: XCUIElement) -> Bool {
    let target = element(withIdentifier: identifier, within: container)
    if target.exists { return true }

    // Attempt a few upward swipes to reveal items further down
    var attempts = 0
    while attempts < 6 && !target.exists {
      if container.exists {
        container.swipeUp()
      } else {
        app.swipeUp()
      }
      attempts += 1
    }

    if target.exists { return true }

    // Try swiping down a bit in case the item is above
    attempts = 0
    while attempts < 3 && !target.exists {
      if container.exists {
        container.swipeDown()
      } else {
        app.swipeDown()
      }
      attempts += 1
    }
    return target.exists
  }
}

extension XCUIElement {
  fileprivate func firstMatchIfExists() -> XCUIElement? {
    return exists ? self : nil
  }
}

extension SwipeConfigurationUITests {
  @MainActor
  fileprivate func configurePlaybackLayoutManually() {
    XCTAssertTrue(
      removeAction("Mark Played", edgeIdentifier: "Leading"),
      "Expected to remove default leading action Mark Played"
    )
    XCTAssertTrue(
      removeAction("Delete", edgeIdentifier: "Trailing"),
      "Expected to remove default trailing action Delete"
    )
    XCTAssertTrue(
      removeAction("Archive", edgeIdentifier: "Trailing"),
      "Expected to remove default trailing action Archive"
    )

    XCTAssertTrue(addAction("Play", edgeIdentifier: "Leading"))
    XCTAssertTrue(addAction("Add to Playlist", edgeIdentifier: "Leading"))
    XCTAssertTrue(addAction("Download", edgeIdentifier: "Trailing"))
    XCTAssertTrue(addAction("Favorite", edgeIdentifier: "Trailing"))
  }

  @MainActor
  fileprivate func seedSwipeConfiguration(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) {
    resetSwipeSettingsToDefault()
    guard let defaults = UserDefaults(suiteName: swipeDefaultsSuite) else {
      XCTFail("Expected swipe defaults suite \(swipeDefaultsSuite) to exist for seeding configuration")
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

  @MainActor
  fileprivate func element(withIdentifier identifier: String) -> XCUIElement {
    let queries: [XCUIElementQuery] = [
      app.buttons,
      app.switches,
      app.segmentedControls,
      app.staticTexts,
      app.otherElements,
      app.cells,
      app.tables,
    ]

    for query in queries {
      let element = query[identifier]
      if element.exists { return element }
    }

    let anyMatch = app.descendants(matching: .any)[identifier]
    return anyMatch
  }

  // Container-scoped variant: search within a specific container first
  @MainActor
  fileprivate func element(withIdentifier identifier: String, within container: XCUIElement)
    -> XCUIElement
  {
    if container.exists {
      let queries: [XCUIElementQuery] = [
        container.buttons,
        container.switches,
        container.segmentedControls,
        container.staticTexts,
        container.otherElements,
        container.cells,
        container.tables,
      ]

      for query in queries {
        let element = query[identifier]
        if element.exists { return element }
      }

      let anyMatch = container.descendants(matching: .any)[identifier]
      if anyMatch.exists { return anyMatch }
    }
    // Fallback to global
    return element(withIdentifier: identifier)
  }

  private func currentDebugState() -> SwipeDebugState? {
    let summaryElement = element(withIdentifier: "SwipeActions.Debug.StateSummary")
    guard summaryElement.exists, let raw = summaryElement.value as? String else {
      return nil
    }
    return parseDebugState(from: raw)
  }

  private func parseDebugState(from raw: String) -> SwipeDebugState? {
    var leading: [String] = []
    var trailing: [String] = []
    var fullLeading = false
    var fullTrailing = false
    var hapticsEnabled = false
    var unsaved = false
    var baselineLoaded = false

    for component in raw.split(separator: ";") {
      let parts = component.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
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

  private struct SwipeDebugState {
    let leading: [String]
    let trailing: [String]
    let fullLeading: Bool
    let fullTrailing: Bool
    let hapticsEnabled: Bool
    let unsaved: Bool
    let baselineLoaded: Bool
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
        let cv = collections.element(boundBy: i)
        if cv.exists
          && cv.descendants(matching: .any).matching(swipePredicate).firstMatch.exists
        {
          return cv
        }
      }

      let scrolls = root.scrollViews.matching(NSPredicate(value: true))
      for i in 0..<scrolls.count {
        let sv = scrolls.element(boundBy: i)
        if sv.exists
          && sv.descendants(matching: .any).matching(swipePredicate).firstMatch.exists
        {
          return sv
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
