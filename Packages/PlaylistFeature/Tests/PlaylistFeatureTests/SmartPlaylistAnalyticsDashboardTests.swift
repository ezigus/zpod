import XCTest
import CoreModels
@testable import PlaylistFeature

// MARK: - Mock Analytics Repository

private final class MockSmartPlaylistAnalyticsRepository: SmartPlaylistAnalyticsRepository,
    @unchecked Sendable
{
    var recordedEvents: [SmartPlaylistPlayEvent] = []
    var stubbedStats: SmartPlaylistStats?
    var stubbedInsights: [SmartPlaylistInsight] = []

    func record(_ event: SmartPlaylistPlayEvent) {
        recordedEvents.append(event)
    }

    func events(for playlistID: String) -> [SmartPlaylistPlayEvent] {
        recordedEvents.filter { $0.playlistID == playlistID }
    }

    func stats(for playlistID: String) -> SmartPlaylistStats {
        stubbedStats ?? SmartPlaylistStats.empty(for: playlistID)
    }

    func insights(for playlistID: String) -> [SmartPlaylistInsight] {
        stubbedInsights
    }

    func exportJSON(for playlistID: String) throws -> Data {
        try JSONEncoder().encode(events(for: playlistID))
    }

    func pruneOldEvents() {}
}

// MARK: - SmartPlaylistAnalyticsDashboardTests

@MainActor
final class SmartPlaylistAnalyticsDashboardTests: XCTestCase {

    private func makeViewModel(
        repository: (any SmartPlaylistAnalyticsRepository)? = nil
    ) -> SmartPlaylistViewModel {
        let manager = InMemorySmartPlaylistManager(
            initialSmartPlaylists: SmartEpisodeListV2.builtInSmartLists
        )
        let vm = SmartPlaylistViewModel(manager: manager, allEpisodesProvider: { [] })
        vm.analyticsRepository = repository
        return vm
    }

    private func makeSamplePlaylist() -> SmartEpisodeListV2 {
        SmartEpisodeListV2(
            name: "Test Playlist",
            rules: SmartListRuleSet(rules: []),
            sortBy: .pubDateNewest
        )
    }

    // MARK: - Stats

    func testStatsReturnsEmptyWhenNoAnalyticsRepository() {
        let vm = makeViewModel(repository: nil)
        let playlist = makeSamplePlaylist()

        let stats = vm.stats(for: playlist)

        XCTAssertEqual(stats.totalPlays, 0)
        XCTAssertEqual(stats.uniqueEpisodesPlayed, 0)
        XCTAssertEqual(stats.totalPlaybackDuration, 0)
        XCTAssertNil(stats.mostRecentPlay)
    }

    func testStatsReturnsCachedValues() {
        let mock = MockSmartPlaylistAnalyticsRepository()
        let playlist = makeSamplePlaylist()
        mock.stubbedStats = SmartPlaylistStats(
            playlistID: playlist.id,
            totalPlays: 12,
            uniqueEpisodesPlayed: 7,
            totalPlaybackDuration: 3600,
            mostRecentPlay: Date()
        )
        let vm = makeViewModel(repository: mock)

        let stats = vm.stats(for: playlist)

        XCTAssertEqual(stats.totalPlays, 12)
        XCTAssertEqual(stats.uniqueEpisodesPlayed, 7)
        XCTAssertEqual(stats.totalPlaybackDuration, 3600)
    }

    // MARK: - Insights

    func testInsightsReturnEmptyWhenNoAnalyticsRepository() {
        let vm = makeViewModel(repository: nil)
        let playlist = makeSamplePlaylist()

        XCTAssertTrue(vm.insights(for: playlist).isEmpty)
    }

    func testInsightsReturnsRepositoryValues() {
        let mock = MockSmartPlaylistAnalyticsRepository()
        mock.stubbedInsights = [
            SmartPlaylistInsight(text: "You play this weekly", systemImage: "calendar"),
            SmartPlaylistInsight(text: "One of your top playlists", systemImage: "star.fill"),
        ]
        let vm = makeViewModel(repository: mock)
        let playlist = makeSamplePlaylist()

        let insights = vm.insights(for: playlist)

        XCTAssertEqual(insights.count, 2)
        XCTAssertEqual(insights[0].text, "You play this weekly")
    }

    // MARK: - Export

    func testExportJSONReturnsEmptyArrayWhenNoRepository() throws {
        let vm = makeViewModel(repository: nil)
        let playlist = makeSamplePlaylist()

        let data = try vm.exportJSON(for: playlist)
        let decoded = try JSONDecoder().decode([SmartPlaylistPlayEvent].self, from: data)

        XCTAssertTrue(decoded.isEmpty)
    }

    func testExportJSONReturnsEncodedData() throws {
        let mock = MockSmartPlaylistAnalyticsRepository()
        let playlist = makeSamplePlaylist()
        let event = SmartPlaylistPlayEvent(
            playlistID: playlist.id,
            episodeID: "ep-1",
            episodeDuration: 1800
        )
        mock.recordedEvents = [event]
        let vm = makeViewModel(repository: mock)

        let data = try vm.exportJSON(for: playlist)
        let decoded = try JSONDecoder().decode([SmartPlaylistPlayEvent].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].episodeID, "ep-1")
    }

    // MARK: - Record Play

    func testRecordPlayDelegatesToRepository() {
        let mock = MockSmartPlaylistAnalyticsRepository()
        let vm = makeViewModel(repository: mock)
        let playlist = makeSamplePlaylist()
        let episode = Episode(
            id: "ep-42",
            title: "Test Episode",
            podcastID: "pod-1",
            podcastTitle: "My Podcast",
            isPlayed: false
        )

        vm.recordPlay(of: episode, from: playlist)

        XCTAssertEqual(mock.recordedEvents.count, 1)
        XCTAssertEqual(mock.recordedEvents[0].episodeID, "ep-42")
        XCTAssertEqual(mock.recordedEvents[0].playlistID, playlist.id)
    }

    func testRecordPlayIsNoOpWhenNoRepository() {
        let vm = makeViewModel(repository: nil)
        let playlist = makeSamplePlaylist()
        let episode = Episode(
            id: "ep-1",
            title: "Episode",
            podcastID: "pod-1",
            podcastTitle: "Podcast",
            isPlayed: false
        )
        // Should not crash
        vm.recordPlay(of: episode, from: playlist)
    }

    // MARK: - Dashboard Toggle

    func testAnalyticsDashboardToggleState() {
        let vm = makeViewModel()

        XCTAssertFalse(vm.isShowingAnalyticsDashboard)
        vm.isShowingAnalyticsDashboard = true
        XCTAssertTrue(vm.isShowingAnalyticsDashboard)
        vm.isShowingAnalyticsDashboard = false
        XCTAssertFalse(vm.isShowingAnalyticsDashboard)
    }
}
