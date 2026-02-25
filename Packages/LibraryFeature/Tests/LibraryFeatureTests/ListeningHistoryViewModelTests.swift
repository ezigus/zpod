import CoreModels
import XCTest
@testable import LibraryFeature

// MARK: - Mock Listening History Repository

private final class MockListeningHistoryRepository: ListeningHistoryRepository,
    @unchecked Sendable
{
    var storedEntries: [PlaybackHistoryEntry] = []
    var stubbedStats: ListeningStatistics = .empty
    var stubbedInsights: [ListeningInsight] = []
    var lastFilter: ListeningHistoryFilter?
    var deletedIDs: [String] = []
    var deleteAllCalled = false
    var exportDataCalled = false
    var exportError: Error?

    func record(_ entry: PlaybackHistoryEntry) {
        storedEntries.append(entry)
    }

    func entries(matching filter: ListeningHistoryFilter) -> [PlaybackHistoryEntry] {
        lastFilter = filter
        return storedEntries
    }

    func allEntries() -> [PlaybackHistoryEntry] {
        storedEntries
    }

    func deleteEntry(id: String) {
        deletedIDs.append(id)
        storedEntries.removeAll { $0.id == id }
    }

    func deleteAll() {
        deleteAllCalled = true
        storedEntries.removeAll()
    }

    func statistics(matching filter: ListeningHistoryFilter) -> ListeningStatistics {
        lastFilter = filter
        return stubbedStats
    }

    func insights() -> [ListeningInsight] {
        stubbedInsights
    }

    func exportData(format: ListeningHistoryExportFormat) throws -> Data {
        exportDataCalled = true
        if let error = exportError { throw error }
        return Data("exported".utf8)
    }

    func pruneOldEntries() {}
}

// MARK: - Mock Privacy Provider

private struct MockListeningHistoryPrivacyProvider: ListeningHistoryPrivacyProvider {
    var enabled: Bool = true

    func isListeningHistoryEnabled() -> Bool { enabled }
    func setListeningHistoryEnabled(_ enabled: Bool) {}
}

// MARK: - ListeningHistoryViewModelTests

@MainActor
final class ListeningHistoryViewModelTests: XCTestCase {

    private func makeViewModel(
        entries: [PlaybackHistoryEntry] = [],
        stats: ListeningStatistics = .empty,
        insights: [ListeningInsight] = [],
        recordingEnabled: Bool = true
    ) -> (ListeningHistoryViewModel, MockListeningHistoryRepository) {
        let repo = MockListeningHistoryRepository()
        repo.storedEntries = entries
        repo.stubbedStats = stats
        repo.stubbedInsights = insights
        let privacy = MockListeningHistoryPrivacyProvider(enabled: recordingEnabled)
        let vm = ListeningHistoryViewModel(repository: repo, privacySettings: privacy)
        return (vm, repo)
    }

    private func makeEntry(
        id: String = UUID().uuidString,
        episodeTitle: String? = "Test Episode",
        podcastTitle: String? = "Test Podcast",
        completed: Bool = true,
        playedAt: Date = Date()
    ) -> PlaybackHistoryEntry {
        PlaybackHistoryEntry(
            id: id,
            episodeId: UUID().uuidString,
            podcastId: "pod-1",
            playedAt: playedAt,
            duration: 1800,
            completed: completed,
            episodeTitle: episodeTitle,
            podcastTitle: podcastTitle
        )
    }

    // MARK: - Load History

    func testLoadHistoryPopulatesAllEntries() {
        let entries = [makeEntry(id: "1"), makeEntry(id: "2"), makeEntry(id: "3")]
        let (vm, _) = makeViewModel(entries: entries)

        vm.loadHistory()

        XCTAssertEqual(vm.allEntries.count, 3)
    }

    func testLoadHistoryPopulatesStatistics() {
        let stats = ListeningStatistics(
            totalListeningTime: 7200,
            episodesStarted: 4,
            episodesCompleted: 3,
            completionRate: 0.75,
            currentStreak: 2,
            longestStreak: 5,
            topPodcasts: [],
            dailyAverage: 1800
        )
        let (vm, _) = makeViewModel(stats: stats)

        vm.loadHistory()

        XCTAssertEqual(vm.statistics.totalListeningTime, 7200)
        XCTAssertEqual(vm.statistics.episodesCompleted, 3)
    }

    func testLoadHistoryPopulatesInsights() {
        let insights = [
            ListeningInsight(text: "Consistent listener", systemImage: "checkmark.circle"),
        ]
        let (vm, _) = makeViewModel(insights: insights)

        vm.loadHistory()

        XCTAssertEqual(vm.insights.count, 1)
        XCTAssertEqual(vm.insights[0].text, "Consistent listener")
    }

    func testLoadHistoryChecksRecordingEnabled() {
        let (vm, _) = makeViewModel(recordingEnabled: false)

        vm.loadHistory()

        XCTAssertFalse(vm.isRecordingEnabled)
    }

    func testLoadHistoryRecordingEnabledTrue() {
        let (vm, _) = makeViewModel(recordingEnabled: true)

        vm.loadHistory()

        XCTAssertTrue(vm.isRecordingEnabled)
    }

    // MARK: - Search Filter

    func testSearchQueryFiltersEntriesByEpisodeTitle() {
        let entries = [
            makeEntry(id: "1", episodeTitle: "Swift Concurrency Deep Dive"),
            makeEntry(id: "2", episodeTitle: "Android Development"),
        ]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.searchQuery = "swift"

        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertEqual(vm.filteredEntries[0].episodeTitle, "Swift Concurrency Deep Dive")
    }

    func testSearchQueryFiltersByPodcastTitle() {
        let entries = [
            makeEntry(id: "1", podcastTitle: "Swift Talk"),
            makeEntry(id: "2", podcastTitle: "Android Weekly"),
        ]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.searchQuery = "android"

        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertEqual(vm.filteredEntries[0].podcastTitle, "Android Weekly")
    }

    func testSearchQueryCaseInsensitive() {
        let entries = [makeEntry(id: "1", episodeTitle: "SWIFT ROCKS")]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.searchQuery = "swift"

        XCTAssertEqual(vm.filteredEntries.count, 1)
    }

    func testEmptySearchQueryReturnsAllEntries() {
        let entries = [makeEntry(id: "1"), makeEntry(id: "2")]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.searchQuery = ""

        XCTAssertEqual(vm.filteredEntries.count, 2)
    }

    // MARK: - Completion Filter

    func testCompletionFilterCompletedOnly() {
        let entries = [
            makeEntry(id: "1", completed: true),
            makeEntry(id: "2", completed: false),
            makeEntry(id: "3", completed: true),
        ]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.completionFilter = true

        XCTAssertEqual(vm.filteredEntries.count, 2)
        XCTAssertTrue(vm.filteredEntries.allSatisfy(\.completed))
    }

    func testCompletionFilterInProgressOnly() {
        let entries = [
            makeEntry(id: "1", completed: true),
            makeEntry(id: "2", completed: false),
        ]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.completionFilter = false

        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertFalse(vm.filteredEntries[0].completed)
    }

    func testNilCompletionFilterReturnsAll() {
        let entries = [makeEntry(completed: true), makeEntry(completed: false)]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.completionFilter = nil

        XCTAssertEqual(vm.filteredEntries.count, 2)
    }

    // MARK: - Entries By Day

    func testEntriesByDayGroupsCorrectly() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            makeEntry(id: "1", playedAt: today),
            makeEntry(id: "2", playedAt: today),
            makeEntry(id: "3", playedAt: yesterday),
        ]
        let (vm, _) = makeViewModel(entries: entries)
        vm.loadHistory()

        let groups = vm.entriesByDay
        XCTAssertEqual(groups.count, 2)
        // Most recent day first
        XCTAssertEqual(groups[0].entries.count, 2)
        XCTAssertEqual(groups[1].entries.count, 1)
    }

    // MARK: - Formatted Display Values

    func testFormattedTotalTimeDisplaysCorrectly() {
        let stats = ListeningStatistics(
            totalListeningTime: 4 * 3600 + 12 * 60,
            episodesStarted: 0,
            episodesCompleted: 0,
            completionRate: 0,
            currentStreak: 0,
            longestStreak: 0,
            topPodcasts: [],
            dailyAverage: 0
        )
        let (vm, _) = makeViewModel(stats: stats)
        vm.loadHistory()

        XCTAssertFalse(vm.formattedTotalTime.isEmpty)
        XCTAssertTrue(vm.formattedTotalTime.contains("4"))
    }

    func testFormattedCompletionRateDisplaysPercentage() {
        let stats = ListeningStatistics(
            totalListeningTime: 0,
            episodesStarted: 100,
            episodesCompleted: 74,
            completionRate: 0.74,
            currentStreak: 0,
            longestStreak: 0,
            topPodcasts: [],
            dailyAverage: 0
        )
        let (vm, _) = makeViewModel(stats: stats)
        vm.loadHistory()

        XCTAssertEqual(vm.formattedCompletionRate, "74%")
    }

    func testFormattedDailyAverageZeroReturnsZeroM() {
        let (vm, _) = makeViewModel(stats: .empty)
        vm.loadHistory()

        XCTAssertEqual(vm.formattedDailyAverage, "0m")
    }

    // MARK: - Delete

    func testDeleteEntryCallsRepositoryAndReloads() {
        let entry = makeEntry(id: "del-1")
        let (vm, repo) = makeViewModel(entries: [entry])
        vm.loadHistory()

        vm.deleteEntry(id: "del-1")

        XCTAssertTrue(repo.deletedIDs.contains("del-1"))
    }

    func testDeleteAllEntriesCallsRepositoryAndReloads() {
        let entries = [makeEntry(id: "1"), makeEntry(id: "2")]
        let (vm, repo) = makeViewModel(entries: entries)
        vm.loadHistory()

        vm.deleteAllEntries()

        XCTAssertTrue(repo.deleteAllCalled)
    }

    // MARK: - Export

    func testExportDataDelegatesToRepository() throws {
        let (vm, _) = makeViewModel()

        let data = try vm.exportData(format: .json)

        XCTAssertFalse(data.isEmpty)
    }

    func testExportDataThrowsWhenRepositoryFails() {
        struct ExportError: Error {}
        let (vm, repo) = makeViewModel()
        repo.exportError = ExportError()

        XCTAssertThrowsError(try vm.exportData(format: .json))
    }
}
