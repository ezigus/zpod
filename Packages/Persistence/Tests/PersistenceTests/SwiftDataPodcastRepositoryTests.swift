import XCTest
import SwiftData
import Dispatch
@testable import CoreModels
@testable import Persistence
@testable import TestSupport

@available(iOS 17, macOS 14, watchOS 10, *)
final class SwiftDataPodcastRepositoryTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var repository: SwiftDataPodcastRepository!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([PodcastEntity.self, EpisodeEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        repository = SwiftDataPodcastRepository(modelContainer: modelContainer)
        XCTFailIfUsingInMemoryPodcastManagerForSync(repository)
    }

    override func tearDown() async throws {
        repository = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testAddAndFindPersistsPodcast() {
        let podcast = MockPodcast.createSample(id: "repo-1", title: "Repository Test")
        repository.add(podcast)

        let found = repository.find(id: podcast.id)
        XCTAssertNotNil(found, "Podcast should be persisted and retrievable")
        XCTAssertEqual(found?.title, podcast.title)
    }

    func testUpdatePreservesDateAddedAndHonorsSubscriptionChange() {
        let originalDate = Date(timeIntervalSince1970: 1234)
        let podcast = MockPodcast.createSample(id: "update-1", title: "Original", episodes: [], isSubscribed: true, dateAdded: originalDate)
        repository.add(podcast)

        let updated = Podcast(
            id: podcast.id,
            title: "Updated Title",
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: false,
            dateAdded: Date(timeIntervalSince1970: 9999),
            folderId: "folder-1",
            tagIds: ["tag-a"]
        )

        repository.update(updated)

        guard let found = repository.find(id: podcast.id) else {
            return XCTFail("Podcast should be present after update")
        }
        XCTAssertEqual(found.title, "Updated Title")
        XCTAssertEqual(found.isSubscribed, false, "Subscription change should be honored")
        XCTAssertEqual(found.dateAdded.timeIntervalSince1970, originalDate.timeIntervalSince1970, accuracy: 0.5, "dateAdded must be preserved")
        XCTAssertEqual(found.folderId, "folder-1")
        XCTAssertEqual(found.tagIds, ["tag-a"])
    }

    func testRemoveDeletesPodcast() {
        let podcast = MockPodcast.createSample(id: "delete-me")
        repository.add(podcast)
        XCTAssertNotNil(repository.find(id: podcast.id))

        repository.remove(id: podcast.id)

        XCTAssertNil(repository.find(id: podcast.id))
        XCTAssertFalse(repository.all().contains { $0.id == podcast.id })
    }

    func testOrganizationQueries() {
        repository.add(MockPodcast.createWithFolder(id: "f1", title: "F1", folderId: "folder-1"))
        repository.add(MockPodcast.createWithFolder(id: "f2", title: "F2", folderId: "folder-2"))
        repository.add(MockPodcast.createWithTags(id: "t1", title: "T1", tagIds: ["tag-1"]))
        repository.add(MockPodcast.createSample(id: "u1", title: "Unorganized"))

        let folder = repository.findByFolder(folderId: "folder-1")
        XCTAssertEqual(folder.map(\.id), ["f1"])

        let tag = repository.findByTag(tagId: "tag-1")
        XCTAssertEqual(tag.map(\.id), ["t1"])

        let unorganized = repository.findUnorganized().map(\.id)
        XCTAssertTrue(unorganized.contains("u1"))
        XCTAssertFalse(unorganized.contains("f1"))
        XCTAssertFalse(unorganized.contains("t1"))
    }

    func testFindByFolderRecursiveIncludesDescendants() throws {
        let folderManager = InMemoryFolderManager()
        try folderManager.add(Folder(id: "root", name: "Root"))
        try folderManager.add(Folder(id: "child", name: "Child", parentId: "root"))
        try folderManager.add(Folder(id: "grand", name: "Grand", parentId: "child"))

        repository.add(MockPodcast.createWithFolder(id: "root-pod", title: "Root", folderId: "root"))
        repository.add(MockPodcast.createWithFolder(id: "child-pod", title: "Child", folderId: "child"))
        repository.add(MockPodcast.createWithFolder(id: "grand-pod", title: "Grand", folderId: "grand"))

        let results = repository.findByFolderRecursive(folderId: "root", folderManager: folderManager)
        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids, ["root-pod", "child-pod", "grand-pod"])
    }

    func testDuplicateAddIsIgnored() {
        let podcast = MockPodcast.createSample(id: "dup")
        repository.add(podcast)
        repository.add(MockPodcast.createSample(id: "dup", title: "Different Title"))

        let found = repository.find(id: "dup")
        XCTAssertEqual(found?.title, podcast.title, "Duplicate add should not overwrite existing data")
    }

    func testSuccessfulAddTriggersRefresh() {
        let refresher = SiriSnapshotRefresherSpy()
        repository = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher
        )

        let podcast = MockPodcast.createSample(id: "siri-add")
        repository.add(podcast)

        XCTAssertEqual(refresher.refreshCount, 1, "Successful add should trigger Siri refresh")
        XCTAssertNotNil(repository.find(id: podcast.id), "Podcast should be persisted")
    }

    func testSuccessfulUpdateTriggersRefresh() {
        let refresher = SiriSnapshotRefresherSpy()
        repository = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher
        )

        let podcast = MockPodcast.createSample(id: "siri-update", title: "Original")
        repository.add(podcast)
        XCTAssertEqual(refresher.refreshCount, 1, "Initial add should trigger refresh")

        let updated = Podcast(
            id: podcast.id,
            title: "Updated Title",
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: true,
            dateAdded: podcast.dateAdded,
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
        repository.update(updated)

        XCTAssertEqual(refresher.refreshCount, 2, "Successful update should trigger Siri refresh")
        XCTAssertEqual(repository.find(id: podcast.id)?.title, "Updated Title")
    }

    func testSuccessfulRemoveTriggersRefresh() {
        let refresher = SiriSnapshotRefresherSpy()
        repository = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher
        )

        let podcast = MockPodcast.createSample(id: "siri-remove")
        repository.add(podcast)
        XCTAssertEqual(refresher.refreshCount, 1, "Initial add should trigger refresh")

        repository.remove(id: podcast.id)

        XCTAssertEqual(refresher.refreshCount, 2, "Successful remove should trigger Siri refresh")
        XCTAssertNil(repository.find(id: podcast.id), "Podcast should be removed")
    }

    func testSaveFailureDoesNotRefreshSiri() {
        enum SaveError: Error { case simulated }
        let refresher = SiriSnapshotRefresherSpy()

        repository = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher,
            saveHandler: { throw SaveError.simulated }
        )

        let podcast = MockPodcast.createSample(id: "fail-save")
        repository.add(podcast)

        XCTAssertEqual(refresher.refreshCount, 0, "Siri refresh should not run on failed save")
        XCTAssertNil(repository.find(id: podcast.id), "Failed saves should not persist data")
        XCTAssertTrue(repository.all().isEmpty, "Failed save should not leave any persisted podcasts")
    }

    func testConcurrentAddsAreSerialised() {
        let group = DispatchGroup()
        let repo = repository!

        for index in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let podcast = MockPodcast.createSample(id: "concurrent-\(index)")
                repo.add(podcast)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + .seconds(5))
        if result == .timedOut {
            return XCTFail("Timed out waiting for concurrent adds; potential deadlock in add()")
        }
        let allIds = Set(repository.all().map(\.id))
        XCTAssertEqual(allIds.count, 20)
        XCTAssertTrue(allIds.contains("concurrent-0"))
        XCTAssertTrue(allIds.contains("concurrent-19"))
    }

    // MARK: - Episode Persistence Tests

    func testAddPersistsEpisodes() {
        let episodes = [
            MockEpisode.create(id: "ep-1", title: "Episode 1"),
            MockEpisode.create(id: "ep-2", title: "Episode 2"),
            MockEpisode.create(id: "ep-3", title: "Episode 3")
        ]
        let podcast = MockPodcast.createSample(id: "podcast-with-episodes", title: "Test Podcast", episodes: episodes)

        repository.add(podcast)

        let found = repository.find(id: podcast.id)
        XCTAssertNotNil(found, "Podcast should be persisted")
        XCTAssertEqual(found?.episodes.count, 3, "All episodes should be persisted")

        let episodeIds = found?.episodes.map { $0.id }.sorted()
        XCTAssertEqual(episodeIds, ["ep-1", "ep-2", "ep-3"])

        let ep1 = found?.episodes.first { $0.id == "ep-1" }
        XCTAssertEqual(ep1?.title, "Episode 1")
    }

    func testFindHydratesEpisodes() {
        let episodes = [
            MockEpisode.create(id: "ep-1", title: "Episode 1", playbackPosition: 100),
            MockEpisode.create(id: "ep-2", title: "Episode 2", isFavorited: true)
        ]
        let podcast = MockPodcast.createSample(id: "hydrate-test", title: "Test Podcast", episodes: episodes)

        repository.add(podcast)
        let found = repository.find(id: podcast.id)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.episodes.count, 2)

        let ep1 = found?.episodes.first { $0.id == "ep-1" }
        XCTAssertEqual(ep1?.playbackPosition, 100, "Episode state should be restored")

        let ep2 = found?.episodes.first { $0.id == "ep-2" }
        XCTAssertEqual(ep2?.isFavorited, true, "Episode state should be restored")
    }

    func testAllHydratesEpisodes() {
        let episodes1 = [MockEpisode.create(id: "ep-1-1"), MockEpisode.create(id: "ep-1-2")]
        let episodes2 = [MockEpisode.create(id: "ep-2-1")]

        repository.add(MockPodcast.createSample(id: "p1", title: "P1", episodes: episodes1))
        repository.add(MockPodcast.createSample(id: "p2", title: "P2", episodes: episodes2))

        let all = repository.all()
        XCTAssertEqual(all.count, 2)

        let firstPodcast = all.first { $0.id == "p1" }
        XCTAssertEqual(firstPodcast?.episodes.count, 2)

        let secondPodcast = all.first { $0.id == "p2" }
        XCTAssertEqual(secondPodcast?.episodes.count, 1)
    }

    func testRemoveCascadeDeletesEpisodes() {
        let episodes = [
            MockEpisode.create(id: "ep-del-1"),
            MockEpisode.create(id: "ep-del-2")
        ]
        let podcast = MockPodcast.createSample(id: "delete-cascade", title: "Delete", episodes: episodes)

        repository.add(podcast)
        XCTAssertEqual(repository.find(id: podcast.id)?.episodes.count, 2, "Episodes should be persisted")

        repository.remove(id: podcast.id)

        XCTAssertNil(repository.find(id: podcast.id), "Podcast should be removed")

        // Verify no orphan EpisodeEntity rows remain by querying the database directly
        // This catches orphans that repository.all() would miss (since orphans have no parent podcast)
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<EpisodeEntity>()
        let orphanCount = (try? context.fetch(descriptor).count) ?? -1
        XCTAssertEqual(orphanCount, 0, "No orphan EpisodeEntity rows should remain after cascade delete")
    }

    func testResetAllPlaybackPositionsUsesPersistedEpisodes() {
        let episodes1 = [
            MockEpisode.create(id: "ep-1-1", playbackPosition: 1000),
            MockEpisode.create(id: "ep-1-2", playbackPosition: 2000)
        ]
        let episodes2 = [
            MockEpisode.create(id: "ep-2-1", playbackPosition: 500)
        ]

        repository.add(MockPodcast.createSample(id: "p1", title: "P1", episodes: episodes1))
        repository.add(MockPodcast.createSample(id: "p2", title: "P2", episodes: episodes2))

        // Verify playback positions are set
        var firstPodcast = repository.find(id: "p1")
        XCTAssertEqual(firstPodcast?.episodes.first { $0.id == "ep-1-1" }?.playbackPosition, 1000)
        XCTAssertEqual(firstPodcast?.episodes.first { $0.id == "ep-1-2" }?.playbackPosition, 2000)

        // Reset all playback positions
        repository.resetAllPlaybackPositions()

        // Verify all positions reset to 0
        firstPodcast = repository.find(id: "p1")
        let secondPodcast = repository.find(id: "p2")

        XCTAssertEqual(firstPodcast?.episodes.first { $0.id == "ep-1-1" }?.playbackPosition, 0)
        XCTAssertEqual(firstPodcast?.episodes.first { $0.id == "ep-1-2" }?.playbackPosition, 0)
        XCTAssertEqual(secondPodcast?.episodes.first { $0.id == "ep-2-1" }?.playbackPosition, 0)
    }

    func testEpisodeDownloadStatusPersists() {
        let episodes = [
            MockEpisode.create(id: "ep-downloaded", downloadStatus: .downloaded),
            MockEpisode.create(id: "ep-downloading", downloadStatus: .downloading),
            MockEpisode.create(id: "ep-failed", downloadStatus: .failed)
        ]
        let podcast = MockPodcast.createSample(id: "download-status-test", title: "Download", episodes: episodes)

        repository.add(podcast)
        let found = repository.find(id: podcast.id)

        XCTAssertEqual(found?.episodes.first { $0.id == "ep-downloaded" }?.downloadStatus, .downloaded)
        XCTAssertEqual(found?.episodes.first { $0.id == "ep-downloading" }?.downloadStatus, .downloading)
        XCTAssertEqual(found?.episodes.first { $0.id == "ep-failed" }?.downloadStatus, .failed)
    }

    func testUpdateReconcilesEpisodesAndPreservesUserState() {
        let originalEpisodes = [
            MockEpisode.create(id: "ep-1", title: "Old Title", playbackPosition: 50, isPlayed: true)
        ]
        let podcast = MockPodcast.createSample(id: "update-episodes", title: "Update Episodes", episodes: originalEpisodes)
        repository.add(podcast)

        let updatedEpisodes = [
            MockEpisode.create(id: "ep-1", title: "New Title", playbackPosition: 0),  // metadata change only
            MockEpisode.create(id: "ep-2", title: "New Episode")
        ]
        let updated = MockPodcast.createSample(id: podcast.id, title: podcast.title, episodes: updatedEpisodes)

        repository.update(updated)

        let found = repository.find(id: podcast.id)
        XCTAssertEqual(found?.episodes.count, 2)

        let ep1 = found?.episodes.first { $0.id == "ep-1" }
        XCTAssertEqual(ep1?.title, "New Title")
        XCTAssertEqual(ep1?.playbackPosition, 50, "User state should be preserved on update")
        XCTAssertEqual(ep1?.isPlayed, true)

        let ep2 = found?.episodes.first { $0.id == "ep-2" }
        XCTAssertEqual(ep2?.title, "New Episode")
    }

    func testUpdateRemovesMissingEpisodesWithoutUserState() {
        let originalEpisodes = [
            Self.makeEpisode(id: "ep-1", title: "Keep"),
            Self.makeEpisode(id: "ep-2", title: "Remove")
        ]
        let original = Self.makePodcast(id: "remove-episodes", episodes: originalEpisodes)
        repository.add(original)

        let updated = Self.makePodcast(
            id: original.id,
            title: original.title,
            episodes: [
                Self.makeEpisode(id: "ep-1", title: "Keep")
            ]
        )
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.map { $0.id }.sorted(), ["ep-1"])
    }

    func testSyncDeletesStaleEpisodesWithoutUserState() {
        let originalEpisodes = [
            Self.makeEpisode(id: "ep-keep", title: "Keep"),
            Self.makeEpisode(id: "ep-stale", title: "Stale", playbackPosition: 0, isPlayed: false, isFavorited: false)
        ]
        let original = Self.makePodcast(id: "sync-delete-stale", title: "Stale Episode Test", episodes: originalEpisodes)
        repository.add(original)

        let updated = Self.makePodcast(
            id: original.id,
            title: original.title,
            episodes: [
                Self.makeEpisode(id: "ep-keep", title: "Keep")
            ]
        )
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.map { $0.id }.sorted(), ["ep-keep"])
    }

    func testSyncKeepsEpisodeWithPlaybackPosition() {
        let original = Self.makePodcast(
            id: "sync-keep-playback",
            title: "Playback Position Test",
            episodes: [
                Self.makeEpisode(id: "ep-orphan", title: "Orphaned", playbackPosition: 120)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.id, "ep-orphan")
        XCTAssertEqual(found?.episodes.first?.playbackPosition, 120)
    }

    func testSyncKeepsPlayedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-played",
            title: "Played Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-played", title: "Played", isPlayed: true)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.isPlayed, true)
    }

    func testSyncKeepsDownloadedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-downloaded",
            title: "Downloaded Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-downloaded", title: "Downloaded", downloadStatus: .downloaded)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.downloadStatus, .downloaded)
    }

    func testSyncKeepsDownloadingEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-downloading",
            title: "Downloading Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-downloading", title: "Downloading", downloadStatus: .downloading)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.downloadStatus, .downloading)
    }

    func testSyncKeepsPausedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-paused",
            title: "Paused Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-paused", title: "Paused", downloadStatus: .paused)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.downloadStatus, .paused)
    }

    func testSyncKeepsFailedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-failed",
            title: "Failed Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-failed", title: "Failed", downloadStatus: .failed)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.downloadStatus, .failed)
    }

    func testSyncKeepsFavoritedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-favorited",
            title: "Favorited Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-favorited", title: "Favorited", isFavorited: true)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.isFavorited, true)
    }

    func testSyncKeepsBookmarkedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-bookmarked",
            title: "Bookmarked Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-bookmarked", title: "Bookmarked", isBookmarked: true)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.isBookmarked, true)
    }

    func testSyncKeepsArchivedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-archived",
            title: "Archived Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-archived", title: "Archived", isArchived: true)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.isArchived, true)
    }

    func testSyncKeepsRatedEpisode() {
        let original = Self.makePodcast(
            id: "sync-keep-rated",
            title: "Rated Episode Test",
            episodes: [
                Self.makeEpisode(id: "ep-rated", title: "Rated", rating: 5)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(id: original.id, title: original.title, episodes: [])
        repository.update(updated)

        let found = repository.find(id: original.id)
        XCTAssertEqual(found?.episodes.count, 1)
        XCTAssertEqual(found?.episodes.first?.rating, 5)
    }

    func testSyncMixedScenarioDeletesOnlyStale() {
        let original = Self.makePodcast(
            id: "sync-mixed",
            title: "Mixed Scenario Test",
            episodes: [
                Self.makeEpisode(id: "ep-keep-in-feed", title: "In Feed"),
                Self.makeEpisode(id: "ep-stale", title: "Stale No State"),
                Self.makeEpisode(id: "ep-orphan-played", title: "Orphan Played", isPlayed: true),
                Self.makeEpisode(id: "ep-orphan-position", title: "Orphan Position", playbackPosition: 60),
                Self.makeEpisode(id: "ep-orphan-downloaded", title: "Orphan Downloaded", downloadStatus: .downloaded),
                Self.makeEpisode(id: "ep-orphan-archived", title: "Orphan Archived", isArchived: true),
                Self.makeEpisode(id: "ep-orphan-rated", title: "Orphan Rated", rating: 4)
            ]
        )
        repository.add(original)

        let updated = Self.makePodcast(
            id: original.id,
            title: original.title,
            episodes: [
                Self.makeEpisode(id: "ep-keep-in-feed", title: "In Feed Updated")
            ]
        )
        repository.update(updated)

        let found = repository.find(id: original.id)
        let ids = Set(found?.episodes.map { $0.id } ?? [])
        XCTAssertEqual(ids, ["ep-keep-in-feed", "ep-orphan-played", "ep-orphan-position", "ep-orphan-downloaded", "ep-orphan-archived", "ep-orphan-rated"])
        XCTAssertFalse(ids.contains("ep-stale"), "Stale episode without user state should be deleted")
    }

    func testInvalidFeedURLSkipsCorruptedRows() throws {
        let context = ModelContext(modelContainer)
        let badEntity = PodcastEntity(
            id: "bad-feed",
            title: "Bad Feed",
            feedURLString: "",
            isSubscribed: true
        )
        context.insert(badEntity)
        try context.save()

        let all = repository.all()
        XCTAssertTrue(all.isEmpty, "Corrupted feed rows should be skipped, not crash")
    }

    func testEpisodesUseSafeConversion() throws {
        // Store an episode with invalid downloadStatus to ensure hydration remains safe
        let context = ModelContext(modelContainer)
        let podcast = PodcastEntity(
            id: "pod-safe",
            title: "Safe",
            feedURLString: "https://example.com/feed.xml",
            isSubscribed: true
        )
        context.insert(podcast)

        let badEpisode = EpisodeEntity(
            id: "ep-safe",
            podcastId: "pod-safe",
            title: "Bad Episode",
            podcastTitle: "Safe",
            downloadStatus: "bogus",
            dateAdded: Date()
        )
        context.insert(badEpisode)
        try context.save()

        let found = repository.find(id: "pod-safe")
        XCTAssertEqual(found?.episodes.first?.downloadStatus, .notDownloaded)
    }

    func testEpisodeIndexSourceReturnsPersistedEpisodes() {
        // Given: Repository with podcasts containing episodes
        let episodes1 = [
            MockEpisode.create(id: "ep-search-1", title: "Episode 1"),
            MockEpisode.create(id: "ep-search-2", title: "Episode 2")
        ]
        let episodes2 = [
            MockEpisode.create(id: "ep-search-3", title: "Episode 3")
        ]

        let podcast1 = MockPodcast.createSample(id: "podcast-1", title: "Podcast 1", episodes: episodes1)
        let podcast2 = MockPodcast.createSample(id: "podcast-2", title: "Podcast 2", episodes: episodes2)

        repository.add(podcast1)
        repository.add(podcast2)

        // When: Using repository with EpisodeIndexSource (simulating search indexing)
        let allPodcasts = repository.all()
        let allEpisodes = allPodcasts.flatMap { $0.episodes }

        // Then: Should return all persisted episodes (verifies hydration for search)
        XCTAssertEqual(allEpisodes.count, 3, "EpisodeIndexSource.documents() depends on all() returning episodes")
        XCTAssertTrue(allEpisodes.contains { $0.id == "ep-search-1" }, "Should find episode 1")
        XCTAssertTrue(allEpisodes.contains { $0.id == "ep-search-2" }, "Should find episode 2")
        XCTAssertTrue(allEpisodes.contains { $0.id == "ep-search-3" }, "Should find episode 3")
    }

    private static func makePodcast(
        id: String = UUID().uuidString,
        title: String = "Sample Podcast",
        isSubscribed: Bool = true,
        folderId: String? = nil,
        tagIds: [String] = [],
        episodes: [Episode] = [],
        dateAdded: Date = Date()
    ) -> Podcast {
        let normalizedEpisodes = episodes.map { episode -> Episode in
            var copy = episode
            copy.podcastID = id
            copy.podcastTitle = title
            return copy
        }
        return Podcast(
            id: id,
            title: title,
            author: "Author",
            description: "Description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology"],
            episodes: normalizedEpisodes,
            isSubscribed: isSubscribed,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
    }

    private static func makeEpisode(
        id: String,
        podcastID: String = "test-podcast",
        title: String = "Test Episode",
        playbackPosition: Int = 0,
        isPlayed: Bool = false,
        downloadStatus: EpisodeDownloadStatus = .notDownloaded,
        isFavorited: Bool = false,
        isBookmarked: Bool = false,
        isArchived: Bool = false,
        rating: Int? = nil
    ) -> Episode {
        Episode(
            id: id,
            title: title,
            podcastID: podcastID,
            podcastTitle: "Test Podcast",
            playbackPosition: playbackPosition,
            isPlayed: isPlayed,
            downloadStatus: downloadStatus,
            isFavorited: isFavorited,
            isBookmarked: isBookmarked,
            isArchived: isArchived,
            rating: rating
        )
    }

    private final class SiriSnapshotRefresherSpy: SiriSnapshotRefreshing, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var refreshCount: Int {
            lock.lock(); defer { lock.unlock() }
            return count
        }

        func refreshAll() {
            lock.lock()
            count += 1
            lock.unlock()
        }
    }
}
