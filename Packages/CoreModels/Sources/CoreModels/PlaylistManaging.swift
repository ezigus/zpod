import Foundation

/// Protocol abstracting playlist CRUD operations.
///
/// Mirrors the existing `PodcastManaging` pattern: synchronous and suitable
/// for both in-memory (testing) and SwiftData (production) backends.
/// Not `Sendable` — all callers are `@MainActor`-isolated, so the protocol
/// value never crosses actor boundaries.
public protocol PlaylistManaging {
    // MARK: - Manual Playlists

    func allPlaylists() -> [Playlist]
    func findPlaylist(id: String) -> Playlist?
    func createPlaylist(_ playlist: Playlist)
    func updatePlaylist(_ playlist: Playlist)
    func deletePlaylist(id: String)
    func addEpisode(episodeId: String, to playlistId: String)
    func removeEpisode(episodeId: String, from playlistId: String)
    func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int)
    @discardableResult func duplicatePlaylist(id: String) -> Playlist?

    // MARK: - Smart Playlists

    func allSmartPlaylists() -> [SmartPlaylist]
    func findSmartPlaylist(id: String) -> SmartPlaylist?
    func createSmartPlaylist(_ smartPlaylist: SmartPlaylist)
    func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist)
    func deleteSmartPlaylist(id: String)
}
