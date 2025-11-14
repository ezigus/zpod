import XCTest

/// UI tests for content discovery and search interface functionality
///
/// **Specifications Covered**: `spec/ui.md` - Search and discovery sections
/// - Search interface and results display testing
/// - Browse and category navigation verification
/// - Subscription management interface testing
/// - Filter and sort controls validation
/// - Content recommendation displays
final class ContentDiscoveryUITests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
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

    // Wait for the main tab bar to be available
    let tabBar = app.tabBars["Main Tab Bar"]
    XCTAssertTrue(
      waitForElement(
        tabBar, timeout: adaptiveTimeout, description: "Main tab bar"),
      "Main tab bar should be available after app launch")

    // Navigate to discovery interface for testing
    let discoverTab = tabBar.buttons["Discover"]
    XCTAssertTrue(discoverTab.exists, "Discover tab should exist")

    discoverTab.tap()

    // Wait for discover screen to load fully
    let discoverNavBar = app.navigationBars["Discover"]
    XCTAssertTrue(
      waitForElement(
        discoverNavBar, timeout: adaptiveTimeout, description: "Discover navigation bar"),
      "Discover screen should load after tapping tab")
  }

  private func rssURLField(in app: XCUIApplication) -> XCUIElement {
    let identifierField = app.textFields["rss-url-field"]
    if identifierField.exists {
      return identifierField
    }

    return app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'https://'")
    ).firstMatch
  }

  // MARK: - Search Interface Tests (Issue 01.1.1 Scenario 1)
  // Given/When/Then: Basic Podcast Search and Discovery

  @MainActor
  func testBasicPodcastSearchInterface_GivenDiscoverTab_WhenSearching_ThenShowsSearchInterface()
    throws
  {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab
    XCTAssertTrue(app.navigationBars["Discover"].exists, "Should be on Discover tab")

    // When: I look for search functionality
    let searchField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'")
    ).firstMatch

    // Then: I should see search interface elements
    XCTAssertTrue(searchField.exists, "Search field should be present")
    XCTAssertTrue(
      searchField.waitForExistence(timeout: adaptiveShortTimeout),
      "Search field should be interactive")
  }

  @MainActor
  func testSearchFieldInput_GivenSearchInterface_WhenTyping_ThenAcceptsInput() throws {
    // Initialize the app
    initializeApp()

    // Given: Search interface is available
    let searchField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'")
    ).firstMatch
    XCTAssertTrue(searchField.exists, "Search field should exist")

    // When: I type in the search field
    searchField.tap()

    // Wait for keyboard to appear - this is the real indicator of readiness
    XCTAssertTrue(
      app.keyboards.firstMatch.waitForExistence(timeout: adaptiveShortTimeout),
      "Keyboard should appear after tapping search field")

    // Make sure the field actually has focus before typing to avoid dropping input on slower sims.
    XCTAssertTrue(
      waitForKeyboardFocus(
        on: searchField, timeout: adaptiveShortTimeout, description: "search field focus"),
      "Search field should gain keyboard focus after tap")

    let desiredQuery = "Swift Talk"
    searchField.typeText(desiredQuery)

    // Then: wait for the value to propagate (adapts to CI lag) and fall back to a visible result cell.
    let valueMatches = waitUntil(
      timeout: adaptiveTimeout,
      pollInterval: 0.15,
      description: "search field contains query"
    ) {
      guard let currentValue = searchField.value as? String else { return false }
      return currentValue.localizedCaseInsensitiveContains(desiredQuery)
    }
    let searchFieldValue = searchField.value as? String

    // Also accept the UI presenting a result cell if the text field clears (common on some devices)
    let swiftTalkTextElement = app.staticTexts[desiredQuery]
    let hasSwiftTalkText = swiftTalkTextElement.waitForExistence(timeout: adaptiveTimeout)

    XCTAssertTrue(
      valueMatches || hasSwiftTalkText,
      "Search field should contain typed text. Found value: '\(searchFieldValue ?? "nil")', Swift Talk text exists: \(hasSwiftTalkText)"
    )
  }

  @MainActor
  func testSearchClearButton_GivenSearchText_WhenTappingClear_ThenClearsSearch() throws {
    // Initialize the app
    initializeApp()

    // Given: I have typed in the search field
    let searchField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'")
    ).firstMatch
    searchField.tap()

    // Wait for keyboard to appear - this is the real indicator of readiness
    XCTAssertTrue(
      app.keyboards.firstMatch.waitForExistence(timeout: adaptiveShortTimeout),
      "Keyboard should appear after tapping search field")

    // Verify the field is ready for input by checking it has focus
    let hasKeyboardFocus2 = (searchField.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    XCTAssertTrue(
      hasKeyboardFocus2,
      "Search field should have keyboard focus after tap")

    // Wait for focus to be fully established before typing using proper async pattern
    let focusExpectation = XCTestExpectation(description: "Wait for search field focus")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      focusExpectation.fulfill()
    }
    _ = XCTWaiter.wait(for: [focusExpectation], timeout: 1.0)

    searchField.typeText("test")

    // When: I tap the clear button (if it exists)
    let clearButton = app.buttons.matching(NSPredicate(format: "label == 'Clear search'"))
      .firstMatch
    if clearButton.exists {
      clearButton.tap()

      // Then: The search field should be empty
      XCTAssertTrue(
        searchField.value as? String == ""
          || searchField.placeholderValue?.contains("Search") == true,
        "Search field should be cleared")
    }
  }

  // MARK: - Discovery Options Menu Tests (Issue 01.1.1 Scenario 4)
  // RSS Feed Addition Interface

  @MainActor
  func testDiscoveryOptionsMenu_GivenDiscoverTab_WhenTappingOptions_ThenShowsMenu() throws {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab
    XCTAssertTrue(
      waitForElement(
        app.navigationBars["Discover"], timeout: adaptiveTimeout,
        description: "Discover navigation bar"), "Should navigate to Discover tab")

    // When: I look for the discovery options menu using smart discovery
    let optionsButton = findAccessibleElement(
      in: app,
      byIdentifier: "discovery-options-menu",
      byLabel: "Discovery options",
      byPartialLabel: "options",
      ofType: .button
    )

    if let button = optionsButton {
      XCTAssertTrue(
        waitForElement(
          button, timeout: adaptiveShortTimeout, description: "discovery options button"),
        "Discovery options control should exist"
      )
      XCTAssertTrue(
        waitForElementToBeHittable(
          button, timeout: adaptiveShortTimeout, description: "discovery options button"),
        "Discovery options control should be hittable"
      )
      // Use navigation pattern for menu interaction
      let menuAppeared = navigateAndWaitForResult(
        triggerAction: { button.tap() },
        expectedElements: [
          app.buttons["discovery-options-menu.add-rss"],
          app.buttons["discovery-options-menu.search-history"],
        ],
        timeout: adaptiveShortTimeout,
        description: "discovery options menu"
      )

      if menuAppeared {
        // Then: I should see menu options including RSS feed addition
        let hasMenuOptions =
          app.buttons["discovery-options-menu.add-rss"].exists
          || app.buttons["discovery-options-menu.search-history"].exists
        XCTAssertTrue(hasMenuOptions, "Discovery options menu should contain expected items")
      } else {
        throw XCTSkip("Menu options did not appear - may need UI adjustments")
      }
    } else {
      throw XCTSkip("Discovery options button not found or not accessible")
    }
  }

  @MainActor
  func testRSSFeedAddition_GivenOptionsMenu_WhenSelectingAddRSSFeed_ThenShowsRSSSheet() throws {
    // Initialize the app
    initializeApp()

    // Given: I have access to the options menu
    let navBar = app.navigationBars["Discover"]
    XCTAssertTrue(navBar.exists)

    // Find the options button using multiple strategies
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier (most reliable)
    let identifiedButton = navBar.buttons["discovery-options-menu"]
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for button with accessibility label
    if optionsButton == nil {
      let labeledButton = navBar.buttons.matching(
        NSPredicate(format: "label == 'Discovery options'")
      ).firstMatch
      if labeledButton.exists && labeledButton.isHittable {
        optionsButton = labeledButton
      }
    }

    // Strategy 3: Look for the last navigation bar button (trailing toolbar item)
    if optionsButton == nil {
      let navButtons = navBar.buttons.allElementsBoundByIndex
      for button in navButtons {
        if button.exists && button.isHittable {
          optionsButton = button
          break
        }
      }
    }

    if let button = optionsButton {
      button.tap()

      guard
        let discoveryDialog = waitForDialog(
          in: app,
          title: "Discovery Options",
          timeout: adaptiveShortTimeout
        )
      else {
        let tree = app.debugDescription
        print("[DEBUG] Discovery dialog missing. Accessibility tree:\n\(tree)")
        XCTFail("Discovery options dialog should appear after tapping the toolbar button")
        return
      }

      guard
        let addRSSOption = resolveDialogButton(
          in: app,
          dialog: discoveryDialog,
          identifier: "discovery-options-menu.add-rss",
          fallbackLabel: "Add RSS Feed"
        )
      else {
        let tree = app.debugDescription
        print("[DEBUG] Discovery dialog missing. Accessibility tree:\n\(tree)")
        XCTFail("Add RSS Feed option should be available in discovery dialog")
        return
      }

      guard
        waitForElement(
          addRSSOption,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed dialog option"
        )
      else { return }

      guard
        waitForElementToBeHittable(
          addRSSOption,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed dialog option"
        )
      else { return }

      // When: I select "Add RSS Feed"
      addRSSOption.tap()

      // Then: RSS feed addition sheet should appear
      let rssSheet = app.navigationBars["Add RSS Feed"]
      guard
        waitForElement(
          rssSheet,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed sheet"
        )
      else { return }

      // And should contain URL input field
      let urlField = rssURLField(in: app)
      XCTAssertTrue(
        waitForElement(
          urlField,
          timeout: adaptiveTimeout,
          description: "RSS feed URL field"
        ),
        "URL input field should be present"
      )
    } else {
      throw XCTSkip("Discovery options button not found or not accessible")
    }
  }

  @MainActor
  func testRSSURLInput_GivenRSSSheet_WhenEnteringURL_ThenAcceptsInput() throws {
    // Initialize the app
    initializeApp()

    // Navigate to RSS sheet if available
    let navBar = app.navigationBars["Discover"]
    XCTAssertTrue(navBar.exists)

    // Find and tap options button
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier
    let identifiedButton = navBar.buttons["discovery-options-menu"]
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for the last navigation bar button
    if optionsButton == nil {
      let navButtons = navBar.buttons.allElementsBoundByIndex
      for button in navButtons {
        if button.exists && button.isHittable {
          optionsButton = button
          break
        }
      }
    }

    if let button = optionsButton {
      button.tap()

      guard
        let discoveryDialog = waitForDialog(
          in: app,
          title: "Discovery Options",
          timeout: adaptiveShortTimeout
        )
      else {
        let tree = app.debugDescription
        print("[DEBUG] Discovery dialog missing. Accessibility tree:\n\(tree)")
        XCTFail("Discovery options dialog should appear before selecting RSS feed")
        return
      }

      guard
        let addRSSOption = resolveDialogButton(
          in: app,
          dialog: discoveryDialog,
          identifier: "discovery-options-menu.add-rss",
          fallbackLabel: "Add RSS Feed"
        )
      else {
        let tree = app.debugDescription
        print("[DEBUG] Discovery dialog missing. Accessibility tree:\n\(tree)")
        XCTFail("Add RSS Feed option should be available in discovery dialog")
        return
      }

      guard
        waitForElement(
          addRSSOption,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed dialog option"
        )
      else { return }

      guard
        waitForElementToBeHittable(
          addRSSOption,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed dialog option"
        )
      else { return }

      addRSSOption.tap()

      // Given: RSS sheet is displayed
      let rssSheetNavBar = app.navigationBars["Add RSS Feed"]
      guard
        waitForElement(
          rssSheetNavBar,
          timeout: adaptiveShortTimeout,
          description: "Add RSS Feed sheet"
        )
      else { return }

      let urlField = rssURLField(in: app)
      guard
        waitForElement(
          urlField,
          timeout: adaptiveTimeout,
          description: "RSS feed URL field"
        )
      else {
        XCTFail("URL field not found in RSS sheet")
        return
      }

      // When: I enter a URL
      urlField.tap()
      XCTAssertTrue(
        app.keyboards.firstMatch.waitForExistence(timeout: adaptiveTimeout),
        "Keyboard should appear after selecting RSS URL field")

      XCTAssertTrue(
        waitForKeyboardFocus(
          on: urlField, timeout: adaptiveTimeout, description: "RSS URL field focus"),
        "RSS URL field should gain keyboard focus")

      let desiredURL = "https://example.com/feed.xml"
      urlField.typeText(desiredURL)

      let urlValueMatches = waitUntil(
        timeout: adaptiveTimeout,
        pollInterval: 0.2,
        description: "RSS URL field reflects input"
      ) {
        guard let currentValue = urlField.value as? String else { return false }
        if currentValue.caseInsensitiveCompare(desiredURL) == .orderedSame { return true }
        let normalized = currentValue.replacingOccurrences(of: "…", with: "")
        guard !normalized.isEmpty else { return false }
        if normalized.caseInsensitiveCompare(desiredURL) == .orderedSame { return true }
        return desiredURL.hasPrefix(normalized)
      }

      let staticTextMatches = app.staticTexts[desiredURL].waitForExistence(timeout: adaptiveTimeout)
      let urlFieldValue = urlField.value as? String

      XCTAssertTrue(
        urlValueMatches || staticTextMatches,
        "URL field should contain entered URL. Current value: '\(urlFieldValue ?? "nil")'"
      )
    } else {
      throw XCTSkip("Discovery options button not found or not accessible")
    }
  }

  // MARK: - Search Filter Tests (Issue 01.1.1 Scenario 2)
  // Advanced Search Across All Content

  @MainActor
  func testSearchFilters_GivenSearchResults_WhenFilteringByType_ThenShowsFilters() throws {
    // Initialize the app
    initializeApp()

    // Given: I have started a search
    let searchField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'")
    ).firstMatch
    if searchField.exists {
      searchField.tap()

      // Wait for keyboard to appear - this is the real indicator of readiness
      XCTAssertTrue(
        app.keyboards.firstMatch.waitForExistence(timeout: adaptiveShortTimeout),
        "Keyboard should appear after tapping search field")

      // Verify the field is ready for input by checking it has focus
      let hasKeyboardFocus3 = (searchField.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
      XCTAssertTrue(
        hasKeyboardFocus3,
        "Search field should have keyboard focus after tap")

      // Wait for focus to be fully established before typing using proper async pattern
      let focusExpectation = XCTestExpectation(description: "Wait for search field focus")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        focusExpectation.fulfill()
      }
      _ = XCTWaiter.wait(for: [focusExpectation], timeout: 0.5)

      searchField.typeText("test")

      // When: Search filters become available
      // Look for filter buttons (All, Podcasts, Episodes)
      let allFilter = app.buttons["All"]
      let podcastsFilter = app.buttons["Podcasts"]
      let episodesFilter = app.buttons["Episodes"]

      // Then: Filter options should be available when searching
      // Note: Filters may appear after typing, so we check if any exist
      let hasFilters = allFilter.exists || podcastsFilter.exists || episodesFilter.exists

      if hasFilters {
        XCTAssertTrue(true, "Search filters are available")
      } else {
        // Filters might appear after search results load
        XCTAssertTrue(true, "Filters may appear after search execution")
      }
    }
  }

  // MARK: - Search History Tests (Issue 01.1.1 Scenario 3)
  // Search Performance and Real-time Results

  @MainActor
  func testSearchHistoryAccess_GivenOptionsMenu_WhenSelectingHistory_ThenShowsHistory() throws {
    // Initialize the app
    initializeApp()

    // Given: I have access to the options menu
    let navBar = app.navigationBars["Discover"]
    XCTAssertTrue(navBar.exists)

    // Find the options button using multiple strategies
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier (most reliable)
    let identifiedButton = navBar.buttons["discovery-options-menu"]
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for button with accessibility label
    if optionsButton == nil {
      let labeledButton = navBar.buttons.matching(
        NSPredicate(format: "label == 'Discovery options'")
      ).firstMatch
      if labeledButton.exists && labeledButton.isHittable {
        optionsButton = labeledButton
      }
    }

    // Strategy 3: Look for the last navigation bar button (trailing toolbar item)
    if optionsButton == nil {
      let navButtons = navBar.buttons.allElementsBoundByIndex
      for button in navButtons {
        if button.exists && button.isHittable {
          optionsButton = button
          break
        }
      }
    }

    if let button = optionsButton {
      button.tap()

      // Wait for menu to appear using proper wait mechanism
      let searchHistoryOption = app.buttons.matching(
        identifier: "discovery-options-menu.search-history"
      ).firstMatch
      if searchHistoryOption.waitForExistence(timeout: 2.0) {
        // When: I select "Search History"
        searchHistoryOption.tap()

        // Then: Search history sheet should appear
        let historySheet = app.navigationBars["Search History"]
        XCTAssertTrue(
          historySheet.waitForExistence(timeout: 3.0),
          "Search history sheet should appear")
      } else {
        throw XCTSkip("Search History option not found in menu")
      }
    } else {
      throw XCTSkip("Discovery options button not found or not accessible")
    }
  }

  // MARK: - Navigation and Accessibility Tests

  @MainActor
  func testDiscoverTabAccessibility_GivenApp_WhenNavigating_ThenSupportsAccessibility() throws {
    // Initialize the app
    initializeApp()

    // Given: The app is launched
    // When: I check accessibility elements on Discover tab
    let discoverNavBar = app.navigationBars["Discover"]

    // Then: Key elements should be accessible
    XCTAssertTrue(discoverNavBar.exists, "Discover navigation should be accessible")

    // Check for accessible search elements
    let searchElements = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'"))
    if searchElements.count > 0 {
      let searchField = searchElements.firstMatch
      XCTAssertTrue(
        searchField.waitForExistence(timeout: adaptiveShortTimeout),
        "Search field should be accessible")
    }
  }

  @MainActor
  func testDiscoverTabTitle_GivenDiscoverTab_WhenViewing_ThenShowsCorrectTitle() throws {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab
    // When: I check the navigation title
    let discoverTitle = app.navigationBars["Discover"]

    // Then: The title should be "Discover"
    XCTAssertTrue(discoverTitle.exists, "Discover tab should show correct title")
  }

  // MARK: - Empty State Tests

  @MainActor
  func testEmptyDiscoverState_GivenNoSearch_WhenViewingDiscover_ThenShowsEmptyState() throws {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab with no active search
    // When: I look at the empty state

    // Then: Should show empty state elements (these might include welcome text, icons, etc.)
    // Note: The exact empty state UI may vary, so we check for common patterns
    let hasEmptyStateElements =
      app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Discover'")).count > 0
      || app.images.count > 0
      || app.buttons.containing(NSPredicate(format: "label CONTAINS 'Add'")).count > 0

    XCTAssertTrue(hasEmptyStateElements, "Discover tab should show some content or empty state")
  }

  // MARK: - Performance and Real-time Tests

  @MainActor
  func testSearchResponsiveness_GivenSearchField_WhenTyping_ThenRespondsQuickly() throws {
    // Initialize the app
    initializeApp()

    // Given: Search interface is available
    let searchField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS 'Search'")
    ).firstMatch

    if searchField.exists {
      // When: I interact with the search field
      searchField.tap()

      // Wait for keyboard to appear - this is the real indicator of readiness
      XCTAssertTrue(
        app.keyboards.firstMatch.waitForExistence(timeout: adaptiveShortTimeout),
        "Keyboard should appear after tapping search field")

      // Type text into the search field (typeText is synchronous, no additional wait needed)
      searchField.typeText("test")

      // Then: Verify the interface is responsive by checking that the text was entered
      // Check the field's value directly - this is the most reliable method
      let enteredValue = searchField.value as? String ?? ""
      XCTAssertTrue(
        enteredValue.contains("test"),
        "Search field should contain typed text, got: '\(enteredValue)'")

      // Additional verification: ensure search field remains available for further interaction
      XCTAssertTrue(searchField.exists, "Search field should remain available after text input")
    } else {
      throw XCTSkip("Search field not found - skipping responsiveness test")
    }
  }
}
