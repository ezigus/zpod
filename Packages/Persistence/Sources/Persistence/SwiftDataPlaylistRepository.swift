import Foundation
import SwiftData
import CoreModels
import OSLog

/// SwiftData-backed repository for playlists.
///
/// Follows the same serial-queue pattern as `SwiftDataPodcastRepository` for
/// thread-safe `ModelContext` access outside the main actor.
@available(iOS 17, macOS 14, watchOS 10, *)
public final class SwiftDataPlaylistRepository: PlaylistManaging, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let serialQueue: DispatchQueue
    private let logger = Logger(subsystem: "us.zig.zpod.persistence", category: "SwiftDataPlaylistRepository")
    private let saveHandler: () throws -> Void

    public convenience init(modelContainer: ModelContainer) {
        self.init(modelContainer: modelContainer, saveHandler: nil)
    }

    public init(
        modelContainer: ModelContainer,
        saveHandler: (() throws -> Void)? = nil
    ) {
        self.modelContainer = modelContainer
        let queue = DispatchQueue(label: "us.zig.zpod.SwiftDataPlaylistRepository")
        self.serialQueue = queue

        var context: ModelContext?
        queue.sync {
            context = ModelContext(modelContainer)
        }
        guard let context else {
            fatalError("Failed to create ModelContext on SwiftDataPlaylistRepository queue.")
        }
        self.modelContext = context
        self.saveHandler = saveHandler ?? { try context.save() }
    }

    // MARK: - PlaylistManaging (Manual Playlists)

    public func allPlaylists() -> [Playlist] {
        serialQueue.sync {
            let descriptor = FetchDescriptor<PlaylistEntity>()
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch all playlists")
                return []
            }
            return entities.map { $0.toDomain() }
        }
    }

    public func findPlaylist(id: String) -> Playlist? {
        serialQueue.sync {
            fetchEntity(id: id)?.toDomain()
        }
    }

    public func createPlaylist(_ playlist: Playlist) {
        serialQueue.sync {
            if fetchEntity(id: playlist.id) != nil {
                logger.warning("Duplicate playlist add ignored: \(playlist.id, privacy: .public)")
                return
            }
            let entity = PlaylistEntity.fromDomain(playlist)
            modelContext.insert(entity)
            saveContext()
        }
    }

    public func updatePlaylist(_ playlist: Playlist) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: playlist.id) else {
                logger.warning("Update ignored for missing playlist: \(playlist.id, privacy: .public)")
                return
            }
            entity.updateFrom(playlist)
            saveContext()
        }
    }

    public func deletePlaylist(id: String) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: id) else {
                logger.warning("Delete ignored for missing playlist: \(id, privacy: .public)")
                return
            }
            modelContext.delete(entity)
            saveContext()
        }
    }

    public func addEpisode(episodeId: String, to playlistId: String) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: playlistId) else { return }
            guard !entity.episodeIds.contains(episodeId) else { return }
            entity.episodeIds.append(episodeId)
            entity.updatedAt = Date()
            saveContext()
        }
    }

    public func removeEpisode(episodeId: String, from playlistId: String) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: playlistId) else { return }
            entity.episodeIds.removeAll { $0 == episodeId }
            entity.updatedAt = Date()
            saveContext()
        }
    }

    public func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: playlistId) else { return }
            var ids = entity.episodeIds
            ids.move(fromOffsets: source, toOffset: destination)
            entity.episodeIds = ids
            entity.updatedAt = Date()
            saveContext()
        }
    }

    @discardableResult
    public func duplicatePlaylist(id: String) -> Playlist? {
        serialQueue.sync {
            guard let original = fetchEntity(id: id) else { return nil }
            let copy = Playlist(
                name: "\(original.name) Copy",
                description: original.playlistDescription,
                episodeIds: original.episodeIds,
                continuousPlayback: original.continuousPlayback,
                shuffleAllowed: original.shuffleAllowed
            )
            let entity = PlaylistEntity.fromDomain(copy)
            modelContext.insert(entity)
            saveContext()
            return copy
        }
    }

    // MARK: - PlaylistManaging (Smart Playlists)

    public func allSmartPlaylists() -> [SmartPlaylist] {
        []
    }

    public func findSmartPlaylist(id: String) -> SmartPlaylist? {
        nil
    }

    public func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) {}

    public func updateSmartPlaylist(_ smartPlaylist: SmartPlaylist) {}

    public func deleteSmartPlaylist(id: String) {}

    // MARK: - Private Helpers

    private func fetchEntity(id: String) -> PlaylistEntity? {
        let predicate = #Predicate<PlaylistEntity> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    private func saveContext() -> Bool {
        do {
            try saveHandler()
            return true
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            return false
        }
    }
}
