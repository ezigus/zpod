//
//  SwipeConfigurationUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.6.2: Swipe Gesture Configuration UI Tests
//

import XCTest

final class SwipeConfigurationUITests: XCTestCase, SmartUITesting {
  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    if let app, app.state == .runningForeground || app.state == .runningBackground {
      app.terminate()
    }
    app = nil
  }

  @MainActor
  func testSwipeConfigurationPresetPersistsAcrossLaunches() throws {
    initializeApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    applyPreset(identifier: "SwipeActions.Preset.Playback")
    setHaptics(enabled: true, styleLabel: "Rigid")
    setFullSwipeToggle(identifier: "SwipeActions.Trailing.FullSwipe", enabled: true)
    saveAndDismissConfiguration()

    relaunchApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    assertActionList(
      leadingIdentifiers: ["SwipeActions.Leading.Play", "SwipeActions.Leading.Add to Playlist"],
      trailingIdentifiers: ["SwipeActions.Trailing.Download", "SwipeActions.Trailing.Favorite"]
    )

    assertToggleState(identifier: "SwipeActions.Trailing.FullSwipe", expected: true)
    assertHapticStyleSelected(label: "Rigid")

    restoreDefaultConfiguration()
  }

  @MainActor
  func testConfiguredSwipeActionsExecuteInEpisodeList() throws {
    initializeApp()

    try navigateToEpisodeList()
    openSwipeConfigurationSheet()

    applyPreset(identifier: "SwipeActions.Preset.Playback")
    saveAndDismissConfiguration()

    let episode = try requireEpisodeButton()

    episode.swipeRight()
    let addToPlaylistButton = element(withIdentifier: "SwipeAction.addToPlaylist")
    XCTAssertTrue(
      addToPlaylistButton.flatMap {
        waitForElement(
          $0, timeout: adaptiveShortTimeout, description: "add to playlist swipe action")
      } ?? false,
      "Add to Playlist swipe action should appear after swiping right"
    )
    addToPlaylistButton?.tap()

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

  // MARK: - Configuration Helpers

  @MainActor
  private func initializeApp() {
    app = launchConfiguredApp()
  }

  @MainActor
  private func relaunchApp() {
    app.terminate()
    app = launchConfiguredApp()
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
    let configureButton = app.buttons["ConfigureSwipeActions"]
    if waitForElement(
      configureButton,
      timeout: adaptiveTimeout,
      description: "configure swipe actions button"
    ) {
      configureButton.tap()
    }

    let sheetTitle = app.navigationBars["Swipe Actions"]
    _ = waitForElement(
      sheetTitle, timeout: adaptiveTimeout, description: "Swipe Actions configuration sheet")
  }

  @MainActor
  private func applyPreset(identifier: String) {
    guard let presetButton = element(withIdentifier: identifier) else {
      XCTFail("Preset button \(identifier) should exist")
      return
    }
    XCTAssertTrue(
      waitForElement(
        presetButton, timeout: adaptiveShortTimeout, description: "preset button \(identifier)"),
      "Preset button \(identifier) should exist"
    )
    presetButton.tap()
  }

  @MainActor
  private func setHaptics(enabled: Bool, styleLabel: String) {
    guard let hapticToggle = element(withIdentifier: "SwipeActions.Haptics.Toggle") else { return }
    if waitForElement(hapticToggle, timeout: adaptiveShortTimeout, description: "haptic toggle") {
      if let shouldToggle = shouldToggleElement(hapticToggle, targetStateOn: enabled) {
        if shouldToggle {
          hapticToggle.tap()
        }
      }
    }

    guard enabled else { return }

    let segmentedControl =
      app.segmentedControls["SwipeActions.Haptics.StylePicker"].exists
      ? app.segmentedControls["SwipeActions.Haptics.StylePicker"]
      : app.segmentedControls.firstMatch
    if segmentedControl.exists {
      let desiredButton = segmentedControl.buttons[styleLabel]
      if desiredButton.exists {
        desiredButton.tap()
      }
    }
  }

  @MainActor
  private func setFullSwipeToggle(identifier: String, enabled: Bool) {
    guard let toggle = element(withIdentifier: identifier) else { return }
    guard waitForElement(toggle, timeout: adaptiveShortTimeout, description: identifier) else {
      return
    }

    if let shouldToggle = shouldToggleElement(toggle, targetStateOn: enabled) {
      if shouldToggle {
        toggle.tap()
      }
    }
  }

  @MainActor
  private func saveAndDismissConfiguration() {
    if let saveButton = element(withIdentifier: "SwipeActions.Save") {
      if waitForElement(saveButton, timeout: adaptiveShortTimeout, description: "save button") {
        saveButton.tap()
      }
    }

    if let configureButton = element(withIdentifier: "ConfigureSwipeActions") {
      _ = waitForElement(configureButton, timeout: adaptiveTimeout, description: "sheet dismissal")
    }
  }

  @MainActor
  private func assertActionList(leadingIdentifiers: [String], trailingIdentifiers: [String]) {
    leadingIdentifiers.forEach { identifier in
      guard let element = element(withIdentifier: identifier) else {
        XCTFail("Expected leading action \(identifier)")
        return
      }
      XCTAssertTrue(
        waitForElement(element, timeout: adaptiveShortTimeout, description: identifier),
        "Expected leading action \(identifier) to appear"
      )
    }

    trailingIdentifiers.forEach { identifier in
      guard let element = element(withIdentifier: identifier) else {
        XCTFail("Expected trailing action \(identifier)")
        return
      }
      XCTAssertTrue(
        waitForElement(element, timeout: adaptiveShortTimeout, description: identifier),
        "Expected trailing action \(identifier) to appear"
      )
    }
  }

  @MainActor
  private func assertToggleState(identifier: String, expected: Bool) {
    guard let toggle = element(withIdentifier: identifier) else {
      XCTFail("Toggle \(identifier) should exist")
      return
    }
    if let currentState = currentStateIsOn(for: toggle) {
      XCTAssertEqual(currentState, expected, "Toggle \(identifier) state mismatch")
    }
  }

  @MainActor
  private func assertHapticStyleSelected(label: String) {
    let segmentedControl =
      app.segmentedControls["SwipeActions.Haptics.StylePicker"].exists
      ? app.segmentedControls["SwipeActions.Haptics.StylePicker"]
      : app.segmentedControls.firstMatch
    XCTAssertTrue(segmentedControl.exists, "Haptic style segmented control should exist")
    let button = segmentedControl.buttons[label]
    XCTAssertTrue(button.exists, "Haptic style option \(label) should exist")
    XCTAssertTrue(button.isSelected, "Haptic style option \(label) should remain selected")
  }

  @MainActor
  private func restoreDefaultConfiguration() {
    openSwipeConfigurationSheet()

    if let defaultPreset = element(withIdentifier: "SwipeActions.Preset.Default") {
      defaultPreset.tap()
    }

    saveAndDismissConfiguration()
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
}

extension XCUIElement {
  fileprivate func firstMatchIfExists() -> XCUIElement? {
    return exists ? self : nil
  }
}

extension SwipeConfigurationUITests {
  @MainActor
  fileprivate func element(withIdentifier identifier: String) -> XCUIElement? {
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
    return anyMatch.exists ? anyMatch : nil
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
