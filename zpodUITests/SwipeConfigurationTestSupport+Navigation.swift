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

    try openConfigurationSheetFromEpisodeList()
  }

  /// Opens the configuration sheet, verifies baseline + section materialization once, and caches
  /// the sheet container for this test instance. Use this to avoid repeated waits within a test.
  @MainActor
  @discardableResult
  func openConfigurationSheetReady(resetDefaults: Bool = true) throws -> XCUIElement? {
    // Always relaunch once per test unless already launched for this seed.
    if !hasLaunchedForCurrentSeed {
      if resetDefaults {
        initializeApp()
      } else {
        relaunchApp(resetDefaults: false)
      }
      hasLaunchedForCurrentSeed = true
    } else if resetDefaults {
      relaunchApp(resetDefaults: true)
    }

    try openConfigurationSheetFromEpisodeList()

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

    // Brief stability wait after section materialization to ensure UI rendering completes
    // The materialization probe checks @State variables that update before SwiftUI renders all elements.
    // In CI's slower environment, there's a race between probe passing and preset button rendering.
    // This 500ms wait ensures all lazy-rendered elements (especially preset buttons) are fully materialized.
    // Aligns with Phase 3 "wait for stability" philosophy (minimal targeted wait, not retry pattern).
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))

    guard let container = swipeActionsSheetListContainer() else {
      XCTFail("Swipe configuration sheet container should be discoverable after opening")
      return nil
    }

    // Cache readiness state to avoid redundant waits on subsequent reuse
    cachedReadiness = ReadinessContext(
      baselineLoaded: true,
      sectionsMaterialized: true,
      seedApplied: hasLaunchedForCurrentSeed,
      sheetContainer: container
    )

    return container
  }

  /// Returns the sheet container if discoverable; otherwise opens it.
  /// Note: Always re-discovers instead of caching to handle SwiftUI sheet lifecycle.
  @MainActor
  @discardableResult
  func reuseOrOpenConfigurationSheet(resetDefaults: Bool = false) throws -> XCUIElement? {
    // If the app is not yet launched or was terminated, open the sheet from scratch.
    if app == nil || app.state == .notRunning || app.state == .unknown {
      return try openConfigurationSheetReady(resetDefaults: true)
    }

    if resetDefaults {
      cachedReadiness = nil  // Clear cache when resetting defaults
      return try openConfigurationSheetReady(resetDefaults: true)
    }

    // OPTIMIZATION: If we have cached readiness and container still exists, return immediately
    // This skips waitForBaselineLoaded + waitForSectionMaterialization (1-2s per call)
    if let cached = cachedReadiness,
       cached.sheetContainer?.exists == true {
      return cached.sheetContainer
    }

    // Try to reuse an existing sheet only when the app is running.
    if let container = swipeActionsSheetListContainer(), container.exists {
      return container
    }

    // Sheet not found, open it fresh.
    return try openConfigurationSheetReady(resetDefaults: false)
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
      XCTFail("Main tab bar not available")
      return
    }

    let libraryTab = tabBar.buttons["Library"]
    guard libraryTab.exists else {
      XCTFail("Library tab unavailable")
      return
    }

    guard
      waitForElement(
        libraryTab,
        timeout: adaptiveShortTimeout,
        description: "Library tab button"
      )
    else {
      XCTFail("Library tab not ready for interaction")
      return
    }

    guard libraryTab.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Library tab did not appear within \(adaptiveShortTimeout) seconds")
      return
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
      XCTFail("Failed to navigate to Library tab")
      return
    }

    guard
      waitForContentToLoad(containerIdentifier: "Podcast Cards Container", timeout: adaptiveTimeout)
    else {
      XCTFail("Library content did not load")
      return
    }

    let podcastButton = app.buttons["Podcast-swift-talk"]
    guard podcastButton.exists else {
      XCTFail("Test podcast unavailable")
      return
    }

    guard podcastButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Podcast button did not appear within \(adaptiveShortTimeout) seconds")
      return
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
      XCTFail("Failed to navigate to episode list")
      return
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
        XCTFail("Episode list did not load")
        return
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

    guard configureButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail(
        "Configure swipe actions button did not appear within \(adaptiveShortTimeout) seconds")
      return
    }

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
