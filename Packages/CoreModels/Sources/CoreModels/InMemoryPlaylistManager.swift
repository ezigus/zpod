import Foundation
#if canImport(Combine)
#if canImport(Combine)
@preconcurrency import Combine
#endif
#endif

/// In-memory playlist manager for testing
@available(macOS 10.15, *)
@MainActor
public class InMemoryPlaylistManager: ObservableObject {
    #if canImport(Combine)
    @available(macOS 10.15, *)
    @Published public private(set) var playlists: [Playlist] = []
    #else
    public private(set) var playlists: [Playlist] = []
    #endif
    #if canImport(Combine)
    @available(macOS 10.15, *)
    @Published public private(set) var smartPlaylists: [SmartPlaylist] = []
    #else
    public private(set) var smartPlaylists: [SmartPlaylist] = []
    #endif
    
    #if canImport(Combine)
    @available(macOS 10.15, *)
    private let playlistsChangedSubject = PassthroughSubject<PlaylistChange, Never>()
    
    @available(macOS 10.15, *)
    public var playlistsChangedPublisher: AnyPublisher<PlaylistChange, Never> {
        playlistsChangedSubject.eraseToAnyPublisher()
    }
    #endif
    
    public init() {}
    
    // MARK: - Manual Playlists
    
    public func createPlaylist(_ playlist: Playlist) {
        // Don't add duplicates
        guard !playlists.contains(where: { $0.id == playlist.id }) else { return }
        
        playlists.append(playlist)
        #if canImport(Combine)
        playlistsChangedSubject.send(.playlistAdded(playlist))
        #endif
    }
    
    public func updatePlaylist(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        playlists[index] = playlist
        #if canImport(Combine)
        playlistsChangedSubject.send(.playlistUpdated(playlist))
        #endif
    }
    
    public func deletePlaylist(id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        
        playlists.remove(at: index)
        #if canImport(Combine)
        playlistsChangedSubject.send(.playlistDeleted(id))
        #endif
    }
    
    public func findPlaylist(id: String) -> Playlist? {
        return playlists.first { $0.id == id }
    }
    
    public func addEpisode(episodeId: String, to playlistId: String) {
        guard let playlist = findPlaylist(id: playlistId) else { return }
        
        // Don't add duplicates
        guard !playlist.episodeIds.contains(episodeId) else { return }
        
        let updatedPlaylist = playlist.withEpisodes(playlist.episodeIds + [episodeId])
        updatePlaylist(updatedPlaylist)
    }
    
    public func removeEpisode(episodeId: String, from playlistId: String) {
        guard let playlist = findPlaylist(id: playlistId) else { return }
        
        let updatedEpisodeIds = playlist.episodeIds.filter { $0 != episodeId }
        let updatedPlaylist = playlist.withEpisodes(updatedEpisodeIds)
        updatePlaylist(updatedPlaylist)
    }
    
    public func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int) {
        guard let playlist = findPlaylist(id: playlistId) else { return }
        
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
        
        // Insert elements at the destination position
        // Clamp destination to valid range after removals
        let insertPosition = min(destination, array.count)
        
        // Insert elements at the calculated position
        for (offset, element) in elementsToMove.enumerated() {
            array.insert(element, at: insertPosition + offset)
        }
    }
    
    // MARK: - Smart Playlists
    
    public func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        // Don't add duplicates
        guard !smartPlaylists.contains(where: { $0.id == smartPlaylist.id }) else { return }
        
        smartPlaylists.append(smartPlaylist)
        #if canImport(Combine)
        playlistsChangedSubject.send(.smartPlaylistAdded(smartPlaylist))
        #endif
    }
    
    public func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
        
        smartPlaylists[index] = smartPlaylist
        #if canImport(Combine)
        playlistsChangedSubject.send(.smartPlaylistUpdated(smartPlaylist))
        #endif
    }
    
    public func deleteSmartPlaylist(id: String) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == id }) else { return }
        
        smartPlaylists.remove(at: index)
        #if canImport(Combine)
        playlistsChangedSubject.send(.smartPlaylistDeleted(id))
        #endif
    }
    
    public func findSmartPlaylist(id: String) -> SmartPlaylist? {
        return smartPlaylists.first { $0.id == id }
    }
}
