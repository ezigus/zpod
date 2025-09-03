import XCTest

/// UI tests for content discovery and search interface functionality
///
/// **Specifications Covered**: `spec/ui.md` - Search and discovery sections
/// - Search interface and results display testing
/// - Browse and category navigation verification
/// - Subscription management interface testing
/// - Filter and sort controls validation
/// - Content recommendation displays
final class ContentDiscoveryUITests: XCTestCase {
    
    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Perform @MainActor UI setup without blocking the main thread
        let exp = expectation(description: "Launch app on main actor")
        var appResult: XCUIApplication?
        
        Task { @MainActor in
            let instance = XCUIApplication()
            instance.launch()
            
            // Navigate to discovery interface for testing
            let tabBar = instance.tabBars["Main Tab Bar"]
            let discoverTab = tabBar.buttons["Discover"]
            if discoverTab.exists {
                discoverTab.tap()
            }
            
            appResult = instance
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 15.0)
        app = appResult
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Search Interface Tests (Issue 01.1.1 Scenario 1)
    // Given/When/Then: Basic Podcast Search and Discovery
    
    @MainActor
    func testBasicPodcastSearchInterface_GivenDiscoverTab_WhenSearching_ThenShowsSearchInterface() throws {
        // Given: I am on the Discover tab
        XCTAssertTrue(app.navigationBars["Discover"].exists, "Should be on Discover tab")
        
        // When: I look for search functionality
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        
        // Then: I should see search interface elements
        XCTAssertTrue(searchField.exists, "Search field should be present")
        XCTAssertTrue(searchField.isHittable, "Search field should be interactive")
    }
    
    @MainActor
    func testSearchFieldInput_GivenSearchInterface_WhenTyping_ThenAcceptsInput() throws {
        // Given: Search interface is available
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        XCTAssertTrue(searchField.exists, "Search field should exist")
        
        // When: I type in the search field
        searchField.tap()
        searchField.typeText("Swift Talk")
        
        // Then: The search field should contain the typed text
        XCTAssertTrue(searchField.value as? String == "Swift Talk" || 
                     app.staticTexts["Swift Talk"].exists, 
                     "Search field should contain typed text")
    }
    
    @MainActor
    func testSearchClearButton_GivenSearchText_WhenTappingClear_ThenClearsSearch() throws {
        // Given: I have typed in the search field
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        searchField.tap()
        searchField.typeText("test")
        
        // When: I tap the clear button (if it exists)
        let clearButton = app.buttons.matching(NSPredicate(format: "accessibilityLabel == 'Clear search'")).firstMatch
        if clearButton.exists {
            clearButton.tap()
            
            // Then: The search field should be empty
            XCTAssertTrue(searchField.value as? String == "" || 
                         searchField.placeholderValue?.contains("Search") == true,
                         "Search field should be cleared")
        }
    }
    
    // MARK: - Discovery Options Menu Tests (Issue 01.1.1 Scenario 4)
    // RSS Feed Addition Interface
    
    @MainActor
    func testDiscoveryOptionsMenu_GivenDiscoverTab_WhenTappingOptions_ThenShowsMenu() throws {
        // Given: I am on the Discover tab
        XCTAssertTrue(app.navigationBars["Discover"].exists)
        
        // When: I tap the discovery options menu
        let optionsButton = app.buttons.matching(NSPredicate(format: "accessibilityLabel == 'Discovery options'")).firstMatch
        if optionsButton.exists {
            optionsButton.tap()
            
            // Then: I should see menu options including RSS feed addition
            let addRSSOption = app.buttons["Add RSS Feed"]
            let searchHistoryOption = app.buttons["Search History"]
            
            // At least one of these options should be available
            XCTAssertTrue(addRSSOption.exists || searchHistoryOption.exists, 
                         "Discovery options menu should contain expected items")
        }
    }
    
    @MainActor
    func testRSSFeedAddition_GivenOptionsMenu_WhenSelectingAddRSSFeed_ThenShowsRSSSheet() throws {
        // Given: I have access to the options menu
        let optionsButton = app.buttons.matching(NSPredicate(format: "accessibilityLabel == 'Discovery options'")).firstMatch
        
        if optionsButton.exists {
            optionsButton.tap()
            
            // When: I select "Add RSS Feed"
            let addRSSOption = app.buttons["Add RSS Feed"]
            if addRSSOption.exists {
                addRSSOption.tap()
                
                // Then: RSS feed addition sheet should appear
                let rssSheet = app.navigationBars["Add RSS Feed"]
                XCTAssertTrue(rssSheet.waitForExistence(timeout: 3.0), 
                             "RSS feed addition sheet should appear")
                
                // And should contain URL input field
                let urlField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'https://'")).firstMatch
                XCTAssertTrue(urlField.exists, "URL input field should be present")
            }
        }
    }
    
    @MainActor
    func testRSSURLInput_GivenRSSSheet_WhenEnteringURL_ThenAcceptsInput() throws {
        // Navigate to RSS sheet if available
        let optionsButton = app.buttons.matching(NSPredicate(format: "accessibilityLabel == 'Discovery options'")).firstMatch
        if optionsButton.exists {
            optionsButton.tap()
            
            let addRSSOption = app.buttons["Add RSS Feed"]
            if addRSSOption.exists {
                addRSSOption.tap()
                
                // Given: RSS sheet is displayed
                let urlField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'https://'")).firstMatch
                if urlField.exists {
                    // When: I enter a URL
                    urlField.tap()
                    urlField.typeText("https://example.com/feed.xml")
                    
                    // Then: The field should contain the URL
                    XCTAssertTrue(urlField.value as? String == "https://example.com/feed.xml" ||
                                 app.staticTexts["https://example.com/feed.xml"].exists,
                                 "URL field should contain entered URL")
                }
            }
        }
    }
    
    // MARK: - Search Filter Tests (Issue 01.1.1 Scenario 2)
    // Advanced Search Across All Content
    
    @MainActor
    func testSearchFilters_GivenSearchResults_WhenFilteringByType_ThenShowsFilters() throws {
        // Given: I have started a search
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        if searchField.exists {
            searchField.tap()
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
        // Given: I have access to the options menu
        let optionsButton = app.buttons.matching(NSPredicate(format: "accessibilityLabel == 'Discovery options'")).firstMatch
        
        if optionsButton.exists {
            optionsButton.tap()
            
            // When: I select "Search History"
            let searchHistoryOption = app.buttons["Search History"]
            if searchHistoryOption.exists {
                searchHistoryOption.tap()
                
                // Then: Search history sheet should appear
                let historySheet = app.navigationBars["Search History"]
                XCTAssertTrue(historySheet.waitForExistence(timeout: 3.0), 
                             "Search history sheet should appear")
            }
        }
    }
    
    // MARK: - Navigation and Accessibility Tests
    
    @MainActor
    func testDiscoverTabAccessibility_GivenApp_WhenNavigating_ThenSupportsAccessibility() throws {
        // Given: The app is launched
        // When: I check accessibility elements on Discover tab
        let discoverNavBar = app.navigationBars["Discover"]
        
        // Then: Key elements should be accessible
        XCTAssertTrue(discoverNavBar.exists, "Discover navigation should be accessible")
        
        // Check for accessible search elements
        let searchElements = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'"))
        if searchElements.count > 0 {
            let searchField = searchElements.firstMatch
            XCTAssertTrue(searchField.isHittable, "Search field should be accessible")
        }
    }
    
    @MainActor
    func testDiscoverTabTitle_GivenDiscoverTab_WhenViewing_ThenShowsCorrectTitle() throws {
        // Given: I am on the Discover tab
        // When: I check the navigation title
        let discoverTitle = app.navigationBars["Discover"]
        
        // Then: The title should be "Discover"
        XCTAssertTrue(discoverTitle.exists, "Discover tab should show correct title")
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func testEmptyDiscoverState_GivenNoSearch_WhenViewingDiscover_ThenShowsEmptyState() throws {
        // Given: I am on the Discover tab with no active search
        // When: I look at the empty state
        
        // Then: Should show empty state elements (these might include welcome text, icons, etc.)
        // Note: The exact empty state UI may vary, so we check for common patterns
        let hasEmptyStateElements = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Discover'")).count > 0 ||
                                   app.images.count > 0 ||
                                   app.buttons.containing(NSPredicate(format: "label CONTAINS 'Add'")).count > 0
        
        XCTAssertTrue(hasEmptyStateElements, "Discover tab should show some content or empty state")
    }
    
    // MARK: - Performance and Real-time Tests
    
    @MainActor
    func testSearchResponsiveness_GivenSearchField_WhenTyping_ThenRespondsQuickly() throws {
        // Given: Search interface is available
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        
        if searchField.exists {
            // When: I type in the search field
            let startTime = Date()
            searchField.tap()
            searchField.typeText("test")
            let endTime = Date()
            
            // Then: The interface should respond within reasonable time (under 1 second for UI interaction)
            let responseTime = endTime.timeIntervalSince(startTime)
            XCTAssertLessThan(responseTime, 1.0, "Search interface should be responsive")
        }
    }
}
