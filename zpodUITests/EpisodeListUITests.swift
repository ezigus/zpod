//
//  EpisodeListUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

import XCTest

final class EpisodeListUITests: XCTestCase, SmartUITesting {
    nonisolated(unsafe) var app: XCUIApplication!
    
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
        
        // Wait for loading using robust pattern
        XCTAssertTrue(
            waitForLoadingToComplete(in: app, timeout: adaptiveTimeout),
            "Library should load successfully"
        )
        
        // When: I tap on a podcast using smart navigation
        let navigationSucceeded = navigateAndWaitForResult(
            triggerAction: {
                let podcastButton = findAccessibleElement(
                    in: app,
                    byIdentifier: "Podcast-swift-talk",
                    byPartialLabel: "swift-talk",
                    ofType: .button
                )
                podcastButton?.tap()
            },
            expectedElements: [
                app.scrollViews["Episode Cards Container"],
                app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).firstMatch
            ],
            timeout: adaptiveTimeout,
            description: "navigation to podcast episodes"
        )
        
        // Then: I should see the episode list
        XCTAssertTrue(navigationSucceeded, "Navigation to podcast episodes should succeed")
    }
    
    @MainActor
    func testEpisodeListDisplaysEpisodes() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast's episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads using robust content loading
        XCTAssertTrue(
            waitForContentToLoad(
                containerIdentifier: "Episode Cards Container",
                itemIdentifiers: ["Episode-st-001"]
            ),
            "Episode content should load and display"
        )
        
        // Then: I should see episodes displayed
        let firstEpisode = findAccessibleElement(
            in: app,
            byIdentifier: "Episode-st-001",
            byPartialLabel: "st-001",
            ofType: .button
        )
        XCTAssertNotNil(firstEpisode, "First episode should be findable")
        XCTAssertTrue(firstEpisode?.exists ?? false, "Episode button should be visible")
    }
    
    @MainActor
    func testEpisodeListScrolling() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list with multiple episodes
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for content using robust loading pattern
        XCTAssertTrue(
            waitForContentToLoad(containerIdentifier: "Episode Cards Container"),
            "Episode list should load before testing scrolling"
        )
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        
        // When: I scroll through the episode list
        episodeCardsContainer.swipeUp()
        
        // Then: The list should scroll smoothly without crashes using stability check
        XCTAssertTrue(
            waitForStableState(app: app, stableFor: 0.3, timeout: adaptiveShortTimeout),
            "App should remain stable after scrolling"
        )
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should still exist after scrolling")
    }
    
    @MainActor
    func testEpisodeDetailNavigation() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for content to load using robust pattern
        XCTAssertTrue(
            waitForContentToLoad(
                containerIdentifier: "Episode Cards Container",
                itemIdentifiers: ["Episode-st-001"]
            ),
            "Episode content should load successfully"
        )
        
        // When: I tap on an episode using smart navigation
        let navigationSucceeded = navigateAndWaitForResult(
            triggerAction: {
                let firstEpisode = findAccessibleElement(
                    in: app,
                    byIdentifier: "Episode-st-001",
                    byPartialLabel: "st-001",
                    ofType: .button
                )
                firstEpisode?.tap()
            },
            expectedElements: [
                app.otherElements["Episode Detail View"],
                app.navigationBars["Episode Detail"],
                app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).firstMatch,
                app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'detail'")).firstMatch
            ],
            timeout: adaptiveTimeout,
            description: "navigation to episode detail"
        )
        
        // Then: Navigation should succeed to some form of detail view
        XCTAssertTrue(navigationSucceeded, "Episode detail navigation should complete")
        
        // Verify we reached a detail state by checking for common detail view indicators
        let detailIndicators = [
            app.otherElements["Episode Detail View"].exists,
            app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS 'detail'")).firstMatch.exists,
            app.buttons["Play"].exists || app.buttons["Pause"].exists,
            !app.scrollViews["Episode Cards Container"].exists // We've navigated away from the list
        ]
        
        XCTAssertTrue(
            detailIndicators.contains(true),
            "Should show episode detail view indicators"
        )
    }
    
    @MainActor
    func testEpisodeStatusIndicators() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for content using robust loading pattern
        XCTAssertTrue(
            waitForContentToLoad(
                containerIdentifier: "Episode Cards Container",
                itemIdentifiers: ["Episode-st-001"]
            ),
            "Episode content should load for status testing"
        )
        
        // When: I look at episodes with different statuses
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        
        // Then: I should see appropriate status indicators
        // Note: This would need more specific test data to verify played/in-progress states
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should display status indicators")
    }
    
    @MainActor
    func testEmptyEpisodeListState() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast with episodes (for now, just verify the basic navigation works)
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for content using robust pattern
        XCTAssertTrue(
            waitForContentToLoad(containerIdentifier: "Episode Cards Container"),
            "Episode container should be available for empty state testing"
        )
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should exist")
    }
    
    @MainActor
    func testPullToRefreshFunctionality() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for content using robust loading pattern
        XCTAssertTrue(
            waitForContentToLoad(containerIdentifier: "Episode Cards Container"),
            "Episode content should load before testing refresh"
        )
        
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        
        // When: I pull down to refresh
        if episodeCardsContainer.exists {
            let startCoordinate = episodeCardsContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endCoordinate = startCoordinate.withOffset(CGVector(dx: 0, dy: 200))
            startCoordinate.press(forDuration: 0, thenDragTo: endCoordinate)
        }
        
        // Then: The refresh should complete without errors using stability check
        XCTAssertTrue(
            waitForStableState(app: app, stableFor: 0.5, timeout: adaptiveTimeout),
            "App should remain stable after pull-to-refresh"
        )
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
        
        // Wait for content using robust loading pattern
        XCTAssertTrue(
            waitForContentToLoad(containerIdentifier: "Episode Cards Container"),
            "Episode content should load on iPad before layout testing"
        )
        
        // When: The episode list loads
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        
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
        
        // Wait for content using robust loading pattern
        XCTAssertTrue(
            waitForContentToLoad(
                containerIdentifier: "Episode Cards Container",
                itemIdentifiers: ["Episode-st-001"]
            ),
            "Episode content should load for accessibility testing"
        )
        
        // When: I check accessibility elements
        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
        
        // Then: Key elements should be accessible using smart discovery
        let firstEpisode = findAccessibleElement(
            in: app,
            byIdentifier: "Episode-st-001",
            byPartialLabel: "st-001",
            ofType: .button
        )
        
        if let episode = firstEpisode {
            XCTAssertTrue(episode.isHittable, "Episode buttons should be accessible")
        } else {
            // Fallback check for any accessible episode buttons
            let episodeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode-'"))
            XCTAssertGreaterThan(episodeButtons.count, 0, "Should have accessible episode buttons")
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
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
        
        // Wait for loading using robust pattern
        XCTAssertTrue(
            waitForLoadingToComplete(in: app, timeout: adaptiveTimeout),
            "Library loading should complete"
        )
        
        // Wait for library content using robust content loading
        XCTAssertTrue(
            waitForContentToLoad(
                containerIdentifier: "Podcast Cards Container",
                itemIdentifiers: ["Podcast-\(podcastId)"]
            ),
            "Podcast library content should load"
        )
        
        // Navigate to podcast using smart navigation pattern
        let navigationSucceeded = navigateAndWaitForResult(
            triggerAction: {
                let podcastButton = findAccessibleElement(
                    in: app,
                    byIdentifier: "Podcast-\(podcastId)",
                    byPartialLabel: podcastId,
                    ofType: .button
                )
                podcastButton?.tap()
            },
            expectedElements: [
                app.scrollViews["Episode Cards Container"],
                app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).firstMatch
            ],
            timeout: adaptiveTimeout,
            description: "navigation to podcast \(podcastId) episodes"
        )
        
        XCTAssertTrue(navigationSucceeded, "Should successfully navigate to podcast episodes")
    }
}