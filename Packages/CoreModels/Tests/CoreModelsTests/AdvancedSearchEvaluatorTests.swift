import XCTest
@testable import CoreModels

/// Unit tests for AdvancedSearchEvaluator verifying scoring and highlighting rules
final class AdvancedSearchEvaluatorTests: XCTestCase {
    private var evaluator: AdvancedSearchEvaluator!
    private var filterEvaluator: EpisodeFilterEvaluator!
    private var sortService: EpisodeSortService!
    private var sampleEpisodes: [Episode]!

    override func setUp() async throws {
        try await super.setUp()
        evaluator = AdvancedSearchEvaluator()
        filterEvaluator = EpisodeFilterEvaluator()
        sortService = EpisodeSortService()
        sampleEpisodes = makeSampleEpisodes()
    }

    override func tearDown() async throws {
        evaluator = nil
        filterEvaluator = nil
        sortService = nil
        sampleEpisodes = nil
        try await super.tearDown()
    }

    func testAdvancedSearchGeneratesHighlightForTitleMatch() throws {
        // Given: A query targeting the title field
        let query = EpisodeSearchQuery(
            terms: [SearchTerm(text: "Swift", field: .title)],
            operators: []
        )

        // When: Performing the advanced search
        let results = evaluator.searchEpisodesAdvanced(
            sampleEpisodes,
            query: query,
            filter: nil,
            includeArchived: false,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: The matching episode should include a highlight for the title
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.episode.id, "title-match")
        XCTAssertFalse(result.highlights.isEmpty)
        XCTAssertEqual(result.highlights.first?.field, .title)
        XCTAssertEqual(result.highlights.first?.matchedTerm.lowercased(), "swift")
        XCTAssertTrue((result.contextSnippet ?? "").contains("Swift"))
    }

    func testAdvancedSearchHonorsBooleanOperators() {
        // Given: A query that requires Swift matches but excludes blocking topics
        let query = EpisodeSearchQuery(
            terms: [
                SearchTerm(text: "Swift", field: .description),
                SearchTerm(text: "blocking", field: .description)
            ],
            operators: [.and, .not]
        )

        // When: Running the advanced search
        let results = evaluator.searchEpisodesAdvanced(
            sampleEpisodes,
            query: query,
            filter: nil,
            includeArchived: false,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: Episodes mentioning Swift should remain while blocking content is excluded
        XCTAssertEqual(results.count, 2)
        let identifiers = results.map { $0.episode.id }
        XCTAssertTrue(identifiers.contains("title-match"))
        XCTAssertTrue(identifiers.contains("description-match"))
        XCTAssertFalse(identifiers.contains("blocked"))
    }

    func testAdvancedSearchAppliesFilterAfterScoring() {
        // Given: A query that matches two episodes but filter keeps favorited ones
        let query = EpisodeSearchQuery(text: "Swift")
        let filter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .favorited)],
            logic: .and,
            sortBy: .title
        )

        // When: Performing advanced search with an additional filter
        let results = evaluator.searchEpisodesAdvanced(
            sampleEpisodes,
            query: query,
            filter: filter,
            includeArchived: false,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )

        // Then: Only the favorited episode should remain after filtering
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.episode.id, "description-match")
    }

    // MARK: - Helpers

    private func makeSampleEpisodes() -> [Episode] {
        let baseDate = Date(timeIntervalSince1970: 1_700_100_000)
        return [
            Episode(
                id: "title-match",
                title: "Swift Concurrency Best Practices",
                podcastID: "pod1",
                podcastTitle: "Concurrency Today",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate,
                duration: 1800,
                description: "Explore Swift async/await with cooperative multitasking",
                isFavorited: false,
                dateAdded: baseDate
            ),
            Episode(
                id: "blocked",
                title: "Debugging Blocking Code",
                podcastID: "pod2",
                podcastTitle: "Systems Hour",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate.addingTimeInterval(-7200),
                duration: 2100,
                description: "Swift tips for diagnosing blocking operations",
                isFavorited: false,
                dateAdded: baseDate.addingTimeInterval(-7200)
            ),
            Episode(
                id: "description-match",
                title: "Modern WWDC Recap",
                podcastID: "pod3",
                podcastTitle: "Apple Recap",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate.addingTimeInterval(-14400),
                duration: 2200,
                description: "Swift concurrency and SwiftUI advancements",
                isFavorited: true,
                dateAdded: baseDate.addingTimeInterval(-14400)
            )
        ]
    }
}
