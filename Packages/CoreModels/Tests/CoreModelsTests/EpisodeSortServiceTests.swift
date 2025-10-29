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
}
