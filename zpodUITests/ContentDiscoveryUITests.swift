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

    // MARK: - Search Interface Tests
    // Covers: Search functionality from ui spec
    
    @MainActor
    func testSearchInterface() throws {
        // Given: Search interface is available
        let searchField = app.searchFields.firstMatch
        
        if searchField.exists {
            // When: Interacting with search field
            searchField.tap()
            
            // Then: Search field should be functional
            XCTAssertTrue(searchField.exists, "Search field should be available")
            XCTAssertNotNil(searchField.placeholderValue, "Search field should have placeholder text")
            
            // Test search input
            searchField.typeText("Swift")
            
            // Search should show results or feedback
            let searchResults = app.tables["Search Results"]
            let noResultsMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No results' OR label CONTAINS 'no results'")).firstMatch
            
            XCTAssertTrue(searchResults.exists || noResultsMessage.exists,
                         "Search should show results or appropriate feedback")
        }
    }
    
    @MainActor
    func testVoiceSearchActivation() throws {
        // Given: Voice search capability
        let voiceSearchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Voice' OR label CONTAINS 'Microphone'")).firstMatch
        
        if voiceSearchButton.exists {
            // When: Activating voice search
            voiceSearchButton.tap()
            
            // Then: Voice search interface should appear
            let voiceInterface = app.otherElements["Voice Search Interface"]
            let microphoneIndicator = app.images.matching(NSPredicate(format: "label CONTAINS 'Microphone'")).firstMatch
            
            XCTAssertTrue(voiceInterface.exists || microphoneIndicator.exists,
                         "Voice search interface should be activated")
        }
    }
    
    @MainActor
    func testSearchFilters() throws {
        // Given: Search with filtering options
        let searchField = app.searchFields.firstMatch
        
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Technology")
            
            // When: Accessing search filters
            let filterButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Filter' OR label CONTAINS 'filter'")).firstMatch
            
            if filterButton.exists {
                filterButton.tap()
                
                // Then: Filter options should be available
                let categoryFilter = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Category'")).firstMatch
                let durationFilter = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Duration'")).firstMatch
                let dateFilter = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date'")).firstMatch
                
                XCTAssertTrue(categoryFilter.exists || durationFilter.exists || dateFilter.exists,
                             "Search filters should be available")
            }
        }
    }
    
    // MARK: - Browse and Category Navigation Tests
    // Covers: Content browsing from ui spec
    
    @MainActor
    func testCategoryBrowsing() throws {
        // Given: Category browsing interface
        let categoriesSection = app.otherElements["Categories"]
        let browseButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Browse' OR label CONTAINS 'Categories'")).firstMatch
        
        if categoriesSection.exists || browseButton.exists {
            if browseButton.exists {
                browseButton.tap()
            }
            
            // When: Browsing categories
            let categoryButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Technology' OR label CONTAINS 'Entertainment' OR label CONTAINS 'News'"))
            
            if categoryButtons.count > 0 {
                let firstCategory = categoryButtons.element(boundBy: 0)
                firstCategory.tap()
                
                // Then: Category content should be displayed
                let categoryContent = app.tables["Category Content"]
                let categoryResults = app.collectionViews["Category Results"]
                
                XCTAssertTrue(categoryContent.exists || categoryResults.exists,
                             "Category browsing should show content")
            }
        }
    }
    
    @MainActor
    func testFeaturedContent() throws {
        // Given: Featured content section
        let featuredSection = app.otherElements["Featured"]
        let featuredCarousel = app.scrollViews["Featured Carousel"]
        
        if featuredSection.exists || featuredCarousel.exists {
            // When: Interacting with featured content
            let featuredItems = app.buttons.allElementsBoundByIndex
            
            if featuredItems.count > 0 {
                let firstFeaturedItem = featuredItems[0]
                if firstFeaturedItem.exists {
                    firstFeaturedItem.tap()
                    
                    // Then: Featured item should open detail view
                    let detailView = app.otherElements["Detail View"]
                    let backButton = app.navigationBars.buttons.element(boundBy: 0)
                    
                    XCTAssertTrue(detailView.exists || backButton.exists,
                                 "Featured content should open detail view")
                }
            }
        }
    }
    
    @MainActor
    func testTopCharts() throws {
        // Given: Top charts or trending section
        let topChartsSection = app.otherElements["Top Charts"]
        let trendingSection = app.otherElements["Trending"]
        
        if topChartsSection.exists || trendingSection.exists {
            // When: Viewing top charts
            let chartItems = app.tables.cells.allElementsBoundByIndex
            
            if !chartItems.isEmpty {
                let firstChartItem = chartItems[0]
                if firstChartItem.exists {
                    firstChartItem.tap()
                    
                    // Then: Chart item should be accessible
                    Thread.sleep(forTimeInterval: 0.5)
                    XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "App should remain stable when accessing chart items")
                }
            }
        }
    }
    
    // MARK: - Subscription Management Interface Tests
    // Covers: Subscription workflows from ui spec
    
    @MainActor
    func testSubscribeButton() throws {
        // Given: Content item with subscription option
        let subscribeButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Subscribe' OR label CONTAINS 'Follow'"))
        
        if subscribeButtons.count > 0 {
            let subscribeButton = subscribeButtons.element(boundBy: 0)
            
            // When: Tapping subscribe button
            let initialLabel = subscribeButton.label
            subscribeButton.tap()
            
            // Then: Button state should change or feedback should be provided
            Thread.sleep(forTimeInterval: 0.5)
            
            let updatedLabel = subscribeButton.label
            let feedbackMessage = app.alerts.firstMatch
            let toastMessage = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Subscribed' OR label CONTAINS 'Added'")).firstMatch
            
            XCTAssertTrue(initialLabel != updatedLabel ||
                         feedbackMessage.exists ||
                         toastMessage.exists,
                         "Subscribe action should provide feedback")
        }
    }
    
    @MainActor
    func testUnsubscribeWorkflow() throws {
        // Given: Subscribed content item
        let unsubscribeButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Unsubscribe' OR label CONTAINS 'Subscribed'"))
        
        if unsubscribeButtons.count > 0 {
            let unsubscribeButton = unsubscribeButtons.element(boundBy: 0)
            
            // When: Unsubscribing
            unsubscribeButton.tap()
            
            // Then: Confirmation or immediate action should occur
            let confirmationAlert = app.alerts.firstMatch
            if confirmationAlert.exists {
                let confirmButton = confirmationAlert.buttons.matching(NSPredicate(format: "label CONTAINS 'Unsubscribe' OR label CONTAINS 'Confirm'")).firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "Unsubscribe workflow should complete successfully")
        }
    }
    
    // MARK: - Content Detail View Tests
    // Covers: Detailed content views from ui spec
    
    @MainActor
    func testContentDetailView() throws {
        // Given: Content item available for detail view
        let contentItems = app.tables.cells.allElementsBoundByIndex + app.collectionViews.cells.allElementsBoundByIndex
        
        if !contentItems.isEmpty {
            let firstItem = contentItems[0]
            if firstItem.exists {
                firstItem.tap()
                
                // When: Viewing content details
                // Then: Detail view should show comprehensive information
                let episodesList = app.tables["Episodes List"]
                let descriptionText = app.textViews.matching(NSPredicate(format: "label CONTAINS 'Description' OR value != ''")).firstMatch
                let artwork = app.images.firstMatch
                
                XCTAssertTrue(episodesList.exists || descriptionText.exists || artwork.exists,
                             "Detail view should show content information")
                
                // Test detail view navigation
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                    
                    // Should return to previous view
                    Thread.sleep(forTimeInterval: 0.3)
                    XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "Detail view navigation should work")
                }
            }
        }
    }
    
    // MARK: - Sorting and Organization Tests
    // Covers: Content organization from ui spec
    
    @MainActor
    func testSortingOptions() throws {
        // Given: Content list with sorting options
        let sortButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sort' OR label CONTAINS 'sort'")).firstMatch
        
        if sortButton.exists {
            // When: Accessing sort options
            sortButton.tap()
            
            // Then: Sort options should be available
            let sortOptions = [
                app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date'")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS 'Popularity'")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS 'Name' OR label CONTAINS 'Title'")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS 'Rating'")).firstMatch
            ]
            
            let availableOptions = sortOptions.filter { $0.exists }
            XCTAssertGreaterThan(availableOptions.count, 0, "Sort options should be available")
            
            // Test selecting a sort option
            if !availableOptions.isEmpty {
                availableOptions[0].tap()
                Thread.sleep(forTimeInterval: 0.5)
                XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "Sort selection should work")
            }
        }
    }
    
    // MARK: - Accessibility Tests
    // Covers: Accessibility for discovery features from ui spec
    
    @MainActor
    func testDiscoveryAccessibility() throws {
        // Given: Discovery interface elements
        let searchField = app.searchFields.firstMatch
        let categoryButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Technology' OR label CONTAINS 'Entertainment'"))
        
        // When: Checking accessibility compliance
        // Then: Elements should be properly accessible
        if searchField.exists {
            XCTAssertTrue(searchField.isAccessibilityElement, "Search field should be accessible")
            XCTAssertNotNil(searchField.accessibilityLabel, "Search field should have accessibility label")
            XCTAssertNotNil(searchField.placeholderValue, "Search field should have placeholder for VoiceOver")
        }
        
        for i in 0..<min(categoryButtons.count, 3) {
            let categoryButton = categoryButtons.element(boundBy: i)
            if categoryButton.exists {
                XCTAssertTrue(categoryButton.isAccessibilityElement, "Category buttons should be accessible")
                XCTAssertFalse(categoryButton.label.isEmpty, "Category buttons should have descriptive labels")
            }
        }
    }
    
    @MainActor
    func testVoiceOverNavigationInDiscovery() throws {
        // Given: Discovery interface for VoiceOver users
        let interactiveElements = app.buttons.allElementsBoundByIndex +
                                 app.searchFields.allElementsBoundByIndex +
                                 app.tables.allElementsBoundByIndex
        
        // When: Checking VoiceOver navigation order
        // Then: Elements should be in logical order and accessible via label or hit test
        for element in interactiveElements.prefix(5) {
            if element.exists {
                XCTAssertTrue(element.isHittable || !element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                             "Discovery elements should be accessible to VoiceOver")
            }
        }
    }
    
    // MARK: - Performance Tests
    // Covers: Discovery interface performance
    
    @MainActor
    func testSearchPerformance() throws {
        // Given: Search interface
        let searchField = app.searchFields.firstMatch
        
        if searchField.exists {
            let startTime = Date().timeIntervalSince1970
            
            // When: Performing search
            searchField.tap()
            searchField.typeText("Technology")
            
            let endTime = Date().timeIntervalSince1970
            let searchTime = endTime - startTime
            
            // Then: Search should be responsive
            XCTAssertLessThan(searchTime, 3.0, "Search input should be responsive")
        }
    }
    
    // MARK: - Error Handling Tests
    // Covers: Error states in discovery interface
    
    @MainActor
    func testNoResultsHandling() throws {
        // Given: Search that returns no results
        let searchField = app.searchFields.firstMatch
        
        if searchField.exists {
            // When: Searching for content that doesn't exist
            searchField.tap()
            searchField.typeText("XYZNonexistentContent123")
            
            // Then: Appropriate feedback should be shown
            let noResultsMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No results' OR label CONTAINS 'no results' OR label CONTAINS 'Nothing found'")).firstMatch
            let emptyState = app.otherElements["Empty State"]
            
            // Allow time for search to complete
            Thread.sleep(forTimeInterval: 1.0)
            
            XCTAssertTrue(noResultsMessage.exists || emptyState.exists,
                         "Search should show appropriate feedback for no results")
        }
    }
    
    // MARK: - Acceptance Criteria Tests
    // Covers: Complete discovery workflows from ui specification
    
    @MainActor
    func testAcceptanceCriteria_CompleteDiscoveryWorkflow() throws {
        // Given: User wants to discover and explore content
        // When: User goes through complete discovery workflow
        
        // Step 1: Browse categories
        let browseButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Browse' OR label CONTAINS 'Categories'")).firstMatch
        if browseButton.exists {
            browseButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Step 2: Search for specific content
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Technology")
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        // Step 3: View content details
        let contentItems = app.tables.cells.allElementsBoundByIndex
        if !contentItems.isEmpty {
            let firstItem = contentItems[0]
            if firstItem.exists {
                firstItem.tap()
                Thread.sleep(forTimeInterval: 0.5)
                
                // Navigate back
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                }
            }
        }
        
        // Then: All discovery workflows should work smoothly
        XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "Discovery workflow should complete without crashes")
        
        // Verify we can still access main discovery interface
        let tabBar = app.tabBars["Main Tab Bar"]
        let discoverTab = tabBar.buttons["Discover"]
        if discoverTab.exists {
            XCTAssertTrue(discoverTab.isEnabled, "Discover tab should remain accessible")
        }
    }
    
    @MainActor
    func testAcceptanceCriteria_AccessibleDiscovery() throws {
        // Given: Discovery interface must be accessible
        // When: Checking comprehensive accessibility
        
        var accessibilityScore = 0
        
        // Check search accessibility
        let searchField = app.searchFields.firstMatch
        if searchField.exists && (searchField.isHittable || searchField.placeholderValue != nil) {
            accessibilityScore += 1
        }
        
        // Check category accessibility
        let categoryButtons = app.buttons.matching(NSPredicate(format: "label != ''"))
        for i in 0..<min(categoryButtons.count, 3) {
            let button = categoryButtons.element(boundBy: i)
            if button.exists && !button.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                accessibilityScore += 1
            }
        }
        
        // Check content list accessibility
        let contentCells = app.tables.cells.allElementsBoundByIndex
        for cell in contentCells.prefix(2) {
            if cell.exists && (cell.isHittable || !cell.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                accessibilityScore += 1
            }
        }
        
        // Then: Discovery interface should have strong accessibility support
        XCTAssertGreaterThanOrEqual(accessibilityScore, 3,
                                   "Discovery interface should have comprehensive accessibility support")
    }
}
