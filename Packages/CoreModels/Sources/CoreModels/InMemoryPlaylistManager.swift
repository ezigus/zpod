import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport

/// In-memory playlist manager for testing
@available(macOS 10.15, *)
@MainActor
public class InMemoryPlaylistManager: ObservableObject, PlaylistManaging {
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var smartPlaylists: [SmartPlaylist] = []
    
    private let playlistsChangedSubject = PassthroughSubject<PlaylistChange, Never>()
    
    public var playlistsChangedPublisher: AnyPublisher<PlaylistChange, Never> {
        playlistsChangedSubject.eraseToAnyPublisher()
    }
    
    public init() {}

    public func allPlaylists() -> [Playlist] { playlists }
    public func allSmartPlaylists() -> [SmartPlaylist] { smartPlaylists }
    
    // MARK: - Manual Playlists
    
    public func createPlaylist(_ playlist: Playlist) {
        // Don't add duplicates
        guard !playlists.contains(where: { $0.id == playlist.id }) else { return }
        
        playlists.append(playlist)
        playlistsChangedSubject.send(.playlistAdded(playlist))
    }
    
    public func updatePlaylist(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        playlists[index] = playlist
        playlistsChangedSubject.send(.playlistUpdated(playlist))
    }
    
    public func deletePlaylist(id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        
        playlists.remove(at: index)
        playlistsChangedSubject.send(.playlistDeleted(id))
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
        playlistsChangedSubject.send(.smartPlaylistAdded(smartPlaylist))
    }
    
    public func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
        
        smartPlaylists[index] = smartPlaylist
        playlistsChangedSubject.send(.smartPlaylistUpdated(smartPlaylist))
    }
    
    public func deleteSmartPlaylist(id: String) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == id }) else { return }
        
        smartPlaylists.remove(at: index)
        playlistsChangedSubject.send(.smartPlaylistDeleted(id))
    }
    
    public func findSmartPlaylist(id: String) -> SmartPlaylist? {
        return smartPlaylists.first { $0.id == id }
    }
}

#else

/// In-memory playlist manager for testing (non-Combine version)
@available(macOS 10.15, *)
@MainActor
public class InMemoryPlaylistManager: PlaylistManaging {
    public private(set) var playlists: [Playlist] = []
    public private(set) var smartPlaylists: [SmartPlaylist] = []
    
    public init() {}

    public func allPlaylists() -> [Playlist] { playlists }
    public func allSmartPlaylists() -> [SmartPlaylist] { smartPlaylists }
    
    // MARK: - Manual Playlists
    
    public func createPlaylist(_ playlist: Playlist) {
        // Don't add duplicates
        guard !playlists.contains(where: { $0.id == playlist.id }) else { return }
        
        playlists.append(playlist)
    }
    
    public func updatePlaylist(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        playlists[index] = playlist
    }
    
    public func deletePlaylist(id: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        
        playlists.remove(at: index)
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
    }
    
    public func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
        
        smartPlaylists[index] = smartPlaylist
    }
    
    public func deleteSmartPlaylist(id: String) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == id }) else { return }
        
        smartPlaylists.remove(at: index)
    }
    
    public func findSmartPlaylist(id: String) -> SmartPlaylist? {
        return smartPlaylists.first { $0.id == id }
    }
}

#endif
