import Foundation
import SwiftData
import CoreModels
import SharedUtilities
import OSLog

/// Persistent manager for podcast library using SwiftData.
///
/// This class provides thread-safe podcast storage with automatic persistence to SQLite.
/// It implements the `PodcastManaging` protocol with SwiftData-backed operations.
///
/// ## Usage
/// ```swift
/// let container = try ModelContainer(for: PodcastEntity.self)
/// let manager = SwiftDataPodcastManager(modelContainer: container)
///
/// // Add a podcast
/// manager.add(podcast)
///
/// // Fetch all podcasts
/// let podcasts = manager.all()
/// ```
///
/// ## Thread Safety
/// Operations are synchronized using a serial queue to ensure thread-safe access to the ModelContext.
///
/// @unchecked Sendable: ModelContext access is protected by serialQueue.
@available(iOS 17, macOS 14, watchOS 10, *)
public final class SwiftDataPodcastManager: PodcastManaging, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let serialQueue = DispatchQueue(label: "us.zig.zpod.SwiftDataPodcastManager")
    private let logger = Logger(subsystem: "us.zig.zpod", category: "SwiftDataPodcastManager")

    /// Creates a new podcast manager.
    ///
    /// - Parameter modelContainer: SwiftData model container (must include PodcastEntity schema)
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        logger.info("SwiftDataPodcastManager initialized")
    }

    // MARK: - PodcastManaging Protocol

    public func all() -> [Podcast] {
        serialQueue.sync {
            let descriptor = FetchDescriptor<PodcastEntity>()
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch all podcasts")
                return []
            }
            return entities.map { $0.toDomain() }
        }
    }

    public func find(id: String) -> Podcast? {
        serialQueue.sync {
            let predicate = #Predicate<PodcastEntity> { $0.id == id }
            let descriptor = FetchDescriptor(predicate: predicate)
            guard let entity = try? modelContext.fetch(descriptor).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    public func add(_ podcast: Podcast) {
        serialQueue.sync {
            // Check if already exists (enforce uniqueness at repository level)
            let predicate = #Predicate<PodcastEntity> { $0.id == podcast.id }
            let descriptor = FetchDescriptor(predicate: predicate)
            if (try? modelContext.fetch(descriptor).first) != nil {
                logger.warning("Attempted to add podcast with duplicate ID: \(podcast.id, privacy: .public)")
                return
            }

            let entity = PodcastEntity.fromDomain(podcast)
            modelContext.insert(entity)

            do {
                try modelContext.save()
                logger.info("Added podcast: \(podcast.title, privacy: .public)")
            } catch {
                logger.error("Failed to add podcast \(podcast.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    public func update(_ podcast: Podcast) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: podcast.id) else {
                logger.warning("Attempted to update non-existent podcast: \(podcast.id, privacy: .public)")
                return
            }

            entity.updateFrom(podcast)

            do {
                try modelContext.save()
                logger.info("Updated podcast: \(podcast.title, privacy: .public)")
            } catch {
                logger.error("Failed to update podcast \(podcast.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    public func remove(id: String) {
        serialQueue.sync {
            guard let entity = fetchEntity(id: id) else {
                logger.warning("Attempted to remove non-existent podcast: \(id, privacy: .public)")
                return
            }

            modelContext.delete(entity)

            do {
                try modelContext.save()
                logger.info("Removed podcast: \(id, privacy: .public)")
            } catch {
                logger.error("Failed to remove podcast \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Organization Filtering

    public func findByFolder(folderId: String) -> [Podcast] {
        serialQueue.sync {
            let predicate = #Predicate<PodcastEntity> { $0.folderId == folderId }
            let descriptor = FetchDescriptor(predicate: predicate)
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch podcasts by folder: \(folderId, privacy: .public)")
                return []
            }
            return entities.map { $0.toDomain() }
        }
    }

    public func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
        serialQueue.sync {
            // Get direct podcasts in this folder
            var podcasts = findByFolder(folderId: folderId)

            // Get podcasts from all descendant folders
            let descendants = folderManager.getDescendants(of: folderId)
            for descendant in descendants {
                podcasts.append(contentsOf: findByFolder(folderId: descendant.id))
            }

            return podcasts
        }
    }

    public func findByTag(tagId: String) -> [Podcast] {
        serialQueue.sync {
            // SwiftData predicate for array contains
            let descriptor = FetchDescriptor<PodcastEntity>()
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch podcasts by tag: \(tagId, privacy: .public)")
                return []
            }

            // Filter in memory since SwiftData predicate for array.contains is complex
            return entities
                .filter { $0.tagIds.contains(tagId) }
                .map { $0.toDomain() }
        }
    }

    public func findUnorganized() -> [Podcast] {
        serialQueue.sync {
            let descriptor = FetchDescriptor<PodcastEntity>()
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch unorganized podcasts")
                return []
            }

            // Filter in memory for nil folderId and empty tagIds
            return entities
                .filter { $0.folderId == nil && $0.tagIds.isEmpty }
                .map { $0.toDomain() }
        }
    }

    // MARK: - Test Utilities

    /// Resets all episode playback positions to 0 across all podcasts.
    /// Used by UI tests to ensure clean state between test runs.
    ///
    /// - Note: This method updates episodes in memory only (not persisted to SwiftData).
    ///   Episodes are transient in the current implementation.
    public func resetAllPlaybackPositions() {
        serialQueue.sync {
            let podcasts = all()
            for podcast in podcasts {
                let resetEpisodes = podcast.episodes.map { episode in
                    episode.withPlaybackPosition(0)
                }
                let updatedPodcast = Podcast(
                    id: podcast.id,
                    title: podcast.title,
                    author: podcast.author,
                    description: podcast.description,
                    artworkURL: podcast.artworkURL,
                    feedURL: podcast.feedURL,
                    categories: podcast.categories,
                    episodes: resetEpisodes,
                    isSubscribed: podcast.isSubscribed,
                    dateAdded: podcast.dateAdded,
                    folderId: podcast.folderId,
                    tagIds: podcast.tagIds
                )
                update(updatedPodcast)
            }
            logger.info("Reset all episode playback positions to 0 for UI tests")
        }
    }

    // MARK: - Private Helpers

    /// Fetches a PodcastEntity by ID from SwiftData.
    ///
    /// - Parameter id: Podcast ID
    /// - Returns: PodcastEntity if found, nil otherwise
    /// - Warning: Must be called from within serialQueue.sync
    private func fetchEntity(id: String) -> PodcastEntity? {
        let predicate = #Predicate<PodcastEntity> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
