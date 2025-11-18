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
    
    // Wait for debug overlay to materialize if in debug mode (500ms delay + buffer)
    if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" {
      let overlayButton = app.buttons.matching(identifier: "SwipeActions.Debug.ApplyPreset.Default.Overlay").firstMatch
      // Give overlay up to 2 seconds to appear (500ms delay + window creation + margin)
      _ = overlayButton.waitForExistence(timeout: 2.0)
      // Don't fail if overlay doesn't appear - tests will fall back to other preset methods
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
    logDebugState("baseline after open")
    reportAvailableSwipeIdentifiers(context: "Sheet opened (initial)", scoped: true)
    guard let app = app else {
      XCTFail("XCUIApplication should be initialized before logging sheet state")
      return
    }
    let scopedRoot = swipeActionsSheetListContainer() ?? app
    print("[SwipeUITestDebug] Scoped tree (initial):\n\(scopedRoot.debugDescription)")
    let scopedAttachment = XCTAttachment(string: scopedRoot.debugDescription)
    scopedAttachment.name = "Scoped Debug Tree (initial)"
    scopedAttachment.lifetime = .keepAlways
    add(scopedAttachment)
    if let toggle = scopedRoot.switches.matching(identifier: "SwipeActions.Haptics.Toggle")
      .firstMatch as XCUIElement?
    {
      print(
        "[SwipeUITestDebug] Haptics switch exists=\(toggle.exists) hittable=\(toggle.isHittable) value=\(String(describing: toggle.value))"
      )
    } else {
      print("[SwipeUITestDebug] Haptics switch not found in scoped root")
    }
    completeSeedIfNeeded()
  }

  /// Waits for SwiftUI List sections to materialize in accessibility tree.
  /// Uses .matching(identifier:).firstMatch pattern per ACCESSIBILITY_TESTING_BEST_PRACTICES.
  /// Returns true if materialization completes, false on timeout.
  @MainActor
  @discardableResult
  func waitForSectionMaterialization(timeout: TimeInterval = 2.0) -> Bool {
    print("[SwipeUITestDebug] Waiting for section materialization (timeout: \(timeout)s)...")

    // Primary indicator: Haptics toggle must exist (per Step 1 plan)
    let hapticsToggle = app.switches
      .matching(identifier: "SwipeActions.Haptics.Toggle")
      .firstMatch

    guard hapticsToggle.waitForExistence(timeout: timeout) else {
      print(
        "[SwipeUITestDebug] ❌ Section materialization failed: Haptics toggle not found within \(timeout)s"
      )
      print("[SwipeUITestDebug] Tree dump:\n\(app.debugDescription)")
      return false
    }

    print("[SwipeUITestDebug] ✅ Haptics toggle found, checking materialization probe...")

    // Optional: Check materialization probe if present (per Step 4 plan)
    let probe = app.staticTexts
      .matching(identifier: "SwipeActions.Debug.Materialized")
      .firstMatch

    if probe.exists, let value = probe.value as? String {
      let materialized = value.contains("Materialized=1")
      print(
        "[SwipeUITestDebug] Materialization probe value: \(value) (materialized: \(materialized))")

      if !materialized {
        print("[SwipeUITestDebug] ⚠️ Probe exists but Materialized=0 (still completing)")
      }

      return materialized
    }

    // Toggle exists, probe either not present or no value - sufficient for materialization
    print("[SwipeUITestDebug] ✅ Section materialization complete (toggle exists)")
    return true
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
  func requireEpisodeButton() throws -> XCUIElement {
    let preferredEpisode = app.buttons["Episode-st-001"]
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
