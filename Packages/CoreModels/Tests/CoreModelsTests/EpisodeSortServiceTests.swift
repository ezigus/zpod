import XCTest
import Foundation
@testable import CoreModels

/// Unit tests for EpisodeSortService helper
final class EpisodeSortServiceTests: XCTestCase {
    
    private var sortService: EpisodeSortService!
    private var testEpisodes: [Episode]!
    
    override func setUp() async throws {
        try await super.setUp()
        sortService = EpisodeSortService()
        testEpisodes = createTestEpisodes()
    }
    
    override func tearDown() async throws {
        sortService = nil
        testEpisodes = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    private func createTestEpisodes() -> [Episode] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            Episode(
                id: "ep1",
                title: "Episode Alpha",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -1, to: now),
                duration: 1800.0, // 30 minutes
                audioURL: URL(string: "https://example.com/ep1.mp3"),
                dateAdded: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            Episode(
                id: "ep2",
                title: "Episode Beta",
                podcastID: "podcast1",
                playbackPosition: 900,
                isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -3, to: now),
                duration: 2400.0, // 40 minutes
                audioURL: URL(string: "https://example.com/ep2.mp3"),
                dateAdded: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
            Episode(
                id: "ep3",
                title: "Episode Charlie",
                podcastID: "podcast1",
                playbackPosition: 1200,
                isPlayed: true,
                pubDate: calendar.date(byAdding: .day, value: -5, to: now),
                duration: 3600.0, // 60 minutes
                audioURL: URL(string: "https://example.com/ep3.mp3"),
                rating: 5,
                dateAdded: calendar.date(byAdding: .day, value: -1, to: now)!
            )
        ]
    }
    
    // MARK: - Sort Tests
    
    func testSortByPubDateNewest() async {
        // When: Sorting by newest publication date
        let sorted = sortService.sortEpisodes(testEpisodes, by: .pubDateNewest)
        
        // Then: Episodes should be ordered newest to oldest
        XCTAssertEqual(sorted[0].id, "ep1", "Newest episode should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Middle episode should be second")
        XCTAssertEqual(sorted[2].id, "ep3", "Oldest episode should be last")
    }
    
    func testSortByPubDateOldest() async {
        // When: Sorting by oldest publication date
        let sorted = sortService.sortEpisodes(testEpisodes, by: .pubDateOldest)
        
        // Then: Episodes should be ordered oldest to newest
        XCTAssertEqual(sorted[0].id, "ep3", "Oldest episode should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Middle episode should be second")
        XCTAssertEqual(sorted[2].id, "ep1", "Newest episode should be last")
    }
    
    func testSortByDuration() async {
        // When: Sorting by duration
        let sorted = sortService.sortEpisodes(testEpisodes, by: .duration)
        
        // Then: Episodes should be ordered shortest to longest
        XCTAssertEqual(sorted[0].id, "ep1", "Shortest episode should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Medium episode should be second")
        XCTAssertEqual(sorted[2].id, "ep3", "Longest episode should be last")
    }
    
    func testSortByTitle() async {
        // When: Sorting by title
        let sorted = sortService.sortEpisodes(testEpisodes, by: .title)
        
        // Then: Episodes should be ordered alphabetically
        XCTAssertEqual(sorted[0].id, "ep1", "Episode Alpha should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Episode Beta should be second")
        XCTAssertEqual(sorted[2].id, "ep3", "Episode Charlie should be last")
    }
    
    func testSortByPlayStatus() async {
        // When: Sorting by play status
        let sorted = sortService.sortEpisodes(testEpisodes, by: .playStatus)
        
        // Then: Episodes should be ordered unplayed, in-progress, played
        XCTAssertEqual(sorted[0].id, "ep1", "Unplayed episode should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "In-progress episode should be second")
        XCTAssertEqual(sorted[2].id, "ep3", "Played episode should be last")
    }
    
    func testSortByRating() async {
        // When: Sorting by rating
        let sorted = sortService.sortEpisodes(testEpisodes, by: .rating)
        
        // Then: Episodes with ratings should come first, highest first
        XCTAssertEqual(sorted[0].id, "ep3", "Rated episode should be first")
    }
    
    func testSortByDateAdded() async {
        // When: Sorting by date added
        let sorted = sortService.sortEpisodes(testEpisodes, by: .dateAdded)

        // Then: Episodes should be ordered newest to oldest added
        XCTAssertEqual(sorted[0].id, "ep3", "Most recently added should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Second added should be second")
        XCTAssertEqual(sorted[2].id, "ep1", "First added should be last")
    }

    // MARK: - Direction Override Tests

    func testSortByTitleAscending() async {
        // Given: Sort by title with ascending = true (A→Z)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .title, ascending: true)

        // Then: Alphabetical A→Z
        XCTAssertEqual(sorted[0].id, "ep1", "Episode Alpha should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Episode Beta should be second")
        XCTAssertEqual(sorted[2].id, "ep3", "Episode Charlie should be last")
    }

    func testSortByTitleDescending() async {
        // Given: Sort by title with ascending = false (Z→A)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .title, ascending: false)

        // Then: Reverse alphabetical Z→A
        XCTAssertEqual(sorted[0].id, "ep3", "Episode Charlie should be first")
        XCTAssertEqual(sorted[1].id, "ep2", "Episode Beta should be second")
        XCTAssertEqual(sorted[2].id, "ep1", "Episode Alpha should be last")
    }

    func testNaturalSortTitleAscending() async {
        // Given: Episodes with numeric titles that differ between lexicographic and natural sort
        let calendar = Calendar.current
        let now = Date()
        let numericEpisodes = [
            Episode(
                id: "e10", title: "Episode 10", podcastID: "p1",
                playbackPosition: 0, isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -1, to: now),
                audioURL: nil,
                dateAdded: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            Episode(
                id: "e2", title: "Episode 2", podcastID: "p1",
                playbackPosition: 0, isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -2, to: now),
                audioURL: nil,
                dateAdded: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
            Episode(
                id: "e11", title: "Episode 11", podcastID: "p1",
                playbackPosition: 0, isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -3, to: now),
                audioURL: nil,
                dateAdded: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            Episode(
                id: "e1", title: "Episode 1", podcastID: "p1",
                playbackPosition: 0, isPlayed: false,
                pubDate: calendar.date(byAdding: .day, value: -4, to: now),
                audioURL: nil,
                dateAdded: calendar.date(byAdding: .day, value: -4, to: now)!
            )
        ]

        // When: Sort ascending with natural sort
        let sorted = sortService.sortEpisodes(numericEpisodes, by: .title, ascending: true)

        // Then: Natural numeric order (1, 2, 10, 11), not lexicographic (1, 10, 11, 2)
        XCTAssertEqual(sorted[0].id, "e1",  "Episode 1 should be first")
        XCTAssertEqual(sorted[1].id, "e2",  "Episode 2 should be second")
        XCTAssertEqual(sorted[2].id, "e10", "Episode 10 should be third")
        XCTAssertEqual(sorted[3].id, "e11", "Episode 11 should be fourth")
    }

    func testNaturalSortTitleDescending() async {
        // Given: Same numeric episodes as above
        let calendar = Calendar.current
        let now = Date()
        let numericEpisodes = [
            Episode(id: "e10", title: "Episode 10", podcastID: "p1", playbackPosition: 0, isPlayed: false,
                    pubDate: nil, audioURL: nil, dateAdded: now),
            Episode(id: "e2",  title: "Episode 2",  podcastID: "p1", playbackPosition: 0, isPlayed: false,
                    pubDate: nil, audioURL: nil, dateAdded: calendar.date(byAdding: .second, value: -1, to: now)!),
            Episode(id: "e11", title: "Episode 11", podcastID: "p1", playbackPosition: 0, isPlayed: false,
                    pubDate: nil, audioURL: nil, dateAdded: calendar.date(byAdding: .second, value: -2, to: now)!),
            Episode(id: "e1",  title: "Episode 1",  podcastID: "p1", playbackPosition: 0, isPlayed: false,
                    pubDate: nil, audioURL: nil, dateAdded: calendar.date(byAdding: .second, value: -3, to: now)!)
        ]

        // When: Sort descending
        let sorted = sortService.sortEpisodes(numericEpisodes, by: .title, ascending: false)

        // Then: Reverse natural order (11, 10, 2, 1)
        XCTAssertEqual(sorted[0].id, "e11", "Episode 11 should be first")
        XCTAssertEqual(sorted[1].id, "e10", "Episode 10 should be second")
        XCTAssertEqual(sorted[2].id, "e2",  "Episode 2 should be third")
        XCTAssertEqual(sorted[3].id, "e1",  "Episode 1 should be fourth")
    }

    func testSortByDurationAscending() async {
        // Given: Sort by duration ascending (shortest first — also the default)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .duration, ascending: true)

        XCTAssertEqual(sorted[0].id, "ep1", "Shortest (30 min) should be first")
        XCTAssertEqual(sorted[2].id, "ep3", "Longest (60 min) should be last")
    }

    func testSortByDurationDescending() async {
        // Given: Sort by duration descending (longest first)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .duration, ascending: false)

        XCTAssertEqual(sorted[0].id, "ep3", "Longest (60 min) should be first")
        XCTAssertEqual(sorted[2].id, "ep1", "Shortest (30 min) should be last")
    }

    func testSortByRatingDescending() async {
        // Given: Sort by rating descending (highest first — also the default)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .rating, ascending: false)

        // Then: ep3 has rating 5, others have nil (0)
        XCTAssertEqual(sorted[0].id, "ep3", "Highest rated should be first")
    }

    func testSortByRatingAscending() async {
        // Given: Sort by rating ascending (lowest first)
        let sorted = sortService.sortEpisodes(testEpisodes, by: .rating, ascending: true)

        // Then: ep3 (rating 5) should be last; unrated (0) episodes are first
        XCTAssertEqual(sorted[2].id, "ep3", "Highest rated should be last when ascending")
    }

    func testDefaultAscendingNilFallback() async {
        // Given: Sort using the convenience overload (no ascending param) matches the default direction.
        // For .title, defaultAscending is true (A→Z).
        let sortedConvenience = sortService.sortEpisodes(testEpisodes, by: .title)
        let sortedExplicit = sortService.sortEpisodes(testEpisodes, by: .title, ascending: true)

        // Then: Both should produce identical ordering
        XCTAssertEqual(sortedConvenience.map { $0.id }, sortedExplicit.map { $0.id },
                       "Convenience overload should match explicit ascending=true for .title")
    }

    func testCodableRoundTripWithAscending() throws {
        // Given: An EpisodeFilter with sortAscending explicitly set
        let filter = EpisodeFilter(sortBy: .title, sortAscending: true)

        // When: Encode then decode
        let encoded = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(EpisodeFilter.self, from: encoded)

        // Then: Round-trip preserves sortAscending
        XCTAssertEqual(decoded.sortAscending, true, "sortAscending: true should survive encode/decode")
        XCTAssertEqual(decoded.sortBy, .title)
    }

    func testCodableBackwardCompatNilAscending() throws {
        // Given: JSON without a sortAscending key (pre-feature persisted data)
        let json = #"{"conditions":[],"logic":"and","sortBy":"title"}"#
        let data = Data(json.utf8)

        // When: Decode
        let filter = try JSONDecoder().decode(EpisodeFilter.self, from: data)

        // Then: sortAscending is nil → effectiveAscending falls back to defaultAscending for .title (true)
        XCTAssertNil(filter.sortAscending, "Missing key should decode as nil")
        XCTAssertTrue(filter.effectiveAscending, "effectiveAscending should fall back to title's default (ascending)")
    }
}
