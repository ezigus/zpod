import XCTest
import CoreModels
@testable import Persistence

/// Tests for `UserDefaultsListeningHistoryRepository`.
///
/// Covers: event recording, filtered retrieval, statistics computation,
/// insights generation, 180-day pruning, JSON/CSV export, and deletion.
final class ListeningHistoryRepositoryTests: XCTestCase {

    private var harness: UserDefaultsTestHarness!
    private var repo: UserDefaultsListeningHistoryRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = makeUserDefaultsHarness(prefix: "listening-history")
        repo = UserDefaultsListeningHistoryRepository(userDefaults: harness.userDefaults)
    }

    override func tearDownWithError() throws {
        repo = nil
        harness = nil
        try super.tearDownWithError()
    }

    // MARK: - Recording & Retrieval

    func testRecordedEntryIsRetrievable() {
        let entry = makeEntry(episodeId: "ep-1", podcastId: "pod-1")
        repo.record(entry)

        let all = repo.allEntries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, entry.id)
    }

    func testMultipleEntriesRecordedCorrectly() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-1"))
        repo.record(makeEntry(episodeId: "ep-3", podcastId: "pod-2"))

        XCTAssertEqual(repo.allEntries().count, 3)
    }

    func testEntriesPersistAcrossInstances() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))

        let repo2 = UserDefaultsListeningHistoryRepository(userDefaults: harness.userDefaults)
        XCTAssertEqual(repo2.allEntries().count, 1)
    }

    // MARK: - Filtering

    func testFilterByPodcastId() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-A"))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-B"))
        repo.record(makeEntry(episodeId: "ep-3", podcastId: "pod-A"))

        let filter = ListeningHistoryFilter(podcastId: "pod-A")
        XCTAssertEqual(repo.entries(matching: filter).count, 2)
    }

    func testFilterByDateRange() {
        let old = Date().addingTimeInterval(-7 * 24 * 3600)
        let recent = Date().addingTimeInterval(-3600)
        repo.record(makeEntry(episodeId: "ep-old", podcastId: "pod-1", date: old))
        repo.record(makeEntry(episodeId: "ep-new", podcastId: "pod-1", date: recent))

        let startDate = Date().addingTimeInterval(-2 * 24 * 3600)
        let filter = ListeningHistoryFilter(startDate: startDate)
        let results = repo.entries(matching: filter)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.episodeId, "ep-new")
    }

    func testFilterCompletedOnly() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", completed: true))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-1", completed: false))

        let filter = ListeningHistoryFilter(completedOnly: true)
        XCTAssertEqual(repo.entries(matching: filter).count, 1)
    }

    func testLastDaysFilter() {
        let old = Date().addingTimeInterval(-10 * 24 * 3600)
        let recent = Date().addingTimeInterval(-3600)
        repo.record(makeEntry(episodeId: "ep-old", podcastId: "pod-1", date: old))
        repo.record(makeEntry(episodeId: "ep-new", podcastId: "pod-1", date: recent))

        let filter = ListeningHistoryFilter.lastDays(7)
        XCTAssertEqual(repo.entries(matching: filter).count, 1)
    }

    // MARK: - Deletion

    func testDeleteEntryById() {
        let entry1 = makeEntry(episodeId: "ep-1", podcastId: "pod-1")
        let entry2 = makeEntry(episodeId: "ep-2", podcastId: "pod-1")
        repo.record(entry1)
        repo.record(entry2)

        repo.deleteEntry(id: entry1.id)

        let all = repo.allEntries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, entry2.id)
    }

    func testDeleteAll() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-2"))

        repo.deleteAll()
        XCTAssertEqual(repo.allEntries().count, 0)
    }

    // MARK: - Statistics

    func testStatisticsEmptyState() {
        let stats = repo.statistics(matching: ListeningHistoryFilter())
        XCTAssertEqual(stats.totalListeningTime, 0)
        XCTAssertEqual(stats.episodesStarted, 0)
        XCTAssertEqual(stats.episodesCompleted, 0)
        XCTAssertEqual(stats.completionRate, 0)
    }

    func testStatisticsTotalListeningTime() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", duration: 1800))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-1", duration: 3600))

        let stats = repo.statistics(matching: ListeningHistoryFilter())
        XCTAssertEqual(stats.totalListeningTime, 5400, accuracy: 0.001)
    }

    func testStatisticsEpisodesStartedAndCompleted() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", completed: true))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-1", completed: true))
        repo.record(makeEntry(episodeId: "ep-3", podcastId: "pod-1", completed: false))

        let stats = repo.statistics(matching: ListeningHistoryFilter())
        XCTAssertEqual(stats.episodesStarted, 3)
        XCTAssertEqual(stats.episodesCompleted, 2)
    }

    func testStatisticsCompletionRate() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", completed: true))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-1", completed: false))

        let stats = repo.statistics(matching: ListeningHistoryFilter())
        XCTAssertEqual(stats.completionRate, 0.5, accuracy: 0.001)
    }

    func testStatisticsTopPodcasts() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-A", duration: 3600, podcastTitle: "Podcast A"))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-A", duration: 1800, podcastTitle: "Podcast A"))
        repo.record(makeEntry(episodeId: "ep-3", podcastId: "pod-B", duration: 900, podcastTitle: "Podcast B"))

        let stats = repo.statistics(matching: ListeningHistoryFilter())
        XCTAssertEqual(stats.topPodcasts.count, 2)
        XCTAssertEqual(stats.topPodcasts.first?.podcastId, "pod-A")
        let topTime = stats.topPodcasts.first?.totalTime ?? 0
        XCTAssertEqual(topTime, 5400, accuracy: 0.001)
    }

    // MARK: - Insights

    func testInsightsForEmptyHistoryContainsNoPlayMessage() {
        let insights = repo.insights()
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains { $0.systemImage == "play.slash" })
    }

    func testInsightsForNonEmptyHistoryContainsPlayCount() {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", duration: 7200))
        let insights = repo.insights()
        XCTAssertTrue(insights.contains { $0.systemImage == "clock.fill" })
    }

    // MARK: - Pruning

    func testPruneRemovesEntriesOlderThan180Days() {
        let old = Date().addingTimeInterval(-181 * 24 * 3600)
        let recent = Date()
        repo.record(makeEntry(episodeId: "ep-old", podcastId: "pod-1", date: old))
        repo.record(makeEntry(episodeId: "ep-new", podcastId: "pod-1", date: recent))

        repo.pruneOldEntries()

        let all = repo.allEntries()
        XCTAssertFalse(all.contains { $0.episodeId == "ep-old" })
        XCTAssertTrue(all.contains { $0.episodeId == "ep-new" })
    }

    func testRecentEntriesSurvivePruning() {
        let withinWindow = Date().addingTimeInterval(-179 * 24 * 3600)
        repo.record(makeEntry(episodeId: "ep-inside", podcastId: "pod-1", date: withinWindow))
        repo.pruneOldEntries()
        XCTAssertTrue(repo.allEntries().contains { $0.episodeId == "ep-inside" })
    }

    // MARK: - Export

    func testExportJSONProducesValidJSON() throws {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1", duration: 1800))
        let data = try repo.exportData(format: .json)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testExportJSONContainsAllEntries() throws {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))
        repo.record(makeEntry(episodeId: "ep-2", podcastId: "pod-2"))

        let data = try repo.exportData(format: .json)
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 2)
    }

    func testExportCSVContainsHeader() throws {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))
        let data = try repo.exportData(format: .csv)
        let csv = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(csv.hasPrefix("id,episodeId,podcastId"))
    }

    func testExportCSVContainsEntryData() throws {
        repo.record(makeEntry(episodeId: "ep-1", podcastId: "pod-1"))
        let data = try repo.exportData(format: .csv)
        let csv = String(data: data, encoding: .utf8) ?? ""
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2) // header + 1 entry
        XCTAssertTrue(lines[1].contains("ep-1"))
    }

    // MARK: - Privacy Settings

    func testPrivacySettingsDefaultsToEnabled() {
        let privacy = UserDefaultsListeningHistoryPrivacySettings(userDefaults: harness.userDefaults)
        XCTAssertTrue(privacy.isListeningHistoryEnabled())
    }

    func testPrivacySettingsCanBeDisabled() {
        let privacy = UserDefaultsListeningHistoryPrivacySettings(userDefaults: harness.userDefaults)
        privacy.setListeningHistoryEnabled(false)
        XCTAssertFalse(privacy.isListeningHistoryEnabled())
    }

    func testPrivacySettingsPersistAcrossInstances() {
        let privacy1 = UserDefaultsListeningHistoryPrivacySettings(userDefaults: harness.userDefaults)
        privacy1.setListeningHistoryEnabled(false)

        let privacy2 = UserDefaultsListeningHistoryPrivacySettings(userDefaults: harness.userDefaults)
        XCTAssertFalse(privacy2.isListeningHistoryEnabled())
    }

    // MARK: - Extended Fields

    func testExtendedFieldsAreRecordedAndRetrieved() {
        let entry = PlaybackHistoryEntry(
            episodeId: "ep-1",
            podcastId: "pod-1",
            duration: 1800,
            completed: true,
            episodeTitle: "Great Episode",
            podcastTitle: "Best Podcast",
            playbackSpeed: 1.5
        )
        repo.record(entry)

        let retrieved = repo.allEntries().first
        XCTAssertEqual(retrieved?.episodeTitle, "Great Episode")
        XCTAssertEqual(retrieved?.podcastTitle, "Best Podcast")
        XCTAssertEqual(retrieved?.playbackSpeed, 1.5)
    }

    func testBackwardCompatibilityWithNilExtendedFields() {
        let entry = PlaybackHistoryEntry(
            episodeId: "ep-1",
            podcastId: "pod-1",
            duration: 1800,
            completed: true
        )
        repo.record(entry)

        let retrieved = repo.allEntries().first
        XCTAssertNil(retrieved?.episodeTitle)
        XCTAssertNil(retrieved?.podcastTitle)
        XCTAssertNil(retrieved?.playbackSpeed)
    }

    // MARK: - Helpers

    private func makeEntry(
        episodeId: String,
        podcastId: String,
        duration: TimeInterval = 300,
        completed: Bool = true,
        date: Date = Date(),
        episodeTitle: String? = nil,
        podcastTitle: String? = nil,
        playbackSpeed: Double? = nil
    ) -> PlaybackHistoryEntry {
        PlaybackHistoryEntry(
            episodeId: episodeId,
            podcastId: podcastId,
            playedAt: date,
            duration: duration,
            completed: completed,
            episodeTitle: episodeTitle,
            podcastTitle: podcastTitle,
            playbackSpeed: playbackSpeed
        )
    }
}
