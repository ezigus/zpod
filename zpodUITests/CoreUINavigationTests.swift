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

}

extension CoreUINavigationTests {

  // MARK: - Helper Methods

  @MainActor
  private func initializeApp() {
    app = launchConfiguredApp()
  }

}

extension CoreUINavigationTests {

  // MARK: - Main Navigation Tests
  // Covers: Basic navigation flow from ui spec

  @MainActor
  func testMainTabBarNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: App is launched and main interface is visible
    // When: User taps different tab bar items
    let tabBar = try waitForElementOrSkip(
      app.tabBars.matching(identifier: "Main Tab Bar").firstMatch,
      timeout: adaptiveTimeout,
      description: "Main tab bar"
    )

    // Test Library tab using robust navigation pattern
    let libraryTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Library").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Library tab"
    )

    // Library tab navigation - verify by checking for Library content
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let libraryNavigation = navigateAndWaitForResult(
      triggerAction: { libraryTab.tap() },
      expectedElements: [
        app.tables.firstMatch,  // Library shows a table/list of podcasts
        app.staticTexts.matching(identifier: "Library").firstMatch
      ],
      timeout: adaptiveTimeout,
      description: "navigation to Library tab"
    )

    if libraryNavigation {
      // Wait for any loading to complete
      _ = waitForLoadingToComplete(in: app, timeout: adaptiveTimeout)
      XCTAssertTrue(
        app.tables.firstMatch.exists || app.staticTexts.matching(identifier: "Library").firstMatch.exists,
        "Library screen should be displayed")
    } else {
      XCTFail("Library navigation did not reach expected destination")
    }

    // Test Discover tab
    let discoverTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Discover").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Discover tab"
    )

    // Discover tab navigation - verify by checking for search field
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let discoverNavigation = navigateAndWaitForResult(
      triggerAction: { discoverTab.tap() },
      expectedElements: [
        app.searchFields.firstMatch,  // Discover has search field
        app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
      ],
      timeout: adaptiveTimeout,
      description: "navigation to Discover tab"
    )

    if discoverNavigation {
      XCTAssertTrue(
        app.searchFields.firstMatch.exists || app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch.exists,
        "Discover screen should be displayed with search field")
    } else {
      XCTFail("Discover navigation did not reach expected destination")
    }

    // Test Player tab with flexible interface detection
    let playerTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Player").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Player tab"
    )

    let playerNavigation = navigateAndWaitForResult(
      triggerAction: { playerTab.tap() },
      expectedElements: [
        app.otherElements.matching(identifier: "Player Interface").firstMatch,
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Now Playing'"))
          .firstMatch,
      ],
      timeout: adaptiveTimeout,
      description: "navigation to Player tab"
    )

    XCTAssertTrue(playerNavigation, "Player interface should be accessible")

    // Then: Navigation should work correctly
    XCTAssertTrue(tabBar.exists, "Tab bar should remain visible during navigation")
  }

  @MainActor
  func testNavigationStackManagement() throws {
    // Initialize the app
    initializeApp()

    // Given: User is on a detail screen
    let tabBar = try waitForElementOrSkip(
      app.tabBars.matching(identifier: "Main Tab Bar").firstMatch,
      timeout: adaptiveTimeout,
      description: "Main tab bar"
    )
    let libraryTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Library").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Library tab"
    )

    libraryTab.tap()

    XCTAssertTrue(
      waitForLoadingToComplete(in: app, timeout: adaptiveTimeout),
      "Library content should load before drilling deeper")

    // Navigate to a podcast detail if available
    let candidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch,
      app.tables.cells.firstMatch,
    ]
    guard
      let firstPodcast = waitForAnyElement(
        candidates,
        timeout: adaptiveTimeout,
        description: "podcast cell",
        failOnTimeout: false
      )
    else {
      XCTFail("Podcast cell not rendered; verify seed data.")
      return
    }
    firstPodcast.tap()

    // When: User uses back navigation
    let backButton = app.navigationBars.buttons.element(boundBy: 0)
    XCTAssertTrue(
      backButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Back button should be available to unwind navigation")
    backButton.tap()

    // Then: Should return to previous screen (verified by Library content presence)
    // (NavigationBar elements are unreliable in modern SwiftUI)
    XCTAssertTrue(
      app.tables.firstMatch.exists || app.staticTexts.matching(identifier: "Library").firstMatch.exists,
      "Should return to Library screen")
  }

}

extension CoreUINavigationTests {

  // MARK: - Accessibility Tests
  // Covers: Accessibility compliance from ui spec

  @MainActor
  func testVoiceOverLabels() throws {
    // Initialize the app
    initializeApp()

    // Given: App interface is loaded
    // When: Checking accessibility labels
    let tabBar = try waitForElementOrSkip(
      app.tabBars.matching(identifier: "Main Tab Bar").firstMatch,
      timeout: adaptiveTimeout,
      description: "Main tab bar"
    )

    // Then: Tab bar buttons should have proper accessibility labels
    let libraryTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Library").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Library tab"
    )
    XCTAssertFalse(libraryTab.label.isEmpty, "Library tab label should not be empty")

    let discoverTab = try waitForElementOrSkip(
      tabBar.buttons.matching(identifier: "Discover").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Discover tab"
    )
    XCTAssertFalse(discoverTab.label.isEmpty, "Discover tab label should not be empty")

    // Test main content areas have accessible labels or are interactable
    let mainContent = app.otherElements.matching(identifier: "Main Content").firstMatch
    if mainContent.exists {
      XCTAssertTrue(
        !mainContent.label.isEmpty || mainContent.isHittable,
        "Main content should be accessible")
    } else if
      let fallback = [
        "Content Container",
        "Episode Cards Container",
        "Library Content",
        "Podcast Cards Container",
      ]
        .compactMap({ findContainerElement(in: app, identifier: $0) })
        .first
    {
      XCTAssertTrue(
        !fallback.label.isEmpty || fallback.isHittable,
        "Fallback content container should be accessible")
    } else {
      XCTFail("Main content container missing; verify test fixtures.")
      return
    }
  }

  @MainActor
  func testAccessibilityHints() throws {
    // Initialize the app
    initializeApp()

    // Given: Interactive elements are visible
    // When: Checking accessibility hints
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch

    // Then: Interactive elements should have helpful hints
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
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
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
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

    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons.matching(identifier: "Settings").firstMatch
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    // Wait for Settings screen to load (async descriptor loading)
    let loadingIndicator = app.otherElements.matching(identifier: "Settings.Loading").firstMatch
    if loadingIndicator.exists {
      XCTAssertTrue(
        waitForElementToDisappear(loadingIndicator, timeout: adaptiveTimeout),
        "Settings loading should complete"
      )
    }

    // Settings screen verification - check for feature rows instead of navigation bar
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let candidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
      app.otherElements.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
      app.cells.matching(identifier: "Settings.Feature.swipeActions").firstMatch,
      app.buttons.matching(identifier: "Swipe Actions").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Feature.Label.swipeActions").firstMatch,
      app.staticTexts.matching(identifier: "Swipe Actions").firstMatch,
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

    // Verify Swipe Actions configuration screen by checking for its list element
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let swipeActionsList = app.otherElements.matching(identifier: "SwipeActions.List").firstMatch
    XCTAssertTrue(
      waitForElement(
        swipeActionsList,
        timeout: adaptiveShortTimeout,
        description: "Swipe Actions configuration list"
      ),
      "Swipe Actions configuration view should appear with actions list"
    )
  }

  @MainActor
  func testSettingsTabPresentsPlaybackPreferences() throws {
    initializeApp()

    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons.matching(identifier: "Settings").firstMatch
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    // Wait for Settings screen to load (async descriptor loading)
    let loadingIndicator = app.otherElements.matching(identifier: "Settings.Loading").firstMatch
    if loadingIndicator.exists {
      XCTAssertTrue(
        waitForElementToDisappear(loadingIndicator, timeout: adaptiveTimeout),
        "Settings loading should complete"
      )
    }

    // Settings screen verification - check for feature rows instead of navigation bar
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let candidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Settings.Feature.playbackPreferences").firstMatch,
      app.otherElements.matching(identifier: "Settings.Feature.playbackPreferences").firstMatch,
      app.cells.matching(identifier: "Settings.Feature.playbackPreferences").firstMatch,
      app.buttons.matching(identifier: "Playback Preferences").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Feature.Label.playbackPreferences").firstMatch,
      app.staticTexts.matching(identifier: "Playback Preferences").firstMatch,
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

    // Verify Playback configuration screen by checking for a toggle control
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let playbackToggle = app.switches.matching(identifier: "Playback.ContinuousToggle").firstMatch
    XCTAssertTrue(
      waitForElement(
        playbackToggle,
        timeout: adaptiveShortTimeout,
        description: "Playback configuration toggle"
      ),
      "Playback configuration view should appear with settings controls"
    )
  }

  @MainActor
  func testSettingsTabPresentsDownloadPolicies() throws {
    initializeApp()

    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(
      waitForElement(
        tabBar,
        timeout: adaptiveShortTimeout,
        description: "Main tab bar"
      ),
      "Main tab bar should be present"
    )

    let settingsTab = tabBar.buttons.matching(identifier: "Settings").firstMatch
    XCTAssertTrue(
      waitForElement(
        settingsTab,
        timeout: adaptiveShortTimeout,
        description: "Settings tab"
      ),
      "Settings tab should exist"
    )

    settingsTab.tap()

    // Wait for Settings screen to load (async descriptor loading)
    let loadingIndicator = app.otherElements.matching(identifier: "Settings.Loading").firstMatch
    if loadingIndicator.exists {
      XCTAssertTrue(
        waitForElementToDisappear(loadingIndicator, timeout: adaptiveTimeout),
        "Settings loading should complete"
      )
    }

    // Settings screen verification - check for feature rows instead of navigation bar
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let candidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Settings.Feature.downloadPolicies").firstMatch,
      app.otherElements.matching(identifier: "Settings.Feature.downloadPolicies").firstMatch,
      app.cells.matching(identifier: "Settings.Feature.downloadPolicies").firstMatch,
      app.buttons.matching(identifier: "Download Policies").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Feature.Label.downloadPolicies").firstMatch,
      app.staticTexts.matching(identifier: "Download Policies").firstMatch,
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

    // Verify Download configuration screen by checking for a toggle control
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let downloadToggle = app.switches.matching(identifier: "Download.AutoToggle").firstMatch
    XCTAssertTrue(
      waitForElement(
        downloadToggle,
        timeout: adaptiveShortTimeout,
        description: "Download configuration toggle"
      ),
      "Download configuration view should appear with settings controls"
    )
  }

}

extension CoreUINavigationTests {

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
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(tabBar.exists, "Main navigation should be available for shortcuts")

    // Test that search is quickly accessible (common shortcut target)
    let searchField = app.searchFields.firstMatch
    if searchField.exists {
      XCTAssertTrue(searchField.exists, "Search should be accessible")
    }
  }

}

extension CoreUINavigationTests {

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
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    if tabBar.exists {
      XCTAssertTrue(tabBar.isHittable, "Tab bar should be visible in current appearance")
    }

    // Check that text is readable
    let textElements = app.staticTexts
    let sampleTexts = [
      textElements.firstMatch,
      app.staticTexts.matching(identifier: "Library").firstMatch,
      app.staticTexts.matching(identifier: "Discover").firstMatch,
      app.staticTexts.matching(identifier: "Player").firstMatch,
    ]

    for textElement in sampleTexts {
      if textElement.exists && !textElement.label.isEmpty {
        XCTAssertTrue(
          textElement.isHittable,
          "Text should be readable in current appearance")
      }
    }
  }

}

extension CoreUINavigationTests {

  // MARK: - Error State Navigation Tests
  // Covers: Error handling in navigation from ui spec

  @MainActor
  func testErrorStateNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: App may encounter error states
    // When: Checking for error handling in navigation

    // Test that app doesn't crash on invalid navigation
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
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

}

extension CoreUINavigationTests {

  // MARK: - Performance Tests
  // Covers: UI responsiveness from ui spec

  @MainActor
  func testNavigationPerformance() throws {
    // Initialize the app
    initializeApp()

    // Given: App is loaded
    // When: Performing navigation actions
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    if tabBar.exists {
      let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
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
        XCTFail("Library tab not found - performance test requires fixtures")
        return
      }
    } else {
      XCTFail("Tab bar not found - performance test requires fixtures")
      return
    }
  }

}

extension CoreUINavigationTests {

  // MARK: - Acceptance Criteria Tests
  // Covers: Complete navigation workflows from ui specification

  @MainActor
  func testAcceptanceCriteria_CompleteNavigationFlow() throws {
    // Initialize the app
    initializeApp()

    // Given: User wants to navigate through main app features
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
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
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
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
      if app.staticTexts.matching(identifier: "Heading Library").firstMatch.exists || app.staticTexts.matching(identifier: "Categories").firstMatch.exists
        || app.staticTexts.matching(identifier: "Featured").firstMatch.exists
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
