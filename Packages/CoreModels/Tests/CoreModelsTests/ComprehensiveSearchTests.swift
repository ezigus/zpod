import XCTest
@testable import CoreModels

/// Comprehensive unit tests for Search models based on spec requirements
final class ComprehensiveSearchTests: XCTestCase {
    
    // MARK: - Test Data
    private var samplePodcast: Podcast!
    private var sampleEpisode: Episode!
    private var sampleNote: Note!
    private let testDate = Date(timeIntervalSince1970: 1642684800) // Fixed date for consistency
    
    override func setUp() async throws {
        try await super.setUp()
        
        samplePodcast = Podcast(
            id: "tech-podcast",
            title: "Swift Programming Podcast",
            author: "iOS Developer",
            description: "A comprehensive podcast about Swift programming and iOS development.",
            artworkURL: URL(string: "https://example.com/swift-artwork.jpg"),
            feedURL: URL(string: "https://example.com/swift-feed.xml")!,
            categories: ["Technology", "Programming", "iOS"],
            episodes: [],
            isSubscribed: true,
            dateAdded: testDate,
            folderId: nil,
            tagIds: ["swift", "ios"]
        )
        
        sampleEpisode = Episode(
            id: "swift-episode",
            title: "Advanced Swift Concurrency Patterns",
            podcastID: "tech-podcast",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: testDate,
            duration: 3600.0,
            description: "Deep dive into Swift 6 concurrency features including async/await, actors, and Sendable protocols.",
            audioURL: URL(string: "https://example.com/swift-concurrency.mp3")
        )
        
        sampleNote = Note(
            id: "note-1",
            content: "Great explanation of actor isolation and data races in Swift concurrency.",
            timestamp: 1800.0, // 30 minutes into episode
            episodeId: "swift-episode",
            createdAt: testDate
        )
    }
    
    // MARK: - SearchResult Tests
    
    func testSearchResult_PodcastResult() {
        // Given: A podcast search result with relevance score
        // When: Creating podcast search result
        let podcastResult = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        
        // Then: Should properly encapsulate podcast and score
        if case .podcast(let podcast, let score) = podcastResult {
            XCTAssertEqual(podcast.id, samplePodcast.id)
            XCTAssertEqual(podcast.title, samplePodcast.title)
            XCTAssertEqual(score, 0.95, accuracy: 0.001)
        } else {
            XCTFail("Should be podcast result")
        }
    }
    
    func testSearchResult_EpisodeResult() {
        // Given: An episode search result with relevance score
        // When: Creating episode search result
        let episodeResult = SearchResult.episode(sampleEpisode, relevanceScore: 0.87)
        
        // Then: Should properly encapsulate episode and score
        if case .episode(let episode, let score) = episodeResult {
            XCTAssertEqual(episode.id, sampleEpisode.id)
            XCTAssertEqual(episode.title, sampleEpisode.title)
            XCTAssertEqual(score, 0.87, accuracy: 0.001)
        } else {
            XCTFail("Should be episode result")
        }
    }
    
    func testSearchResult_NoteResult() {
        // Given: A note search result with relevance score
        // When: Creating note search result
        let noteResult = SearchResult.note(sampleNote, relevanceScore: 0.72)
        
        // Then: Should properly encapsulate note and score
        if case .note(let note, let score) = noteResult {
            XCTAssertEqual(note.id, sampleNote.id)
            XCTAssertEqual(note.content, sampleNote.content)
            XCTAssertEqual(score, 0.72, accuracy: 0.001)
        } else {
            XCTFail("Should be note result")
        }
    }
    
    // MARK: - SearchResult Equality Tests
    
    func testSearchResult_PodcastEquality_SameContent() {
        // Given: Two identical podcast search results
        let result1 = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        let result2 = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(result1, result2)
    }
    
    func testSearchResult_PodcastEquality_DifferentScore() {
        // Given: Two podcast search results with different scores
        let result1 = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        let result2 = SearchResult.podcast(samplePodcast, relevanceScore: 0.85)
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(result1, result2)
    }
    
    func testSearchResult_EpisodeEquality_SameContent() {
        // Given: Two identical episode search results
        let result1 = SearchResult.episode(sampleEpisode, relevanceScore: 0.87)
        let result2 = SearchResult.episode(sampleEpisode, relevanceScore: 0.87)
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(result1, result2)
    }
    
    func testSearchResult_NoteEquality_SameContent() {
        // Given: Two identical note search results
        let result1 = SearchResult.note(sampleNote, relevanceScore: 0.72)
        let result2 = SearchResult.note(sampleNote, relevanceScore: 0.72)
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(result1, result2)
    }
    
    func testSearchResult_DifferentTypes_NotEqual() {
        // Given: Different types of search results
        let podcastResult = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        let episodeResult = SearchResult.episode(sampleEpisode, relevanceScore: 0.95)
        let noteResult = SearchResult.note(sampleNote, relevanceScore: 0.95)
        
        // When: Comparing for equality
        // Then: Different types should not be equal
        XCTAssertNotEqual(podcastResult, episodeResult)
        XCTAssertNotEqual(episodeResult, noteResult)
        XCTAssertNotEqual(podcastResult, noteResult)
    }
    
    // MARK: - SearchFilter Tests (Based on Spec)
    
    func testSearchFilter_All() {
        // Given: Search filter for all content types
        // When: Using .all filter
        let allFilter = SearchFilter.all
        
        // Then: Should be all filter
        XCTAssertEqual(allFilter, .all)
    }
    
    func testSearchFilter_PodcastsOnly() {
        // Given: Search filter for podcasts only
        // When: Using .podcastsOnly filter
        let podcastsFilter = SearchFilter.podcastsOnly
        
        // Then: Should be podcasts only filter
        XCTAssertEqual(podcastsFilter, .podcastsOnly)
    }
    
    func testSearchFilter_EpisodesOnly() {
        // Given: Search filter for episodes only
        // When: Using .episodesOnly filter
        let episodesFilter = SearchFilter.episodesOnly
        
        // Then: Should be episodes only filter
        XCTAssertEqual(episodesFilter, .episodesOnly)
    }
    
    func testSearchFilter_NotesOnly() {
        // Given: Search filter for notes only
        // When: Using .notesOnly filter
        let notesFilter = SearchFilter.notesOnly
        
        // Then: Should be notes only filter
        XCTAssertEqual(notesFilter, .notesOnly)
    }
    
    // MARK: - SearchQuery Tests (Based on Spec)
    
    func testSearchQuery_BasicTextSearch() {
        // Given: A basic text search query
        // When: Creating search query for keywords
        let query = SearchQuery(
            text: "Swift concurrency",
            filter: .all,
            sortBy: .relevance
        )
        
        // Then: Should properly configure basic search
        XCTAssertEqual(query.text, "Swift concurrency")
        XCTAssertEqual(query.filter, .all)
        XCTAssertEqual(query.sortBy, .relevance)
        XCTAssertTrue(query.categoryFilters.isEmpty)
        XCTAssertNil(query.podcastId)
        XCTAssertNil(query.dateRange)
    }
    
    func testSearchQuery_FilteredSearch() {
        // Given: A filtered search query
        // When: Creating search query with specific filter
        let query = SearchQuery(
            text: "iOS development",
            filter: .episodesOnly,
            sortBy: .datePublished
        )
        
        // Then: Should apply filter correctly
        XCTAssertEqual(query.text, "iOS development")
        XCTAssertEqual(query.filter, .episodesOnly)
        XCTAssertEqual(query.sortBy, .datePublished)
    }
    
    func testSearchQuery_CategoryFiltered() {
        // Given: A search query with category filters
        // When: Creating search query with categories
        let query = SearchQuery(
            text: "programming",
            filter: .all,
            sortBy: .relevance,
            categoryFilters: ["Technology", "Programming"]
        )
        
        // Then: Should include category filters
        XCTAssertEqual(query.text, "programming")
        XCTAssertEqual(query.categoryFilters, ["Technology", "Programming"])
        XCTAssertEqual(query.categoryFilters.count, 2)
    }
    
    func testSearchQuery_PodcastSpecific() {
        // Given: A search query for specific podcast
        // When: Creating search query with podcast ID
        let query = SearchQuery(
            text: "concurrency",
            filter: .episodesOnly,
            sortBy: .relevance,
            podcastId: "tech-podcast"
        )
        
        // Then: Should limit search to specific podcast
        XCTAssertEqual(query.text, "concurrency")
        XCTAssertEqual(query.filter, .episodesOnly)
        XCTAssertEqual(query.podcastId, "tech-podcast")
    }
    
    func testSearchQuery_DateRangeFiltered() {
        // Given: A search query with date range
        // When: Creating search query with date constraints
        let startDate = Date(timeIntervalSince1970: 1640000000)
        let endDate = Date(timeIntervalSince1970: 1650000000)
        let dateRange = DateRange(start: startDate, end: endDate)
        
        let query = SearchQuery(
            text: "recent episodes",
            filter: .episodesOnly,
            sortBy: .datePublished,
            dateRange: dateRange
        )
        
        // Then: Should include date range filter
        XCTAssertEqual(query.text, "recent episodes")
        XCTAssertNotNil(query.dateRange)
        XCTAssertEqual(query.dateRange?.start, startDate)
        XCTAssertEqual(query.dateRange?.end, endDate)
    }
    
    // MARK: - SearchQuery SortBy Tests
    
    func testSearchQuery_SortByRelevance() {
        // Given: Search query sorted by relevance
        // When: Using relevance sorting
        let query = SearchQuery(text: "test", filter: .all, sortBy: .relevance)
        
        // Then: Should sort by relevance
        XCTAssertEqual(query.sortBy, .relevance)
    }
    
    func testSearchQuery_SortByDatePublished() {
        // Given: Search query sorted by publication date
        // When: Using date published sorting
        let query = SearchQuery(text: "test", filter: .all, sortBy: .datePublished)
        
        // Then: Should sort by publication date
        XCTAssertEqual(query.sortBy, .datePublished)
    }
    
    func testSearchQuery_SortByDateAdded() {
        // Given: Search query sorted by date added
        // When: Using date added sorting
        let query = SearchQuery(text: "test", filter: .all, sortBy: .dateAdded)
        
        // Then: Should sort by date added
        XCTAssertEqual(query.sortBy, .dateAdded)
    }
    
    func testSearchQuery_SortByDuration() {
        // Given: Search query sorted by duration
        // When: Using duration sorting
        let query = SearchQuery(text: "test", filter: .all, sortBy: .duration)
        
        // Then: Should sort by duration
        XCTAssertEqual(query.sortBy, .duration)
    }
    
    func testSearchQuery_SortByTitle() {
        // Given: Search query sorted by title
        // When: Using title sorting
        let query = SearchQuery(text: "test", filter: .all, sortBy: .title)
        
        // Then: Should sort by title
        XCTAssertEqual(query.sortBy, .title)
    }
    
    // MARK: - SearchResults Collection Tests
    
    func testSearchResults_MixedResults() {
        // Given: Mixed search results
        // When: Creating collection of different result types
        let podcastResult = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        let episodeResult = SearchResult.episode(sampleEpisode, relevanceScore: 0.87)
        let noteResult = SearchResult.note(sampleNote, relevanceScore: 0.72)
        
        let results = SearchResults(
            query: SearchQuery(text: "Swift", filter: .all, sortBy: .relevance),
            results: [podcastResult, episodeResult, noteResult],
            totalCount: 3,
            hasMore: false
        )
        
        // Then: Should properly organize mixed results
        XCTAssertEqual(results.results.count, 3)
        XCTAssertEqual(results.totalCount, 3)
        XCTAssertFalse(results.hasMore)
        XCTAssertEqual(results.query.text, "Swift")
    }
    
    func testSearchResults_PaginatedResults() {
        // Given: Paginated search results
        // When: Creating results with pagination
        let episodeResult = SearchResult.episode(sampleEpisode, relevanceScore: 0.87)
        
        let results = SearchResults(
            query: SearchQuery(text: "programming", filter: .episodesOnly, sortBy: .relevance),
            results: [episodeResult],
            totalCount: 50,
            hasMore: true
        )
        
        // Then: Should indicate more results available
        XCTAssertEqual(results.results.count, 1)
        XCTAssertEqual(results.totalCount, 50)
        XCTAssertTrue(results.hasMore)
    }
    
    func testSearchResults_EmptyResults() {
        // Given: Empty search results
        // When: Creating results with no matches
        let results = SearchResults(
            query: SearchQuery(text: "nonexistent", filter: .all, sortBy: .relevance),
            results: [],
            totalCount: 0,
            hasMore: false
        )
        
        // Then: Should handle empty results gracefully
        XCTAssertTrue(results.results.isEmpty)
        XCTAssertEqual(results.totalCount, 0)
        XCTAssertFalse(results.hasMore)
    }
    
    // MARK: - SearchSuggestion Tests
    
    func testSearchSuggestion_TextSuggestion() {
        // Given: A text-based search suggestion
        // When: Creating text suggestion
        let suggestion = SearchSuggestion.text("Swift programming")
        
        // Then: Should be text suggestion
        if case .text(let text) = suggestion {
            XCTAssertEqual(text, "Swift programming")
        } else {
            XCTFail("Should be text suggestion")
        }
    }
    
    func testSearchSuggestion_PodcastSuggestion() {
        // Given: A podcast-based search suggestion
        // When: Creating podcast suggestion
        let suggestion = SearchSuggestion.podcast(samplePodcast)
        
        // Then: Should be podcast suggestion
        if case .podcast(let podcast) = suggestion {
            XCTAssertEqual(podcast.id, samplePodcast.id)
            XCTAssertEqual(podcast.title, samplePodcast.title)
        } else {
            XCTFail("Should be podcast suggestion")
        }
    }
    
    func testSearchSuggestion_CategorySuggestion() {
        // Given: A category-based search suggestion
        // When: Creating category suggestion
        let suggestion = SearchSuggestion.category("Technology")
        
        // Then: Should be category suggestion
        if case .category(let category) = suggestion {
            XCTAssertEqual(category, "Technology")
        } else {
            XCTFail("Should be category suggestion")
        }
    }
    
    // MARK: - Note Model Tests (Supporting Search)
    
    func testNote_Initialization() {
        // Given: Note properties for search support
        // When: Creating a note
        // Then: Should properly initialize note for search indexing
        XCTAssertEqual(sampleNote.id, "note-1")
        XCTAssertEqual(sampleNote.content, "Great explanation of actor isolation and data races in Swift concurrency.")
        XCTAssertEqual(sampleNote.timestamp, 1800.0)
        XCTAssertEqual(sampleNote.episodeId, "swift-episode")
        XCTAssertEqual(sampleNote.createdAt, testDate)
    }
    
    func testNote_SearchableContent() {
        // Given: A note with searchable content
        // When: Checking content for search indexing
        // Then: Should contain searchable terms
        XCTAssertTrue(sampleNote.content.contains("actor isolation"))
        XCTAssertTrue(sampleNote.content.contains("Swift concurrency"))
        XCTAssertTrue(sampleNote.content.contains("data races"))
    }
    
    func testNote_TimestampAssociation() {
        // Given: A note with timestamp
        // When: Checking timestamp for episode association
        // Then: Should link to specific episode moment
        XCTAssertEqual(sampleNote.timestamp, 1800.0) // 30 minutes
        XCTAssertEqual(sampleNote.episodeId, "swift-episode")
    }
    
    // MARK: - DateRange Tests
    
    func testDateRange_ValidRange() {
        // Given: Valid start and end dates
        // When: Creating date range
        let startDate = Date(timeIntervalSince1970: 1640000000)
        let endDate = Date(timeIntervalSince1970: 1650000000)
        let dateRange = DateRange(start: startDate, end: endDate)
        
        // Then: Should properly store date range
        XCTAssertEqual(dateRange.start, startDate)
        XCTAssertEqual(dateRange.end, endDate)
        XCTAssertTrue(dateRange.end > dateRange.start)
    }
    
    func testDateRange_SameDate() {
        // Given: Same start and end dates
        // When: Creating date range for single day
        let sameDate = Date(timeIntervalSince1970: 1640000000)
        let dateRange = DateRange(start: sameDate, end: sameDate)
        
        // Then: Should handle same dates
        XCTAssertEqual(dateRange.start, dateRange.end)
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testSearchModelsSendableCompliance() {
        // Given: Search models should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let podcastResult = SearchResult.podcast(samplePodcast, relevanceScore: 0.95)
        let _: Sendable = podcastResult
        let _: Sendable = SearchFilter.all
        let _: Sendable = SearchQuery(text: "test", filter: .all, sortBy: .relevance)
        
        XCTAssertNotNil(podcastResult)
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testSearchQuery_EmptyText() {
        // Given: Search query with empty text
        // When: Creating query with empty string
        let emptyQuery = SearchQuery(text: "", filter: .all, sortBy: .relevance)
        
        // Then: Should handle empty text gracefully
        XCTAssertEqual(emptyQuery.text, "")
        XCTAssertTrue(emptyQuery.text.isEmpty)
    }
    
    func testSearchQuery_VeryLongText() {
        // Given: Search query with very long text
        // When: Creating query with long search string
        let longText = String(repeating: "very long search query ", count: 100)
        let longQuery = SearchQuery(text: longText, filter: .all, sortBy: .relevance)
        
        // Then: Should handle long search text
        XCTAssertEqual(longQuery.text, longText)
        XCTAssertTrue(longQuery.text.count > 1000)
    }
    
    func testSearchQuery_UnicodeText() {
        // Given: Search query with Unicode characters
        // When: Creating query with Unicode
        let unicodeText = "🎧 programação em Swift 📱"
        let unicodeQuery = SearchQuery(text: unicodeText, filter: .all, sortBy: .relevance)
        
        // Then: Should handle Unicode properly
        XCTAssertEqual(unicodeQuery.text, unicodeText)
        XCTAssertTrue(unicodeQuery.text.contains("🎧"))
        XCTAssertTrue(unicodeQuery.text.contains("programação"))
    }
    
    func testSearchResult_ZeroRelevanceScore() {
        // Given: Search result with zero relevance
        // When: Creating result with 0.0 score
        let zeroScoreResult = SearchResult.podcast(samplePodcast, relevanceScore: 0.0)
        
        // Then: Should handle zero score
        if case .podcast(_, let score) = zeroScoreResult {
            XCTAssertEqual(score, 0.0, accuracy: 0.001)
        } else {
            XCTFail("Should be podcast result with zero score")
        }
    }
    
    func testSearchResult_NegativeRelevanceScore() {
        // Given: Search result with negative relevance (edge case)
        // When: Creating result with negative score
        let negativeScoreResult = SearchResult.episode(sampleEpisode, relevanceScore: -0.1)
        
        // Then: Should handle negative score
        if case .episode(_, let score) = negativeScoreResult {
            XCTAssertEqual(score, -0.1, accuracy: 0.001)
        } else {
            XCTFail("Should be episode result with negative score")
        }
    }
    
    func testSearchResult_VeryHighRelevanceScore() {
        // Given: Search result with very high relevance
        // When: Creating result with score > 1.0
        let highScoreResult = SearchResult.note(sampleNote, relevanceScore: 1.5)
        
        // Then: Should handle high scores
        if case .note(_, let score) = highScoreResult {
            XCTAssertEqual(score, 1.5, accuracy: 0.001)
        } else {
            XCTFail("Should be note result with high score")
        }
    }
}