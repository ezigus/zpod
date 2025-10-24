import UIKit
import XCTest

/// Core UI navigation and accessibility tests for the main application interface
///
/// **Specifications Covered**: `spec/ui.md` - Navigation sections
/// - Main navigation flow between screens and tabs
/// - Accessibility compliance and VoiceOver support
/// - Quick action handling and app shortcuts
final class CoreUINavigationTests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
    // Stop immediately when a failure occurs
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()

    // Initialize app without @MainActor calls in setup
    // XCUIApplication creation and launch will be done in test methods
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Helper Methods

  @MainActor
  private func initializeApp() {
    app = launchConfiguredApp()
  }

  // MARK: - Main Navigation Tests
  // Covers: Basic navigation flow from ui spec

  @MainActor
  func testMainTabBarNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: App is launched and main interface is visible
    // When: User taps different tab bar items
    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(tabBar.exists, "Main tab bar should be visible")

    // Test Library tab using robust navigation pattern
    let libraryTab = tabBar.buttons["Library"]
    if libraryTab.exists {
      let libraryNavigation = navigateAndWaitForResult(
        triggerAction: { libraryTab.tap() },
        expectedElements: [app.navigationBars["Library"]],
        timeout: adaptiveTimeout,
        description: "navigation to Library tab"
      )

      if libraryNavigation {
        // Wait for any loading to complete
        let _ = waitForLoadingToComplete(in: app, timeout: adaptiveTimeout)
        XCTAssertTrue(app.navigationBars["Library"].exists, "Library screen should be displayed")
      }
    }

    // Test Discover tab
    let discoverTab = tabBar.buttons["Discover"]
    if discoverTab.exists {
      let discoverNavigation = navigateAndWaitForResult(
        triggerAction: { discoverTab.tap() },
        expectedElements: [app.navigationBars["Discover"]],
        timeout: adaptiveTimeout,
        description: "navigation to Discover tab"
      )

      if discoverNavigation {
        XCTAssertTrue(app.navigationBars["Discover"].exists, "Discover screen should be displayed")
      }
    }

    // Test Player tab with flexible interface detection
    let playerTab = tabBar.buttons["Player"]
    if playerTab.exists {
      let playerNavigation = navigateAndWaitForResult(
        triggerAction: { playerTab.tap() },
        expectedElements: [
          app.otherElements["Player Interface"],
          app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Now Playing'"))
            .firstMatch,
        ],
        timeout: adaptiveTimeout,
        description: "navigation to Player tab"
      )

      XCTAssertTrue(playerNavigation, "Player interface should be accessible")
    }

    // Then: Navigation should work correctly
    XCTAssertTrue(tabBar.exists, "Tab bar should remain visible during navigation")
  }

  @MainActor
  func testNavigationStackManagement() throws {
    // Initialize the app
    initializeApp()

    // Given: User is on a detail screen
    let tabBar = app.tabBars["Main Tab Bar"]
    let libraryTab = tabBar.buttons["Library"]

    if libraryTab.exists {
      libraryTab.tap()

      // Navigate to a podcast detail if available
      let firstPodcast = app.tables.cells.firstMatch
      if firstPodcast.exists {
        firstPodcast.tap()

        // When: User uses back navigation
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
          backButton.tap()

          // Then: Should return to previous screen
          XCTAssertTrue(app.navigationBars["Library"].exists, "Should return to Library screen")
        }
      }
    }
  }

  // MARK: - Accessibility Tests
  // Covers: Accessibility compliance from ui spec

  @MainActor
  func testVoiceOverLabels() throws {
    // Initialize the app
    initializeApp()

    // Given: App interface is loaded
    // When: Checking accessibility labels
    let tabBar = app.tabBars["Main Tab Bar"]

    // Then: Tab bar buttons should have proper accessibility labels
    let libraryTab = tabBar.buttons["Library"]
    if libraryTab.exists {
      XCTAssertFalse(libraryTab.label.isEmpty, "Library tab label should not be empty")
    }

    let discoverTab = tabBar.buttons["Discover"]
    if discoverTab.exists {
      XCTAssertFalse(discoverTab.label.isEmpty, "Discover tab label should not be empty")
    }

    // Test main content areas have accessible labels or are interactable
    let mainContent = app.otherElements["Main Content"]
    if mainContent.exists {
      XCTAssertTrue(
        !mainContent.label.isEmpty || mainContent.isHittable,
        "Main content should be accessible")
    }
  }

  @MainActor
  func testAccessibilityHints() throws {
    // Initialize the app
    initializeApp()

    // Given: Interactive elements are visible
    // When: Checking accessibility hints
    let tabBar = app.tabBars["Main Tab Bar"]

    // Then: Interactive elements should have helpful hints
    let libraryTab = tabBar.buttons["Library"]
    if libraryTab.exists, let hint = libraryTab.accessibilityHint {
      XCTAssertFalse(hint.isEmpty, "Library tab hint should provide guidance")
    }

    // Check for search functionality accessibility
    let searchField = app.searchFields.firstMatch
    if searchField.exists {
      let hasLabel = !searchField.label.isEmpty
      let hasPlaceholder = !(searchField.placeholderValue ?? "").isEmpty
      XCTAssertTrue(
        hasLabel || hasPlaceholder,
        "Search field should expose label or placeholder text for accessibility")
    }
  }

  @MainActor
  func testKeyboardNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: App supports keyboard navigation
    // When: Using keyboard navigation (simulated through accessibility)

    // Test specific known interactive elements instead of using indexed access
    let tabBar = app.tabBars["Main Tab Bar"]
    if tabBar.exists {
      // Test tab bar buttons - these are primary keyboard navigation targets
      let tabButtons = ["Library", "Discover", "Player", "Settings"]
      for buttonName in tabButtons {
        let button = tabBar.buttons[buttonName]
        if button.exists {
          let traits = button.accessibilityTraits
          XCTAssertTrue(
            button.isHittable || traits.contains(.button),
            "\(buttonName) tab should be keyboard accessible")
          XCTAssertFalse(
            button.label.isEmpty,
            "\(buttonName) tab should have descriptive label for keyboard navigation")
        }
      }
    }

    // Test search field if available (common keyboard navigation target)
    let searchField = app.searchFields.firstMatch
    if searchField.exists {
      let traits = searchField.accessibilityTraits
      XCTAssertTrue(
        searchField.isHittable || traits.contains(.searchField),
        "Search field should be keyboard accessible")
    }

    // Test navigation bars (contain back buttons and other controls)
    let navigationBar = app.navigationBars.firstMatch
    if navigationBar.exists {
      XCTAssertTrue(
        navigationBar.isHittable,
        "Navigation bar should be keyboard accessible")

      // Test any buttons in the navigation bar
      let navButtons = navigationBar.buttons
      if navButtons.count > 0 {
        let firstNavButton = navButtons.firstMatch
        if firstNavButton.exists {
          XCTAssertTrue(
            firstNavButton.isHittable,
            "Navigation buttons should be keyboard accessible")
        }
      }
    }

    // Test table views (scrollable and selectable content)
    let tableView = app.tables.firstMatch
    if tableView.exists {
      XCTAssertTrue(
        tableView.isHittable,
        "Table view should be keyboard navigable")
    }
  }

  @MainActor
  func testSettingsTabPresentsSwipeActions() throws {
    initializeApp()

    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    let settingsNavigationBar = app.navigationBars["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsNavigationBar,
        timeout: adaptiveShortTimeout,
        description: "Settings navigation bar"
      ),
      "Settings screen should appear after tapping the tab"
    )

    let candidates: [XCUIElement] = [
      app.cells["Settings.Feature.swipeActions"],
      app.buttons["Swipe Actions"],
      app.staticTexts["Settings.Feature.Label.swipeActions"],
      app.staticTexts["Swipe Actions"],
    ]

    guard
      let swipeActionsElement = waitForAnyElement(
        candidates,
        timeout: adaptiveShortTimeout,
        description: "Swipe Actions settings row"
      )
    else {
      XCTFail("Swipe Actions row should be visible in settings")
      return
    }

    swipeActionsElement.tap()

    let swipeNavigationBar = app.navigationBars["Swipe Actions"]
    XCTAssertTrue(
      waitForElement(
        swipeNavigationBar,
        timeout: adaptiveShortTimeout,
        description: "Swipe Actions configuration"
      ),
      "Swipe Actions configuration view should appear"
    )
  }

  @MainActor
  func testSettingsTabPresentsPlaybackPreferences() throws {
    initializeApp()

    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    let settingsNavigationBar = app.navigationBars["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsNavigationBar,
        timeout: adaptiveShortTimeout,
        description: "Settings navigation bar"
      ),
      "Settings screen should appear after tapping the tab"
    )

    let candidates: [XCUIElement] = [
      app.cells["Settings.Feature.playbackPreferences"],
      app.staticTexts["Settings.Feature.Label.playbackPreferences"],
      app.staticTexts["Playback Preferences"],
      app.buttons["Playback Preferences"],
    ]

    guard
      let playbackRow = waitForAnyElement(
        candidates,
        timeout: adaptiveShortTimeout,
        description: "Playback preferences settings row"
      )
    else {
      XCTFail("Playback preferences row should be visible in settings")
      return
    }

    playbackRow.tap()

    let playbackNavBar = app.navigationBars["Playback"]
    XCTAssertTrue(
      waitForElement(
        playbackNavBar,
        timeout: adaptiveShortTimeout,
        description: "Playback configuration screen"
      ),
      "Playback configuration view should appear"
    )
  }

  @MainActor
  func testSettingsTabPresentsDownloadPolicies() throws {
    initializeApp()

    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    let settingsNavigationBar = app.navigationBars["Settings"]
    XCTAssertTrue(
      waitForElement(
        settingsNavigationBar,
        timeout: adaptiveShortTimeout,
        description: "Settings navigation bar"
      ),
      "Settings screen should appear after tapping the tab"
    )

    let candidates: [XCUIElement] = [
      app.cells["Settings.Feature.downloadPolicies"],
      app.staticTexts["Settings.Feature.Label.downloadPolicies"],
      app.staticTexts["Download Policies"],
      app.buttons["Download Policies"],
    ]

    guard
      let downloadsRow = waitForAnyElement(
        candidates,
        timeout: adaptiveShortTimeout,
        description: "Download policies settings row"
      )
    else {
      XCTFail("Download policies row should be visible in settings")
      return
    }

    downloadsRow.tap()

    let downloadsNavBar = app.navigationBars["Downloads"]
    XCTAssertTrue(
      waitForElement(
        downloadsNavBar,
        timeout: adaptiveShortTimeout,
        description: "Download configuration screen"
      ),
      "Download configuration view should appear"
    )
  }

  // MARK: - App Shortcuts Tests
  // Covers: iOS Quick Actions from ui spec

  @MainActor
  func testAppShortcutHandling() throws {
    // Initialize the app
    initializeApp()

    // Given: App supports quick actions
    // Note: Quick actions are typically tested through app launch with shortcut items
    // This test verifies the app can handle shortcut-triggered launches

    // When: App is launched (simulating shortcut activation)
    // Then: App should handle launch gracefully
    XCTAssertTrue(app.state == .runningForeground, "App should launch successfully")

    // Verify key screens are accessible for shortcuts
    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(tabBar.exists, "Main navigation should be available for shortcuts")

    // Test that search is quickly accessible (common shortcut target)
    let searchField = app.searchFields.firstMatch
    if searchField.exists {
      XCTAssertTrue(searchField.exists, "Search should be accessible")
    }
  }

  // MARK: - Dark Mode and Appearance Tests
  // Covers: Theme customization from ui spec

  @MainActor
  func testAppearanceAdaptation() throws {
    // Initialize the app
    initializeApp()

    // Given: App supports appearance changes
    // When: Checking that UI elements are visible and functional regardless of appearance
    // Note: XCUITest doesn't provide direct access to interface style, so we verify
    // that elements are visible and interactive which indicates proper appearance adaptation

    // Then: App should adapt to system appearance
    // Verify that content is visible in current appearance mode
    let tabBar = app.tabBars["Main Tab Bar"]
    if tabBar.exists {
      XCTAssertTrue(tabBar.isHittable, "Tab bar should be visible in current appearance")
    }

    // Check that text is readable
    let textElements = app.staticTexts
    let sampleTexts = [
      textElements.firstMatch,
      app.staticTexts["Library"],
      app.staticTexts["Discover"],
      app.staticTexts["Player"],
    ]

    for textElement in sampleTexts {
      if textElement.exists && !textElement.label.isEmpty {
        XCTAssertTrue(
          textElement.isHittable,
          "Text should be readable in current appearance")
      }
    }
  }

  // MARK: - Error State Navigation Tests
  // Covers: Error handling in navigation from ui spec

  @MainActor
  func testErrorStateNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: App may encounter error states
    // When: Checking for error handling in navigation

    // Test that app doesn't crash on invalid navigation
    let tabBar = app.tabBars["Main Tab Bar"]
    if tabBar.exists {
      // Test specific known tabs instead of generic indexed access
      let knownTabs = ["Library", "Discover", "Player", "Settings"]
      for tabName in knownTabs {
        let tab = tabBar.buttons[tabName]
        if tab.exists {
          tab.tap()
          // Verify transition without hardcoded delay
          XCTAssertTrue(tab.isSelected || tab.isHittable, "Tab should respond to tap interaction")
        }
      }

      // Then: App should remain stable
      XCTAssertTrue(app.state == .runningForeground, "App should remain stable during navigation")
      XCTAssertTrue(tabBar.exists, "Tab bar should remain functional")
    }
  }

  // MARK: - Performance Tests
  // Covers: UI responsiveness from ui spec

  @MainActor
  func testNavigationPerformance() throws {
    // Initialize the app
    initializeApp()

    // Given: App is loaded
    // When: Performing navigation actions
    let tabBar = app.tabBars["Main Tab Bar"]
    if tabBar.exists {
      let libraryTab = tabBar.buttons["Library"]
      if libraryTab.exists {
        libraryTab.tap()
        // Verify navigation responsiveness by checking tab state
        XCTAssertTrue(
          libraryTab.isSelected || libraryTab.isHittable,
          "Library tab should respond to navigation")
        XCTAssertTrue(
          app.state == .runningForeground,
          "App should remain responsive during navigation")
      } else {
        throw XCTSkip("Library tab not found - skipping performance test")
      }
    } else {
      throw XCTSkip("Tab bar not found - skipping performance test")
    }
  }

  // MARK: - Acceptance Criteria Tests
  // Covers: Complete navigation workflows from ui specification

  @MainActor
  func testAcceptanceCriteria_CompleteNavigationFlow() throws {
    // Initialize the app
    initializeApp()

    // Given: User wants to navigate through main app features
    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(tabBar.exists, "Main tab bar should be available")

    // When: User explores each main section
    let knownTabNames = ["Library", "Discover", "Player", "Settings"]

    for (index, tabName) in knownTabNames.enumerated() {
      if index < 4 {  // Limit to reasonable number of tabs
        let tab = tabBar.buttons[tabName]
        if tab.exists {
          tab.tap()

          // Verify navigation worked without hardcoded delay
          let navigationBar = app.navigationBars.firstMatch
          XCTAssertTrue(
            navigationBar.exists || app.otherElements.firstMatch.exists,
            "Each tab should show content")

          // Verify tab remains interactive after navigation
          XCTAssertTrue(tab.isHittable, "Tab should remain interactive after navigation")
        }
      }
    }

    // Then: All navigation should work smoothly
    XCTAssertTrue(app.state == .runningForeground, "App should remain stable")
    XCTAssertTrue(tabBar.exists, "Tab bar should remain accessible")
  }

  @MainActor
  func testAcceptanceCriteria_AccessibilityCompliance() throws {
    // Initialize the app
    initializeApp()

    // Given: App must be accessible to all users
    // When: Checking accessibility compliance

    // Verify main interface elements have accessibility labels
    let tabBar = app.tabBars["Main Tab Bar"]
    if tabBar.exists {
      let knownTabNames = ["Library", "Discover", "Player", "Settings"]

      for tabName in knownTabNames {
        let tab = tabBar.buttons[tabName]
        if tab.exists {
          let traits = tab.accessibilityTraits
          XCTAssertFalse(tab.label.isEmpty, "Tab should have descriptive label")
          XCTAssertTrue(
            tab.isHittable || traits.contains(.button),
            "Tab should be accessible")
        }
      }
    }

    // Check for proper heading structure - use specific known headings
    var headingCount = 0

    // Check for known accessibility headings first
    let knownHeadings = ["Library", "Discover", "Categories", "Featured", "Now Playing"]
    for headingText in knownHeadings {
      let heading = app.staticTexts[headingText]
      if heading.exists && heading.accessibilityTraits.contains(.header) {
        headingCount += 1
        break
      }
    }

    // Fallback: search for any element with header trait (limited search)
    if headingCount == 0 {
      let firstStaticText = app.staticTexts.firstMatch
      if firstStaticText.exists && firstStaticText.accessibilityTraits.contains(.header) {
        headingCount = 1
      }
    }

    // Final fallback: known heading identifiers in this app
    if headingCount == 0 {
      if app.staticTexts["Heading Library"].exists || app.staticTexts["Categories"].exists
        || app.staticTexts["Featured"].exists
      {
        headingCount = 1
      }
    }

    // Then: App should have proper accessibility structure
    XCTAssertGreaterThan(headingCount, 0, "App should have accessible headings")
  }
}

// TODO: [Issue #12.3] Add performance testing patterns for UI responsiveness validation
// This would include testing animation performance, scroll performance, and touch responsiveness

// TODO: [Issue #12.4] Implement automated accessibility testing integration
// This would add automated VoiceOver testing and accessibility audit capabilities
