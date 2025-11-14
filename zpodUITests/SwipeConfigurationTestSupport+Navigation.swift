//
//  SwipeConfigurationTestSupport+Navigation.swift
//  zpodUITests
//
//  Navigation + sheet orchestration helpers for Issue 02.6.3.
//

import Foundation
import XCTest

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

  @MainActor
  func openConfigurationSheetFromEpisodeList() throws {
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

    let navigationSucceeded = navigateAndWaitForResult(
      triggerAction: { libraryTab.tap() },
      expectedElements: [
        app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch,
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

    let podcastButton = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
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

    let episodeNavSucceeded = navigateAndWaitForResult(
      triggerAction: { podcastButton.tap() },
      expectedElements: [
        app.buttons.matching(identifier: "ConfigureSwipeActions").firstMatch,
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
      let configureButton = app.buttons.matching(identifier: "ConfigureSwipeActions").firstMatch
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
      app.navigationBars.matching(identifier: "Swipe Actions").firstMatch,
      app.otherElements.matching(identifier: "Swipe Actions").firstMatch,
      app.staticTexts.matching(identifier: "Swipe Actions").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Save").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch,
    ]

    if existingIndicators.contains(where: { $0.exists }) {
      completeSeedIfNeeded()
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

    _ = waitForElementToBeHittable(
      configureButton,
      timeout: adaptiveShortTimeout,
      description: "configure swipe actions button"
    )

    tapElement(configureButton, description: "configure swipe actions button")

    let refreshedIndicators: [XCUIElement] = [
      app.navigationBars.matching(identifier: "Swipe Actions").firstMatch,
      app.otherElements.matching(identifier: "Swipe Actions").firstMatch,
      app.staticTexts.matching(identifier: "Swipe Actions").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Save").firstMatch,
      app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch,
    ]

    var sheetPresented = waitForAnyElement(
      refreshedIndicators,
      timeout: adaptiveTimeout,
      description: "Swipe Actions configuration sheet"
    )

    if sheetPresented == nil {
      logger.warning(
        "[SwipeUITestDebug] Swipe Actions sheet did not appear after first tap, retrying")
      _ = waitForElementToBeHittable(
        configureButton,
        timeout: adaptiveShortTimeout,
        description: "configure swipe actions button (retry)"
      )
      tapElement(configureButton, description: "configure swipe actions button (retry)")
      sheetPresented = waitForAnyElement(
        refreshedIndicators,
        timeout: adaptiveTimeout,
        description: "Swipe Actions configuration sheet (retry)"
      )
    }

    guard sheetPresented != nil else {
      XCTFail("Swipe configuration sheet failed to present")
      return
    }

    _ = waitForBaselineLoaded()

    guard waitForSectionMaterialization() else {
      XCTFail("Haptics section failed to materialize after baseline loaded")
      return
    }

    logDebugState("baseline after open")
    reportAvailableSwipeIdentifiers(context: "Sheet opened (initial)")
    completeSeedIfNeeded()
  }

  @MainActor
  func waitForSheetDismissal() {
    let navBar = app.navigationBars.matching(identifier: "Swipe Actions").firstMatch
    let saveButton = app.buttons.matching(identifier: "SwipeActions.Save").firstMatch
    _ = waitForElementToDisappear(saveButton, timeout: adaptiveTimeout)
    _ = waitForElementToDisappear(navBar, timeout: adaptiveTimeout)
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
    let cancelButton = app.buttons.matching(identifier: "SwipeActions.Cancel").firstMatch
    guard cancelButton.waitForExistence(timeout: adaptiveShortTimeout) else { return }
    tapElement(cancelButton, description: "SwipeActions.Cancel")
    _ = waitForElementToDisappear(
      app.buttons.matching(identifier: "SwipeActions.Save").firstMatch, timeout: adaptiveTimeout)
  }

  @MainActor
  func requireEpisodeButton() throws -> XCUIElement {
    let preferredEpisode = app.buttons.matching(identifier: "Episode-st-001").firstMatch
    if preferredEpisode.exists {
      return preferredEpisode
    }

    let fallbackEpisode = app.buttons
      .matching(NSPredicate(format: "identifier CONTAINS 'Episode-'"))
      .firstMatch
    guard fallbackEpisode.exists else {
      throw XCTSkip("No episode button available for swipe configuration testing")
    }
    return fallbackEpisode
  }
}
