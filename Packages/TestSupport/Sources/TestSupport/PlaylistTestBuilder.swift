import Foundation
import CoreModels
import XCTest

/// Builder for setting up playlist test scenarios
///
/// This builder simplifies the creation of playlists and smart playlists for testing.
/// It provides a fluent API for playlist setup.
///
/// Example usage:
/// ```swift
/// let builder = await PlaylistTestBuilder()
///     .withPlaylistManager(playlistManager)
///     .addManualPlaylist(name: "My Favorites", episodeIds: ["ep1", "ep2"])
///     .addSmartPlaylist(name: "Recent", maxEpisodes: 20)
/// ```
@MainActor
public final class PlaylistTestBuilder {
    private var playlistManager: PlaylistManager?
    
    public init() {}
    
    // MARK: - Manager Configuration
    
    /// Sets the playlist manager for this builder
    @discardableResult
    public func withPlaylistManager(_ manager: PlaylistManager) -> Self {
        self.playlistManager = manager
        return self
    }
    
    // MARK: - Playlist Setup
    
    /// Adds a manual playlist
    @discardableResult
    public func addManualPlaylist(
        id: String? = nil,
        name: String,
        episodeIds: [String] = [],
        continuousPlayback: Bool = false,
        shuffleAllowed: Bool = true
    ) async -> Self {
        guard let playlistManager = playlistManager else {
            XCTFail("Playlist manager not configured")
            return self
        }
        
        let playlist = Playlist(
            id: id ?? UUID().uuidString,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed
        )
        
        await playlistManager.createPlaylist(playlist)
        return self
    }
    
    /// Adds a smart playlist with customizable criteria
    @discardableResult
    public func addSmartPlaylist(
        id: String? = nil,
        name: String,
        maxEpisodes: Int = 50,
        orderBy: SmartPlaylistOrderBy = .dateAdded,
        filterRules: [SmartPlaylistFilterRule] = []
    ) async -> Self {
        guard let playlistManager = playlistManager else {
            XCTFail("Playlist manager not configured")
            return self
        }
        
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: maxEpisodes,
            orderBy: orderBy,
            filterRules: filterRules
        )
        
        let smartPlaylist = SmartPlaylist(
            id: id ?? UUID().uuidString,
            name: name,
            criteria: criteria
        )
        
        await playlistManager.createSmartPlaylist(smartPlaylist)
        return self
    }
    
    /// Adds a smart playlist for unplayed episodes
    @discardableResult
    public func addUnplayedSmartPlaylist(
        name: String = "Unplayed",
        maxEpisodes: Int = 50
    ) async -> Self {
        return await addSmartPlaylist(
            name: name,
            maxEpisodes: maxEpisodes,
            filterRules: [.isPlayed(false)]
        )
    }
    
    /// Adds a smart playlist for downloaded episodes
    @discardableResult
    public func addDownloadedSmartPlaylist(
        name: String = "Downloaded",
        maxEpisodes: Int = 50
    ) async -> Self {
        return await addSmartPlaylist(
            name: name,
            maxEpisodes: maxEpisodes,
            filterRules: [.isDownloaded]
        )
    }
}
