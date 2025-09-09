//
//  EpisodeListUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

import XCTest

final class EpisodeListUITests: XCTestCase {
    nonisolated(unsafe) private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Initialize app without @MainActor calls in setup
        // XCUIApplication creation and launch will be done in test methods
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Episode List Navigation Tests
    
    @MainActor
    func testNavigationToPodcastEpisodeList() throws {
        // Initialize the app
        initializeApp()
        
        // Given: The app is launched and showing the Library tab
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        XCTAssertTrue(libraryTab.exists, "Library tab should exist")
        libraryTab.tap()
        
        // Wait for loading to complete
        let loadingIndicator = app.otherElements["Loading View"]
        if loadingIndicator.exists {
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 10), "Loading should complete within 10 seconds")
        }
        
        // When: I tap on a podcast in the library
        let podcastButton = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
        XCTAssertTrue(podcastButton.waitForExistence(timeout: 5), "Swift Talk podcast should be visible")
        podcastButton.tap()
        
        // Then: I should see the episode list
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should be displayed")
    }
    
    @MainActor
    func testEpisodeListDisplaysEpisodes() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast's episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should exist")
        
        // Then: I should see episodes displayed
        let firstEpisode = app.buttons.matching(identifier: "Episode-st-001").firstMatch
        XCTAssertTrue(firstEpisode.waitForExistence(timeout: 5), "First episode should be visible")
        
        // And: Episode titles should be visible
        XCTAssertTrue(firstEpisode.exists, "Episode button should contain title")
    }
    
    @MainActor
    func testEpisodeListScrolling() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list with multiple episodes
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
        
        // When: I scroll through the episode list
        episodeCardsContainer.swipeUp()
        
        // Then: The list should scroll smoothly without crashes
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should still exist after scrolling")
    }
    
    @MainActor
    func testEpisodeDetailNavigation() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I tap on an episode
        let firstEpisode = app.buttons.matching(identifier: "Episode-st-001").firstMatch
        XCTAssertTrue(firstEpisode.waitForExistence(timeout: 5), "First episode should be visible")
        firstEpisode.tap()
        
        // Then: I should see the episode detail view
        let episodeDetailView = app.otherElements["Episode Detail View"]
        XCTAssertTrue(episodeDetailView.waitForExistence(timeout: 5), "Episode detail view should be displayed")
    }
    
    @MainActor
    func testEpisodeStatusIndicators() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I look at episodes with different statuses
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
        
        // Then: I should see appropriate status indicators
        // Note: This would need more specific test data to verify played/in-progress states
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should display status indicators")
    }
    
    @MainActor
    func testEmptyEpisodeListState() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast with no episodes (if available)
        // This test would need specific test data setup
        
        // For now, just verify the basic navigation works
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
    }
    
    @MainActor
    func testPullToRefreshFunctionality() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
        
        // When: I pull down to refresh
        if episodeCardsContainer.exists {
            let startCoordinate = episodeCardsContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endCoordinate = startCoordinate.withOffset(CGVector(dx: 0, dy: 200))
            startCoordinate.press(forDuration: 0, thenDragTo: endCoordinate)
        }
        
        // Then: The refresh should complete without errors
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should still exist after refresh")
    }
    
    // MARK: - iPad Responsive Design Tests
    
    @MainActor
    func testIPadLayout() throws {
        // Skip this test on iPhone
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test is only for iPad")
        }
        
        // Initialize the app
        initializeApp()
        
        // Given: I'm on iPad and navigate to episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
        
        // Then: The layout should be optimized for iPad
        // Note: Specific iPad layout tests would require more detailed UI structure validation
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should display properly on iPad")
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testEpisodeListAccessibility() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I check accessibility elements
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.waitForExistence(timeout: 5), "Episode cards container should exist")
        
        // Then: Key elements should be accessible
        let firstEpisode = app.buttons.matching(identifier: "Episode-st-001").firstMatch
        if firstEpisode.waitForExistence(timeout: 3) {
            XCTAssertTrue(firstEpisode.isHittable, "Episode buttons should be accessible")
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func initializeApp() {
        app = XCUIApplication()
        app.launch()
    }
    
    @MainActor
    private func navigateToPodcastEpisodes(_ podcastId: String) {
        // Navigate to Library tab
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        XCTAssertTrue(libraryTab.exists, "Library tab should exist")
        libraryTab.tap()
        
        // Wait for loading to complete
        let loadingIndicator = app.otherElements["Loading View"]
        if loadingIndicator.exists {
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 10), "Loading should complete within 10 seconds")
        }
        
        // Wait for library content to load - now looking for cards container instead of table
        let cardsContainer = app.scrollViews["Podcast Cards Container"]
        XCTAssertTrue(cardsContainer.waitForExistence(timeout: 5), "Podcast cards container should be visible")
        
        // Wait for and tap podcast card with better error messaging
        let podcastButton = app.buttons.matching(identifier: "Podcast-\(podcastId)").firstMatch
        XCTAssertTrue(podcastButton.waitForExistence(timeout: 10), 
                     "Podcast button with ID 'Podcast-\(podcastId)' should be visible. Available buttons: \(app.buttons.allElementsBoundByIndex.map { $0.identifier })")
        podcastButton.tap()
    }
}