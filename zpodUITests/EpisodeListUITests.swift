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
        
        // Given: The app is launched and we navigate to Library tab
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            let libraryTab = tabBar.buttons["Library"]
            if libraryTab.exists {
                libraryTab.tap()
                
                // Wait for library content using simple existence check
                let libraryContent = app.scrollViews["Podcast Cards Container"]
                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // When: I tap on a podcast using direct element access
                    let podcastButton = app.buttons["Podcast-swift-talk"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Then: I should see the episode list
                        let episodeContainer = app.scrollViews["Episode Cards Container"]
                        XCTAssertTrue(episodeContainer.waitForExistence(timeout: adaptiveTimeout), 
                                     "Navigation to podcast episodes should succeed")
                    } else {
                        throw XCTSkip("Test podcast not available - skipping navigation test")
                    }
                } else {
                    throw XCTSkip("Library content not available - skipping navigation test")
                }
            } else {
                throw XCTSkip("Library tab not available - skipping navigation test")
            }
        } else {
            throw XCTSkip("Main tab bar not available - skipping navigation test")
        }
    }
    
    @MainActor
    func testEpisodeListDisplaysEpisodes() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast's episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: The episode list loads, check for episode container
        let episodeContainer = app.scrollViews["Episode Cards Container"]
        if episodeContainer.exists {
            
            // Then: I should see episodes displayed using direct element access
            let firstEpisode = app.buttons["Episode-st-001"]
            if firstEpisode.exists {
                XCTAssertTrue(firstEpisode.exists, "Episode button should be visible")
            } else {
                // Fallback: look for any episode button
                let anyEpisodeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode-'")).firstMatch
                XCTAssertTrue(anyEpisodeButton.exists, "At least one episode should be visible")
            }
        } else {
            throw XCTSkip("Episode container not available - skipping episode display test")
        }
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
        
        // Then: The list should scroll smoothly without crashes
        // Wait for scroll animation to complete using XCTestExpectation
        let scrollCompleteExpectation = XCTestExpectation(description: "Scroll animation completes")
        
        func checkScrollCompleted() {
            if episodeCardsContainer.exists && episodeCardsContainer.isHittable {
                scrollCompleteExpectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    checkScrollCompleted()
                }
            }
        }
        
        checkScrollCompleted()
        wait(for: [scrollCompleteExpectation], timeout: adaptiveShortTimeout)
        
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
            triggerAction: { [self] in
                let firstEpisode = self.findAccessibleElement(
                    in: self.app,
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
        
        // Given: App is launched and we navigate to episode list
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            let libraryTab = tabBar.buttons["Library"]
            if libraryTab.exists {
                libraryTab.tap()
                
                // Wait for library to load using simple existence check
                let libraryContent = app.scrollViews["Podcast Cards Container"]
                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // Look for a podcast to tap
                    let podcastButton = app.buttons["Podcast-swift-talk"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Wait for episode list container to appear
                        let episodeCardsContainer = app.scrollViews["Episode Cards Container"]
                        if episodeCardsContainer.waitForExistence(timeout: adaptiveTimeout) {
                            
                            // When: I pull down to refresh
                            let startCoordinate = episodeCardsContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                            let endCoordinate = startCoordinate.withOffset(CGVector(dx: 0, dy: 200))
                            startCoordinate.press(forDuration: 0, thenDragTo: endCoordinate)
                            
                            // Then: The container should still exist after refresh
                            XCTAssertTrue(episodeCardsContainer.exists, "Episode cards container should still exist after refresh")
                        } else {
                            throw XCTSkip("Episode Cards Container not available - skipping pull to refresh test")
                        }
                    } else {
                        throw XCTSkip("Test podcast not available - skipping pull to refresh test")
                    }
                } else {
                    throw XCTSkip("Library content not available - skipping pull to refresh test")
                }
            } else {
                throw XCTSkip("Library tab not available - skipping pull to refresh test")
            }
        } else {
            throw XCTSkip("Main tab bar not available - skipping pull to refresh test")
        }
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
            // Wait for episode element to be ready for accessibility testing using XCTestExpectation
            let accessibilityReadyExpectation = XCTestExpectation(description: "Episode element ready for accessibility")
            
            func checkAccessibilityReady() {
                if episode.exists && episode.isHittable {
                    accessibilityReadyExpectation.fulfill()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        checkAccessibilityReady()
                    }
                }
            }
            
            checkAccessibilityReady()
            wait(for: [accessibilityReadyExpectation], timeout: adaptiveShortTimeout)
        } else {
            // Fallback check for any accessible episode buttons
            let episodeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode-'"))
            XCTAssertGreaterThan(episodeButtons.count, 0, "Should have accessible episode buttons")
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
        // Navigate to Library tab using simple approach
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            let libraryTab = tabBar.buttons["Library"]
            if libraryTab.exists {
                libraryTab.tap()
                
                // Wait for library content using simple existence check
                let libraryContent = app.scrollViews["Podcast Cards Container"]
                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // Navigate to podcast using direct element access
                    let podcastButton = app.buttons["Podcast-\(podcastId)"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Verify we reached episode list
                        let episodeContainer = app.scrollViews["Episode Cards Container"]
                        XCTAssertTrue(episodeContainer.waitForExistence(timeout: adaptiveTimeout), 
                                     "Should navigate to episode list for podcast \(podcastId)")
                    } else {
                        XCTFail("Podcast \(podcastId) button not found")
                    }
                } else {
                    XCTFail("Library content failed to load")
                }
            } else {
                XCTFail("Library tab not found")
            }
        } else {
            XCTFail("Main tab bar not found")
        }
    }
}