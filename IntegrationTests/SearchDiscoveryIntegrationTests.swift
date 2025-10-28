import XCTest
@testable import CoreModels
@testable import TestSupport
@testable import SearchDomain
@testable import DiscoverFeature

/// Integration tests for search and discovery workflows
///
/// **Specifications Covered**: Discovery and search workflows (Issue 01.1.1)
/// - Complete subscription and discovery workflows
/// - Search integration with organized content
/// - RSS feed URL addition
/// - Advanced search across all content
/// - Search performance and real-time results
final class SearchDiscoveryIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var searchService: SearchService!
    private var searchViewModel: SearchViewModel!
    private var searchDefaultsSuiteName: String!
    private var searchDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        searchDefaultsSuiteName = "SearchDiscoveryIntegrationTests.\(UUID().uuidString)"
        guard let suiteDefaults = UserDefaults(suiteName: searchDefaultsSuiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        searchDefaults = suiteDefaults
        searchDefaults.removePersistentDomain(forName: searchDefaultsSuiteName)

        let setupExpectation = expectation(description: "Setup main actor components")

        Task { @MainActor in
            searchService = SearchService(
                indexSources: [
                    PodcastIndexSource(podcastManager: podcastManager),
                    EpisodeIndexSource(podcastManager: podcastManager)
                ]
            )

            searchViewModel = SearchViewModel(
                searchService: searchService,
                podcastManager: podcastManager,
                rssParser: MockRSSParser(),
                userDefaults: searchDefaults
            )
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 5.0)
    }
    
    override func tearDown() {
        searchViewModel = nil
        searchService = nil
        folderManager = nil
        podcastManager = nil
        if let searchDefaultsSuiteName {
            searchDefaults?.removePersistentDomain(forName: searchDefaultsSuiteName)
        }
        searchDefaults = nil
        searchDefaultsSuiteName = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func rebuildSearchIndex() async {
        await searchService.rebuildIndex()
    }

    private func searchPodcasts(
        _ query: String,
        filter: SearchFilter = .podcastsOnly
    ) async -> [Podcast] {
        let results = await searchService.search(query: query, filter: filter)
        return results.compactMap { result in
            if case .podcast(let podcast, _) = result {
                return podcast
            }
            return nil
        }
    }
    
    // MARK: - Issue 01.1.1: Search and Discovery Integration Tests
    
    @MainActor
    func testIssue01_1_1_CompleteSearchAndSubscriptionWorkflow() async throws {
        // Scenario 1: Basic Podcast Search and Discovery
        // Given: I am on the Discover tab with an active internet connection
        
        // Simulate some podcasts available for discovery
        let availablePodcasts = [
            Podcast(
                id: "swift-talk",
                title: "Swift Talk",
                author: "objc.io",
                description: "A weekly video series on Swift programming",
                feedURL: URL(string: "https://talk.objc.io/podcast.xml")!,
                categories: ["Technology", "Programming"],
                isSubscribed: false
            ),
            Podcast(
                id: "ios-dev-weekly",
                title: "iOS Dev Weekly Podcast",
                author: "Dave Verwer",
                description: "Weekly iOS development news and tips",
                feedURL: URL(string: "https://iosdevweekly.com/podcast.xml")!,
                categories: ["Technology", "iOS"],
                isSubscribed: false
            ),
            Podcast(
                id: "design-better",
                title: "Design Better",
                author: "InVision",
                description: "A show about design and product development",
                feedURL: URL(string: "https://invision.com/design-better.xml")!,
                categories: ["Design", "Business"],
                isSubscribed: false
            )
        ]
        
        // Add podcasts to search index to simulate discovery
        for podcast in availablePodcasts {
            podcastManager.add(podcast)
        }
        await searchService.rebuildIndex()
        await searchService.rebuildIndex()
        
        // When: I search for "Swift Talk" podcast using keywords
        searchViewModel.searchText = "Swift Talk"
        await searchViewModel.search()
        
        // Then: I should see relevant podcast results with artwork, titles, descriptions, and ratings
        XCTAssertFalse(searchViewModel.searchResults.isEmpty, "Search should return results")
        XCTAssertFalse(searchViewModel.isSearching, "Search should be completed")
        XCTAssertNil(searchViewModel.errorMessage, "Search should not have errors")
        
        guard case .podcast(let foundPodcast, let relevanceScore) = searchViewModel.searchResults.first else {
            XCTFail("First result should be a podcast")
            return
        }
        
        XCTAssertEqual(foundPodcast.title, "Swift Talk")
        XCTAssertEqual(foundPodcast.author, "objc.io")
        XCTAssertTrue(foundPodcast.description?.contains("Swift programming") == true)
        XCTAssertGreaterThan(relevanceScore, 0.0)
        
        // And: I should be able to tap "Subscribe" to add the podcast to my library
        XCTAssertFalse(foundPodcast.isSubscribed, "Podcast should not be subscribed initially")
        
        // When: I subscribe to the podcast
        searchViewModel.subscribe(to: foundPodcast)
        
        // Then: The subscription should appear immediately in my Library with proper metadata
        let subscribedPodcasts = podcastManager.all().filter { $0.isSubscribed }
        XCTAssertEqual(subscribedPodcasts.count, 1)
        
        let subscribedPodcast = subscribedPodcasts.first!
        XCTAssertEqual(subscribedPodcast.id, "swift-talk")
        XCTAssertEqual(subscribedPodcast.title, "Swift Talk")
        XCTAssertTrue(subscribedPodcast.isSubscribed)
        XCTAssertNotNil(subscribedPodcast.dateAdded)
    }
    
    @MainActor
    func testIssue01_1_1_AdvancedSearchAcrossAllContent() async throws {
        // Scenario 2: Advanced Search Across All Content
        // Given: I want to search across all podcasts, episodes, and show notes
        
        let podcast = Podcast(
            id: "tech-podcast",
            title: "Tech Weekly",
            author: "Tech Network",
            description: "Weekly technology discussions",
            feedURL: URL(string: "https://example.com/tech.xml")!,
            categories: ["Technology"]
        )
        
        // Add podcast to library for indexing
        podcastManager.add(podcast)
        await searchService.rebuildIndex()
        
        // When: I use the unified search interface with text query
        searchViewModel.searchText = "technology"
        await searchViewModel.search()
        
        // Then: Results should include podcasts, individual episodes, and show note content
        XCTAssertFalse(searchViewModel.searchResults.isEmpty, "Should find results for technology")
        
        // And: I should be able to filter results by content type
        searchViewModel.currentFilter = .podcastsOnly
        await searchViewModel.search()
        
        // Verify filtering works
        for result in searchViewModel.searchResults {
            switch result {
            case .podcast(_, _):
                XCTAssertTrue(true, "Should only contain podcast results")
            case .episode(_, _), .note(_, _):
                XCTFail("Should not contain non-podcast results when filtering by podcasts only")
            }
        }
        
        // And: I should be able to subscribe to podcasts directly from search results
        if case .podcast(let foundPodcast, _) = searchViewModel.searchResults.first {
            searchViewModel.subscribe(to: foundPodcast)
            let subscribed = podcastManager.find(id: foundPodcast.id)
            XCTAssertTrue(subscribed?.isSubscribed == true)
        }
    }
    
    @MainActor
    func testIssue01_1_1_SearchPerformanceAndRealTimeResults() async throws {
        // Scenario 3: Search Performance and Real-time Results
        // Given: I am typing in the search field
        
        let testPodcast = Podcast(
            id: "performance-test",
            title: "Performance Test Podcast",
            feedURL: URL(string: "https://example.com/performance.xml")!
        )
        
        podcastManager.add(testPodcast)
        await searchService.rebuildIndex()
        
        // When: I enter search terms with real-time feedback
        let startTime = Date()
        searchViewModel.searchText = "Performance"
        await searchViewModel.search()
        let endTime = Date()
        
        // Then: Search results should appear within 2 seconds with debounced queries
        let searchDuration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(searchDuration, 2.0, "Search should complete within 2 seconds")
        XCTAssertFalse(searchViewModel.searchResults.isEmpty, "Should find performance test podcast")
        
        // And: Recent searches should be saved and easily accessible
        XCTAssertTrue(searchViewModel.searchHistory.contains("Performance"), "Search should be added to history")
        
        // Test search history functionality
        searchViewModel.searchText = "Another Search"
        await searchViewModel.search()
        
        XCTAssertEqual(searchViewModel.searchHistory.count, 2)
        XCTAssertEqual(searchViewModel.searchHistory.first, "Another Search")
        XCTAssertEqual(searchViewModel.searchHistory.last, "Performance")
        
        // Test using search from history
        searchViewModel.useSearchFromHistory("Performance")
        XCTAssertEqual(searchViewModel.searchText, "Performance")
        
        // Test clearing search history
        searchViewModel.clearSearchHistory()
        XCTAssertTrue(searchViewModel.searchHistory.isEmpty)
    }
    
    @MainActor
    func testIssue01_1_1_RSSFeedURLAddition() async throws {
        // Scenario 4: Adding Podcast by Direct RSS Feed URL
        // Given: I know the RSS feed URL of a podcast
        
        let mockParser = MockRSSParser()
        searchViewModel = SearchViewModel(
            searchService: searchService,
            podcastManager: podcastManager,
            rssParser: mockParser,
            userDefaults: searchDefaults
        )
        
        let expectedPodcast = Podcast(
            id: "rss-test-podcast",
            title: "RSS Test Podcast",
            author: "RSS Author",
            description: "A podcast added via RSS URL",
            feedURL: URL(string: "https://example.com/rss-test.xml")!
        )
        
        mockParser.mockPodcast = expectedPodcast
        
        // When: I select "Add by RSS Feed URL" and enter the URL
        searchViewModel.rssURL = "https://example.com/rss-test.xml"
        await searchViewModel.addPodcastByRSSURL()
        
        // Then: The app should validate the feed and add the podcast with proper error handling
        XCTAssertEqual(podcastManager.all().count, 1)
        
        let addedPodcast = podcastManager.all().first!
        XCTAssertEqual(addedPodcast.id, "rss-test-podcast")
        XCTAssertEqual(addedPodcast.title, "RSS Test Podcast")
        XCTAssertTrue(addedPodcast.isSubscribed)
        XCTAssertEqual(searchViewModel.rssURL, "") // Should clear URL after success
        XCTAssertNil(searchViewModel.errorMessage)
        XCTAssertFalse(searchViewModel.isAddingRSSFeed)
        
        // Test error handling for invalid URLs
        searchViewModel.rssURL = ""
        await searchViewModel.addPodcastByRSSURL()

        XCTAssertEqual(searchViewModel.errorMessage, "Invalid RSS feed URL")
        XCTAssertFalse(searchViewModel.isAddingRSSFeed)

        // Test error handling for parsing failures
        mockParser.shouldThrowError = true
        searchViewModel.rssURL = "https://example.com/broken-feed.xml"
        await searchViewModel.addPodcastByRSSURL()
        
        XCTAssertNotNil(searchViewModel.errorMessage)
        XCTAssertTrue(searchViewModel.errorMessage?.contains("Failed to add RSS feed") == true)
        XCTAssertFalse(searchViewModel.isAddingRSSFeed)
    }
    
    @MainActor
    func testIssue01_1_1_EndToEndDiscoveryWorkflow() async throws {
        // Complete workflow test covering all scenarios
        // Given: User wants to discover, search, and subscribe to podcasts
        
        let availablePodcasts = [
            Podcast(id: "swift-1", title: "Swift Programming", feedURL: URL(string: "https://example.com/swift1.xml")!),
            Podcast(id: "swift-2", title: "Swift Weekly", feedURL: URL(string: "https://example.com/swift2.xml")!)
        ]
        
        // Add to search index
        for podcast in availablePodcasts {
            podcastManager.add(podcast)
        }

        await searchService.rebuildIndex()
        let serviceResults = await searchService.search(query: "Swift", filter: .podcastsOnly)
        XCTAssertEqual(serviceResults.count, 2)

        // Step 1: Search for content
        searchViewModel.searchText = "Swift"
        await searchViewModel.search()
        
        XCTAssertEqual(searchViewModel.searchResults.count, 2) // Two Swift podcasts
        
        // Step 2: Filter results
        searchViewModel.currentFilter = .podcastsOnly
        await searchViewModel.search()
        
        XCTAssertEqual(searchViewModel.searchResults.count, 2) // Still two podcast results
        
        // Step 3: Subscribe to podcasts from results
        if case .podcast(let firstPodcast, _) = searchViewModel.searchResults.first {
            searchViewModel.subscribe(to: firstPodcast)
        }
        
        if case .podcast(let secondPodcast, _) = searchViewModel.searchResults.last {
            searchViewModel.subscribe(to: secondPodcast)
        }
        
        // Verify subscriptions
        let subscribedPodcasts = podcastManager.all().filter { $0.isSubscribed }
        XCTAssertEqual(subscribedPodcasts.count, 2)
        
        // Step 4: Add RSS feed directly
        let mockParser = MockRSSParser()
        searchViewModel = SearchViewModel(
            searchService: searchService,
            podcastManager: podcastManager,
            rssParser: mockParser,
            userDefaults: searchDefaults
        )
        
        mockParser.mockPodcast = Podcast(
            id: "rss-direct",
            title: "Direct RSS Podcast",
            feedURL: URL(string: "https://example.com/direct.xml")!
        )
        
        searchViewModel.rssURL = "https://example.com/direct.xml"
        await searchViewModel.addPodcastByRSSURL()
        
        // Verify total podcasts
        let totalPodcasts = podcastManager.all()
        XCTAssertEqual(totalPodcasts.count, 3) // 2 from search + 1 from RSS
        XCTAssertTrue(totalPodcasts.allSatisfy { $0.isSubscribed })
        
        // Step 5: Verify search history
        XCTAssertEqual(searchViewModel.searchHistory.count, 1)
        XCTAssertEqual(searchViewModel.searchHistory.first, "Swift")
        
        // Complete workflow validation
        XCTAssertNil(searchViewModel.errorMessage, "No errors should occur in complete workflow")
        XCTAssertFalse(searchViewModel.isSearching, "Search should be completed")
        XCTAssertFalse(searchViewModel.isAddingRSSFeed, "RSS addition should be completed")
    }
    
    // MARK: - Search and Content Discovery Integration Tests
    
    func testSearchAndDiscoveryIntegration() async throws {
        // Given: User has organized library and wants to search across it
        let folders = [
            Folder(id: "tech", name: "Technology"),
            Folder(id: "entertainment", name: "Entertainment")
        ]
        
        folders.forEach { try? folderManager.add($0) }
        
        let podcasts = [
            Podcast(
                id: "swift-pod",
                title: "Swift Programming Guide",
                description: "Learn Swift programming from experts",
                feedURL: URL(string: "https://example.com/swift.xml")!,
                folderId: "tech",
                tagIds: ["swift", "programming", "education"]
            ),
            Podcast(
                id: "comedy-pod",
                title: "Comedy Hour",
                description: "Weekly comedy show",
                feedURL: URL(string: "https://example.com/comedy.xml")!,
                folderId: "entertainment",
                tagIds: ["comedy", "entertainment"]
            ),
            Podcast(
                id: "swift-music",
                title: "Taylor Swift Music Review",
                description: "Reviews of Taylor Swift albums",
                feedURL: URL(string: "https://example.com/swift-music.xml")!,
                folderId: "entertainment",
                tagIds: ["music", "entertainment"]
            )
        ]
        
        // When: User builds library and searches
        podcasts.forEach { podcastManager.add($0) }
        await rebuildSearchIndex()
        
        // Then: Search should work across different organization dimensions
        
        // General search
        let swiftResults = await searchPodcasts("Swift")
        XCTAssertEqual(swiftResults.count, 2) // Programming guide + music review

        // Folder-scoped search
        let techSwiftResults = swiftResults.filter { $0.folderId == "tech" }
        XCTAssertEqual(techSwiftResults.count, 1)
        XCTAssertEqual(techSwiftResults.first?.title, "Swift Programming Guide")

        let entertainmentSwiftResults = swiftResults.filter { $0.folderId == "entertainment" }
        XCTAssertEqual(entertainmentSwiftResults.count, 1)
        XCTAssertEqual(entertainmentSwiftResults.first?.title, "Taylor Swift Music Review")

        // Tag-scoped search
        let programmingResults = await searchPodcasts("programming")
        let programmingTagged = programmingResults.filter { $0.tagIds.contains("programming") }
        XCTAssertEqual(programmingResults.count, 1)
        XCTAssertEqual(programmingTagged.count, 1)
        XCTAssertEqual(programmingTagged.first?.title, "Swift Programming Guide")
        
        // Cross-organization filtering
        let techPodcasts = podcastManager.findByFolder(folderId: "tech")
        let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
        let educationPodcasts = podcastManager.findByTag(tagId: "education")
        
        XCTAssertEqual(techPodcasts.count, 1)
        XCTAssertEqual(programmingPodcasts.count, 1)
        XCTAssertEqual(educationPodcasts.count, 1)
        
        // All should reference the same podcast
        XCTAssertEqual(techPodcasts.first?.id, programmingPodcasts.first?.id)
        XCTAssertEqual(programmingPodcasts.first?.id, educationPodcasts.first?.id)
    }
}
