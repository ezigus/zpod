import Foundation
import SwiftData
import CoreModels
import OSLog

/// SwiftData-backed repository for podcasts.
///
/// This package-scoped implementation replaces the app-target `SwiftDataPodcastManager`.
/// It keeps synchronous APIs required by `PodcastManaging` and uses a serial queue to
/// ensure thread-safe access to the SwiftData `ModelContext`.
///
/// NOTE: Episode hydration currently performs per-podcast queries (N+1). This is
/// acceptable for the current scale (< 100 podcasts). If performance regresses,
/// batch-fetch episodes grouped by podcastId (track as Issue 27.1.1.4).
@available(iOS 17, macOS 14, watchOS 10, *)
public final class SwiftDataPodcastRepository: PodcastManaging, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let serialQueue: DispatchQueue
    private let logger = Logger(subsystem: "us.zig.zpod.persistence", category: "SwiftDataPodcastRepository")
    private var siriSnapshotRefresher: SiriSnapshotRefreshing?
    private let saveHandler: () throws -> Void

    public convenience init(modelContainer: ModelContainer) {
        self.init(modelContainer: modelContainer, siriSnapshotRefresher: nil, saveHandler: nil)
    }

    public init(
        modelContainer: ModelContainer,
        siriSnapshotRefresher: SiriSnapshotRefreshing?,
        saveHandler: (() throws -> Void)? = nil
    ) {
        self.modelContainer = modelContainer
        let queue = DispatchQueue(label: "us.zig.zpod.SwiftDataPodcastRepository")
        self.serialQueue = queue

        var context: ModelContext?
        queue.sync {
            context = ModelContext(modelContainer)
        }
        guard let context else {
            fatalError("Failed to create ModelContext on SwiftDataPodcastRepository queue.")
        }
        self.modelContext = context
        self.siriSnapshotRefresher = siriSnapshotRefresher
        self.saveHandler = saveHandler ?? { try context.save() }
    }

    // MARK: - PodcastManaging

    public func all() -> [Podcast] {
        serialQueue.sync {
            let descriptor = FetchDescriptor<PodcastEntity>()
            guard let entities = try? modelContext.fetch(descriptor) else {
                logger.error("Failed to fetch all podcasts")
                return []
            }

            return entities.compactMap(hydratePodcast)
        }
    }

    public func find(id: String) -> Podcast? {
        serialQueue.sync {
            let predicate = #Predicate<PodcastEntity> { $0.id == id }
            let descriptor = FetchDescriptor(predicate: predicate)
            let entity: PodcastEntity?
            do {
                entity = try modelContext.fetch(descriptor).first
            } catch {
                logger.error("Failed to fetch podcast \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
            guard let entity else { return nil }
            return hydratePodcast(entity)
        }
    }

    public func add(_ podcast: Podcast) {
        let didSave = serialQueue.sync { () -> Bool in
            if fetchEntity(id: podcast.id) != nil {
                logger.warning("Duplicate podcast add ignored: \(podcast.id, privacy: .public)")
                return false
            }

            let entity = PodcastEntity.fromDomain(podcast)
            modelContext.insert(entity)

            // Persist episodes
            for episode in podcast.episodes {
                let episodeEntity = EpisodeEntity.fromDomain(episode, podcastId: podcast.id)
                modelContext.insert(episodeEntity)
            }

            return saveContext()
        }

        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    public func update(_ podcast: Podcast) {
        let didSave = serialQueue.sync { () -> Bool in
            guard let entity = fetchEntity(id: podcast.id) else {
                logger.warning("Update ignored for missing podcast: \(podcast.id, privacy: .public)")
                return false
            }

            let resolved = makePodcast(from: podcast, entity: entity)
            entity.updateFrom(resolved)

            // Upsert episodes: preserve user state on existing rows, insert new episodes.
            let existingEpisodes = fetchEpisodeEntitiesUnlocked(forPodcastId: podcast.id)
            var existingById = Dictionary(uniqueKeysWithValues: existingEpisodes.map { ($0.id, $0) })

            for episode in podcast.episodes {
                if let existing = existingById.removeValue(forKey: episode.id) {
                    existing.updateMetadataFrom(episode)
                } else {
                    let episodeEntity = EpisodeEntity.fromDomain(episode, podcastId: podcast.id)
                    modelContext.insert(episodeEntity)
                }
            }

            // Delete episodes that are no longer present in the incoming podcast
            for removed in existingById.values {
                modelContext.delete(removed)
            }

            return saveContext()
        }

        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    public func remove(id: String) {
        let didSave = serialQueue.sync { () -> Bool in
            guard let entity = fetchEntity(id: id) else {
                logger.warning("Remove ignored for missing podcast: \(id, privacy: .public)")
                return false
            }

            // Cascade delete all episodes for this podcast
            let episodeEntities = fetchEpisodeEntitiesUnlocked(forPodcastId: id)
            for episodeEntity in episodeEntities {
                modelContext.delete(episodeEntity)
            }

            modelContext.delete(entity)
            return saveContext()
        }

        if didSave {
            refreshSiriSnapshotsIfNeeded()
        }
    }

    public func findByFolder(folderId: String) -> [Podcast] {
        serialQueue.sync {
            fetchByFolderUnlocked(folderId: folderId)
        }
    }

    public func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
        serialQueue.sync {
            var podcasts = fetchByFolderUnlocked(folderId: folderId)
            let descendants = folderManager.getDescendants(of: folderId)
            for descendant in descendants {
                podcasts.append(contentsOf: fetchByFolderUnlocked(folderId: descendant.id))
            }
            return podcasts
        }
    }

    public func findByTag(tagId: String) -> [Podcast] {
        serialQueue.sync {
            let all = fetchAllEntities(errorMessage: "Failed to fetch podcasts by tag: \(tagId)")
            return all
                .filter { $0.tagIds.contains(tagId) }
                .compactMap(hydratePodcast)
        }
    }

    public func findUnorganized() -> [Podcast] {
        serialQueue.sync {
            let all = fetchAllEntities(errorMessage: "Failed to fetch unorganized podcasts")
            return all
                .filter { $0.folderId == nil && $0.tagIds.isEmpty }
                .compactMap(hydratePodcast)
        }
    }

    /// Resets all episode playback positions to 0 across all podcasts.
    /// Operates on persisted episodes (Issue 27.1.1.1).
    public func resetAllPlaybackPositions() {
        let didSave = serialQueue.sync { () -> Bool in
            let allEpisodes = fetchAllEpisodeEntitiesUnlocked()
            guard !allEpisodes.isEmpty else { return false }

            var didUpdate = false
            for entity in allEpisodes where entity.playbackPosition != 0 {
                entity.playbackPosition = 0
                didUpdate = true
            }

            guard didUpdate else { return false }
            return saveContext()
        }

        if didSave {
            refreshSiriSnapshotsIfNeeded()
            logger.info("Reset all episode playback positions to 0")
        } else {
            logger.info("Skipped playback reset (no episodes with playback position)")
        }
    }

    // MARK: - Configuration

    /// Allows attaching a refresher after initialization (used by app-layer DI).
    public func setSiriSnapshotRefresher(_ refresher: SiriSnapshotRefreshing?) {
        serialQueue.sync {
            self.siriSnapshotRefresher = refresher
        }
    }

    // MARK: - Private Helpers

    private func fetchEntity(id: String) -> PodcastEntity? {
        let predicate = #Predicate<PodcastEntity> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func hydratePodcast(_ entity: PodcastEntity) -> Podcast? {
        let episodes = fetchEpisodesUnlocked(forPodcastId: entity.id)
        return entity.toDomainSafe(episodes: episodes)
    }

    private func fetchByFolderUnlocked(folderId: String) -> [Podcast] {
        let predicate = #Predicate<PodcastEntity> { $0.folderId == folderId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return fetchEntities(descriptor, errorMessage: "Failed to fetch podcasts by folder: \(folderId)")
            .compactMap(hydratePodcast)
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

    private func makePodcast(
        from podcast: Podcast,
        entity: PodcastEntity,
        episodes: [Episode]? = nil
    ) -> Podcast {
        let resolvedIsSubscribed = resolveIsSubscribed(for: podcast, existing: entity)
        return Podcast(
            id: podcast.id,
            title: podcast.title,
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: episodes ?? podcast.episodes,
            isSubscribed: resolvedIsSubscribed,
            dateAdded: entity.dateAdded,
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
    }

    private func resolveIsSubscribed(for podcast: Podcast, existing: PodcastEntity) -> Bool {
        if podcast.isSubscribed != existing.isSubscribed {
            return podcast.isSubscribed
        }
        return existing.isSubscribed
    }

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

    private func refreshSiriSnapshotsIfNeeded() {
        let refresher = serialQueue.sync { siriSnapshotRefresher }
        refresher?.refreshAll()
    }

    // MARK: - Episode Helpers

    /// Fetch episodes for a podcast (must be called within serialQueue.sync)
    private func fetchEpisodesUnlocked(forPodcastId podcastId: String) -> [Episode] {
        let predicate = #Predicate<EpisodeEntity> { $0.podcastId == podcastId }
        let descriptor = FetchDescriptor(predicate: predicate)
        do {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { $0.toDomainSafe() }
        } catch {
            logger.error("Failed to fetch episodes for podcast \(podcastId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Fetch episode entities for a podcast (must be called within serialQueue.sync)
    private func fetchEpisodeEntitiesUnlocked(forPodcastId podcastId: String) -> [EpisodeEntity] {
        let predicate = #Predicate<EpisodeEntity> { $0.podcastId == podcastId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch all episode entities (must be called within serialQueue.sync)
    private func fetchAllEpisodeEntitiesUnlocked() -> [EpisodeEntity] {
        let descriptor = FetchDescriptor<EpisodeEntity>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
