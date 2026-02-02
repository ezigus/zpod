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
}

// MARK: - Mock Implementations

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
    
    func parseFeed(from url: URL) async throws -> Podcast {
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
