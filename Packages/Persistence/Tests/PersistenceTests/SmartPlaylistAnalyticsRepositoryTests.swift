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

    // MARK: - Event Count Cap

    func testRecordEnforcesMaxEventCount() {
        // Use a small cap (20) to keep the test fast while proving the mechanism works.
        let cappedRepo = UserDefaultsSmartPlaylistAnalyticsRepository(
            userDefaults: harness.userDefaults,
            maxEventCount: 20
        )
        let batchSize = 30
        // Anchor 7 days in the past so events fall well within the 90-day retention
        // window. 1-hour gaps ensure ordering survives ISO-8601 JSON encode/decode.
        let baseDate = Date(timeIntervalSinceNow: -(7 * 24 * 3600))
        for idx in 0..<batchSize {
            cappedRepo.record(makeEvent(
                playlistID: "pl-cap",
                episodeID: "ep-\(idx)",
                date: baseDate.addingTimeInterval(Double(idx) * 3600)
            ))
        }

        let allEvents = cappedRepo.events(for: "pl-cap")
        XCTAssertLessThanOrEqual(allEvents.count, 20, "Event count should be capped at maxEventCount")

        // The oldest events (ep-0 through ep-9) should have been pruned
        XCTAssertFalse(allEvents.contains { $0.episodeID == "ep-0" },
                       "Oldest event should be pruned when cap is exceeded")
        // The newest event should be retained
        XCTAssertTrue(allEvents.contains { $0.episodeID == "ep-\(batchSize - 1)" },
                      "Most recent event should be retained")
    }

    func testPruningAtCapEnforcesMaxEventCount() {
        // Verifies that recording more events than maxEventCount trims the store to
        // exactly maxEventCount, discarding the oldest events first.
        // NOTE: Logger.debug is called inside the pruning branch but cannot be verified
        // directly — Logger is a static enum backed by os.Logger with no injection point.
        // Enforced count here is proof the pruning branch (containing the log call) executed.
        let cap = 5
        let cappedRepo = UserDefaultsSmartPlaylistAnalyticsRepository(
            userDefaults: harness.userDefaults,
            maxEventCount: cap
        )
        // Anchor 7 days in the past so events fall well within the 90-day retention
        // window. 1-hour gaps ensure ordering survives ISO-8601 JSON encode/decode.
        let baseDate = Date(timeIntervalSinceNow: -(7 * 24 * 3600))
        let recordCount = 10
        for idx in 0..<recordCount {
            cappedRepo.record(makeEvent(
                playlistID: "pl-log",
                episodeID: "ep-\(idx)",
                date: baseDate.addingTimeInterval(Double(idx) * 3600)
            ))
        }

        let retained = cappedRepo.events(for: "pl-log")
        XCTAssertEqual(retained.count, cap,
                       "Pruning branch should have fired, capping events at \(cap)")
        // Newest events are retained; oldest are discarded.
        XCTAssertTrue(retained.contains { $0.episodeID == "ep-\(recordCount - 1)" },
                      "Most recent event must be retained after pruning")
        XCTAssertFalse(retained.contains { $0.episodeID == "ep-0" },
                       "Oldest events must be discarded by pruning")
    }

    func testPruningWithCapOfOne() {
        // Edge case: maxEventCount = 1 verifies the pruning logic has no off-by-one errors.
        let cap = 1
        let cappedRepo = UserDefaultsSmartPlaylistAnalyticsRepository(
            userDefaults: harness.userDefaults,
            maxEventCount: cap
        )
        let baseDate = Date(timeIntervalSinceNow: -(7 * 24 * 3600))
        cappedRepo.record(makeEvent(playlistID: "pl-one", episodeID: "ep-older", date: baseDate))
        cappedRepo.record(makeEvent(playlistID: "pl-one", episodeID: "ep-newer",
                                    date: baseDate.addingTimeInterval(3600)))

        let retained = cappedRepo.events(for: "pl-one")
        XCTAssertEqual(retained.count, 1, "Only 1 event should be retained with cap of 1")
        XCTAssertTrue(retained.contains { $0.episodeID == "ep-newer" },
                      "Newer event must be retained when cap is 1")
        XCTAssertFalse(retained.contains { $0.episodeID == "ep-older" },
                       "Older event must be discarded when cap is 1")
    }

    func testNoPruningWhenUnderCap() {
        // Verifies the pruning branch is NOT triggered when event count stays below maxEventCount.
        let cap = 10
        let cappedRepo = UserDefaultsSmartPlaylistAnalyticsRepository(
            userDefaults: harness.userDefaults,
            maxEventCount: cap
        )
        let baseDate = Date(timeIntervalSinceNow: -(7 * 24 * 3600))
        for idx in 0..<5 {
            cappedRepo.record(makeEvent(
                playlistID: "pl-under",
                episodeID: "ep-\(idx)",
                date: baseDate.addingTimeInterval(Double(idx) * 3600)
            ))
        }

        let retained = cappedRepo.events(for: "pl-under")
        XCTAssertEqual(retained.count, 5,
                       "No events should be pruned when count is below maxEventCount")
        // Verify every originally recorded event is still present — proves no pruning occurred.
        let expectedEpisodeIDs = Set((0..<5).map { "ep-\($0)" })
        let retainedEpisodeIDs = Set(retained.map { $0.episodeID })
        XCTAssertEqual(retainedEpisodeIDs, expectedEpisodeIDs,
                       "All recorded events should be present when under cap — no pruning should have occurred")
    }

    func testNoPruningWhenExactlyAtCap() {
        // Verifies the pruning branch is NOT triggered when event count equals maxEventCount exactly.
        // The condition is `events.count > maxEventCount`, so equality must not fire.
        let cap = 5
        let cappedRepo = UserDefaultsSmartPlaylistAnalyticsRepository(
            userDefaults: harness.userDefaults,
            maxEventCount: cap
        )
        let baseDate = Date(timeIntervalSinceNow: -(7 * 24 * 3600))
        for idx in 0..<cap {
            cappedRepo.record(makeEvent(
                playlistID: "pl-exact",
                episodeID: "ep-\(idx)",
                date: baseDate.addingTimeInterval(Double(idx) * 3600)
            ))
        }

        let retained = cappedRepo.events(for: "pl-exact")
        XCTAssertEqual(retained.count, cap,
                       "Exactly cap-many events should be retained without triggering pruning")
        // Verify every originally recorded event is still present — proves no pruning occurred.
        let expectedEpisodeIDs = Set((0..<cap).map { "ep-\($0)" })
        let retainedEpisodeIDs = Set(retained.map { $0.episodeID })
        XCTAssertEqual(retainedEpisodeIDs, expectedEpisodeIDs,
                       "All recorded events should be present when exactly at cap — no pruning should have occurred")
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
