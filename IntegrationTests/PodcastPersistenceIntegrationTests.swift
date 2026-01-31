import XCTest
import SwiftData
@testable import CoreModels
@testable import Persistence
@testable import zpod
@testable import LibraryFeature
import SharedUtilities

/// Integration tests for podcast persistence across app lifecycle.
///
/// **Specifications Covered**
/// - `Issues/27.1.2-migrate-zpod-to-persistent-podcast-repository.md` — Data survives app restart
/// - `Issues/27.1-podcast-persistence-architecture.md` — Production-grade persistent storage
///
/// **Test Coverage**
/// - Data persistence across container recreation (simulates app restart)
/// - In-memory mode verification (UI tests should not persist)
/// - Persistence layer integration with app infrastructure
@available(iOS 17, macOS 14, watchOS 10, *)
final class PodcastPersistenceIntegrationTests: XCTestCase {

    // MARK: - Properties

    private let persistenceSchema = Schema([PodcastEntity.self, EpisodeEntity.self])
    private var persistentStoreURL: URL!
    private let siriSnapshotRefresher = NoopSiriSnapshotRefresher()

    private struct NoopSiriSnapshotRefresher: SiriSnapshotRefreshing, @unchecked Sendable {
        func refreshAll() {}
    }

    private func makeManager(container: ModelContainer) -> SwiftDataPodcastRepository {
        SwiftDataPodcastRepository(
            modelContainer: container,
            siriSnapshotRefresher: siriSnapshotRefresher
        )
    }

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary persistent store for integration testing
        let tempDir = FileManager.default.temporaryDirectory
        persistentStoreURL = tempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
    }

    override func tearDown() async throws {
        // Clean up temporary store
        if let url = persistentStoreURL {
            try? FileManager.default.removeItem(at: url)
            // Also remove SHM and WAL files that SQLite creates
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        }
        persistentStoreURL = nil
        try await super.tearDown()
    }

    // MARK: - Persistence Tests

    func testPodcastsPersistAcrossContainerRecreation() async throws {
        let podcastId = "persist-test"

        // Phase 1: Add podcast with persistent container
        do {
            // Given: A persistent container with a podcast
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            let podcast = Podcast(
                id: podcastId,
                title: "Persistent Podcast",
                author: "Test Author",
                description: "Should survive restart",
                artworkURL: URL(string: "https://example.com/artwork.jpg"),
                feedURL: URL(string: "https://example.com/feed.xml")!,
                categories: ["Technology", "Science"],
                episodes: [],
                isSubscribed: true,
                dateAdded: Date(),
                folderId: "test-folder",
                tagIds: ["tag-1", "tag-2"]
            )

            // When: Adding podcast
            manager.add(podcast)

            // Then: Podcast should be immediately accessible
            let found = manager.find(id: podcastId)
            XCTAssertNotNil(found, "Podcast should be added successfully")
            XCTAssertEqual(found?.title, "Persistent Podcast")
        }

        // Phase 2: Destroy container and create new one (simulates app restart)
        do {
            // Given: New container pointing to same persistent store
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying for podcast after "restart"
            let found = manager.find(id: podcastId)

            // Then: Podcast should still exist with all fields preserved
            XCTAssertNotNil(found, "Podcast should persist across container recreation")
            XCTAssertEqual(found?.id, podcastId)
            XCTAssertEqual(found?.title, "Persistent Podcast")
            XCTAssertEqual(found?.author, "Test Author")
            XCTAssertEqual(found?.description, "Should survive restart")
            XCTAssertEqual(found?.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
            XCTAssertEqual(found?.feedURL.absoluteString, "https://example.com/feed.xml")
            XCTAssertEqual(found?.categories, ["Technology", "Science"])
            XCTAssertEqual(found?.isSubscribed, true)
            XCTAssertEqual(found?.folderId, "test-folder")
            XCTAssertEqual(found?.tagIds, ["tag-1", "tag-2"])
        }
    }

    func testEpisodesPersistAcrossContainerRecreation() async throws {
        let podcastId = "persist-episodes"
        let episodeId = "episode-1"

        // Phase 1: Add podcast with episodes
        do {
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: persistenceSchema, configurations: [configuration])
            let manager = makeManager(container: container)

            let episodes = [
                Episode(
                    id: episodeId,
                    title: "Persisted Episode",
                    podcastID: podcastId,
                    podcastTitle: "Persistent Podcast",
                    playbackPosition: 321,
                    isPlayed: true,
                    downloadStatus: .downloaded,
                    isFavorited: true
                )
            ]
            let podcast = Podcast(
                id: podcastId,
                title: "Persistent Podcast",
                author: "Test Author",
                description: "Should survive restart",
                artworkURL: URL(string: "https://example.com/artwork.jpg"),
                feedURL: URL(string: "https://example.com/feed.xml")!,
                categories: ["Technology", "Science"],
                episodes: episodes,
                isSubscribed: true,
                dateAdded: Date(),
                folderId: "test-folder",
                tagIds: ["tag-1", "tag-2"]
            )

            manager.add(podcast)

            let found = manager.find(id: podcastId)
            XCTAssertEqual(found?.episodes.count, 1)
            XCTAssertEqual(found?.episodes.first?.id, episodeId)
            XCTAssertEqual(found?.episodes.first?.playbackPosition, 321)
            XCTAssertEqual(found?.episodes.first?.isFavorited, true)
        }

        // Phase 2: Verify episodes after container recreation
        do {
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: persistenceSchema, configurations: [configuration])
            let manager = makeManager(container: container)

            let found = manager.find(id: podcastId)
            XCTAssertNotNil(found, "Podcast should persist across container recreation")
            XCTAssertEqual(found?.episodes.count, 1, "Episodes should persist across restart")
            let episode = found?.episodes.first
            XCTAssertEqual(episode?.id, episodeId)
            XCTAssertEqual(episode?.playbackPosition, 321)
            XCTAssertEqual(episode?.isFavorited, true)
            XCTAssertEqual(episode?.downloadStatus, .downloaded)
        }
    }

    func testMultiplePodcastsPersistCorrectly() async throws {
        // Phase 1: Add multiple podcasts
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // Given: Multiple podcasts with different properties
            let podcasts = [
                Podcast(id: "pod-1", title: "First Podcast", feedURL: URL(string: "https://example.com/1.xml")!, isSubscribed: true),
                Podcast(id: "pod-2", title: "Second Podcast", feedURL: URL(string: "https://example.com/2.xml")!, folderId: "folder-a"),
                Podcast(id: "pod-3", title: "Third Podcast", feedURL: URL(string: "https://example.com/3.xml")!, tagIds: ["tag-1", "tag-2"])
            ]

            // When: Adding all podcasts
            for podcast in podcasts {
                manager.add(podcast)
            }

            // Then: All should be accessible
            XCTAssertEqual(manager.all().count, 3)
        }

        // Phase 2: Verify all persisted
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying after restart
            let allPodcasts = manager.all()

            // Then: All podcasts should persist with correct properties
            XCTAssertEqual(allPodcasts.count, 3, "All podcasts should persist")

            let first = allPodcasts.first { $0.id == "pod-1" }
            XCTAssertNotNil(first)
            XCTAssertEqual(first?.isSubscribed, true)

            let second = allPodcasts.first { $0.id == "pod-2" }
            XCTAssertNotNil(second)
            XCTAssertEqual(second?.folderId, "folder-a")

            let third = allPodcasts.first { $0.id == "pod-3" }
            XCTAssertNotNil(third)
            XCTAssertEqual(third?.tagIds, ["tag-1", "tag-2"])
        }
    }

    func testUpdatesPersistCorrectly() async throws {
        let podcastId = "update-persist-test"

        // Phase 1: Add and update podcast
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // Given: A podcast that will be updated
            let original = Podcast(
                id: podcastId,
                title: "Original Title",
                feedURL: URL(string: "https://example.com/feed.xml")!,
                isSubscribed: true
            )
            manager.add(original)

            // When: Updating the podcast
            let updated = Podcast(
                id: podcastId,
                title: "Updated Title",
                author: "New Author",
                feedURL: URL(string: "https://example.com/feed.xml")!,
                isSubscribed: true,
                dateAdded: original.dateAdded,
                folderId: "new-folder"
            )
            manager.update(updated)

            // Then: Updates should be immediately visible
            let found = manager.find(id: podcastId)
            XCTAssertEqual(found?.title, "Updated Title")
        }

        // Phase 2: Verify updates persisted
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying after restart
            let found = manager.find(id: podcastId)

            // Then: Updates should persist
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.title, "Updated Title")
            XCTAssertEqual(found?.author, "New Author")
            XCTAssertEqual(found?.isSubscribed, true)
            XCTAssertEqual(found?.folderId, "new-folder")
        }
    }

    func testDeletesPersistCorrectly() async throws {
        // Phase 1: Add and delete podcast
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // Given: Two podcasts
            manager.add(Podcast(id: "keep", title: "Keep Me", feedURL: URL(string: "https://example.com/keep.xml")!))
            manager.add(Podcast(id: "delete", title: "Delete Me", feedURL: URL(string: "https://example.com/delete.xml")!))
            XCTAssertEqual(manager.all().count, 2)

            // When: Deleting one podcast
            manager.remove(id: "delete")

            // Then: Should have one podcast
            XCTAssertEqual(manager.all().count, 1)
        }

        // Phase 2: Verify deletion persisted
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying after restart
            let allPodcasts = manager.all()

            // Then: Deletion should persist
            XCTAssertEqual(allPodcasts.count, 1)
            XCTAssertEqual(allPodcasts.first?.id, "keep")
            XCTAssertNil(manager.find(id: "delete"))
        }
    }

    // MARK: - In-Memory Mode Tests

    func testInMemoryModeDoesNotPersist() async throws {
        let podcastId = "in-memory-test"

        // Phase 1: Add podcast with in-memory container
        do {
            // Given: In-memory container
            let schema = persistenceSchema
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            let podcast = Podcast(
                id: podcastId,
                title: "In-Memory Podcast",
                author: "Test",
                description: "Should NOT persist",
                feedURL: URL(string: "https://example.com/feed.xml")!
            )

            // When: Adding podcast
            manager.add(podcast)

            // Then: Should be accessible immediately
            XCTAssertNotNil(manager.find(id: podcastId))
        }

        // Phase 2: New in-memory container should be empty
        do {
            // Given: New in-memory container
            let schema = persistenceSchema
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying for podcast
            let found = manager.find(id: podcastId)

            // Then: Should not persist (different in-memory database)
            XCTAssertNil(found, "In-memory data should not persist across container recreation")
            XCTAssertEqual(manager.all().count, 0, "New in-memory container should be empty")
        }
    }

    // MARK: - Organization Persistence Tests

    func testOrganizationPersistsCorrectly() async throws {
        // Phase 1: Add organized podcasts
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // Given: Podcasts with different organization
            manager.add(Podcast(id: "folder-pod", title: "Folder Podcast", feedURL: URL(string: "https://example.com/1.xml")!, folderId: "tech"))
            manager.add(Podcast(id: "tag-pod", title: "Tagged Podcast", feedURL: URL(string: "https://example.com/2.xml")!, tagIds: ["important", "favorites"]))
            manager.add(Podcast(id: "unorg-pod", title: "Unorganized", feedURL: URL(string: "https://example.com/3.xml")!))

            // When: Querying by organization
            XCTAssertEqual(manager.findByFolder(folderId: "tech").count, 1)
            XCTAssertEqual(manager.findByTag(tagId: "important").count, 1)
            XCTAssertEqual(manager.findUnorganized().count, 1)
        }

        // Phase 2: Verify organization persisted
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            // When: Querying by organization after restart
            let folderPodcasts = manager.findByFolder(folderId: "tech")
            let taggedPodcasts = manager.findByTag(tagId: "important")
            let unorganized = manager.findUnorganized()

            // Then: Organization should persist
            XCTAssertEqual(folderPodcasts.count, 1)
            XCTAssertEqual(folderPodcasts.first?.title, "Folder Podcast")

            XCTAssertEqual(taggedPodcasts.count, 1)
            XCTAssertEqual(taggedPodcasts.first?.title, "Tagged Podcast")
            XCTAssertTrue(taggedPodcasts.first?.tagIds.contains("favorites") ?? false)

            XCTAssertEqual(unorganized.count, 1)
            XCTAssertEqual(unorganized.first?.title, "Unorganized")
        }
    }

    // MARK: - Future Integration Tests (Placeholders)

    func testSiriSnapshotReflectsPersistentData() async throws {
        let primarySuiteName = "test.siri.primary.\(UUID().uuidString)"
        let devSuiteName = "test.siri.dev.\(UUID().uuidString)"

        defer {
            UserDefaults(suiteName: primarySuiteName)?.removePersistentDomain(forName: primarySuiteName)
            UserDefaults(suiteName: devSuiteName)?.removePersistentDomain(forName: devSuiteName)
        }

        let podcast = Podcast(
            id: "siri-test-podcast",
            title: "Siri Snapshot Podcast",
            author: "Test Author",
            description: "Podcast used for Siri snapshot integration test",
            feedURL: URL(string: "https://example.com/siri.xml")!,
            isSubscribed: true
        )

        // Phase 1: Persist data and refresh snapshots.
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            manager.add(podcast)

            SiriSnapshotCoordinator(
                podcastManager: manager,
                primarySuiteName: primarySuiteName,
                devSuiteName: devSuiteName
            ).refreshAllForTesting()

            waitForSnapshots(inSuiteNamed: primarySuiteName)
            waitForSnapshots(inSuiteNamed: devSuiteName)

            let primaryDefaults = try XCTUnwrap(UserDefaults(suiteName: primarySuiteName))
            let snapshots = try SiriMediaLibrary.load(from: primaryDefaults)
            XCTAssertEqual(snapshots.count, 1)
            XCTAssertEqual(snapshots.first?.id, podcast.id)
            XCTAssertEqual(snapshots.first?.title, podcast.title)
            // Episodes are transient in SwiftData; snapshots only include podcast metadata until Issue 28.1.8.
            XCTAssertEqual(snapshots.first?.episodes.count, 0)

            let devDefaults = try XCTUnwrap(UserDefaults(suiteName: devSuiteName))
            let devSnapshots = try SiriMediaLibrary.load(from: devDefaults)
            XCTAssertEqual(devSnapshots.count, 1)
        }

        // Clear snapshots so phase 2 proves a fresh refresh after restart.
        UserDefaults(suiteName: primarySuiteName)?.removeObject(forKey: SiriMediaLibrary.storageKey)
        UserDefaults(suiteName: devSuiteName)?.removeObject(forKey: SiriMediaLibrary.storageKey)

        // Phase 2: Simulate restart by recreating the container and refreshing snapshots.
        do {
            let schema = persistenceSchema
            let configuration = ModelConfiguration(url: persistentStoreURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let manager = makeManager(container: container)

            SiriSnapshotCoordinator(
                podcastManager: manager,
                primarySuiteName: primarySuiteName,
                devSuiteName: devSuiteName
            ).refreshAllForTesting()

            waitForSnapshots(inSuiteNamed: primarySuiteName)
            waitForSnapshots(inSuiteNamed: devSuiteName)

            let primaryDefaults = try XCTUnwrap(UserDefaults(suiteName: primarySuiteName))
            let snapshots = try SiriMediaLibrary.load(from: primaryDefaults)
            XCTAssertEqual(snapshots.count, 1)
            XCTAssertEqual(snapshots.first?.id, podcast.id)
            XCTAssertEqual(snapshots.first?.title, podcast.title)
            // Episodes are transient in SwiftData; snapshots only include podcast metadata until Issue 28.1.8.
            XCTAssertEqual(snapshots.first?.episodes.count, 0)
        }
    }

    func testCarPlayEpisodeLookupFindsPersistedEpisodes() async throws {
        #if os(iOS)
        // Given: A persistent container with podcast + episodes
        let schema = persistenceSchema
        let configuration = ModelConfiguration(url: persistentStoreURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = makeManager(container: container)

        let episodes = [
            Episode(
                id: "ep-carplay-1",
                title: "CarPlay Episode 1",
                podcastID: "podcast-carplay",
                podcastTitle: "CarPlay Test Podcast",
                playbackPosition: 0,
                isPlayed: false,
                duration: 1800
            ),
            Episode(
                id: "ep-carplay-2",
                title: "CarPlay Episode 2",
                podcastID: "podcast-carplay",
                podcastTitle: "CarPlay Test Podcast",
                playbackPosition: 0,
                isPlayed: false,
                duration: 2400
            )
        ]

        let podcast = Podcast(
            id: "podcast-carplay",
            title: "CarPlay Test Podcast",
            feedURL: URL(string: "https://example.com/carplay-feed.xml")!,
            episodes: episodes,
            isSubscribed: true,
            dateAdded: Date()
        )

        repository.add(podcast)

        // When: Configuring CarPlay dependencies with the SwiftData repository
        await MainActor.run {
            CarPlayDependencyRegistry.configure(podcastManager: repository)

            // Then: Episode lookup should find persisted episodes via podcastManager.all()
            let foundPodcast = repository.all().first { $0.id == "podcast-carplay" }
            XCTAssertNotNil(foundPodcast, "Repository should hydrate podcasts with episodes")
            XCTAssertEqual(foundPodcast?.episodes.count, 2, "Should find both episodes")

            let foundEpisode = foundPodcast?.episodes.first { $0.id == "ep-carplay-1" }
            XCTAssertNotNil(foundEpisode, "episodeLookup logic depends on all() returning episodes")
            XCTAssertEqual(foundEpisode?.title, "CarPlay Episode 1")
        }
        #else
        throw XCTSkip("CarPlay dependencies only available on iOS")
        #endif
    }
}

@available(iOS 17, macOS 14, watchOS 10, *)
private extension PodcastPersistenceIntegrationTests {
    func waitForSnapshots(inSuiteNamed suiteName: String, timeout: TimeInterval = 5.0) {
        let predicate = NSPredicate { _, _ in
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            return defaults.data(forKey: SiriMediaLibrary.storageKey) != nil
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Timed out waiting for Siri snapshots")
    }
}
