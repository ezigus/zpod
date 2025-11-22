//
//  SwipeConfigurationTestSupport+Navigation.swift
//  zpodUITests
//
//  Navigation + sheet orchestration helpers for Issue 02.6.3.
//

import Foundation
import XCTest

enum SwipeConfigurationNavigationError: Error {
  case missingEpisodeButton
}

extension SwipeConfigurationTestCase {
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
  }

  @MainActor
  func relaunchApp(resetDefaults: Bool = false) {
    if app == nil {
      if resetDefaults {
        resetSwipeSettingsToDefault()
      }
      app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: resetDefaults))
      return
    }

    app.terminate()
    if resetDefaults {
      resetSwipeSettingsToDefault()
    }
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: resetDefaults))
  }

  @MainActor
  func beginWithFreshConfigurationSheet(resetDefaults: Bool = true) throws {
    if resetDefaults {
      initializeApp()
    } else {
      relaunchApp(resetDefaults: false)
    }

    // In interactive mode, wait for debug overlay to materialize before opening sheet
    if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" {
      let overlayButton = app.buttons
        .matching(identifier: "SwipeActions.Debug.ApplyPreset.Default.Overlay")
        .firstMatch
      _ = overlayButton.waitForExistence(timeout: adaptiveShortTimeout)
    }

    try openConfigurationSheetFromEpisodeList()
  }

  /// Opens the configuration sheet, verifies baseline + section materialization once, and caches
  /// the sheet container for this test instance. Use this to avoid repeated waits within a test.
  @MainActor
  @discardableResult
  func openConfigurationSheetReady(resetDefaults: Bool = true) throws -> XCUIElement? {
    try beginWithFreshConfigurationSheet(resetDefaults: resetDefaults)

    // Only verify debug baseline if debug overlay is enabled (UITEST_SWIPE_DEBUG=1)
    if baseLaunchEnvironment["UITEST_SWIPE_DEBUG"] == "1" {
      XCTAssertTrue(
        waitForBaselineLoaded(),
        "Swipe configuration baseline should load after opening sheet"
      )
    }
    XCTAssertTrue(
      waitForSectionMaterialization(timeout: adaptiveShortTimeout),
      "Swipe configuration sections should materialize within timeout"
    )

    // Cache the container for the remainder of the test
    cachedSwipeContainer = swipeActionsSheetListContainer()
    XCTAssertNotNil(cachedSwipeContainer, "Swipe configuration sheet container should be discoverable")
    return cachedSwipeContainer
  }

  /// Returns the cached sheet container if available; otherwise opens it.
  @MainActor
  @discardableResult
  func reuseOrOpenConfigurationSheet(resetDefaults: Bool = false) throws -> XCUIElement? {
    if resetDefaults {
      cachedSwipeContainer = nil
    }
    if let cached = cachedSwipeContainer, cached.exists {
      return cached
    }
    return try openConfigurationSheetReady(resetDefaults: resetDefaults)
  }

  @MainActor
  func openConfigurationSheetFromEpisodeList() throws {
    try navigateToEpisodeList()
    openSwipeConfigurationSheet()
  }

  @MainActor
  func navigateToEpisodeList() throws {
    let tabBar = app.tabBars["Main Tab Bar"]
    guard tabBar.exists else {
      XCTFail("Main tab bar not available"); return
    }

    let libraryTab = tabBar.buttons["Library"]
    guard libraryTab.exists else {
      XCTFail("Library tab unavailable"); return
    }

    guard
      waitForElement(
        libraryTab,
        timeout: adaptiveShortTimeout,
        description: "Library tab button"
      )
    else {
      XCTFail("Library tab not ready for interaction"); return
    }

    guard
      waitForElementToBeHittable(
        libraryTab,
        timeout: adaptiveShortTimeout,
        description: "Library tab button"
      )
    else {
      XCTFail("Library tab not hittable"); return
    }

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
      XCTFail("Failed to navigate to Library tab"); return
    }

    guard
      waitForContentToLoad(containerIdentifier: "Podcast Cards Container", timeout: adaptiveTimeout)
    else {
      XCTFail("Library content did not load"); return
    }

    let podcastButton = app.buttons["Podcast-swift-talk"]
    guard podcastButton.exists else {
      XCTFail("Test podcast unavailable"); return
    }

    guard
      waitForElementToBeHittable(
        podcastButton,
        timeout: adaptiveShortTimeout,
        description: "Podcast button"
      )
    else {
      XCTFail("Podcast button not hittable"); return
    }

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
      XCTFail("Failed to navigate to episode list"); return
    }

    if !waitForContentToLoad(
      containerIdentifier: "Episode Cards Container",
      timeout: adaptiveTimeout
    ) {
      let configureButton = app.buttons["ConfigureSwipeActions"]
      guard
      waitForElement(
        configureButton,
        timeout: adaptiveShortTimeout,
        description: "configure swipe actions button"
      )
    else {
      XCTFail("Episode list did not load"); return
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
      completeSeedIfNeeded()
      return
    }

    let configureButton = element(withIdentifier: "ConfigureSwipeActions")
    guard
      waitForElement(
        configureButton,
        timeout: adaptiveShortTimeout,
        description: "configure swipe actions button"
      )
    else {
      XCTFail("Configure swipe actions button should exist before opening sheet")
      return
    }

    _ = waitForElementToBeHittable(
      configureButton,
      timeout: adaptiveShortTimeout,
      description: "configure swipe actions button"
    )

    tapElement(configureButton, description: "configure swipe actions button")

    let refreshedIndicators: [XCUIElement] = [
      app.navigationBars["Swipe Actions"],
      app.otherElements["Swipe Actions"],
      app.staticTexts["Swipe Actions"],
      app.buttons["SwipeActions.Save"],
      app.buttons["SwipeActions.Cancel"],
    ]

    _ = waitForAnyElement(
      refreshedIndicators,
      timeout: adaptiveShortTimeout,
      description: "Swipe Actions configuration sheet"
    )

    // Only verify debug baseline if debug overlay is enabled (UITEST_SWIPE_DEBUG=1)
    if baseLaunchEnvironment["UITEST_SWIPE_DEBUG"] == "1" {
      XCTAssertTrue(
        waitForBaselineLoaded(),
        "Swipe configuration baseline should load after opening sheet"
      )
    }
    XCTAssertTrue(
      waitForSectionMaterialization(timeout: adaptiveShortTimeout),
      "Swipe configuration sections should materialize within timeout"
    )
    completeSeedIfNeeded()
  }

  @MainActor
  func waitForSheetDismissal() {
    let navBar = app.navigationBars["Swipe Actions"]
    let saveButton = app.buttons["SwipeActions.Save"]
    _ = waitForElementToDisappear(saveButton, timeout: adaptiveTimeout)
    _ = waitForElementToDisappear(navBar, timeout: adaptiveTimeout)
  }

  @MainActor
  func saveAndDismissConfiguration() {
    let saveButton = element(withIdentifier: "SwipeActions.Save")
    guard waitForElement(saveButton, timeout: postReadinessTimeout, description: "save button")
    else {
      return
    }
    _ = waitForSaveButton(enabled: true)
    saveButton.tap()
    waitForSheetDismissal()
  }

  func dismissConfigurationSheetIfNeeded() {
    let cancelButton = app.buttons["SwipeActions.Cancel"]
    guard cancelButton.exists else { return }
    tapElement(cancelButton, description: "SwipeActions.Cancel")
    _ = waitForElementToDisappear(app.buttons["SwipeActions.Save"], timeout: adaptiveTimeout)
  }

  @MainActor
  func requireEpisodeButton() throws -> XCUIElement {
    let preferredEpisode = app.buttons["Episode-st-001"]
    if preferredEpisode.exists {
      return preferredEpisode
    }

    let fallbackEpisode = app.buttons
      .matching(NSPredicate(format: "identifier CONTAINS 'Episode-'"))
      .firstMatch
    guard fallbackEpisode.exists else {
      XCTFail("No episode button available for swipe configuration testing")
      throw SwipeConfigurationNavigationError.missingEpisodeButton
    }
    return fallbackEpisode
  }
}
