import XCTest
@testable import CoreModels

/// Unit tests for EpisodeSearchHelper covering basic filtering scenarios
final class EpisodeSearchHelperTests: XCTestCase {
    private var helper: EpisodeSearchHelper!
    private var filterEvaluator: EpisodeFilterEvaluator!
    private var sortService: EpisodeSortService!
    private var sampleEpisodes: [Episode]!

    override func setUp() async throws {
        try await super.setUp()
        helper = EpisodeSearchHelper()
        filterEvaluator = EpisodeFilterEvaluator()
        sortService = EpisodeSortService()
        sampleEpisodes = makeSampleEpisodes()
    }

    override func tearDown() async throws {
        helper = nil
        filterEvaluator = nil
        sortService = nil
        sampleEpisodes = nil
        try await super.tearDown()
    }

    func testSearchEpisodesMatchesTitleAndDescription() {
        // Given: A query that should match by title or description
        let query = "Swift"

        // When: Searching episodes without extra filtering
        let results = helper.searchEpisodes(
            sampleEpisodes,
            query: query,
            filter: nil,
            includeArchived: false,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: Only the matching non-archived episodes should appear
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.id == "title-match" })
        XCTAssertTrue(results.contains { $0.id == "description-match" })
        XCTAssertFalse(results.contains { $0.id == "archived" })
    }

    func testSearchEpisodesIncludesArchivedWhenRequested() {
        // Given: A query that matches an archived episode
        let query = "Archive"

        // When: Including archived episodes in the search
        let results = helper.searchEpisodes(
            sampleEpisodes,
            query: query,
            filter: nil,
            includeArchived: true,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: The archived episode should be returned
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "archived")
    }

    func testSearchEpisodesAppliesAdditionalFilter() {
        // Given: A query that matches multiple episodes
        let query = "Swift"
        let favoritedCondition = EpisodeFilterCondition(criteria: .favorited)
        let filter = EpisodeFilter(conditions: [favoritedCondition], logic: .and, sortBy: .title)

        // When: Searching with an additional filter to keep only favorited episodes
        let results = helper.searchEpisodes(
            sampleEpisodes,
            query: query,
            filter: filter,
            includeArchived: false,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: Only the favorited episode should remain
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "description-match")
    }

    // MARK: - Helpers

    private func makeSampleEpisodes() -> [Episode] {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            Episode(
                id: "title-match",
                title: "Swift Async Await Overview",
                podcastID: "pod1",
                podcastTitle: "Concurrency Today",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate,
                duration: 1800,
                description: "A quick refresher on structured concurrency",
                isFavorited: false,
                dateAdded: baseDate
            ),
            Episode(
                id: "description-match",
                title: "WWDC Highlights",
                podcastID: "pod1",
                podcastTitle: "Apple Recap",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate.addingTimeInterval(-86400),
                duration: 2400,
                description: "Deep dive into Swift UI testing and Swift concurrency",
                isFavorited: true,
                dateAdded: baseDate.addingTimeInterval(-86400)
            ),
            Episode(
                id: "archived",
                title: "Archived Episode",
                podcastID: "pod2",
                podcastTitle: "Legacy Feed",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate.addingTimeInterval(-172800),
                duration: 1500,
                description: "Archive cleanup tips",
                isFavorited: false,
                isArchived: true,
                dateAdded: baseDate.addingTimeInterval(-172800)
            ),
            Episode(
                id: "other",
                title: "News Roundup",
                podcastID: "pod2",
                podcastTitle: "Daily Pod",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate.addingTimeInterval(-259200),
                duration: 1200,
                description: "Market analysis and interviews",
                isFavorited: false,
                dateAdded: baseDate.addingTimeInterval(-259200)
            )
        ]
    }
}
