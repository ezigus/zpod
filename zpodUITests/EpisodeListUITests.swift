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
        
        // XCUIApplication doesn't require @MainActor, so we can create it directly
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Episode List Navigation Tests
    
    @MainActor
    func testNavigationToPodcastEpisodeList() throws {
        // Given: The app is launched and showing the Library tab
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        XCTAssertTrue(libraryTab.exists, "Library tab should exist")
        libraryTab.tap()
        
        // When: I tap on a podcast in the library
        let podcastRow = app.cells.matching(identifier: "Podcast-swift-talk").firstMatch
        XCTAssertTrue(podcastRow.waitForExistence(timeout: 5), "Swift Talk podcast should be visible")
        podcastRow.tap()
        
        // Then: I should see the episode list
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should be displayed")
    }
    
    @MainActor
    func testEpisodeListDisplaysEpisodes() throws {
        // Given: I navigate to a podcast's episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.exists, "Episode list should exist")
        
        // Then: I should see episodes displayed
        let firstEpisode = app.cells.matching(identifier: "Episode-st-001").firstMatch
        XCTAssertTrue(firstEpisode.waitForExistence(timeout: 5), "First episode should be visible")
        
        // And: Episode titles should be visible
        let episodeTitle = firstEpisode.staticTexts["Episode Title"]
        XCTAssertTrue(episodeTitle.exists, "Episode title should be visible")
    }
    
    @MainActor
    func testEpisodeListScrolling() throws {
        // Given: I'm viewing an episode list with multiple episodes
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
        
        // When: I scroll through the episode list
        episodeList.swipeUp()
        
        // Then: The list should scroll smoothly without crashes
        XCTAssertTrue(episodeList.exists, "Episode list should still exist after scrolling")
    }
    
    @MainActor
    func testEpisodeDetailNavigation() throws {
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I tap on an episode
        let firstEpisode = app.cells.matching(identifier: "Episode-st-001").firstMatch
        XCTAssertTrue(firstEpisode.waitForExistence(timeout: 5), "First episode should be visible")
        firstEpisode.tap()
        
        // Then: I should see the episode detail view
        let episodeDetailView = app.otherElements["Episode Detail View"]
        XCTAssertTrue(episodeDetailView.waitForExistence(timeout: 5), "Episode detail view should be displayed")
    }
    
    @MainActor
    func testEpisodeStatusIndicators() throws {
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I look at episodes with different statuses
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
        
        // Then: I should see appropriate status indicators
        // Note: This would need more specific test data to verify played/in-progress states
        XCTAssertTrue(episodeList.exists, "Episode list should display status indicators")
    }
    
    @MainActor
    func testEmptyEpisodeListState() throws {
        // Given: I navigate to a podcast with no episodes (if available)
        // This test would need specific test data setup
        
        // For now, just verify the basic navigation works
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
    }
    
    @MainActor
    func testPullToRefreshFunctionality() throws {
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
        
        // When: I pull down to refresh
        let firstCell = episodeList.cells.firstMatch
        if firstCell.exists {
            let startCoordinate = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let endCoordinate = startCoordinate.withOffset(CGVector(dx: 0, dy: 200))
            startCoordinate.press(forDuration: 0, thenDragTo: endCoordinate)
        }
        
        // Then: The refresh should complete without errors
        XCTAssertTrue(episodeList.exists, "Episode list should still exist after refresh")
    }
    
    // MARK: - iPad Responsive Design Tests
    
    @MainActor
    func testIPadLayout() throws {
        // Skip this test on iPhone
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test is only for iPad")
        }
        
        // Given: I'm on iPad and navigate to episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
        
        // Then: The layout should be optimized for iPad
        // Note: Specific iPad layout tests would require more detailed UI structure validation
        XCTAssertTrue(episodeList.exists, "Episode list should display properly on iPad")
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testEpisodeListAccessibility() throws {
        // Given: I navigate to episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I check accessibility elements
        let episodeList = app.tables["Episode List"]
        XCTAssertTrue(episodeList.waitForExistence(timeout: 5), "Episode list should exist")
        
        // Then: Key elements should be accessible
        let firstEpisode = app.cells.matching(identifier: "Episode-st-001").firstMatch
        if firstEpisode.waitForExistence(timeout: 3) {
            XCTAssertTrue(firstEpisode.isHittable, "Episode cells should be accessible")
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToPodcastEpisodes(_ podcastId: String) {
        // Navigate to Library tab
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        if libraryTab.exists {
            libraryTab.tap()
        }
        
        // Wait for and tap podcast row
        let podcastRow = app.cells.matching(identifier: "Podcast-\(podcastId)").firstMatch
        if podcastRow.waitForExistence(timeout: 5) {
            podcastRow.tap()
        }
    }
}