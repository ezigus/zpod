import CoreModels
import Foundation

/// ViewModel for playlist management screens.
///
/// Owns the list state and delegates persistence to an injected `PlaylistManaging`.
/// Episode resolution is performed via an injected provider closure so the feature
/// package remains independent of the concrete persistence or networking layers.
@MainActor
@Observable
public final class PlaylistViewModel {

    // MARK: - Observable State

    public private(set) var playlists: [Playlist] = []
    public var isShowingCreateSheet = false
    public var editingPlaylist: Playlist? = nil
    public var errorMessage: String? = nil

    // MARK: - Dependencies

    private let manager: any PlaylistManaging
    private let episodeProvider: (Playlist) -> [Episode]

    // MARK: - Initialization

    public init(
        manager: any PlaylistManaging,
        episodeProvider: @escaping (Playlist) -> [Episode] = { _ in [] }
    ) {
        self.manager = manager
        self.episodeProvider = episodeProvider
        self.playlists = manager.allPlaylists()
    }

    // MARK: - Episode Resolution

    public func episodes(for playlist: Playlist) -> [Episode] {
        episodeProvider(playlist)
    }

    // MARK: - Playlist CRUD

    public func createPlaylist(name: String, description: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let playlist = Playlist(name: trimmedName, description: description)
        manager.createPlaylist(playlist)
        reload()
    }

    public func updatePlaylist(_ playlist: Playlist) {
        manager.updatePlaylist(playlist)
        reload()
    }

    public func deletePlaylist(at offsets: IndexSet) {
        for index in offsets {
            manager.deletePlaylist(id: playlists[index].id)
        }
        reload()
    }

    public func deletePlaylist(id: String) {
        manager.deletePlaylist(id: id)
        reload()
    }

    public func duplicatePlaylist(_ playlist: Playlist) {
        manager.duplicatePlaylist(id: playlist.id)
        reload()
    }

    // MARK: - Episode Management

    public func addEpisode(_ episodeId: String, to playlist: Playlist) {
        manager.addEpisode(episodeId: episodeId, to: playlist.id)
        reload()
    }

    public func removeEpisode(_ episodeId: String, from playlist: Playlist) {
        manager.removeEpisode(episodeId: episodeId, from: playlist.id)
        reload()
    }

    public func removeEpisodes(at offsets: IndexSet, from playlist: Playlist) {
        let idsToRemove = offsets.map { playlist.episodeIds[$0] }
        for episodeId in idsToRemove {
            manager.removeEpisode(episodeId: episodeId, from: playlist.id)
        }
        reload()
    }

    public func reorderEpisodes(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        manager.reorderEpisodes(in: playlist.id, from: source, to: destination)
        reload()
    }

    // MARK: - Private

    private func reload() {
        playlists = manager.allPlaylists()
    }
}
