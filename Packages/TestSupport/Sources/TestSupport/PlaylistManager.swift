import Foundation
import CoreModels

/// Mock playlist manager for testing playlist workflows
///
/// This @MainActor-bound manager provides an in-memory playlist implementation
/// suitable for integration tests. It manages both manual and smart playlists.
@MainActor
public final class PlaylistManager {
    public private(set) var playlists: [Playlist] = []
    public private(set) var smartPlaylists: [SmartPlaylist] = []
    
    public init() {}
    
    public func createPlaylist(_ playlist: Playlist) async {
        playlists.append(playlist)
    }
    
    public func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) async {
        smartPlaylists.append(smartPlaylist)
    }
}
