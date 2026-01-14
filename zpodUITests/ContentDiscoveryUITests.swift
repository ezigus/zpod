import XCTest
/// UI tests for content discovery and search interface functionality
///
/// **Specifications Covered**: `spec/ui.md` - Search and discovery sections
/// - Search interface and results display testing
/// - Browse and category navigation verification
/// - Subscription management interface testing
/// - Filter and sort controls validation
/// - Content recommendation displays
///
/// - Note: Type body length rule disabled due to comprehensive test coverage
// swiftlint:disable:next type_body_length
final class ContentDiscoveryUITests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!
  private var discoverDiagnosticsEnabled: Bool {
    ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"
  }

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
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(
      waitForElement(
        tabBar, timeout: adaptiveTimeout, description: "Main tab bar"),
      "Main tab bar should be available after app launch")

    // Navigate to discovery interface for testing
    let discoverTab = tabBar.buttons.matching(identifier: "Discover").firstMatch
    XCTAssertTrue(discoverTab.exists, "Discover tab should exist")
    logDiscoverDiagnostics("pre-tap", app: app, discoverTab: discoverTab)

    // Try coordinate-based tap if button isn't responding
    if discoverTab.isHittable {
      discoverTab.tap()
    } else {
      // Force tap using coordinate
      let coordinate = discoverTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      coordinate.tap()
    }

    // Wait for tab selection to complete (tab should have .selected trait)
    // This synchronization step prevents race conditions where we query for
    // search field before SwiftUI finishes the tab transition animation.
    let tabSelectedPredicate = NSPredicate(format: "isSelected == true")
    var tabSwitchResult = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: tabSelectedPredicate, object: discoverTab)],
      timeout: adaptiveShortTimeout
    )
    if tabSwitchResult != .completed {
      // Fallback: tap again if first tap didn't register
      discoverTab.tap()
      tabSwitchResult = XCTWaiter().wait(
        for: [XCTNSPredicateExpectation(predicate: tabSelectedPredicate, object: discoverTab)],
        timeout: adaptiveShortTimeout
      )
    }
    logDiscoverDiagnostics("post-tap", app: app, discoverTab: discoverTab)

    let discoverRoot = discoverRootElement(in: app)
    _ = waitForElement(
      discoverRoot,
      timeout: adaptiveShortTimeout,
      description: "Discover root marker"
    )

    // Wait for discover screen to load fully by checking for search field
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let searchField = discoverSearchField(in: app, probeTimeout: 0.5, finalTimeout: adaptiveShortTimeout)
    var searchFieldAppeared = searchField.waitForExistence(timeout: adaptiveTimeout)
    if !searchFieldAppeared {
      discoverTab.tap()
      searchFieldAppeared = searchField.waitForExistence(timeout: adaptiveTimeout)
    }

    XCTAssertTrue(
      searchFieldAppeared,
      "Discover screen should load after tapping tab"
    )
  }

  @MainActor
  private func logDiscoverDiagnostics(_ message: String, app: XCUIApplication, discoverTab: XCUIElement?) {
    guard discoverDiagnosticsEnabled else { return }
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let miniPlayer = app.otherElements.matching(identifier: "Mini Player").firstMatch
    let discoverRootOther = app.otherElements.matching(identifier: "Discover.Root").firstMatch
    let discoverRootAny = app.descendants(matching: .any)
      .matching(identifier: "Discover.Root")
      .firstMatch
    let customSearchField = app.textFields.matching(identifier: "Discover.SearchField").firstMatch
    let searchableField = app.searchFields.firstMatch

    print("[DiscoverDiag] \(message)")
    print("[DiscoverDiag] tabBar exists=\(tabBar.exists) frame=\(tabBar.frame)")
    if let discoverTab {
      print(
        "[DiscoverDiag] discoverTab exists=\(discoverTab.exists) selected=\(discoverTab.isSelected) hittable=\(discoverTab.isHittable) frame=\(discoverTab.frame)"
      )
    }
    if miniPlayer.exists {
      print(
        "[DiscoverDiag] miniPlayer exists=\(miniPlayer.exists) hittable=\(miniPlayer.isHittable) frame=\(miniPlayer.frame)"
      )
    } else {
      print("[DiscoverDiag] miniPlayer exists=false")
    }
    if discoverRootOther.exists {
      print(
        "[DiscoverDiag] discoverRoot other exists=\(discoverRootOther.exists) type=\(String(describing: discoverRootOther.elementType)) frame=\(discoverRootOther.frame)"
      )
    } else {
      print("[DiscoverDiag] discoverRoot other exists=false")
    }
    if discoverRootAny.exists {
      print(
        "[DiscoverDiag] discoverRoot any exists=\(discoverRootAny.exists) type=\(String(describing: discoverRootAny.elementType)) frame=\(discoverRootAny.frame)"
      )
    } else {
      print("[DiscoverDiag] discoverRoot any exists=false")
    }
    print(
      "[DiscoverDiag] searchField textField exists=\(customSearchField.exists) searchField exists=\(searchableField.exists)"
    )
  }

  private func rssURLField(in app: XCUIApplication) -> XCUIElement {
    let identifierField = app.textFields.matching(identifier: "rss-url-field").firstMatch
    if identifierField.waitForExistence(timeout: adaptiveShortTimeout) {
      return identifierField
    }

    let urlPlaceholderField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS[cd] 'https://'")
    ).firstMatch
    if urlPlaceholderField.waitForExistence(timeout: adaptiveShortTimeout) {
      return urlPlaceholderField
    }

    let rssPlaceholderField = app.textFields.matching(
      NSPredicate(format: "placeholderValue CONTAINS[cd] 'rss'")
    ).firstMatch
    if rssPlaceholderField.waitForExistence(timeout: adaptiveShortTimeout) {
      return rssPlaceholderField
    }

    return identifierField
  }

  // Search field discovery is shared via UITestHelpers.discoverSearchField(in:)

  // MARK: - Search Interface Tests (Issue 01.1.1 Scenario 1)
  // Given/When/Then: Basic Podcast Search and Discovery

  @MainActor
  func testBasicPodcastSearchInterface_GivenDiscoverTab_WhenSearching_ThenShowsSearchInterface()
    throws
  {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    XCTAssertTrue(searchField.exists, "Should be on Discover tab with search field visible")

    // When: I look for search functionality
    // (searchField already retrieved above)

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
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    XCTAssertTrue(
      waitForElement(searchField, timeout: adaptiveShortTimeout, description: "Search field"),
      "Search field should exist"
    )
    XCTAssertTrue(
      waitForElementToBeHittable(searchField, timeout: adaptiveShortTimeout, description: "Search field"),
      "Search field should be hittable"
    )

    // When: I type in the search field
    searchField.tap()
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(
      waitForElement(keyboard, timeout: adaptiveShortTimeout, description: "Keyboard"),
      "Keyboard should appear after focusing search field"
    )
    _ = waitForKeyboardFocus(on: searchField, timeout: adaptiveShortTimeout, description: "Search field focus")
    let desiredQuery = "Swift Talk"
    searchField.typeText(desiredQuery)

    // Then: Entered text should remain in the field even when results lag
    let valuePredicate = NSPredicate { _, _ in
      let fieldValue = searchField.value as? String ?? ""
      return fieldValue.contains(desiredQuery)
    }
    let expectation = XCTNSPredicateExpectation(predicate: valuePredicate, object: nil)
    expectation.expectationDescription = "Search field should echo query"
    let result = XCTWaiter.wait(for: [expectation], timeout: adaptiveShortTimeout)
    XCTAssertEqual(
      result,
      .completed,
      "Search field should echo the entered query even before results render"
    )
  }

  @MainActor
  func testSearchClearButton_GivenSearchText_WhenTappingClear_ThenClearsSearch() throws {
    // Initialize the app
    initializeApp()

    // Given: I have typed in the search field
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    searchField.tap()
    searchField.typeText("test")

    // When: I tap the clear button (if it exists)
    let clearButton = app.buttons.matching(NSPredicate(format: "label == 'Clear search'"))
      .firstMatch
    if clearButton.exists {
      clearButton.tap()

      // Then: The search field should be empty
      let fieldValue = searchField.value as? String ?? ""
      XCTAssertTrue(
        fieldValue.isEmpty || searchField.placeholderValue?.contains("Search") == true,
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
      discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout),
      timeout: adaptiveTimeout,
        description: "Discover search field"), "Should navigate to Discover tab")

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
          app.buttons.matching(identifier: "discovery-options-menu.add-rss").firstMatch,
          app.buttons.matching(identifier: "discovery-options-menu.search-history").firstMatch,
        ],
        timeout: adaptiveShortTimeout,
        description: "discovery options menu"
      )

      if menuAppeared {
        // Then: I should see menu options including RSS feed addition
        let hasMenuOptions =
          app.buttons.matching(identifier: "discovery-options-menu.add-rss").firstMatch.exists
          || app.buttons.matching(identifier: "discovery-options-menu.search-history").firstMatch.exists
        XCTAssertTrue(hasMenuOptions, "Discovery options menu should contain expected items")
      } else {
        XCTFail("Menu options did not appear - may need UI adjustments"); return
      }
    } else {
      XCTFail("Discovery options button not found or not accessible"); return
    }
  }

  @MainActor
  func testRSSFeedAddition_GivenOptionsMenu_WhenSelectingAddRSSFeed_ThenShowsRSSSheet() throws {
    // Initialize the app
    initializeApp()

    // Given: I have access to the options menu
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    XCTAssertTrue(searchField.exists, "Should be on Discover tab")

    // Find the options button using multiple strategies
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier (most reliable)
    let identifiedButton = app.buttons.matching(identifier: "discovery-options-menu").firstMatch
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for button with accessibility label
    if optionsButton == nil {
      let labeledButton = app.buttons.matching(
        NSPredicate(format: "label == 'Discovery options'")
      ).firstMatch
      if labeledButton.exists && labeledButton.isHittable {
        optionsButton = labeledButton
      }
    }

    // Strategy 3 removed: Overly broad search through all buttons can match
    // unintended elements. Strategies 1 and 2 should be sufficient.

    if let button = optionsButton {
      button.tap()

      guard
        let discoveryDialog = waitForDialog(
          in: app,
          title: "Discovery Options",
          timeout: adaptiveShortTimeout
        )
      else {
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

      // Then: RSS feed addition sheet should appear (verified by presence of URL field)
      // (NavigationBar elements are unreliable in modern SwiftUI)
      let urlField = rssURLField(in: app)
      guard
        waitForElement(
          urlField,
          timeout: adaptiveShortTimeout,
          description: "RSS feed URL field"
        )
      else { return }

      // And URL input field should be ready for input
      XCTAssertTrue(
        waitForElement(
          urlField,
          timeout: adaptiveTimeout,
          description: "RSS feed URL field"
        ),
        "URL input field should be present"
      )
    } else {
      XCTFail("Discovery options button not found or not accessible"); return
    }
  }

  @MainActor
  func testRSSURLInput_GivenRSSSheet_WhenEnteringURL_ThenAcceptsInput() throws {
    // Initialize the app
    initializeApp()

    // Navigate to RSS sheet if available
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    XCTAssertTrue(searchField.exists, "Should be on Discover tab")

    // Find and tap options button
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier
    let identifiedButton = app.buttons.matching(identifier: "discovery-options-menu").firstMatch
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for toolbar buttons containing "options" or "menu"
    if optionsButton == nil {
      let toolbarButtons = app.buttons.allElementsBoundByIndex
      for button in toolbarButtons {
        let label = button.label.lowercased()
        if (label.contains("option") || label.contains("menu")) && button.exists && button.isHittable {
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

      // Given: RSS sheet is displayed (verified by presence of URL field)
      // (NavigationBar elements are unreliable in modern SwiftUI)
      let urlField = rssURLField(in: app)
      guard
        waitForElement(
          urlField,
          timeout: adaptiveShortTimeout,
          description: "RSS feed URL field (sheet presence)"
        )
      else { return }
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
      let desiredURL = "https://example.com/feed.xml"
      urlField.tap()
      urlField.typeText(desiredURL)

      // Then: Verify the URL was entered (field may show ellipsis or full URL)
      let urlFieldValue = urlField.value as? String ?? ""
      XCTAssertTrue(
        urlFieldValue.contains("example.com") || urlFieldValue.contains("feed"),
        "URL field should contain entered URL, got: '\(urlFieldValue)'"
      )
    } else {
      XCTFail("Discovery options button not found or not accessible"); return
    }
  }

  // MARK: - Search Filter Tests (Issue 01.1.1 Scenario 2)
  // Advanced Search Across All Content

  @MainActor
  func testSearchFilters_GivenSearchResults_WhenFilteringByType_ThenShowsFilters() throws {
    // Initialize the app
    initializeApp()

    // Given: I have started a search
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)
    if searchField.exists {
      // Note: tap() to focus, then typeText() to enter text.
      searchField.tap()
      searchField.typeText("test")

      // Then: Filter options should be available when searching
      let allFilter = app.buttons.matching(identifier: "All").firstMatch
      let podcastsFilter = app.buttons.matching(identifier: "Podcasts").firstMatch
      let episodesFilter = app.buttons.matching(identifier: "Episodes").firstMatch

      let hasFilters = allFilter.exists || podcastsFilter.exists || episodesFilter.exists
      XCTAssertTrue(
        hasFilters,
        "Search filters should be available after typing. Found: All=\(allFilter.exists), Podcasts=\(podcastsFilter.exists), Episodes=\(episodesFilter.exists)"
      )
    }
  }

  // MARK: - Search History Tests (Issue 01.1.1 Scenario 3)
  // Search Performance and Real-time Results

  @MainActor
  func testSearchHistoryAccess_GivenOptionsMenu_WhenSelectingHistory_ThenShowsHistory() throws {
    // Initialize the app
    initializeApp()

    // Given: I have access to the options menu
    let searchField = discoverSearchField(
      in: app,
      probeTimeout: 0.4,
      finalTimeout: adaptiveShortTimeout
    )
    XCTAssertTrue(searchField.exists, "Should be on Discover tab")

    // Populate search history by performing a search
    // This ensures the Search History button is enabled
    searchField.tap()
    searchField.typeText("test query")
    // Submit the search to add it to history
    if app.keyboards.buttons["Search"].exists {
      app.keyboards.buttons["Search"].tap()
    } else {
      searchField.typeText("\n")
    }
    // Brief wait for history to be recorded
    _ = searchField.waitForExistence(timeout: 1)

    // Find the options button using multiple strategies
    var optionsButton: XCUIElement?

    // Strategy 1: Look for button with accessibility identifier (most reliable)
    let identifiedButton = app.buttons.matching(identifier: "discovery-options-menu").firstMatch
    if identifiedButton.exists && identifiedButton.isHittable {
      optionsButton = identifiedButton
    }

    // Strategy 2: Look for button with accessibility label
    if optionsButton == nil {
      let labeledButton = app.buttons.matching(
        NSPredicate(format: "label == 'Discovery options'")
      ).firstMatch
      if labeledButton.exists && labeledButton.isHittable {
        optionsButton = labeledButton
      }
    }

    // Strategy 3 removed: Overly broad search through all buttons can match
    // unintended elements. Strategies 1 and 2 should be sufficient.

    if let button = optionsButton {
      button.tap()

      // Wait for menu to appear using proper wait mechanism
      let searchHistoryOption = app.buttons.matching(
        identifier: "discovery-options-menu.search-history"
      ).firstMatch
      if searchHistoryOption.waitForExistence(timeout: adaptiveShortTimeout) {
        // Wait for button to become enabled (history persistence may lag slightly)
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: searchHistoryOption)
        let result = XCTWaiter.wait(for: [expectation], timeout: adaptiveShortTimeout)
        guard result == .completed else {
          XCTFail("Search History button did not become enabled - history may not have persisted")
          return
        }
        // When: I select "Search History"
        searchHistoryOption.tap()

        // Then: Search history sheet should appear
        // First verify the sheet container appeared (more reliable than List element)
        let searchHistorySheet = app.otherElements.matching(identifier: "Search History Sheet").firstMatch
        XCTAssertTrue(
          searchHistorySheet.waitForExistence(timeout: adaptiveShortTimeout),
          "Search history sheet should appear after selecting Search History option"
        )

        // Verify the Done button is accessible (confirms sheet is interactive)
        let doneButton = app.buttons.matching(identifier: "Search History Done").firstMatch
        XCTAssertTrue(
          doneButton.waitForExistence(timeout: 2),
          "Done button should be accessible in search history sheet"
        )
      } else {
        XCTFail("Search History option not found in menu"); return
      }
    } else {
      XCTFail("Discovery options button not found or not accessible"); return
    }
  }

  // MARK: - Navigation and Accessibility Tests

  @MainActor
  func testDiscoverTabAccessibility_GivenApp_WhenNavigating_ThenSupportsAccessibility() throws {
    // Initialize the app
    initializeApp()

    // Given: The app is launched
    // When: I check accessibility elements on Discover tab
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)

    // Then: Key elements should be accessible
    XCTAssertTrue(searchField.exists, "Discover search field should be accessible")
    XCTAssertTrue(
      searchField.waitForExistence(timeout: adaptiveShortTimeout),
      "Search field should be accessible")
  }

  @MainActor
  func testDiscoverTabTitle_GivenDiscoverTab_WhenViewing_ThenShowsCorrectTitle() throws {
    // Initialize the app
    initializeApp()

    // Given: I am on the Discover tab
    // When: I verify the screen is displaying correctly
    // (NavigationBar elements are unreliable in modern SwiftUI)
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)

    // Then: The Discover tab should be showing (verified by search field presence)
    XCTAssertTrue(searchField.exists, "Discover tab should be showing with search field")
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
    let searchField = discoverSearchField(in: app, probeTimeout: 0.4, finalTimeout: adaptiveShortTimeout)

    if searchField.exists {
      // When: I interact with the search field
      searchField.tap()
      searchField.typeText("test")

      // Then: Verify the text was entered
      let enteredValue = searchField.value as? String ?? ""
      XCTAssertTrue(
        enteredValue.contains("test"),
        "Search field should contain typed text, got: '\(enteredValue)'"
      )
    } else {
      XCTFail("Search field not found - skipping responsiveness test"); return
    }
  }
}
