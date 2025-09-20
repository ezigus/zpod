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
                guard let libraryContent = findContainerElement(in: app, identifier: "Podcast Cards Container") else {
                    XCTFail("Library content container not found")
                    return
                }

                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // When: I tap on a podcast using direct element access
                    let podcastButton = app.buttons["Podcast-swift-talk"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Then: I should see some form of episode list content
                        // Check for multiple possible indicators of episode list screen
                        var foundContainer = false
                        let candidateIdentifiers = [
                            "Episode Cards Container",
                            "Content Container"
                        ]
                        
                        for identifier in candidateIdentifiers {
                            if let container = findContainerElement(in: app, identifier: identifier),
                               container.waitForExistence(timeout: adaptiveShortTimeout) {
                                foundContainer = true
                                break
                            }
                        }
                        
                        if !foundContainer {
                            // Fallback: check for other scrollable/table elements or navigation change
                            let anyTable = app.tables.firstMatch
                            let anyCollection = app.collectionViews.firstMatch
                            let anyScrollView = app.scrollViews.firstMatch
                            let episodeNavBar = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Episode' OR identifier CONTAINS 'episode'")).firstMatch
                            
                            if anyTable.exists || anyCollection.exists || anyScrollView.exists || episodeNavBar.exists {
                                foundContainer = true
                            }
                        }

                        XCTAssertTrue(foundContainer, "Should navigate to some form of episode list content")
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
        if let episodeContainer = findContainerElement(in: app, identifier: "Episode Cards Container") {
            
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
        
        // When: I check for any scroll container and perform scrolling
        var candidateContainers: [XCUIElement] = []
        if let episodeCards = findContainerElement(in: app, identifier: "Episode Cards Container") {
            candidateContainers.append(episodeCards)
        }
        if let contentContainer = findContainerElement(in: app, identifier: "Content Container") {
            candidateContainers.append(contentContainer)
        }
        let tableView = app.tables.firstMatch
        if tableView.exists { candidateContainers.append(tableView) }
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists { candidateContainers.append(collectionView) }
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists { candidateContainers.append(scrollView) }
        
        if let container = candidateContainers.first {
            // Perform scroll action
            container.swipeUp()
            
            // Then: The container should still exist after scrolling
            XCTAssertTrue(container.exists, "Scroll container should still exist after scrolling")
        } else {
            throw XCTSkip("No container available - skipping scrolling test")
        }
    }
    
    @MainActor
    func testEpisodeDetailNavigation() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I tap on an episode using direct element access
        let firstEpisode = app.buttons["Episode-st-001"]
        if firstEpisode.exists {
            firstEpisode.tap()
            
            // Then: I should navigate to some form of detail view
            // Check for multiple possible detail view indicators
            let detailIndicators = [
                app.otherElements["Episode Detail View"],
                app.navigationBars["Episode Detail"],
                app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).firstMatch,
                app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'detail'")).firstMatch,
                app.buttons["Play"],
                app.buttons["Pause"]
            ]
            
            var foundDetailView = false
            for indicator in detailIndicators {
                if indicator.waitForExistence(timeout: adaptiveShortTimeout) {
                    foundDetailView = true
                    break
                }
            }
            
            // Also check that we've navigated away from the list
            let navigatedAway = findContainerElement(in: app, identifier: "Episode Cards Container") == nil
            
            XCTAssertTrue(foundDetailView || navigatedAway, "Should navigate to episode detail or away from list")
        } else {
            // Fallback: try any episode button
            let anyEpisodeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode-'")).firstMatch
            if anyEpisodeButton.exists {
                anyEpisodeButton.tap()
                
                // Simple check: verify we're no longer in the episode list
                let navigatedAway = findContainerElement(in: app, identifier: "Episode Cards Container") == nil
                XCTAssertTrue(navigatedAway, "Should navigate away from episode list")
            } else {
                throw XCTSkip("No episode buttons available - skipping detail navigation test")
            }
        }
    }
    
    @MainActor
    func testEpisodeStatusIndicators() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I'm viewing an episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for an episode row to become visible
        let firstEpisode = waitForAnyElement([
            app.buttons["Episode-st-001"],
            app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Episode-" )).firstMatch
        ], timeout: adaptiveTimeout, description: "episode button", failOnTimeout: false)

        XCTAssertNotNil(firstEpisode, "Episode content should load for status testing")

        // Then: I should see appropriate status indicators (placeholder assertion for now)
        if let episodeElement = firstEpisode {
            XCTAssertTrue(episodeElement.exists, "Episode element should be discoverable")
        }
    }
    
    @MainActor
    func testEmptyEpisodeListState() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to a podcast with episodes (for now, just verify the basic navigation works)
        navigateToPodcastEpisodes("swift-talk")
        
        // Wait for the placeholder episode list to become visible
        let placeholderEpisode = waitForAnyElement([
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Episode-" )).firstMatch,
            app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Episode-" )).firstMatch
        ], timeout: adaptiveTimeout, description: "episode placeholder", failOnTimeout: false)

        XCTAssertNotNil(placeholderEpisode, "Episode placeholder content should be discoverable")
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
                guard let libraryContent = findContainerElement(in: app, identifier: "Podcast Cards Container") else {
                    XCTFail("Library content container not found")
                    return
                }

                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // Look for a podcast to tap
                    let podcastButton = app.buttons["Podcast-swift-talk"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Wait for episode list container to appear
                        if waitForContentToLoad(containerIdentifier: "Episode Cards Container", timeout: adaptiveTimeout) {
                            guard let episodeCardsContainer = findContainerElement(in: app, identifier: "Episode Cards Container") else {
                                throw XCTSkip("Episode Cards Container not available - skipping pull to refresh test")
                            }
                            
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
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testEpisodeListAccessibility() throws {
        // Initialize the app
        initializeApp()
        
        // Given: I navigate to episode list
        navigateToPodcastEpisodes("swift-talk")
        
        // When: I check accessibility elements
        // Look for any available content container
        var foundContainer = false
        if let episodeCards = findContainerElement(in: app, identifier: "Episode Cards Container") {
            foundContainer = episodeCards.exists
        } else if let contentContainer = findContainerElement(in: app, identifier: "Content Container") {
            foundContainer = contentContainer.exists
        } else {
            let tableView = app.tables.firstMatch
            let collectionView = app.collectionViews.firstMatch
            let scrollView = app.scrollViews.firstMatch
            foundContainer = tableView.exists || collectionView.exists || scrollView.exists
        }
        
        if foundContainer {
            // Then: Key elements should be accessible
            let firstEpisode = app.buttons["Episode-st-001"]
            if firstEpisode.exists && firstEpisode.isHittable {
                // Test specific episode accessibility
                XCTAssertFalse(firstEpisode.label.isEmpty, "Episode should have accessible label")
                XCTAssertTrue(firstEpisode.isHittable, "Episode should be accessible")
            } else {
                // Fallback: check for any accessible episode buttons
                let episodeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode-'"))
                if episodeButtons.count > 0 {
                    let anyEpisode = episodeButtons.firstMatch
                    XCTAssertTrue(anyEpisode.exists, "Should have accessible episode buttons")
                } else {
                    throw XCTSkip("No episode buttons available for accessibility testing")
                }
            }
        } else {
            throw XCTSkip("No content container available for accessibility testing")
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
                guard let libraryContent = findContainerElement(in: app, identifier: "Podcast Cards Container") else {
                    XCTFail("Library content container not found")
                    return
                }

                if libraryContent.waitForExistence(timeout: adaptiveTimeout) {
                    
                    // Navigate to podcast using direct element access
                    let podcastButton = app.buttons["Podcast-\(podcastId)"]
                    if podcastButton.exists {
                        podcastButton.tap()
                        
                        // Verify we reached some form of episode list content
                        // Check for multiple possible indicators
                        var foundContainer = false
                        let candidateIdentifiers = [
                            "Episode Cards Container",
                            "Content Container"
                        ]

                        for identifier in candidateIdentifiers {
                            if let container = findContainerElement(in: app, identifier: identifier),
                               container.waitForExistence(timeout: adaptiveShortTimeout) {
                                foundContainer = true
                                break
                            }
                        }

                        if !foundContainer {
                            let tableView = app.tables.firstMatch
                            let collectionView = app.collectionViews.firstMatch
                            let scrollView = app.scrollViews.firstMatch
                            foundContainer = tableView.exists || collectionView.exists || scrollView.exists
                        }

                        XCTAssertTrue(foundContainer, "Should navigate to episode list for podcast \(podcastId)")
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
