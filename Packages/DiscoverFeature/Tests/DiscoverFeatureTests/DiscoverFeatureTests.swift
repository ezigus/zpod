import XCTest
import CoreModels
import SearchDomain
import TestSupport
@testable import DiscoverFeature

/// Test suite for Issue 01.1.1: Subscription Discovery and Search Interface
/// Validates the Given/When/Then scenarios from the specification
final class DiscoverFeatureTests: XCTestCase {
    
    private var viewModel: SearchViewModel!
    private var mockSearchService: MockSearchService!
    private var mockPodcastManager: MockPodcastManager!
    private var mockRSSParser: MockRSSParser!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create fresh mock instances for each test
        mockSearchService = MockSearchService()
        mockPodcastManager = MockPodcastManager()
        mockRSSParser = MockRSSParser()
        
        // Create view model with mocks
        viewModel = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockSearchService = nil
        mockPodcastManager = nil
        mockRSSParser = nil
        
        // Clear UserDefaults test data
        UserDefaults.standard.removeObject(forKey: "SearchHistory")
        
        try await super.tearDown()
    }
    
    // MARK: - Scenario 1: Basic Podcast Search and Discovery Tests
    
    @MainActor
    func testBasicPodcastSearch_GivenDiscoverTabWithInternet_WhenSearchingForSwiftTalk_ThenShowsRelevantResults() async {
        // Given: I am on the Discover tab with an active internet connection
        let expectedPodcast = Podcast(
            id: "swift-talk",
            title: "Swift Talk",
            author: "objc.io",
            description: "A weekly video series on Swift programming",
            feedURL: URL(string: "https://example.com/swift-talk")!
        )
        
        mockSearchService.mockResults = [
            .podcast(expectedPodcast, relevanceScore: 0.95)
        ]
        
        // When: I search for "Swift Talk" podcast using keywords
        viewModel.searchText = "Swift Talk"
        await viewModel.search()
        
        // Then: I should see relevant podcast results with artwork, titles, descriptions
        XCTAssertEqual(viewModel.searchResults.count, 1)
        
        if case .podcast(let podcast, let score) = viewModel.searchResults.first {
            XCTAssertEqual(podcast.title, "Swift Talk")
            XCTAssertEqual(podcast.author, "objc.io")
            XCTAssertEqual(podcast.description, "A weekly video series on Swift programming")
            XCTAssertEqual(score, 0.95, accuracy: 0.01)
        } else {
            XCTFail("Expected podcast result")
        }
        
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testBasicPodcastSubscription_GivenSearchResults_WhenTappingSubscribe_ThenPodcastAddedToLibrary() async {
        // Given: I have search results displayed
        let testPodcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            author: "Test Author",
            feedURL: URL(string: "https://example.com/test")!,
            isSubscribed: false
        )
        
        // When: I tap "Subscribe" to add the podcast to my library
        viewModel.subscribe(to: testPodcast)
        
        // Then: The subscription should appear in my Library with proper metadata
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 1)
        
        let addedPodcast = mockPodcastManager.addedPodcasts.first!
        XCTAssertEqual(addedPodcast.id, "test-podcast")
        XCTAssertEqual(addedPodcast.title, "Test Podcast")
        XCTAssertTrue(addedPodcast.isSubscribed)
        XCTAssertNotNil(addedPodcast.dateAdded)
    }
    
    // MARK: - Scenario 2: Advanced Search Across All Content Tests
    
    @MainActor
    func testAdvancedSearchAcrossContent_GivenUnifiedSearchInterface_WhenSearchingWithTextQuery_ThenIncludesAllContentTypes() async {
        // Given: I want to search across all podcasts, episodes, and show notes
        let podcast = Podcast(
            id: "podcast1",
            title: "Tech Talk",
            feedURL: URL(string: "https://example.com/tech")!
        )
        
        let episode = Episode(
            id: "episode1",
            title: "Swift Concurrency",
            podcastID: "podcast1",
            podcastTitle: "Tech Talk",
            pubDate: Date(),
            duration: 1800
        )
        
        mockSearchService.mockResults = [
            .podcast(podcast, relevanceScore: 0.9),
            .episode(episode, relevanceScore: 0.8)
        ]
        
        // When: I use the unified search interface with text query
        viewModel.searchText = "Swift"
        await viewModel.search()
        
        // Then: Results should include podcasts, individual episodes, and show note content
        XCTAssertEqual(viewModel.searchResults.count, 2)
        
        let resultTypes = viewModel.searchResults.map { result in
            switch result {
            case .podcast: return "podcast"
            case .episode: return "episode"
            case .note: return "note"
            }
        }
        
        XCTAssertTrue(resultTypes.contains("podcast"))
        XCTAssertTrue(resultTypes.contains("episode"))
    }
    
    @MainActor
    func testAdvancedSearchFiltering_GivenSearchResults_WhenApplyingFilters_ThenResultsFilteredByContentType() async {
        // Given: I have search results with mixed content types
        let podcast = Podcast(id: "p1", title: "Podcast", feedURL: URL(string: "https://example.com")!)
        let episode = Episode(id: "e1", title: "Episode", podcastID: "p1", podcastTitle: "Podcast", pubDate: Date(), duration: 1800)
        
        mockSearchService.mockResults = [
            .podcast(podcast, relevanceScore: 0.9),
            .episode(episode, relevanceScore: 0.8)
        ]
        
        // When: I apply content type filter
        viewModel.currentFilter = .podcastsOnly
        viewModel.searchText = "test"
        await viewModel.search()
        
        // Then: I should be able to filter results by content type
        XCTAssertEqual(mockSearchService.lastFilter, .podcastsOnly)
    }
    
    // MARK: - Scenario 3: Search Performance and Real-time Results Tests
    
    @MainActor
    func testSearchPerformance_GivenTypingInSearchField_WhenEnteringSearchTerms_ThenResultsAppearWithinTimeLimit() async {
        // Given: I am typing in the search field
        mockSearchService.mockResults = [
            .podcast(Podcast(id: "p1", title: "Test", feedURL: URL(string: "https://example.com")!), relevanceScore: 0.9)
        ]
        
        // When: I enter search terms with real-time feedback
        let startTime = Date()
        viewModel.searchText = "test query"
        await viewModel.search()
        let endTime = Date()
        
        // Then: Search results should appear within 2 seconds with debounced queries
        let searchDuration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(searchDuration, 2.0, "Search should complete within 2 seconds")
        XCTAssertFalse(viewModel.searchResults.isEmpty)
    }
    
    @MainActor
    func testSearchHistory_GivenSearchExecuted_WhenSearchCompletes_ThenRecentSearchesSaved() async {
        // Given: I perform searches
        mockSearchService.mockResults = [
            .podcast(Podcast(id: "p1", title: "Test", feedURL: URL(string: "https://example.com")!), relevanceScore: 0.9)
        ]
        
        // When: I complete searches
        viewModel.searchText = "first search"
        await viewModel.search()
        
        viewModel.searchText = "second search"
        await viewModel.search()
        
        // Then: Recent searches should be saved and easily accessible
        XCTAssertEqual(viewModel.searchHistory.count, 2)
        XCTAssertEqual(viewModel.searchHistory.first, "second search")
        XCTAssertEqual(viewModel.searchHistory.last, "first search")
    }
    
    @MainActor
    func testEmptySearchHandling_GivenEmptySearchTerm_WhenSearching_ThenReturnsEmptyResults() async {
        // Given: Empty search term
        viewModel.searchText = ""
        
        // When: Performing search
        await viewModel.search()
        
        // Then: Should return empty results without calling service
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertFalse(mockSearchService.searchCalled)
    }
    
    // MARK: - Scenario 4: RSS Feed URL Addition Tests
    
    @MainActor
    func testRSSFeedAddition_GivenValidRSSFeedURL_WhenAddingFeed_ThenPodcastValidatedAndAdded() async {
        // Given: I know the RSS feed URL of a podcast
        let testURL = "https://example.com/podcast.xml"
        let expectedPodcast = Podcast(
            id: "rss-podcast",
            title: "RSS Podcast",
            author: "RSS Author",
            feedURL: URL(string: testURL)!
        )
        
        mockRSSParser.mockPodcast = expectedPodcast
        
        // When: I select "Add by RSS Feed URL" and enter the URL
        viewModel.rssURL = testURL
        await viewModel.addPodcastByRSSURL()
        
        // Then: The app should validate the feed and add the podcast with proper error handling
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 1)
        
        let addedPodcast = mockPodcastManager.addedPodcasts.first!
        XCTAssertEqual(addedPodcast.id, "rss-podcast")
        XCTAssertEqual(addedPodcast.title, "RSS Podcast")
        XCTAssertTrue(addedPodcast.isSubscribed)
        XCTAssertEqual(viewModel.rssURL, "") // Should clear URL after success
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testRSSFeedAddition_GivenInvalidURL_WhenAddingFeed_ThenShowsErrorMessage() async {
        // Given: Invalid RSS feed URL
        let invalidURL = "not-a-valid-url"
        
        // When: I enter an invalid URL
        viewModel.rssURL = invalidURL
        await viewModel.addPodcastByRSSURL()
        
        // Then: Invalid feeds should show clear error messages
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 0)
        XCTAssertEqual(viewModel.errorMessage, "Invalid RSS feed URL")
        XCTAssertFalse(viewModel.isAddingRSSFeed)
    }
    
    @MainActor
    func testRSSFeedAddition_GivenParsingError_WhenAddingFeed_ThenShowsErrorWithRetryOption() async {
        // Given: URL that causes parsing error
        let testURL = "https://example.com/invalid-feed.xml"
        mockRSSParser.shouldThrowError = true
        
        // When: Parsing fails
        viewModel.rssURL = testURL
        await viewModel.addPodcastByRSSURL()
        
        // Then: Should show error message with retry options
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to add RSS feed") == true)
        XCTAssertFalse(viewModel.isAddingRSSFeed)
    }
    
    // MARK: - UI Interaction Tests
    
    @MainActor
    func testClearSearch_GivenSearchResultsDisplayed_WhenClearingSearch_ThenResetsToInitialState() {
        // Given: Search results are displayed
        viewModel.searchText = "test query"
        viewModel.searchResults = [
            .podcast(Podcast(id: "p1", title: "Test", feedURL: URL(string: "https://example.com")!), relevanceScore: 0.9)
        ]
        
        // When: Clearing search
        viewModel.clearSearch()
        
        // Then: Should reset to initial state
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testSearchHistoryUsage_GivenSearchHistory_WhenSelectingHistoryItem_ThenPopulatesSearchField() {
        // Given: Search history exists
        viewModel.searchHistory = ["previous search", "another search"]
        
        // When: Selecting a history item
        viewModel.useSearchFromHistory("previous search")
        
        // Then: Should populate search field
        XCTAssertEqual(viewModel.searchText, "previous search")
    }
    
    @MainActor
    func testClearSearchHistory_GivenSearchHistoryExists_WhenClearing_ThenHistoryEmptied() {
        // Given: Search history exists
        viewModel.searchHistory = ["search1", "search2", "search3"]
        
        // When: Clearing history
        viewModel.clearSearchHistory()
        
        // Then: History should be emptied
        XCTAssertTrue(viewModel.searchHistory.isEmpty)
    }

    // MARK: - Directory Service Integration Tests

    @MainActor
    func testDirectorySearch_GivenDirectoryService_WhenSearching_ThenExternalResultsMergedWithLocal() async {
        // Given: A view model with a directory service
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = DirectorySearchResult(
            id: "ext-1",
            title: "External Podcast",
            author: "External Author",
            feedURL: URL(string: "https://external.com/feed.xml")!,
            episodeCount: 10,
            provider: "itunes"
        )
        mockDirectoryService.mockResults = [externalPodcast]

        let localPodcast = Podcast(id: "local-1", title: "Local Podcast", feedURL: URL(string: "https://local.com/feed.xml")!)
        mockSearchService.mockResults = [.podcast(localPodcast, relevanceScore: 0.9)]

        let vmWithDirectory = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )

        // When: Searching
        vmWithDirectory.searchText = "podcast"
        await vmWithDirectory.search()

        // Then: Results contain both local and external entries
        XCTAssertEqual(vmWithDirectory.searchResults.count, 2)
        let titles = vmWithDirectory.searchResults.compactMap { result -> String? in
            if case .podcast(let p, _) = result { return p.title }
            return nil
        }
        XCTAssertTrue(titles.contains("Local Podcast"))
        XCTAssertTrue(titles.contains("External Podcast"))
        XCTAssertFalse(vmWithDirectory.isSearchingDirectory)
    }

    @MainActor
    func testDirectorySearch_GivenDuplicateFeedURL_WhenMerging_ThenLocalResultTakesPrecedence() async {
        // Given: Local and external results sharing the same feed URL
        let sharedURL = URL(string: "https://shared.com/feed.xml")!
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = DirectorySearchResult(
            id: "ext-dup",
            title: "External Duplicate",
            author: "External Author",
            feedURL: sharedURL,
            episodeCount: 5,
            provider: "itunes"
        )
        mockDirectoryService.mockResults = [externalPodcast]

        let localPodcast = Podcast(id: "local-dup", title: "Local Version", feedURL: sharedURL)
        mockSearchService.mockResults = [.podcast(localPodcast, relevanceScore: 0.9)]

        let vmWithDirectory = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )

        // When: Searching
        vmWithDirectory.searchText = "duplicate"
        await vmWithDirectory.search()

        // Then: Only the local result is kept (no duplicate)
        XCTAssertEqual(vmWithDirectory.searchResults.count, 1)
        if case .podcast(let p, _) = vmWithDirectory.searchResults.first {
            XCTAssertEqual(p.title, "Local Version")
        } else {
            XCTFail("Expected podcast result")
        }
    }

    @MainActor
    func testDirectorySearch_GivenServiceFailure_WhenSearching_ThenLocalResultsStillShown() async {
        // Given: A directory service that throws errors
        let mockDirectoryService = MockDirectoryService()
        mockDirectoryService.shouldThrowError = true

        let localPodcast = Podcast(id: "local-1", title: "Local Podcast", feedURL: URL(string: "https://local.com/feed.xml")!)
        mockSearchService.mockResults = [.podcast(localPodcast, relevanceScore: 0.9)]

        let vmWithDirectory = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )

        // When: Searching (directory call fails)
        vmWithDirectory.searchText = "podcast"
        await vmWithDirectory.search()

        // Then: Local results are still displayed, no crash
        XCTAssertEqual(vmWithDirectory.searchResults.count, 1)
        if case .podcast(let p, _) = vmWithDirectory.searchResults.first {
            XCTAssertEqual(p.title, "Local Podcast")
        } else {
            XCTFail("Expected podcast result")
        }
        XCTAssertNil(vmWithDirectory.errorMessage)
        XCTAssertFalse(vmWithDirectory.isSearchingDirectory)
    }

    @MainActor
    func testSubscribeExternalPodcast_GivenNoEpisodesAndDirectoryService_WhenSubscribing_ThenFetchesFeedFirst() async {
        // Given: A view model with directory service and an external podcast (no episodes)
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = Podcast(
            id: "ext-1",
            title: "External Podcast",
            feedURL: URL(string: "https://external.com/feed.xml")!,
            isSubscribed: false
        )

        let fullPodcast = Podcast(
            id: "ext-1",
            title: "External Podcast",
            feedURL: URL(string: "https://external.com/feed.xml")!,
            isSubscribed: false
        )
        mockRSSParser.mockPodcast = fullPodcast

        let vmWithDirectory = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )

        // When: Subscribing to the external podcast
        vmWithDirectory.subscribe(to: externalPodcast)

        // Wait deterministically for the unstructured Task spawned by subscribe(to:) to complete.
        // Using XCTNSPredicateExpectation instead of Task.sleep to avoid fixed-time flakiness.
        let manager = mockPodcastManager!
        let podcastAdded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in manager.all().count >= 1 },
            object: nil
        )
        await fulfillment(of: [podcastAdded], timeout: 5)

        // Then: RSS parser was called to fetch full feed before subscribing
        XCTAssertTrue(mockRSSParser.parseFeedCalled, "RSS parser should be called for external podcasts with no episodes")
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 1)
    }

    @MainActor
    func testIsSearchingDirectory_GivenDirectoryService_WhenNoDirectoryService_ThenFalse() async {
        // Given: A view model WITHOUT directory service
        viewModel.searchText = "test"
        await viewModel.search()

        // Then: isSearchingDirectory should never be true when no service configured
        XCTAssertFalse(viewModel.isSearchingDirectory)
    }

    // MARK: - Already Subscribed Edge Case (spec: "Already subscribed" badge)

    @MainActor
    func testSearch_GivenAlreadySubscribedPodcast_WhenResultReturned_ThenIsSubscribedFlagIsTrue() async {
        // Given: A podcast that the user already subscribes to
        let subscribedPodcast = Podcast(
            id: "subscribed-pod",
            title: "Already Subscribed Show",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            isSubscribed: true
        )
        mockSearchService.mockResults = [.podcast(subscribedPodcast, relevanceScore: 0.9)]

        // When: User searches and the subscribed podcast appears in results
        viewModel.searchText = "subscribed show"
        await viewModel.search()

        // Then: The result carries isSubscribed=true so the view renders the badge, not the Subscribe button
        XCTAssertEqual(viewModel.searchResults.count, 1)
        if case .podcast(let p, _) = viewModel.searchResults.first {
            XCTAssertTrue(p.isSubscribed, "Result for an already-subscribed podcast must have isSubscribed=true")
        } else {
            XCTFail("Expected a podcast search result")
        }
    }

    // MARK: - No Results Empty State (spec: "No results found" empty state)

    @MainActor
    func testSearch_GivenNoMatchingResults_WhenQueryReturnsEmpty_ThenSearchResultsIsEmpty() async {
        // Given: Search service returns no results
        mockSearchService.mockResults = []

        // When: User searches for something that matches nothing
        viewModel.searchText = "xyzzy no match"
        await viewModel.search()

        // Then: searchResults is empty — the view renders the "No results found" empty state
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertFalse(viewModel.searchText.isEmpty, "searchText must still be non-empty to trigger the empty-state branch")
    }

    // MARK: - episodeCountMap Tests

    @MainActor
    func testEpisodeCountMap_GivenDirectoryResults_WhenSearching_ThenPopulated() async {
        // Given: directory service returns results with episode counts
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = DirectorySearchResult(
            id: "ext-1",
            title: "External Show",
            feedURL: URL(string: "https://ext.com/feed.xml")!,
            episodeCount: 42,
            provider: "itunes"
        )
        mockDirectoryService.mockResults = [externalPodcast]

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )
        vm.searchText = "show"
        await vm.search()

        // Then: episodeCountMap keyed by feed URL string
        XCTAssertEqual(vm.episodeCountMap["https://ext.com/feed.xml"], 42,
            "episodeCountMap should be populated with episode count from directory result")
    }

    @MainActor
    func testEpisodeCountMap_GivenNilEpisodeCount_WhenSearching_ThenNotAdded() async {
        // Given: directory result without episode count
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = DirectorySearchResult(
            id: "ext-2",
            title: "No Count Show",
            feedURL: URL(string: "https://nocount.com/feed.xml")!,
            episodeCount: nil,
            provider: "itunes"
        )
        mockDirectoryService.mockResults = [externalPodcast]

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )
        vm.searchText = "no count"
        await vm.search()

        // Then: episodeCountMap is empty (nil episode counts are not stored)
        XCTAssertTrue(vm.episodeCountMap.isEmpty,
            "episodeCountMap should not contain entries for results without episode counts")
    }

    @MainActor
    func testEpisodeCountMap_WhenClearSearch_ThenCleared() async {
        // Given: a completed directory search that populated the map
        let mockDirectoryService = MockDirectoryService()
        let externalPodcast = DirectorySearchResult(
            id: "ext-3",
            title: "Clearable Show",
            feedURL: URL(string: "https://clearable.com/feed.xml")!,
            episodeCount: 10,
            provider: "itunes"
        )
        mockDirectoryService.mockResults = [externalPodcast]

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )
        vm.searchText = "clearable"
        await vm.search()
        XCTAssertFalse(vm.episodeCountMap.isEmpty, "Precondition: map should be non-empty after search")

        // When: clearing the search
        vm.clearSearch()

        // Then: map is cleared
        XCTAssertTrue(vm.episodeCountMap.isEmpty,
            "episodeCountMap should be cleared when clearSearch() is called")
    }

    // MARK: - Filter-aware Directory Search Tests

    @MainActor
    func testDirectorySearch_GivenEpisodesOnlyFilter_WhenSearching_ThenDirectorySkipped() async {
        // Given: directory service configured but filter excludes podcasts
        let mockDirectoryService = MockDirectoryService()
        mockDirectoryService.mockResults = [
            DirectorySearchResult(
                id: "ext-1", title: "Some Podcast",
                feedURL: URL(string: "https://example.com/feed.xml")!,
                provider: "itunes"
            )
        ]

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )
        vm.currentFilter = .episodesOnly
        vm.searchText = "podcast"
        await vm.search()

        // Then: directory results not merged; isSearchingDirectory was never set
        XCTAssertFalse(vm.isSearchingDirectory, "isSearchingDirectory should be false for episodes-only filter")
        // episodeCountMap should be empty because directory was not queried
        XCTAssertTrue(vm.episodeCountMap.isEmpty,
            "episodeCountMap should be empty when directory search is skipped")
    }

    @MainActor
    func testDirectorySearch_GivenNotesOnlyFilter_WhenSearching_ThenDirectorySkipped() async {
        // Given: notes-only filter (no podcasts)
        let mockDirectoryService = MockDirectoryService()
        mockDirectoryService.mockResults = [
            DirectorySearchResult(
                id: "ext-1", title: "Some Podcast",
                feedURL: URL(string: "https://example.com/feed.xml")!,
                provider: "itunes"
            )
        ]

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )
        vm.currentFilter = .notesOnly
        vm.searchText = "note"
        await vm.search()

        XCTAssertFalse(vm.isSearchingDirectory, "isSearchingDirectory should be false for notes-only filter")
        XCTAssertTrue(vm.episodeCountMap.isEmpty)
    }

    // MARK: - subscribeByFetchingFeed Fallback Tests

    @MainActor
    func testSubscribeByFetchingFeed_GivenRSSParseFailure_WhenSubscribing_ThenFallsBackToDirectoryMetadata() async {
        // Given: RSS parser throws; directory service configured
        let mockDirectoryService = MockDirectoryService()
        mockRSSParser.shouldThrowError = true

        let externalPodcast = Podcast(
            id: "rss-fail-1",
            title: "RSS Fail Podcast",
            feedURL: URL(string: "https://rssfail.com/feed.xml")!,
            isSubscribed: false
        )

        let vm = await SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: mockDirectoryService
        )

        // When: subscribing to an external podcast (no episodes) whose RSS fails
        vm.subscribe(to: externalPodcast)

        // Wait for the async subscribe task to complete
        let manager = mockPodcastManager!
        let podcastAdded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in manager.all().count >= 1 },
            object: nil
        )
        await fulfillment(of: [podcastAdded], timeout: 5)

        // Then: falls back to persistSubscription (podcast added with directory metadata)
        XCTAssertEqual(mockPodcastManager.addedPodcasts.count, 1,
            "Podcast should be subscribed via fallback even when RSS parse fails")
        if let subscribed = mockPodcastManager.addedPodcasts.first {
            XCTAssertTrue(subscribed.isSubscribed, "Fallback-subscribed podcast must have isSubscribed=true")
            XCTAssertTrue(subscribed.episodes.isEmpty,
                "Fallback subscription has no episodes since RSS parse failed")
        }
    }

    // MARK: - Stale search guard tests

    @MainActor
    func testStaleSearch_WhenSearchTextChangedBeforeExternalResultsArrive_DoesNotResetIsSearching() async {
        // Given: a directory service that blocks until explicitly signaled.
        // This lets the test control exactly when the external task finishes
        // so we can reproduce the race without timing-based sleeps.
        let gatedDirectory = GatedMockDirectoryService()

        let vm = SearchViewModel(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: mockRSSParser,
            directoryService: gatedDirectory
        )

        // When: search("pod") starts — the gated directory service blocks the external task
        vm.searchText = "pod"
        let firstSearchTask = Task { @MainActor in await vm.search() }

        // Yield so the first search reaches the gated await inside fetchDirectoryResults
        await Task.yield()
        await Task.yield()

        // Change searchText — makes the first search stale
        vm.searchText = "podcast"

        // Start a second search (simulates what the debouncer fires after the edit)
        let secondSearchTask = Task { @MainActor in await vm.search() }
        await Task.yield()
        await Task.yield()

        // Unblock BOTH directory calls so both searches can finish
        gatedDirectory.unblockAll()

        // Wait for both searches to complete
        await firstSearchTask.value
        await secondSearchTask.value

        // Then: isSearching must be false — the second search completed cleanly and
        // the stale first search must NOT have clobbered the loading flag
        XCTAssertFalse(vm.isSearching,
            "isSearching should be false after both searches complete; stale guard must not reset it mid-flight")
    }
}

// MARK: - Mock Implementations

/// Directory service that blocks each search() call until the test calls unblockAll().
/// Used to deterministically reproduce stale-search race conditions.
private final class GatedMockDirectoryService: PodcastDirectorySearching, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var shouldUnblock = false

    func search(query: String, limit: Int) async throws -> [DirectorySearchResult] {
        await withCheckedContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }
            if shouldUnblock {
                continuation.resume()
            } else {
                continuations.append(continuation)
            }
        }
        return []
    }

    /// Unblocks all currently pending and future search() calls.
    func unblockAll() {
        lock.lock()
        let pending = continuations
        continuations = []
        shouldUnblock = true
        lock.unlock()
        for cont in pending { cont.resume() }
    }
}

private final class MockDirectoryService: PodcastDirectorySearching, @unchecked Sendable {
    var mockResults: [DirectorySearchResult] = []
    var shouldThrowError = false

    func search(query: String, limit: Int) async throws -> [DirectorySearchResult] {
        if shouldThrowError {
            throw NSError(domain: "MockDirectoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock directory error"])
        }
        return mockResults
    }
}

private final class MockSearchService: SearchServicing, @unchecked Sendable {
    var mockResults: [SearchResult] = []
    var shouldThrowError = false
    var searchCalled = false
    var lastQuery: String = ""
    var lastFilter: SearchFilter?
    
    func search(query: String, filter: SearchFilter?) async -> [SearchResult] {
        searchCalled = true
        lastQuery = query
        lastFilter = filter
        
        if shouldThrowError {
            return []
        }
        
        return mockResults
    }
    
    func rebuildIndex() async {
        // Mock implementation
    }
}

private final class MockRSSParser: RSSFeedParsing, @unchecked Sendable {
    var mockPodcast: Podcast?
    var shouldThrowError = false
    var parseFeedCalled = false

    func parseFeed(from url: URL) async throws -> Podcast {
        parseFeedCalled = true
        if shouldThrowError {
            throw NSError(domain: "MockRSSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock RSS parsing error"])
        }

        return mockPodcast ?? Podcast(
            id: "mock-podcast",
            title: "Mock Podcast",
            feedURL: url
        )
    }
}

private final class MockPodcastManager: PodcastManaging, @unchecked Sendable {
    var addedPodcasts: [Podcast] = []
    private let lock = NSLock()
    
    func all() -> [Podcast] {
        lock.lock()
        defer { lock.unlock() }
        return addedPodcasts
    }
    
    func find(id: String) -> Podcast? {
        lock.lock()
        defer { lock.unlock() }
        return addedPodcasts.first { $0.id == id }
    }
    
    func add(_ podcast: Podcast) {
        lock.lock()
        defer { lock.unlock() }
        addedPodcasts.append(podcast)
    }
    
    func update(_ podcast: Podcast) {
        lock.lock()
        defer { lock.unlock() }
        if let index = addedPodcasts.firstIndex(where: { $0.id == podcast.id }) {
            addedPodcasts[index] = podcast
        }
    }
    
    func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        addedPodcasts.removeAll { $0.id == id }
    }

    func findByFolder(folderId: String) -> [Podcast] { [] }

    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] { [] }

    func findByTag(tagId: String) -> [Podcast] { [] }

    func findUnorganized() -> [Podcast] { [] }

    func fetchOrphanedEpisodes() -> [Episode] { [] }

    func deleteOrphanedEpisode(id: String) -> Bool { false }

    func deleteAllOrphanedEpisodes() -> Int { 0 }
}
