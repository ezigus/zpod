import XCTest
@testable import CoreModels

/// Unit tests for InMemoryPlaylistManager CRUD lifecycle and episode operations.
/// Exercises the data-layer contract independently of any ViewModel or UI layer.
@available(macOS 10.15, *)
final class InMemoryPlaylistManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeManager(playlists: [Playlist] = []) -> InMemoryPlaylistManager {
        let manager = InMemoryPlaylistManager()
        for playlist in playlists {
            manager.createPlaylist(playlist)
        }
        return manager
    }

    private func makeSamplePlaylist(
        id: String = UUID().uuidString,
        name: String = "Test Playlist",
        description: String = "",
        episodeIds: [String] = []
    ) -> Playlist {
        Playlist(id: id, name: name, description: description, episodeIds: episodeIds)
    }

    // MARK: - Create

    func testCreatePlaylistAppendsToList() {
        // Given
        let manager = makeManager()
        let playlist = makeSamplePlaylist(name: "Morning Drive")

        // When
        manager.createPlaylist(playlist)

        // Then
        XCTAssertEqual(manager.allPlaylists().count, 1)
        XCTAssertEqual(manager.allPlaylists()[0].name, "Morning Drive")
    }

    func testCreatePlaylistIgnoresDuplicateId() {
        // Given
        let playlist = makeSamplePlaylist(id: "unique-id", name: "Original")
        let manager = makeManager(playlists: [playlist])

        // When - attempt to add another playlist with same ID
        let duplicate = makeSamplePlaylist(id: "unique-id", name: "Duplicate")
        manager.createPlaylist(duplicate)

        // Then - only the original should be present
        XCTAssertEqual(manager.allPlaylists().count, 1)
        XCTAssertEqual(manager.allPlaylists()[0].name, "Original")
    }

    func testCreateMultiplePlaylists() {
        // Given
        let manager = makeManager()

        // When
        manager.createPlaylist(makeSamplePlaylist(name: "A"))
        manager.createPlaylist(makeSamplePlaylist(name: "B"))
        manager.createPlaylist(makeSamplePlaylist(name: "C"))

        // Then
        XCTAssertEqual(manager.allPlaylists().count, 3)
    }

    // MARK: - Find

    func testFindPlaylistByIdReturnsCorrectPlaylist() {
        // Given
        let playlist = makeSamplePlaylist(id: "target-id", name: "Target")
        let manager = makeManager(playlists: [playlist])

        // When
        let found = manager.findPlaylist(id: "target-id")

        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Target")
    }

    func testFindPlaylistByIdReturnsNilForMissingId() {
        // Given
        let manager = makeManager()

        // When
        let found = manager.findPlaylist(id: "does-not-exist")

        // Then
        XCTAssertNil(found)
    }

    // MARK: - Update

    func testUpdatePlaylistChangesName() {
        // Given
        let original = makeSamplePlaylist(id: "pl-1", name: "Old Name")
        let manager = makeManager(playlists: [original])

        // When
        let updated = original.withName("New Name")
        manager.updatePlaylist(updated)

        // Then
        XCTAssertEqual(manager.allPlaylists()[0].name, "New Name")
    }

    func testUpdatePlaylistChangesDescription() {
        // Given
        let original = makeSamplePlaylist(id: "pl-1", name: "My List")
        let manager = makeManager(playlists: [original])

        // When
        let updated = original.withDescription("A great description")
        manager.updatePlaylist(updated)

        // Then
        XCTAssertEqual(manager.allPlaylists()[0].description, "A great description")
    }

    func testUpdateNonExistentPlaylistDoesNothing() {
        // Given
        let manager = makeManager()
        let phantom = makeSamplePlaylist(id: "ghost", name: "Ghost")

        // When
        manager.updatePlaylist(phantom)

        // Then
        XCTAssertTrue(manager.allPlaylists().isEmpty)
    }

    // MARK: - Delete

    func testDeletePlaylistRemovesById() {
        // Given
        let playlist = makeSamplePlaylist(id: "del-id", name: "To Delete")
        let manager = makeManager(playlists: [playlist])

        // When
        manager.deletePlaylist(id: "del-id")

        // Then
        XCTAssertTrue(manager.allPlaylists().isEmpty)
    }

    func testDeletePlaylistOnlyRemovesTarget() {
        // Given
        let p1 = makeSamplePlaylist(id: "keep", name: "Keep")
        let p2 = makeSamplePlaylist(id: "remove", name: "Remove")
        let manager = makeManager(playlists: [p1, p2])

        // When
        manager.deletePlaylist(id: "remove")

        // Then
        XCTAssertEqual(manager.allPlaylists().count, 1)
        XCTAssertEqual(manager.allPlaylists()[0].id, "keep")
    }

    func testDeleteNonExistentPlaylistDoesNothing() {
        // Given
        let playlist = makeSamplePlaylist(name: "Existing")
        let manager = makeManager(playlists: [playlist])

        // When
        manager.deletePlaylist(id: "does-not-exist")

        // Then
        XCTAssertEqual(manager.allPlaylists().count, 1)
    }

    // MARK: - Episode Operations

    func testAddEpisodeAppendsToPlaylist() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1")
        let manager = makeManager(playlists: [playlist])

        // When
        manager.addEpisode(episodeId: "ep-42", to: "pl-1")

        // Then
        XCTAssertEqual(manager.findPlaylist(id: "pl-1")?.episodeIds, ["ep-42"])
    }

    func testAddEpisodeSkipsDuplicates() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1", episodeIds: ["ep-1"])
        let manager = makeManager(playlists: [playlist])

        // When
        manager.addEpisode(episodeId: "ep-1", to: "pl-1")

        // Then
        XCTAssertEqual(manager.findPlaylist(id: "pl-1")?.episodeIds.count, 1)
    }

    func testAddEpisodeToNonExistentPlaylistDoesNothing() {
        // Given
        let manager = makeManager()

        // When (no crash expected)
        manager.addEpisode(episodeId: "ep-1", to: "missing-playlist")

        // Then
        XCTAssertTrue(manager.allPlaylists().isEmpty)
    }

    func testRemoveEpisodeDeletesFromPlaylist() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1", episodeIds: ["ep-1", "ep-2"])
        let manager = makeManager(playlists: [playlist])

        // When
        manager.removeEpisode(episodeId: "ep-1", from: "pl-1")

        // Then
        XCTAssertEqual(manager.findPlaylist(id: "pl-1")?.episodeIds, ["ep-2"])
    }

    func testRemoveNonExistentEpisodeDoesNothing() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1", episodeIds: ["ep-1"])
        let manager = makeManager(playlists: [playlist])

        // When
        manager.removeEpisode(episodeId: "ep-ghost", from: "pl-1")

        // Then
        XCTAssertEqual(manager.findPlaylist(id: "pl-1")?.episodeIds, ["ep-1"])
    }

    func testReorderEpisodesMovesItemsCorrectly() {
        // Given: [ep-1, ep-2, ep-3], move ep-3 to position 0
        let playlist = makeSamplePlaylist(id: "pl-1", episodeIds: ["ep-1", "ep-2", "ep-3"])
        let manager = makeManager(playlists: [playlist])

        // When
        manager.reorderEpisodes(in: "pl-1", from: IndexSet(integer: 2), to: 0)

        // Then
        XCTAssertEqual(manager.findPlaylist(id: "pl-1")?.episodeIds, ["ep-3", "ep-1", "ep-2"])
    }

    // MARK: - Duplicate Playlist

    func testDuplicatePlaylistCreatesIndependentCopy() {
        // Given
        let original = makeSamplePlaylist(id: "orig", name: "My List", description: "Great list", episodeIds: ["ep-1", "ep-2"])
        let manager = makeManager(playlists: [original])

        // When
        let copy = manager.duplicatePlaylist(id: "orig")

        // Then
        XCTAssertNotNil(copy)
        XCTAssertEqual(manager.allPlaylists().count, 2)
        XCTAssertNotEqual(copy?.id, "orig")
        XCTAssertEqual(copy?.name, "My List Copy")
        XCTAssertEqual(copy?.description, "Great list")
        XCTAssertEqual(copy?.episodeIds, ["ep-1", "ep-2"])
    }

    func testDuplicateNonExistentPlaylistReturnsNil() {
        // Given
        let manager = makeManager()

        // When
        let result = manager.duplicatePlaylist(id: "missing")

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Description Field

    func testPlaylistDescriptionStoredAndRetrieved() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1", name: "Described", description: "A helpful description")
        let manager = makeManager(playlists: [playlist])

        // When
        let found = manager.findPlaylist(id: "pl-1")

        // Then
        XCTAssertEqual(found?.description, "A helpful description")
    }

    func testWithDescriptionBuilderPreservesOtherFields() {
        // Given
        let playlist = makeSamplePlaylist(id: "pl-1", name: "Named", episodeIds: ["ep-1"])

        // When
        let updated = playlist.withDescription("New description")

        // Then — only description changed, other fields preserved
        XCTAssertEqual(updated.id, "pl-1")
        XCTAssertEqual(updated.name, "Named")
        XCTAssertEqual(updated.episodeIds, ["ep-1"])
        XCTAssertEqual(updated.description, "New description")
        // updatedAt must have advanced
        XCTAssertGreaterThanOrEqual(updated.updatedAt, playlist.updatedAt)
    }

    // MARK: - Monotonic updatedAt

    func testUpdatedAtAdvancesOnWithEpisodes() {
        // Given
        let playlist = makeSamplePlaylist()
        let originalUpdatedAt = playlist.updatedAt

        // When (fast successive update)
        let updated = playlist.withEpisodes(["ep-1"])

        // Then
        XCTAssertGreaterThanOrEqual(updated.updatedAt, originalUpdatedAt)
        // Should not equal the original (monotonic advancement)
        if updated.updatedAt == originalUpdatedAt {
            // The monotonic helper should have bumped it by 0.001s
            XCTFail("updatedAt should have advanced from original value")
        }
    }
}
