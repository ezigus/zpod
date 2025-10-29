import XCTest
import Foundation
@testable import CoreModels

/// Unit tests for EpisodeFilterEvaluator helper
final class EpisodeFilterEvaluatorTests: XCTestCase {
    
    private var evaluator: EpisodeFilterEvaluator!
    private var testEpisodes: [Episode]!
    
    override func setUp() async throws {
        try await super.setUp()
        evaluator = EpisodeFilterEvaluator()
        testEpisodes = createTestEpisodes()
    }
    
    override func tearDown() async throws {
        evaluator = nil
        testEpisodes = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    private func createTestEpisodes() -> [Episode] {
        return [
            Episode(
                id: "ep1",
                title: "Unplayed Episode",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                audioURL: URL(string: "https://example.com/ep1.mp3")
            ),
            Episode(
                id: "ep2",
                title: "In Progress Episode",
                podcastID: "podcast1",
                playbackPosition: 900,
                isPlayed: false,
                audioURL: URL(string: "https://example.com/ep2.mp3")
            ),
            Episode(
                id: "ep3",
                title: "Played Episode",
                podcastID: "podcast1",
                playbackPosition: 1800,
                isPlayed: true,
                audioURL: URL(string: "https://example.com/ep3.mp3")
            ),
            Episode(
                id: "ep4",
                title: "Favorited Episode",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                audioURL: URL(string: "https://example.com/ep4.mp3"),
                isFavorited: true
            ),
            Episode(
                id: "ep5",
                title: "Archived Episode",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                audioURL: URL(string: "https://example.com/ep5.mp3"),
                isArchived: true
            )
        ]
    }
    
    // MARK: - Condition Matching Tests
    
    func testEpisodeMatches_Unplayed() async {
        // Given: Unplayed condition
        let condition = EpisodeFilterCondition(criteria: .unplayed)
        
        // When/Then: Should match unplayed episodes only
        XCTAssertTrue(evaluator.episodeMatches(testEpisodes[0], condition: condition))
        XCTAssertTrue(evaluator.episodeMatches(testEpisodes[1], condition: condition))
        XCTAssertFalse(evaluator.episodeMatches(testEpisodes[2], condition: condition))
    }
    
    func testEpisodeMatches_InProgress() async {
        // Given: In-progress condition
        let condition = EpisodeFilterCondition(criteria: .inProgress)
        
        // When/Then: Should match in-progress episodes only
        XCTAssertFalse(evaluator.episodeMatches(testEpisodes[0], condition: condition))
        XCTAssertTrue(evaluator.episodeMatches(testEpisodes[1], condition: condition))
        XCTAssertFalse(evaluator.episodeMatches(testEpisodes[2], condition: condition))
    }
    
    func testEpisodeMatches_Favorited() async {
        // Given: Favorited condition
        let condition = EpisodeFilterCondition(criteria: .favorited)
        
        // When/Then: Should match favorited episodes only
        XCTAssertFalse(evaluator.episodeMatches(testEpisodes[0], condition: condition))
        XCTAssertTrue(evaluator.episodeMatches(testEpisodes[3], condition: condition))
    }
    
    func testEpisodeMatches_Negated() async {
        // Given: Negated unplayed condition
        let condition = EpisodeFilterCondition(criteria: .unplayed, isNegated: true)
        
        // When/Then: Should match played episodes (negation of unplayed)
        XCTAssertFalse(evaluator.episodeMatches(testEpisodes[0], condition: condition))
        XCTAssertTrue(evaluator.episodeMatches(testEpisodes[2], condition: condition))
    }
    
    // MARK: - Filter Application Tests
    
    func testApplyFilter_EmptyFilter() async {
        // Given: Empty filter
        let filter = EpisodeFilter(conditions: [], logic: .and, sortBy: .pubDateNewest)
        
        // When: Applying filter
        let filtered = evaluator.applyFilter(testEpisodes, filter: filter)
        
        // Then: Should exclude archived but return all others
        XCTAssertEqual(filtered.count, 4) // All except archived
        XCTAssertFalse(filtered.contains { $0.id == "ep5" })
    }
    
    func testApplyFilter_SingleCondition() async {
        // Given: Filter with single unplayed condition
        let condition = EpisodeFilterCondition(criteria: .unplayed)
        let filter = EpisodeFilter(conditions: [condition], logic: .and, sortBy: .pubDateNewest)
        
        // When: Applying filter
        let filtered = evaluator.applyFilter(testEpisodes, filter: filter)
        
        // Then: Should return unplayed non-archived episodes (includes in-progress episodes that aren't marked as played)
        XCTAssertEqual(filtered.count, 3) // ep1, ep2 (in-progress but not played), and ep4
        XCTAssertTrue(filtered.contains { $0.id == "ep1" })
        XCTAssertTrue(filtered.contains { $0.id == "ep2" })
        XCTAssertTrue(filtered.contains { $0.id == "ep4" })
    }
    
    func testApplyFilter_ANDLogic() async {
        // Given: Filter with AND logic (unplayed AND favorited)
        let conditions = [
            EpisodeFilterCondition(criteria: .unplayed),
            EpisodeFilterCondition(criteria: .favorited)
        ]
        let filter = EpisodeFilter(conditions: conditions, logic: .and, sortBy: .pubDateNewest)
        
        // When: Applying filter
        let filtered = evaluator.applyFilter(testEpisodes, filter: filter)
        
        // Then: Should return only episodes matching both conditions
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "ep4")
    }
    
    func testApplyFilter_ORLogic() async {
        // Given: Filter with OR logic (favorited OR played)
        let conditions = [
            EpisodeFilterCondition(criteria: .favorited),
            EpisodeFilterCondition(criteria: .inProgress)
        ]
        let filter = EpisodeFilter(conditions: conditions, logic: .or, sortBy: .pubDateNewest)
        
        // When: Applying filter
        let filtered = evaluator.applyFilter(testEpisodes, filter: filter)
        
        // Then: Should return episodes matching either condition
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.id == "ep2" }) // in-progress
        XCTAssertTrue(filtered.contains { $0.id == "ep4" }) // favorited
    }
    
    func testApplyFilter_ArchivedIncluded() async {
        // Given: Filter explicitly including archived
        let condition = EpisodeFilterCondition(criteria: .archived)
        let filter = EpisodeFilter(conditions: [condition], logic: .and, sortBy: .pubDateNewest)
        
        // When: Applying filter
        let filtered = evaluator.applyFilter(testEpisodes, filter: filter)
        
        // Then: Should return only archived episodes
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "ep5")
    }
}
