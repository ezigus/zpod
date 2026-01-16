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
    private let serialQueue: DispatchQueue
    private let logger = Logger(subsystem: "us.zig.zpod", category: "SwiftDataPodcastManager")
    private let siriSnapshotRefresher: SiriSnapshotRefreshing?

    /// Creates a new podcast manager.
    ///
    /// - Parameter modelContainer: SwiftData model container (must include PodcastEntity schema)
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let queue = DispatchQueue(label: "us.zig.zpod.SwiftDataPodcastManager")
        self.serialQueue = queue
        var context: ModelContext?
        queue.sync {
            context = ModelContext(modelContainer)
        }
        guard let context else {
            fatalError("Failed to create ModelContext on SwiftDataPodcastManager queue.")
        }
        self.modelContext = context
        self.siriSnapshotRefresher = nil
        logger.info("SwiftDataPodcastManager initialized")
    }

    init(
        modelContainer: ModelContainer,
        siriSnapshotRefresher: SiriSnapshotRefreshing?
    ) {
        self.modelContainer = modelContainer
        let queue = DispatchQueue(label: "us.zig.zpod.SwiftDataPodcastManager")
        self.serialQueue = queue
        var context: ModelContext?
        queue.sync {
            context = ModelContext(modelContainer)
        }
        guard let context else {
            fatalError("Failed to create ModelContext on SwiftDataPodcastManager queue.")
        }
        self.modelContext = context
        self.siriSnapshotRefresher = siriSnapshotRefresher
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
        let didSave = serialQueue.sync { () -> Bool in
            // Check if already exists (enforce uniqueness at repository level)
            let predicate = #Predicate<PodcastEntity> { $0.id == podcast.id }
            let descriptor = FetchDescriptor(predicate: predicate)
            if (try? modelContext.fetch(descriptor).first) != nil {
                logger.warning("Attempted to add podcast with duplicate ID: \(podcast.id, privacy: .public)")
                return false
            }

            let entity = PodcastEntity.fromDomain(podcast)
            modelContext.insert(entity)

            do {
                try modelContext.save()
                logger.info("Added podcast: \(podcast.title, privacy: .public)")
                return true
            } catch {
                logger.error("Failed to add podcast \(podcast.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    public func update(_ podcast: Podcast) {
        let didSave = serialQueue.sync { () -> Bool in
            guard let entity = fetchEntity(id: podcast.id) else {
                logger.warning("Attempted to update non-existent podcast: \(podcast.id, privacy: .public)")
                return false
            }

            let resolvedIsSubscribed = resolveIsSubscribed(for: podcast, existing: entity)
            let resolvedPodcast = Podcast(
                id: podcast.id,
                title: podcast.title,
                author: podcast.author,
                description: podcast.description,
                artworkURL: podcast.artworkURL,
                feedURL: podcast.feedURL,
                categories: podcast.categories,
                episodes: podcast.episodes,
                isSubscribed: resolvedIsSubscribed,
                dateAdded: entity.dateAdded,
                folderId: podcast.folderId,
                tagIds: podcast.tagIds
            )
            entity.updateFrom(resolvedPodcast)

            do {
                try modelContext.save()
                logger.info("Updated podcast: \(podcast.title, privacy: .public)")
                return true
            } catch {
                logger.error("Failed to update podcast \(podcast.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    public func remove(id: String) {
        let didSave = serialQueue.sync { () -> Bool in
            guard let entity = fetchEntity(id: id) else {
                logger.warning("Attempted to remove non-existent podcast: \(id, privacy: .public)")
                return false
            }

            modelContext.delete(entity)

            do {
                try modelContext.save()
                logger.info("Removed podcast: \(id, privacy: .public)")
                return true
            } catch {
                logger.error("Failed to remove podcast \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    // MARK: - Organization Filtering

    public func findByFolder(folderId: String) -> [Podcast] {
        serialQueue.sync {
            fetchByFolderUnlocked(folderId: folderId)
        }
    }

    public func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
        serialQueue.sync {
            // Get direct podcasts in this folder
            var podcasts = fetchByFolderUnlocked(folderId: folderId)

            // Get podcasts from all descendant folders
            let descendants = folderManager.getDescendants(of: folderId)
            for descendant in descendants {
                podcasts.append(contentsOf: fetchByFolderUnlocked(folderId: descendant.id))
            }

            return podcasts
        }
    }

    public func findByTag(tagId: String) -> [Podcast] {
        serialQueue.sync {
            let entities = fetchAllEntities(errorMessage: "Failed to fetch podcasts by tag: \(tagId)")
            return entities
                .filter { $0.tagIds.contains(tagId) }
                .map { $0.toDomain() }
        }
    }

    public func findUnorganized() -> [Podcast] {
        serialQueue.sync {
            let entities = fetchAllEntities(errorMessage: "Failed to fetch unorganized podcasts")
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
        let didSave = serialQueue.sync { () -> Bool in
            let entities = fetchAllEntities(errorMessage: "Failed to fetch podcasts for playback reset")
            guard !entities.isEmpty else { return false }

            var didUpdate = false
            for entity in entities {
                let podcast = entity.toDomain()
                guard !podcast.episodes.isEmpty else { continue }

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
                let resolvedIsSubscribed = resolveIsSubscribed(for: updatedPodcast, existing: entity)
                let resolvedPodcast = Podcast(
                    id: updatedPodcast.id,
                    title: updatedPodcast.title,
                    author: updatedPodcast.author,
                    description: updatedPodcast.description,
                    artworkURL: updatedPodcast.artworkURL,
                    feedURL: updatedPodcast.feedURL,
                    categories: updatedPodcast.categories,
                    episodes: updatedPodcast.episodes,
                    isSubscribed: resolvedIsSubscribed,
                    dateAdded: entity.dateAdded,
                    folderId: updatedPodcast.folderId,
                    tagIds: updatedPodcast.tagIds
                )
                entity.updateFrom(resolvedPodcast)
                didUpdate = true
            }

            guard didUpdate else { return false }

            do {
                try modelContext.save()
                return true
            } catch {
                logger.error("Failed to reset playback positions: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        if didSave {
            refreshSiriSnapshotsIfNeeded()
            logger.info("Reset all episode playback positions to 0 for UI tests")
        } else {
            logger.info("Skipped playback reset (no persisted episodes)")
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

    private func fetchByFolderUnlocked(folderId: String) -> [Podcast] {
        let predicate = #Predicate<PodcastEntity> { $0.folderId == folderId }
        let descriptor = FetchDescriptor(predicate: predicate)
        let entities = fetchEntities(
            descriptor,
            errorMessage: "Failed to fetch podcasts by folder: \(folderId)"
        )
        return entities.map { $0.toDomain() }
    }

    private func fetchAllEntities(errorMessage: String) -> [PodcastEntity] {
        let descriptor = FetchDescriptor<PodcastEntity>()
        return fetchEntities(descriptor, errorMessage: errorMessage)
    }

    private func fetchEntities(
        _ descriptor: FetchDescriptor<PodcastEntity>,
        errorMessage: String
    ) -> [PodcastEntity] {
        guard let entities = try? modelContext.fetch(descriptor) else {
            logger.error("\(errorMessage)")
            return []
        }
        return entities
    }

    private func resolveIsSubscribed(for podcast: Podcast, existing: PodcastEntity) -> Bool {
        let sameExceptSubscription = (
            existing.title == podcast.title
            && existing.author == podcast.author
            && existing.podcastDescription == podcast.description
            && existing.artworkURLString == podcast.artworkURL?.absoluteString
            && existing.feedURLString == podcast.feedURL.absoluteString
            && existing.categories == podcast.categories
            && existing.dateAdded == podcast.dateAdded
            && existing.folderId == podcast.folderId
            && existing.tagIds == podcast.tagIds
        )
        return sameExceptSubscription ? podcast.isSubscribed : existing.isSubscribed
    }

    private func refreshSiriSnapshotsIfNeeded() {
        if let refresher = siriSnapshotRefresher {
            refresher.refreshAll()
            return
        }

        #if os(iOS)
        guard #available(iOS 14.0, *) else { return }
        SiriSnapshotCoordinator(podcastManager: self).refreshAll()
        #endif
    }
}
