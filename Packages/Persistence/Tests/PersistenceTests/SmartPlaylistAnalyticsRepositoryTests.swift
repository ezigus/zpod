import XCTest
import CoreModels
@testable import Persistence

/// Tests for `UserDefaultsSmartPlaylistAnalyticsRepository`.
///
/// Covers: event recording, per-playlist retrieval, stats computation,
/// insights generation, 90-day pruning, and JSON export validity.
final class SmartPlaylistAnalyticsRepositoryTests: XCTestCase {

    private var harness: UserDefaultsTestHarness!
    private var repo: UserDefaultsSmartPlaylistAnalyticsRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = makeUserDefaultsHarness(prefix: "smart-analytics")
        repo = UserDefaultsSmartPlaylistAnalyticsRepository(userDefaults: harness.userDefaults)
    }

    override func tearDownWithError() throws {
        repo = nil
        harness = nil
        try super.tearDownWithError()
    }

    // MARK: - Recording & Retrieval

    func testRecordedEventIsRetrievable() {
        let event = makeEvent(playlistID: "pl-1", episodeID: "ep-1")
        repo.record(event)

        let events = repo.events(for: "pl-1")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, event.id)
    }

    func testEventsAreFilteredByPlaylistID() {
        repo.record(makeEvent(playlistID: "pl-A", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-B", episodeID: "ep-2"))
        repo.record(makeEvent(playlistID: "pl-A", episodeID: "ep-3"))

        XCTAssertEqual(repo.events(for: "pl-A").count, 2)
        XCTAssertEqual(repo.events(for: "pl-B").count, 1)
    }

    func testEventsPersistAcrossRepositoryInstances() {
        let event = makeEvent(playlistID: "pl-1", episodeID: "ep-1")
        repo.record(event)

        let repo2 = UserDefaultsSmartPlaylistAnalyticsRepository(userDefaults: harness.userDefaults)
        let events = repo2.events(for: "pl-1")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, event.id)
    }

    func testMultipleEventsForSameEpisodeAreAllRecorded() {
        for _ in 0..<3 {
            repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        }
        XCTAssertEqual(repo.events(for: "pl-1").count, 3)
    }

    // MARK: - Stats: Empty State

    func testStatsForPlaylistWithNoEventsReturnsEmpty() {
        let stats = repo.stats(for: "unknown-playlist")
        XCTAssertEqual(stats.totalPlays, 0)
        XCTAssertEqual(stats.uniqueEpisodesPlayed, 0)
        XCTAssertEqual(stats.totalPlaybackDuration, 0)
        XCTAssertNil(stats.mostRecentPlay)
    }

    // MARK: - Stats: Computation

    func testStatsTotalPlaysMatchesRecordedEventCount() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))

        XCTAssertEqual(repo.stats(for: "pl-1").totalPlays, 3)
    }

    func testStatsUniqueEpisodesCountsDistinctEpisodeIDs() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))

        XCTAssertEqual(repo.stats(for: "pl-1").uniqueEpisodesPlayed, 2)
    }

    func testStatsTotalDurationSumsEpisodeDurations() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", duration: 1800))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2", duration: 3600))

        XCTAssertEqual(repo.stats(for: "pl-1").totalPlaybackDuration, 5400, accuracy: 0.001)
    }

    func testStatsDurationIgnoresNilDurations() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", duration: nil))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2", duration: 1200))

        XCTAssertEqual(repo.stats(for: "pl-1").totalPlaybackDuration, 1200, accuracy: 0.001)
    }

    func testStatsMostRecentPlayIsLatestDate() {
        let older = Date().addingTimeInterval(-7200)
        let newer = Date().addingTimeInterval(-60)
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", date: older))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2", date: newer))

        let stats = repo.stats(for: "pl-1")
        XCTAssertEqual(
            stats.mostRecentPlay?.timeIntervalSince1970 ?? 0,
            newer.timeIntervalSince1970,
            accuracy: 0.01
        )
    }

    func testStatsAreIsolatedBetweenPlaylists() {
        repo.record(makeEvent(playlistID: "pl-A", episodeID: "ep-1", duration: 1800))
        repo.record(makeEvent(playlistID: "pl-B", episodeID: "ep-2", duration: 900))

        XCTAssertEqual(repo.stats(for: "pl-A").totalPlays, 1)
        XCTAssertEqual(repo.stats(for: "pl-B").totalPlays, 1)
        XCTAssertNotEqual(
            repo.stats(for: "pl-A").totalPlaybackDuration,
            repo.stats(for: "pl-B").totalPlaybackDuration
        )
    }

    // MARK: - Insights

    func testInsightsForEmptyPlaylistContainsNoPlayMessage() {
        let insights = repo.insights(for: "empty-playlist")
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains { $0.systemImage == "play.slash" })
    }

    func testInsightsForPlaylistWithEventsContainsPlayCount() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        let insights = repo.insights(for: "pl-1")
        XCTAssertTrue(insights.contains { $0.systemImage == "play.fill" })
    }

    func testInsightsContainsUniqueEpisodeInsightForMultipleDistinctEpisodes() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2"))
        let insights = repo.insights(for: "pl-1")
        XCTAssertTrue(insights.contains { $0.systemImage == "sparkles" })
    }

    func testInsightsDoesNotContainUniqueEpisodeInsightForSingleEpisode() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        let insights = repo.insights(for: "pl-1")
        XCTAssertFalse(insights.contains { $0.systemImage == "sparkles" })
    }

    func testInsightsContainsHoursListenedWhenDurationExceedsOneHour() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", duration: 7200))
        let insights = repo.insights(for: "pl-1")
        XCTAssertTrue(insights.contains { $0.systemImage == "clock.fill" })
    }

    func testInsightsDoesNotContainHoursInsightForShortPlayback() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", duration: 600))
        let insights = repo.insights(for: "pl-1")
        XCTAssertFalse(insights.contains { $0.systemImage == "clock.fill" })
    }

    func testInsightsContainsLastPlayedDateInsight() {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        let insights = repo.insights(for: "pl-1")
        XCTAssertTrue(insights.contains { $0.systemImage == "calendar" })
    }

    // MARK: - Pruning

    func testPruneRemovesEventsOlderThan90Days() {
        let old = Date().addingTimeInterval(-91 * 24 * 3600)
        let recent = Date()
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-old", date: old))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-new", date: recent))

        repo.pruneOldEvents()

        let events = repo.events(for: "pl-1")
        XCTAssertFalse(events.contains { $0.episodeID == "ep-old" })
        XCTAssertTrue(events.contains { $0.episodeID == "ep-new" })
    }

    func testRecentEventsAreNotPrunedOnRecord() {
        let event = makeEvent(playlistID: "pl-1", episodeID: "ep-fresh")
        repo.record(event)
        XCTAssertTrue(repo.events(for: "pl-1").contains { $0.id == event.id })
    }

    func testEventsInsideRetentionWindowSurvivePrune() {
        let withinWindow = Date().addingTimeInterval(-89 * 24 * 3600)
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-inside", date: withinWindow))
        repo.pruneOldEvents()
        XCTAssertTrue(repo.events(for: "pl-1").contains { $0.episodeID == "ep-inside" })
    }

    // MARK: - JSON Export

    func testExportJSONProducesValidJSON() throws {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1", duration: 1800))
        let data = try repo.exportJSON(for: "pl-1")
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testExportJSONContainsAllRecordedEvents() throws {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-2"))

        let data = try repo.exportJSON(for: "pl-1")
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 2)
    }

    func testExportJSONExcludesEventsFromOtherPlaylists() throws {
        repo.record(makeEvent(playlistID: "pl-1", episodeID: "ep-1"))
        repo.record(makeEvent(playlistID: "pl-2", episodeID: "ep-2"))

        let data = try repo.exportJSON(for: "pl-1")
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
    }

    func testExportJSONForEmptyPlaylistReturnsEmptyArray() throws {
        let data = try repo.exportJSON(for: "no-events")
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 0)
    }

    // MARK: - Helpers

    private func makeEvent(
        playlistID: String,
        episodeID: String,
        duration: TimeInterval? = nil,
        date: Date = Date()
    ) -> SmartPlaylistPlayEvent {
        SmartPlaylistPlayEvent(
            playlistID: playlistID,
            episodeID: episodeID,
            episodeDuration: duration,
            occurredAt: date
        )
    }
}
