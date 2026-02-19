import XCTest
import CoreModels
@testable import PlaylistFeature

@MainActor
final class PlaylistFeatureTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(
        playlists: [Playlist] = []
    ) -> (PlaylistViewModel, InMemoryPlaylistManager) {
        let manager = InMemoryPlaylistManager()
        for playlist in playlists {
            manager.createPlaylist(playlist)
        }
        let vm = PlaylistViewModel(manager: manager)
        return (vm, manager)
    }

    private func makeSamplePlaylist(
        id: String = UUID().uuidString,
        name: String = "Test Playlist",
        description: String = "",
        episodeIds: [String] = []
    ) -> Playlist {
        Playlist(id: id, name: name, description: description, episodeIds: episodeIds)
    }

    // MARK: - Initialization

    func testInitLoadesExistingPlaylists() {
        let playlists = [makeSamplePlaylist(name: "A"), makeSamplePlaylist(name: "B")]
        let (vm, _) = makeViewModel(playlists: playlists)
        XCTAssertEqual(vm.playlists.count, 2)
    }

    func testInitDefaultSheetStateIsFalse() {
        let (vm, _) = makeViewModel()
        XCTAssertFalse(vm.isShowingCreateSheet)
        XCTAssertNil(vm.editingPlaylist)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Create Playlist

    func testCreatePlaylistAddsToList() {
        let (vm, _) = makeViewModel()
        vm.createPlaylist(name: "Morning Drive")
        XCTAssertEqual(vm.playlists.count, 1)
        XCTAssertEqual(vm.playlists[0].name, "Morning Drive")
    }

    func testCreatePlaylistWithDescription() {
        let (vm, _) = makeViewModel()
        vm.createPlaylist(name: "Tech", description: "Deep dives into tech")
        XCTAssertEqual(vm.playlists[0].description, "Deep dives into tech")
    }

    func testCreatePlaylistTrimsWhitespace() {
        let (vm, _) = makeViewModel()
        vm.createPlaylist(name: "  Trimmed  ")
        XCTAssertEqual(vm.playlists[0].name, "Trimmed")
    }

    func testCreatePlaylistIgnoresEmptyName() {
        let (vm, _) = makeViewModel()
        vm.createPlaylist(name: "   ")
        XCTAssertTrue(vm.playlists.isEmpty)
    }

    // MARK: - Update Playlist

    func testUpdatePlaylistChangesName() {
        let original = makeSamplePlaylist(name: "Old Name")
        let (vm, _) = makeViewModel(playlists: [original])
        let updated = original.withName("New Name")
        vm.updatePlaylist(updated)
        XCTAssertEqual(vm.playlists[0].name, "New Name")
    }

    func testUpdatePlaylistChangesDescription() {
        let original = makeSamplePlaylist(name: "My List")
        let (vm, _) = makeViewModel(playlists: [original])
        let updated = original.withDescription("A great description")
        vm.updatePlaylist(updated)
        XCTAssertEqual(vm.playlists[0].description, "A great description")
    }

    // MARK: - Delete Playlist

    func testDeletePlaylistByIdRemovesIt() {
        let p = makeSamplePlaylist(id: "del-1", name: "To Delete")
        let (vm, _) = makeViewModel(playlists: [p])
        vm.deletePlaylist(id: "del-1")
        XCTAssertTrue(vm.playlists.isEmpty)
    }

    func testDeletePlaylistAtOffsetsRemovesCorrectItem() {
        let p1 = makeSamplePlaylist(name: "First")
        let p2 = makeSamplePlaylist(name: "Second")
        let (vm, _) = makeViewModel(playlists: [p1, p2])
        vm.deletePlaylist(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.playlists.count, 1)
        XCTAssertEqual(vm.playlists[0].name, "Second")
    }

    // MARK: - Duplicate Playlist

    func testDuplicatePlaylistCreatesACopy() {
        let p = makeSamplePlaylist(name: "Original", description: "Desc", episodeIds: ["ep-1"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.duplicatePlaylist(p)
        XCTAssertEqual(vm.playlists.count, 2)
        let copy = vm.playlists[1]
        XCTAssertEqual(copy.name, "Original Copy")
        XCTAssertEqual(copy.description, "Desc")
        XCTAssertEqual(copy.episodeIds, ["ep-1"])
        XCTAssertNotEqual(copy.id, p.id)
    }

    // MARK: - Episode Management

    func testAddEpisodeAppendsToPlaylist() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist")
        let (vm, _) = makeViewModel(playlists: [p])
        vm.addEpisode("ep-42", to: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-42"])
    }

    func testAddEpisodeDoesNotDuplicate() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.addEpisode("ep-1", to: p)
        XCTAssertEqual(vm.playlists[0].episodeIds.count, 1)
    }

    func testRemoveEpisodeDeletesFromPlaylist() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1", "ep-2"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.removeEpisode("ep-1", from: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-2"])
    }

    func testRemoveEpisodesAtOffsetsDeletesCorrectOnes() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1", "ep-2", "ep-3"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.removeEpisodes(at: IndexSet([0, 2]), from: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-2"])
    }

    func testReorderEpisodesMovesItems() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1", "ep-2", "ep-3"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.reorderEpisodes(in: p, from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-3", "ep-1", "ep-2"])
    }

    // MARK: - Batch Episode Addition

    func testAddEpisodesAddsMultipleAtOnce() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist")
        let (vm, _) = makeViewModel(playlists: [p])
        vm.addEpisodes(["ep-1", "ep-2", "ep-3"], to: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-1", "ep-2", "ep-3"])
    }

    func testAddEpisodesSkipsDuplicates() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.addEpisodes(["ep-1", "ep-2"], to: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-1", "ep-2"])
    }

    func testAddEpisodesWithEmptyArrayDoesNotChangePlaylist() {
        let p = makeSamplePlaylist(id: "pl-1", name: "My Playlist", episodeIds: ["ep-1"])
        let (vm, _) = makeViewModel(playlists: [p])
        vm.addEpisodes([], to: p)
        XCTAssertEqual(vm.playlists[0].episodeIds, ["ep-1"])
    }

    // MARK: - Episode Provider

    func testEpisodeProviderResolvesEpisodesForPlaylist() {
        let p = makeSamplePlaylist(name: "My Playlist")
        let episode = Episode(
            id: "ep-1",
            title: "Test Episode",
            podcastID: "pod-1",
            podcastTitle: "Test Podcast"
        )
        let manager = InMemoryPlaylistManager()
        manager.createPlaylist(p)
        let vm = PlaylistViewModel(manager: manager) { _ in [episode] }
        let resolved = vm.episodes(for: p)
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].id, "ep-1")
    }

    // MARK: - Total Duration

    func testTotalDurationSumsEpisodeDurations() {
        let p = makeSamplePlaylist(id: "pl-dur", name: "Duration Test", episodeIds: ["ep-1", "ep-2"])
        let episodes = [
            Episode(id: "ep-1", title: "E1", podcastID: "pod-1", podcastTitle: "P1", duration: 1800),
            Episode(id: "ep-2", title: "E2", podcastID: "pod-1", podcastTitle: "P1", duration: 900),
        ]
        let manager = InMemoryPlaylistManager()
        manager.createPlaylist(p)
        let vm = PlaylistViewModel(manager: manager) { _ in episodes }
        XCTAssertEqual(vm.totalDuration(for: p), 2700)
    }

    func testTotalDurationReturnsNilForEmptyEpisodeList() {
        let p = makeSamplePlaylist(id: "pl-empty", name: "Empty", episodeIds: [])
        let (vm, _) = makeViewModel(playlists: [p])
        XCTAssertNil(vm.totalDuration(for: p))
    }

    func testTotalDurationReturnsNilWhenNoEpisodeDurationsKnown() {
        let p = makeSamplePlaylist(id: "pl-nodur", name: "No Durations", episodeIds: ["ep-1"])
        let episodes = [Episode(id: "ep-1", title: "E1", podcastID: "pod-1", podcastTitle: "P1")]
        let manager = InMemoryPlaylistManager()
        manager.createPlaylist(p)
        let vm = PlaylistViewModel(manager: manager) { _ in episodes }
        XCTAssertNil(vm.totalDuration(for: p))
    }

    func testTotalDurationSkipsNilDurations() {
        let p = makeSamplePlaylist(id: "pl-mixed", name: "Mixed", episodeIds: ["ep-1", "ep-2"])
        let episodes = [
            Episode(id: "ep-1", title: "E1", podcastID: "pod-1", podcastTitle: "P1", duration: 600),
            Episode(id: "ep-2", title: "E2", podcastID: "pod-1", podcastTitle: "P1"), // no duration
        ]
        let manager = InMemoryPlaylistManager()
        manager.createPlaylist(p)
        let vm = PlaylistViewModel(manager: manager) { _ in episodes }
        XCTAssertEqual(vm.totalDuration(for: p), 600)
    }
}
