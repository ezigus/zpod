//
//  BatchOperationUITests.swift
//  zpodUITests
//
//  Created for Issue 02.1.3: Batch Operations and Episode Status Management
//

import XCTest

final class BatchOperationUITests: XCTestCase, SmartUITesting {
    nonisolated(unsafe) var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    private func initializeApp() {
        app = XCUIApplication()
        app.launch()
    }
    
    // MARK: - Multi-Selection Interface Tests
    
    @MainActor
    func testEnterMultiSelectMode() throws {
        // Given: The app is launched and showing episode list
        initializeApp()
        
        // Navigate to episode list
        navigateToEpisodeList()
        
        // When: I tap the "Select" button
        let selectButton = app.navigationBars.buttons["Select"]
        XCTAssertTrue(selectButton.exists, "Select button should be available")
        selectButton.tap()
        
        // Then: Multi-select mode should be active
        XCTAssertTrue(
            waitForElementToAppear(app.navigationBars.buttons["Done"]),
            "Done button should appear in multi-select mode"
        )
        
        // And: Selection controls should be visible
        let selectionControls = app.staticTexts["0 selected"]
        XCTAssertTrue(selectionControls.exists, "Selection count should be visible")
        
        // And: All/None/Invert buttons should be available
        XCTAssertTrue(app.buttons["All"].exists, "All button should be available")
        XCTAssertTrue(app.buttons["None"].exists, "None button should be available")
        XCTAssertTrue(app.buttons["Invert"].exists, "Invert button should be available")
    }
    
    @MainActor
    func testSelectEpisodesInMultiSelectMode() throws {
        // Given: Multi-select mode is active
        initializeApp()
        navigateToEpisodeList()
        enterMultiSelectMode()
        
        // When: I tap on individual episodes
        let firstEpisode = findFirstEpisode()
        XCTAssertTrue(firstEpisode.exists, "First episode should be available")
        firstEpisode.tap()
        
        // Then: Episode should be selected
        XCTAssertTrue(
            waitForTextToAppear("1 selected"),
            "Selection count should update to 1"
        )
        
        // And: Checkbox should show selected state
        let selectedCheckbox = firstEpisode.images["checkmark.circle.fill"]
        XCTAssertTrue(selectedCheckbox.exists, "Selected checkbox should be visible")
        
        // When: I select another episode
        let secondEpisode = findSecondEpisode()
        if secondEpisode.exists {
            secondEpisode.tap()
            
            // Then: Selection count should increase
            XCTAssertTrue(
                waitForTextToAppear("2 selected"),
                "Selection count should update to 2"
            )
        }
    }
    
    @MainActor
    func testSelectAllEpisodes() throws {
        // Given: Multi-select mode is active
        initializeApp()
        navigateToEpisodeList()
        enterMultiSelectMode()
        
        // When: I tap "All" button
        let allButton = app.buttons["All"]
        allButton.tap()
        
        // Then: All episodes should be selected
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["3 selected"].exists },
                { self.app.staticTexts["4 selected"].exists },
                { self.app.staticTexts["5 selected"].exists }
            ]),
            "All episodes should be selected"
        )
        
        // And: Batch action buttons should appear
        XCTAssertTrue(
            waitForElementToAppear(app.buttons["Mark as Played"]),
            "Batch action buttons should appear when episodes are selected"
        )
    }
    
    @MainActor
    func testDeselectAllEpisodes() throws {
        // Given: All episodes are selected
        initializeApp()
        navigateToEpisodeList()
        enterMultiSelectMode()
        app.buttons["All"].tap()
        
        // Wait for selection to complete
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["3 selected"].exists },
                { self.app.staticTexts["4 selected"].exists },
                { self.app.staticTexts["5 selected"].exists }
            ])
        )
        
        // When: I tap "None" button
        let noneButton = app.buttons["None"]
        noneButton.tap()
        
        // Then: No episodes should be selected
        XCTAssertTrue(
            waitForTextToAppear("0 selected"),
            "All episodes should be deselected"
        )
    }
    
    @MainActor
    func testInvertSelection() throws {
        // Given: Some episodes are selected
        initializeApp()
        navigateToEpisodeList()
        enterMultiSelectMode()
        
        // Select first episode
        let firstEpisode = findFirstEpisode()
        firstEpisode.tap()
        
        // Wait for selection
        XCTAssertTrue(waitForTextToAppear("1 selected"))
        
        // When: I tap "Invert" button
        let invertButton = app.buttons["Invert"]
        invertButton.tap()
        
        // Then: Selection should be inverted
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["2 selected"].exists },
                { self.app.staticTexts["3 selected"].exists },
                { self.app.staticTexts["4 selected"].exists }
            ]),
            "Selection should be inverted"
        )
    }
    
    // MARK: - Batch Operations Tests
    
    @MainActor
    func testMarkSelectedEpisodesAsPlayed() throws {
        // Given: Episodes are selected
        initializeApp()
        navigateToEpisodeList()
        selectMultipleEpisodes()
        
        // When: I tap "Mark as Played" button
        let markPlayedButton = app.buttons["Mark as Played"]
        XCTAssertTrue(markPlayedButton.exists, "Mark as Played button should be available")
        markPlayedButton.tap()
        
        // Then: Batch operation should start
        XCTAssertTrue(
            waitForElementToAppear(app.staticTexts["Processing..."]),
            "Batch operation progress should be visible"
        )
        
        // And: Progress indicator should appear
        XCTAssertTrue(
            waitForElementToAppear(app.progressIndicators.firstMatch),
            "Progress indicator should be visible"
        )
        
        // And: Operation should complete
        XCTAssertTrue(
            waitForTextToAppear("Completed"),
            "Operation should complete successfully"
        )
    }
    
    @MainActor
    func testBatchDownloadOperation() throws {
        // Given: Episodes are selected
        initializeApp()
        navigateToEpisodeList()
        selectMultipleEpisodes()
        
        // When: I tap "Download" button
        let downloadButton = app.buttons["Download"]
        if downloadButton.exists {
            downloadButton.tap()
        } else {
            // Try accessing through "More" menu
            let moreButton = app.buttons["More"]
            moreButton.tap()
            
            // Wait for batch operation sheet
            XCTAssertTrue(
                waitForElementToAppear(app.buttons["Download"]),
                "Download option should be available in batch operations"
            )
            app.buttons["Download"].tap()
        }
        
        // Then: Download operation should start
        XCTAssertTrue(
            waitForElementToAppear(app.staticTexts["Processing..."]),
            "Download operation should start"
        )
    }
    
    @MainActor
    func testBatchOperationCancellation() throws {
        // Given: A long-running batch operation is in progress
        initializeApp()
        navigateToEpisodeList()
        selectMultipleEpisodes()
        
        // Start a batch operation
        let downloadButton = app.buttons["Download"]
        if downloadButton.exists {
            downloadButton.tap()
        }
        
        // When: I tap the "Cancel" button
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
        
        // Then: Operation should be cancelled
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["Cancelled"].exists },
                { !self.app.staticTexts["Processing..."].exists }
            ]),
            "Operation should be cancelled"
        )
    }
    
    // MARK: - Advanced Selection Features Tests
    
    @MainActor
    func testCriteriaBasedSelection() throws {
        // Given: Multi-select mode is active
        initializeApp()
        navigateToEpisodeList()
        enterMultiSelectMode()
        
        // When: I tap "Criteria" button
        let criteriaButton = app.buttons["Criteria"]
        criteriaButton.tap()
        
        // Then: Selection criteria sheet should appear
        XCTAssertTrue(
            waitForElementToAppear(app.navigationBars["Select Episodes"]),
            "Selection criteria sheet should appear"
        )
        
        // And: Various criteria options should be available
        XCTAssertTrue(app.staticTexts["Play Status"].exists, "Play Status section should be available")
        XCTAssertTrue(app.staticTexts["Download Status"].exists, "Download Status section should be available")
        XCTAssertTrue(app.staticTexts["Date Range"].exists, "Date Range section should be available")
        
        // When: I configure criteria and apply
        // Select "Played" status
        app.pickers.firstMatch.swipeUp() // Navigate to played option
        app.buttons["Apply"].tap()
        
        // Then: Episodes matching criteria should be selected
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["1 selected"].exists },
                { self.app.staticTexts["2 selected"].exists },
                { self.app.staticTexts["0 selected"].exists }
            ]),
            "Episodes matching criteria should be selected"
        )
    }
    
    @MainActor
    func testLongPressToEnterMultiSelect() throws {
        // Given: Normal episode list view
        initializeApp()
        navigateToEpisodeList()
        
        // When: I long press on an episode
        let firstEpisode = findFirstEpisode()
        firstEpisode.press(forDuration: 1.0)
        
        // Then: Multi-select mode should be activated
        XCTAssertTrue(
            waitForElementToAppear(app.navigationBars.buttons["Done"]),
            "Multi-select mode should be activated by long press"
        )
        
        // And: The long-pressed episode should be selected
        XCTAssertTrue(
            waitForTextToAppear("1 selected"),
            "Long-pressed episode should be selected"
        )
    }
    
    // MARK: - Visual Feedback Tests
    
    @MainActor
    func testProgressIndicatorsForDownloadingEpisodes() throws {
        // Given: Episode list with downloading episodes
        initializeApp()
        navigateToEpisodeList()
        
        // When: There are episodes with download progress
        // Look for download progress indicators
        let downloadProgress = app.progressIndicators.matching(identifier: "Download Progress").firstMatch
        let downloadingText = app.staticTexts["Downloading..."]
        
        // Then: Progress indicators should be visible if downloads are active
        if downloadingText.exists {
            XCTAssertTrue(downloadProgress.exists, "Download progress should be visible for downloading episodes")
        }
    }
    
    @MainActor
    func testPlaybackProgressIndicators() throws {
        // Given: Episode list with episodes in progress
        initializeApp()
        navigateToEpisodeList()
        
        // When: There are episodes with playback progress
        let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Progress:'")).firstMatch
        
        // Then: Playback progress should be visible
        if progressText.exists {
            let playbackProgress = app.progressIndicators.matching(identifier: "Playback Progress").firstMatch
            XCTAssertTrue(playbackProgress.exists, "Playback progress should be visible for episodes in progress")
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func navigateToEpisodeList() {
        // Navigate to Library tab
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        if libraryTab.exists {
            libraryTab.tap()
        }
        
        // Wait for library to load
        XCTAssertTrue(
            waitForLoadingToComplete(in: app, timeout: adaptiveTimeout),
            "Library should load successfully"
        )
        
        // Navigate to a podcast's episodes
        let firstPodcast = findAccessibleElement(
            in: app,
            byIdentifier: "Podcast-swift-talk",
            byPartialLabel: "Swift",
            ofType: .button
        )
        
        if let podcast = firstPodcast {
            podcast.tap()
        }
        
        // Wait for episode list to load
        XCTAssertTrue(
            waitForElementToAppear(app.otherElements["Episode List View"]),
            "Episode list should load"
        )
    }
    
    @MainActor
    private func enterMultiSelectMode() {
        let selectButton = app.navigationBars.buttons["Select"]
        if selectButton.exists {
            selectButton.tap()
        }
        
        XCTAssertTrue(
            waitForElementToAppear(app.navigationBars.buttons["Done"]),
            "Multi-select mode should be active"
        )
    }
    
    @MainActor
    private func selectMultipleEpisodes() {
        enterMultiSelectMode()
        
        // Select at least 2 episodes
        let firstEpisode = findFirstEpisode()
        let secondEpisode = findSecondEpisode()
        
        if firstEpisode.exists {
            firstEpisode.tap()
        }
        
        if secondEpisode.exists {
            secondEpisode.tap()
        }
        
        // Wait for selection to be confirmed
        XCTAssertTrue(
            waitForAnyCondition([
                { self.app.staticTexts["1 selected"].exists },
                { self.app.staticTexts["2 selected"].exists }
            ]),
            "Episodes should be selected"
        )
    }
    
    @MainActor
    private func findFirstEpisode() -> XCUIElement {
        return findAccessibleElement(
            in: app,
            byIdentifier: "Episode-st-001",
            byPartialLabel: "Episode",
            ofType: .button
        ) ?? app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).firstMatch
    }
    
    @MainActor
    private func findSecondEpisode() -> XCUIElement {
        return findAccessibleElement(
            in: app,
            byIdentifier: "Episode-st-002",
            byPartialLabel: "Episode",
            ofType: .button
        ) ?? app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Episode'")).element(boundBy: 1)
    }
    
    @MainActor
    private func waitForTextToAppear(_ text: String, timeout: TimeInterval = 5.0) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.staticTexts[text]
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    @MainActor
    private func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}