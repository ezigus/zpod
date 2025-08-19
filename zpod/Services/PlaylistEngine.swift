import Foundation
@preconcurrency import Combine

/// Service for evaluating smart playlists and generating playback queues
@MainActor
public protocol PlaylistEngineProtocol {
    /// Evaluate smart playlist to concrete episode list
    func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) -> [Episode]
    
    /// Generate playback queue from manual playlist with shuffle support
    func generatePlaybackQueue(
        from playlist: Playlist,
        episodes: [Episode],
        shuffle: Bool
    ) -> [Episode]
    
    /// Generate playback queue from smart playlist with shuffle support  
    func generatePlaybackQueue(
        from smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState],
        shuffle: Bool
    ) -> [Episode]
}

/// Implementation of playlist evaluation engine
@MainActor
public class PlaylistEngine: PlaylistEngineProtocol {
    
    public init() {}
    
    public func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) -> [Episode] {
        // Convert rule data to rule objects
        let rules = smartPlaylist.rules.compactMap { PlaylistRuleFactory.createRule(from: $0) }
        
        // Filter episodes matching ALL rules (AND logic)
        let matchingEpisodes = episodes.filter { episode in
            // Empty rules means match all episodes
            guard !rules.isEmpty else { return true }
            
            // All rules must match for episode to be included
            return rules.allSatisfy { rule in
                rule.matches(episode: episode, downloadStatus: downloadStatuses[episode.id])
            }
        }
        
        // Apply sorting
        let sortedEpisodes = sortEpisodes(matchingEpisodes, by: smartPlaylist.sortCriteria)
        
        // Limit to maxEpisodes
        return Array(sortedEpisodes.prefix(smartPlaylist.maxEpisodes))
    }
    
    public func generatePlaybackQueue(
        from playlist: Playlist,
        episodes: [Episode],
        shuffle: Bool
    ) -> [Episode] {
        // Get episodes in playlist order, filtering out any that no longer exist
        let playlistEpisodes = playlist.episodeIds.compactMap { episodeId in
            episodes.first { $0.id == episodeId }
        }
        
        // Apply shuffle if requested AND allowed by playlist
        if shuffle && playlist.shuffleAllowed {
            return playlistEpisodes.shuffled()
        } else {
            return playlistEpisodes
        }
    }
    
    public func generatePlaybackQueue(
        from smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState],
        shuffle: Bool
    ) -> [Episode] {
        // First evaluate the smart playlist to get concrete episode list
        let evaluatedEpisodes = evaluateSmartPlaylist(
            smartPlaylist,
            episodes: episodes,
            downloadStatuses: downloadStatuses
        )
        
        // Apply shuffle if requested AND allowed by playlist
        if shuffle && smartPlaylist.shuffleAllowed {
            return evaluatedEpisodes.shuffled()
        } else {
            return evaluatedEpisodes
        }
    }
    
    /// Sort episodes according to the specified criteria
    private func sortEpisodes(_ episodes: [Episode], by criteria: PlaylistSortCriteria) -> [Episode] {
        switch criteria {
        case .pubDateNewest:
            return episodes.sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
        case .pubDateOldest:
            return episodes.sorted { ($0.pubDate ?? .distantFuture) < ($1.pubDate ?? .distantFuture) }
        case .titleAscending:
            return episodes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return episodes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .durationShortest:
            return episodes.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .durationLongest:
            return episodes.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .playbackPosition:
            // Sort by playback position descending (resume in-progress episodes first)
            return episodes.sorted { $0.playbackPosition > $1.playbackPosition }
        }
    }
}

/// Change event types for playlist manager
public enum PlaylistChange {
    case playlistAdded(Playlist)
    case playlistUpdated(Playlist)
    case playlistDeleted(String)
    case smartPlaylistAdded(SmartPlaylist)
    case smartPlaylistUpdated(SmartPlaylist)
    case smartPlaylistDeleted(String)
}

/// Service for playlist CRUD operations and persistence
@MainActor
public protocol PlaylistManagerProtocol: ObservableObject {
    // Manual playlists
    var playlists: [Playlist] { get }
    func createPlaylist(_ playlist: Playlist)
    func updatePlaylist(_ playlist: Playlist)
    func deletePlaylist(id: String)
    func findPlaylist(id: String) -> Playlist?
    func addEpisode(episodeId: String, to playlistId: String)
    func removeEpisode(episodeId: String, from playlistId: String)
    func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int)
    
    // Smart playlists
    var smartPlaylists: [SmartPlaylist] { get }
    func createSmartPlaylist(_ smartPlaylist: SmartPlaylist)
    func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist)
    func deleteSmartPlaylist(id: String)
    func findSmartPlaylist(id: String) -> SmartPlaylist?
    
    // Change notifications
    var playlistsChangedPublisher: AnyPublisher<PlaylistChange, Never> { get }
}

/// In-memory implementation of playlist manager for development and testing
@MainActor
public class InMemoryPlaylistManager: PlaylistManagerProtocol {
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var smartPlaylists: [SmartPlaylist] = []
    
    private let changeSubject = PassthroughSubject<PlaylistChange, Never>()
    
    public var playlistsChangedPublisher: AnyPublisher<PlaylistChange, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    public init() {}
    
    // MARK: - Manual Playlist Operations
    
    public func createPlaylist(_ playlist: Playlist) {
        // Ensure unique ID
        guard !playlists.contains(where: { $0.id == playlist.id }) else {
            print("Warning: Playlist with ID \(playlist.id) already exists")
            return
        }
        
        playlists.append(playlist)
        changeSubject.send(.playlistAdded(playlist))
    }
    
    public func updatePlaylist(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            print("Warning: Attempting to update non-existent playlist \(playlist.id)")
            return
        }
        
        playlists[index] = playlist
        changeSubject.send(.playlistUpdated(playlist))
    }
    
    public func deletePlaylist(id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            print("Warning: Attempting to delete non-existent playlist \(id)")
            return
        }
        
        playlists.remove(at: index)
        changeSubject.send(.playlistDeleted(id))
    }
    
    public func findPlaylist(id: String) -> Playlist? {
        return playlists.first { $0.id == id }
    }
    
    public func addEpisode(episodeId: String, to playlistId: String) {
        guard let playlist = findPlaylist(id: playlistId) else {
            print("Warning: Cannot add episode to non-existent playlist \(playlistId)")
            return
        }
        
        // Don't add duplicates
        guard !playlist.episodeIds.contains(episodeId) else {
            print("Warning: Episode \(episodeId) already in playlist \(playlistId)")
            return
        }
        
        let updatedPlaylist = playlist.withEpisodes(playlist.episodeIds + [episodeId])
        updatePlaylist(updatedPlaylist)
    }
    
    public func removeEpisode(episodeId: String, from playlistId: String) {
        guard let playlist = findPlaylist(id: playlistId) else {
            print("Warning: Cannot remove episode from non-existent playlist \(playlistId)")
            return
        }
        
        let updatedEpisodeIds = playlist.episodeIds.filter { $0 != episodeId }
        let updatedPlaylist = playlist.withEpisodes(updatedEpisodeIds)
        updatePlaylist(updatedPlaylist)
    }
    
    public func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int) {
        guard let playlist = findPlaylist(id: playlistId) else {
            print("Warning: Cannot reorder episodes in non-existent playlist \(playlistId)")
            return
        }
        
        var episodeIds = playlist.episodeIds
        moveElements(in: &episodeIds, fromOffsets: source, toOffset: destination)
        
        let updatedPlaylist = playlist.withEpisodes(episodeIds)
        updatePlaylist(updatedPlaylist)
    }
    
    /// Helper method to move elements in an array from source indices to destination
    /// This implements SwiftUI's move(fromOffsets:toOffset:) behavior correctly
    private func moveElements<T>(in array: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        // Extract elements to move in original order
        let elementsToMove = source.sorted().map { array[$0] }
        
        // Remove elements from highest index to lowest to avoid index shifting
        for index in source.sorted(by: >) {
            array.remove(at: index)
        }
        
        // Calculate insertion index based on SwiftUI's behavior:
        // The destination index refers to the position in the original array
        // After removing elements, we need to adjust for how many were removed before destination
        let insertionIndex = destination - source.count(where: { $0 < destination })
        
        // Insert elements at the calculated position
        for (offset, element) in elementsToMove.enumerated() {
            array.insert(element, at: min(insertionIndex + offset, array.count))
        }
    }
    
    // MARK: - Smart Playlist Operations
    
    public func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        // Ensure unique ID
        guard !smartPlaylists.contains(where: { $0.id == smartPlaylist.id }) else {
            print("Warning: Smart playlist with ID \(smartPlaylist.id) already exists")
            return
        }
        
        smartPlaylists.append(smartPlaylist)
        changeSubject.send(.smartPlaylistAdded(smartPlaylist))
    }
    
    public func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == smartPlaylist.id }) else {
            print("Warning: Attempting to update non-existent smart playlist \(smartPlaylist.id)")
            return
        }
        
        smartPlaylists[index] = smartPlaylist
        changeSubject.send(.smartPlaylistUpdated(smartPlaylist))
    }
    
    public func deleteSmartPlaylist(id: String) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == id }) else {
            print("Warning: Attempting to delete non-existent smart playlist \(id)")
            return
        }
        
        smartPlaylists.remove(at: index)
        changeSubject.send(.smartPlaylistDeleted(id))
    }
    
    public func findSmartPlaylist(id: String) -> SmartPlaylist? {
        return smartPlaylists.first { $0.id == id }
    }
}
