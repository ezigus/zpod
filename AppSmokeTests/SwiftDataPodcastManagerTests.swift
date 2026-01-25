import XCTest
import SwiftData
import TestSupport
import Foundation
@testable import CoreModels
@testable import Persistence

/// Comprehensive unit tests for SwiftDataPodcastRepository (app smoke coverage).
///
/// **Specifications Covered**
/// - `Issues/27.1-podcast-persistence-architecture.md` — Persistent podcast storage with SwiftData
/// - `Issues/27.1.1-podcast-repository-persistent-implementation.md` — Repository implementation with >90% coverage
///
/// **Test Coverage**
/// - CRUD operations (add, find, update, remove, all)
/// - Organization filtering (folders, tags, unorganized, recursive)
/// - Duplicate handling and edge cases
/// - Domain/entity conversion logic
/// - Data persistence across updates
@available(iOS 17, macOS 14, watchOS 10, *)
final class SwiftDataPodcastRepositoryAppTests: XCTestCase {

    // MARK: - Properties

    private var modelContainer: ModelContainer!
    private var manager: SwiftDataPodcastRepository!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory container for isolated testing
        let schema = Schema([PodcastEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        manager = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: NoopSiriSnapshotRefresher()
        )
    }

    override func tearDown() async throws {
        manager = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Test Helpers

    /// Creates a sample podcast for testing with customizable properties.
    private func makeSamplePodcast(
        id: String = UUID().uuidString,
        title: String = "Sample Podcast",
        author: String? = "Test Author",
        description: String? = "Test Description",
        feedURL: URL = URL(string: "https://example.com/feed.xml")!,
        categories: [String] = ["Technology"],
        isSubscribed: Bool = false,
        folderId: String? = nil,
        tagIds: [String] = []
    ) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: author,
            description: description,
            artworkURL: URL(string: "https://example.com/art.jpg"),
            feedURL: feedURL,
            categories: categories,
            episodes: [],
            isSubscribed: isSubscribed,
            dateAdded: Date(),
            folderId: folderId,
            tagIds: tagIds
        )
    }

    private final class SiriSnapshotRefresherSpy: SiriSnapshotRefreshing, @unchecked Sendable {
        private let lock = NSLock()
        private var _refreshCount = 0

        var refreshCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _refreshCount
        }

        func refreshAll() {
            lock.lock()
            _refreshCount += 1
            lock.unlock()
        }
    }

    private struct NoopSiriSnapshotRefresher: SiriSnapshotRefreshing, @unchecked Sendable {
        func refreshAll() {}
    }

    // MARK: - CRUD Tests: Add

    func testAdd_NewPodcast_SuccessfullyAdds() {
        // Given: A new podcast
        let podcast = makeSamplePodcast(id: "test-1", title: "Test Podcast")

        // When: Adding the podcast
        manager.add(podcast)

        // Then: Podcast should be retrievable
        let retrieved = manager.find(id: "test-1")
        XCTAssertNotNil(retrieved, "Added podcast should be findable")
        XCTAssertEqual(retrieved?.id, "test-1")
        XCTAssertEqual(retrieved?.title, "Test Podcast")
        XCTAssertEqual(retrieved?.author, "Test Author")
    }

    func testAdd_DuplicateId_SilentlyIgnores() {
        // Given: A podcast already in storage
        let podcast1 = makeSamplePodcast(id: "duplicate", title: "First")
        manager.add(podcast1)

        let podcast2 = makeSamplePodcast(id: "duplicate", title: "Second")

        // When: Attempting to add duplicate
        manager.add(podcast2)

        // Then: Original podcast should remain unchanged (silent ignore per implementation)
        let retrieved = manager.find(id: "duplicate")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "First", "Original podcast should be preserved")
    }

    func testAdd_PreservesAllFields() {
        // Given: A podcast with all fields populated
        let podcast = Podcast(
            id: "full-fields",
            title: "Complete Podcast",
            author: "Test Author",
            description: "Detailed description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Tech", "News", "Science"],
            episodes: [],
            isSubscribed: true,
            dateAdded: Date(),
            folderId: "folder-123",
            tagIds: ["tag-a", "tag-b"]
        )

        // When: Adding the podcast
        manager.add(podcast)

        // Then: All fields should be preserved
        let retrieved = manager.find(id: "full-fields")
        XCTAssertEqual(retrieved?.title, "Complete Podcast")
        XCTAssertEqual(retrieved?.author, "Test Author")
        XCTAssertEqual(retrieved?.description, "Detailed description")
        XCTAssertEqual(retrieved?.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
        XCTAssertEqual(retrieved?.feedURL.absoluteString, "https://example.com/feed.xml")
        XCTAssertEqual(retrieved?.categories, ["Tech", "News", "Science"])
        XCTAssertEqual(retrieved?.isSubscribed, true)
        XCTAssertEqual(retrieved?.folderId, "folder-123")
        XCTAssertEqual(retrieved?.tagIds, ["tag-a", "tag-b"])
    }

    // MARK: - CRUD Tests: Find

    func testFind_ExistingPodcast_ReturnsCorrectPodcast() {
        // Given: Multiple podcasts in storage
        manager.add(makeSamplePodcast(id: "pod-1", title: "Podcast One"))
        manager.add(makeSamplePodcast(id: "pod-2", title: "Podcast Two"))
        manager.add(makeSamplePodcast(id: "find-me", title: "Findable"))

        // When: Finding a specific podcast
        let found = manager.find(id: "find-me")

        // Then: Correct podcast should be returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, "find-me")
        XCTAssertEqual(found?.title, "Findable")
    }

    func testFind_NonexistentPodcast_ReturnsNil() {
        // Given: Empty database

        // When: Searching for non-existent podcast
        let found = manager.find(id: "nonexistent")

        // Then: Should return nil
        XCTAssertNil(found, "Non-existent podcast should return nil")
    }

    // MARK: - CRUD Tests: Update

    func testUpdate_ExistingPodcast_UpdatesFields() {
        // Given: A podcast in storage
        let original = makeSamplePodcast(id: "update-me", title: "Original Title", author: "Original Author")
        manager.add(original)

        // When: Updating the podcast (create new instance with updated fields)
        let updated = Podcast(
            id: original.id,
            title: "Updated Title",
            author: "Updated Author",
            description: "Updated Description",
            artworkURL: original.artworkURL,
            feedURL: original.feedURL,
            categories: original.categories,
            episodes: original.episodes,
            isSubscribed: original.isSubscribed,
            dateAdded: original.dateAdded,
            folderId: original.folderId,
            tagIds: original.tagIds
        )
        manager.update(updated)

        // Then: Fields should be updated
        let retrieved = manager.find(id: "update-me")
        XCTAssertEqual(retrieved?.title, "Updated Title")
        XCTAssertEqual(retrieved?.author, "Updated Author")
        XCTAssertEqual(retrieved?.description, "Updated Description")
    }

    func testUpdate_HonorsIsSubscribedWhenMetadataChanges() {
        // Given: A subscribed podcast in storage
        let original = makeSamplePodcast(id: "subscribed", title: "Original", isSubscribed: true)
        manager.add(original)

        // When: Updating metadata while explicitly changing subscription
        let updated = Podcast(
            id: original.id,
            title: "Updated Title",
            author: original.author,
            description: original.description,
            artworkURL: original.artworkURL,
            feedURL: original.feedURL,
            categories: original.categories,
            episodes: original.episodes,
            isSubscribed: false,
            dateAdded: original.dateAdded,
            folderId: original.folderId,
            tagIds: original.tagIds
        )
        manager.update(updated)

        // Then: Subscription should reflect the explicit change
        let retrieved = manager.find(id: "subscribed")
        XCTAssertEqual(retrieved?.isSubscribed, false)
    }

    func testUpdate_AllowsIsSubscribedChangeWhenOnlySubscriptionChanges() {
        // Given: A subscribed podcast in storage
        let original = makeSamplePodcast(id: "toggle-sub", isSubscribed: true)
        manager.add(original)

        // When: Updating only the subscription flag
        let updated = Podcast(
            id: original.id,
            title: original.title,
            author: original.author,
            description: original.description,
            artworkURL: original.artworkURL,
            feedURL: original.feedURL,
            categories: original.categories,
            episodes: original.episodes,
            isSubscribed: false,
            dateAdded: original.dateAdded,
            folderId: original.folderId,
            tagIds: original.tagIds
        )
        manager.update(updated)

        // Then: Subscription should be updated
        let retrieved = manager.find(id: "toggle-sub")
        XCTAssertEqual(retrieved?.isSubscribed, false)
    }

    func testUpdate_PreservesDateAdded() {
        // Given: A podcast with a specific dateAdded
        let originalDate = Date(timeIntervalSince1970: 1000000)
        let podcast = Podcast(
            id: "preserve-date",
            title: "Original",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            dateAdded: originalDate
        )
        manager.add(podcast)

        // When: Updating the podcast (create new instance with updated title)
        let updated = Podcast(
            id: podcast.id,
            title: "Updated",
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: podcast.isSubscribed,
            dateAdded: Date(timeIntervalSince1970: 2000000), // Try to change dateAdded
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
        manager.update(updated)

        // Then: dateAdded should be preserved (not changed to the new value)
        let retrieved = manager.find(id: "preserve-date")
        XCTAssertNotNil(retrieved)
        let retrievedInterval = retrieved?.dateAdded.timeIntervalSince1970 ?? 0
        XCTAssertEqual(
            retrievedInterval,
            originalDate.timeIntervalSince1970,
            accuracy: 1.0,
            "dateAdded should be preserved on update"
        )
    }

    func testUpdate_NonexistentPodcast_SilentlyIgnores() {
        // Given: Empty database
        let podcast = makeSamplePodcast(id: "nonexistent", title: "Ghost Podcast")

        // When: Attempting to update non-existent podcast
        manager.update(podcast)

        // Then: Should not crash or throw (silently ignores per implementation)
        let retrieved = manager.find(id: "nonexistent")
        XCTAssertNil(retrieved, "Non-existent podcast should not be created by update")
    }

    func testUpdate_Organization_UpdatesFolderAndTags() {
        // Given: A podcast without organization
        let podcast = makeSamplePodcast(id: "organize-me")
        manager.add(podcast)

        // When: Updating with folder and tags (create new instance)
        let updated = Podcast(
            id: podcast.id,
            title: podcast.title,
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: podcast.isSubscribed,
            dateAdded: podcast.dateAdded,
            folderId: "new-folder",
            tagIds: ["tag-1", "tag-2"]
        )
        manager.update(updated)

        // Then: Organization should be updated
        let retrieved = manager.find(id: "organize-me")
        XCTAssertEqual(retrieved?.folderId, "new-folder")
        XCTAssertEqual(retrieved?.tagIds, ["tag-1", "tag-2"])
    }

    // MARK: - CRUD Tests: Remove

    func testRemove_ExistingPodcast_DeletesSuccessfully() {
        // Given: A podcast in storage
        let podcast = makeSamplePodcast(id: "delete-me", title: "To Be Deleted")
        manager.add(podcast)
        XCTAssertNotNil(manager.find(id: "delete-me"), "Podcast should exist before deletion")

        // When: Removing the podcast
        manager.remove(id: "delete-me")

        // Then: Podcast should no longer exist
        let retrieved = manager.find(id: "delete-me")
        XCTAssertNil(retrieved, "Deleted podcast should not be findable")
    }

    func testRemove_NonexistentPodcast_SilentlyIgnores() {
        // Given: Empty database

        // When: Attempting to remove non-existent podcast
        manager.remove(id: "nonexistent")

        // Then: Should not crash or throw (silently ignores per implementation)
        // No assertion needed - test passes if no exception thrown
    }

    func testRemove_DoesNotAffectOtherPodcasts() {
        // Given: Multiple podcasts in storage
        manager.add(makeSamplePodcast(id: "keep-1", title: "Keep Me 1"))
        manager.add(makeSamplePodcast(id: "delete", title: "Delete Me"))
        manager.add(makeSamplePodcast(id: "keep-2", title: "Keep Me 2"))

        // When: Removing one podcast
        manager.remove(id: "delete")

        // Then: Other podcasts should remain
        XCTAssertNotNil(manager.find(id: "keep-1"))
        XCTAssertNotNil(manager.find(id: "keep-2"))
        XCTAssertNil(manager.find(id: "delete"))
    }

    // MARK: - CRUD Tests: All

    func testAll_EmptyDatabase_ReturnsEmptyArray() {
        // Given: Empty database

        // When: Fetching all podcasts
        let podcasts = manager.all()

        // Then: Should return empty array
        XCTAssertEqual(podcasts.count, 0, "Empty database should return empty array")
    }

    func testAll_MultiplePodcasts_ReturnsAllPodcasts() {
        // Given: Multiple podcasts in storage
        manager.add(makeSamplePodcast(id: "1", title: "Podcast 1"))
        manager.add(makeSamplePodcast(id: "2", title: "Podcast 2"))
        manager.add(makeSamplePodcast(id: "3", title: "Podcast 3"))

        // When: Fetching all podcasts
        let podcasts = manager.all()

        // Then: All podcasts should be returned
        XCTAssertEqual(podcasts.count, 3)
        XCTAssertTrue(podcasts.contains { $0.title == "Podcast 1" })
        XCTAssertTrue(podcasts.contains { $0.title == "Podcast 2" })
        XCTAssertTrue(podcasts.contains { $0.title == "Podcast 3" })
    }

    func testAll_ReflectsAdditionsAndDeletions() {
        // Given: Initial podcasts
        manager.add(makeSamplePodcast(id: "1", title: "First"))
        manager.add(makeSamplePodcast(id: "2", title: "Second"))
        XCTAssertEqual(manager.all().count, 2)

        // When: Adding and removing podcasts
        manager.add(makeSamplePodcast(id: "3", title: "Third"))
        XCTAssertEqual(manager.all().count, 3)

        manager.remove(id: "1")

        // Then: Count should reflect changes
        let final = manager.all()
        XCTAssertEqual(final.count, 2)
        XCTAssertFalse(final.contains { $0.id == "1" })
        XCTAssertTrue(final.contains { $0.id == "2" })
        XCTAssertTrue(final.contains { $0.id == "3" })
    }

    // MARK: - Organization Tests: Find by Folder

    func testFindByFolder_MatchingPodcasts_ReturnsFilteredResults() {
        // Given: Podcasts in different folders
        manager.add(makeSamplePodcast(id: "1", title: "In Folder A", folderId: "folder-a"))
        manager.add(makeSamplePodcast(id: "2", title: "In Folder B", folderId: "folder-b"))
        manager.add(makeSamplePodcast(id: "3", title: "Also In Folder A", folderId: "folder-a"))

        // When: Querying by folder
        let results = manager.findByFolder(folderId: "folder-a")

        // Then: Only matching podcasts should be returned
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.folderId == "folder-a" })
        XCTAssertTrue(results.contains { $0.title == "In Folder A" })
        XCTAssertTrue(results.contains { $0.title == "Also In Folder A" })
    }

    func testFindByFolder_NoMatches_ReturnsEmptyArray() {
        // Given: Podcasts in various folders
        manager.add(makeSamplePodcast(id: "1", folderId: "folder-a"))
        manager.add(makeSamplePodcast(id: "2", folderId: "folder-b"))

        // When: Querying for non-existent folder
        let results = manager.findByFolder(folderId: "nonexistent-folder")

        // Then: Should return empty array
        XCTAssertEqual(results.count, 0)
    }

    func testFindByFolder_NilFolderId_NotReturnedInFolderQuery() {
        // Given: Mix of organized and unorganized podcasts
        manager.add(makeSamplePodcast(id: "1", title: "Organized", folderId: "folder-a"))
        manager.add(makeSamplePodcast(id: "2", title: "Unorganized", folderId: nil))

        // When: Querying by folder
        let results = manager.findByFolder(folderId: "folder-a")

        // Then: Only podcasts with matching folderId should be returned
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Organized")
    }

    func testFindByFolderRecursive_IncludesDescendants() throws {
        // Given: A folder hierarchy (root -> child -> grandchild)
        let folderManager = InMemoryFolderManager()
        try folderManager.add(Folder(id: "root", name: "Root"))
        try folderManager.add(Folder(id: "child", name: "Child", parentId: "root"))
        try folderManager.add(Folder(id: "grandchild", name: "Grandchild", parentId: "child"))

        manager.add(makeSamplePodcast(id: "pod-root", title: "Root Pod", folderId: "root"))
        manager.add(makeSamplePodcast(id: "pod-child", title: "Child Pod", folderId: "child"))
        manager.add(makeSamplePodcast(id: "pod-grandchild", title: "Grandchild Pod", folderId: "grandchild"))
        manager.add(makeSamplePodcast(id: "pod-other", title: "Other Pod", folderId: "other"))

        // When: Querying recursively from root
        let results = manager.findByFolderRecursive(folderId: "root", folderManager: folderManager)

        // Then: Includes podcasts in root and all descendants
        let ids = Set(results.map { $0.id })
        XCTAssertEqual(ids, ["pod-root", "pod-child", "pod-grandchild"])
    }

    // MARK: - Organization Tests: Find by Tag

    func testFindByTag_MatchingPodcasts_ReturnsFilteredResults() {
        // Given: Podcasts with various tags
        manager.add(makeSamplePodcast(id: "1", title: "Tagged A", tagIds: ["tag-a", "tag-b"]))
        manager.add(makeSamplePodcast(id: "2", title: "Tagged B Only", tagIds: ["tag-b"]))
        manager.add(makeSamplePodcast(id: "3", title: "Tagged C", tagIds: ["tag-c"]))

        // When: Querying by tag
        let results = manager.findByTag(tagId: "tag-a")

        // Then: Only podcasts with that tag should be returned
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Tagged A")
    }

    func testFindByTag_MultipleMatches_ReturnsAll() {
        // Given: Multiple podcasts with the same tag
        manager.add(makeSamplePodcast(id: "1", title: "First", tagIds: ["common-tag"]))
        manager.add(makeSamplePodcast(id: "2", title: "Second", tagIds: ["common-tag", "other-tag"]))
        manager.add(makeSamplePodcast(id: "3", title: "Third", tagIds: ["common-tag"]))

        // When: Querying by common tag
        let results = manager.findByTag(tagId: "common-tag")

        // Then: All matching podcasts should be returned
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.tagIds.contains("common-tag") })
    }

    func testFindByTag_NoMatches_ReturnsEmptyArray() {
        // Given: Podcasts with various tags
        manager.add(makeSamplePodcast(id: "1", tagIds: ["tag-a"]))
        manager.add(makeSamplePodcast(id: "2", tagIds: ["tag-b"]))

        // When: Querying for non-existent tag
        let results = manager.findByTag(tagId: "nonexistent-tag")

        // Then: Should return empty array
        XCTAssertEqual(results.count, 0)
    }

    func testFindByTag_EmptyTagIds_NotReturnedInTagQuery() {
        // Given: Mix of tagged and untagged podcasts
        manager.add(makeSamplePodcast(id: "1", title: "Tagged", tagIds: ["tag-a"]))
        manager.add(makeSamplePodcast(id: "2", title: "Untagged", tagIds: []))

        // When: Querying by tag
        let results = manager.findByTag(tagId: "tag-a")

        // Then: Only tagged podcasts should be returned
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Tagged")
    }

    // MARK: - Organization Tests: Find Unorganized

    func testFindUnorganized_PodcastsWithoutFolderOrTags_ReturnsCorrectResults() {
        // Given: Mix of organized and unorganized podcasts
        manager.add(makeSamplePodcast(id: "1", title: "Has Folder", folderId: "folder-1", tagIds: []))
        manager.add(makeSamplePodcast(id: "2", title: "Has Tags", folderId: nil, tagIds: ["tag-1"]))
        manager.add(makeSamplePodcast(id: "3", title: "Has Both", folderId: "folder-1", tagIds: ["tag-1"]))
        manager.add(makeSamplePodcast(id: "4", title: "Unorganized", folderId: nil, tagIds: []))
        manager.add(makeSamplePodcast(id: "5", title: "Also Unorganized", folderId: nil, tagIds: []))

        // When: Finding unorganized podcasts
        let results = manager.findUnorganized()

        // Then: Only podcasts without folder or tags should be returned
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.folderId == nil && $0.tagIds.isEmpty })
        XCTAssertTrue(results.contains { $0.title == "Unorganized" })
        XCTAssertTrue(results.contains { $0.title == "Also Unorganized" })
    }

    func testFindUnorganized_AllOrganized_ReturnsEmptyArray() {
        // Given: All podcasts are organized
        manager.add(makeSamplePodcast(id: "1", folderId: "folder-1"))
        manager.add(makeSamplePodcast(id: "2", tagIds: ["tag-1"]))
        manager.add(makeSamplePodcast(id: "3", folderId: "folder-2", tagIds: ["tag-2"]))

        // When: Finding unorganized podcasts
        let results = manager.findUnorganized()

        // Then: Should return empty array
        XCTAssertEqual(results.count, 0)
    }

    func testFindUnorganized_EmptyDatabase_ReturnsEmptyArray() {
        // Given: Empty database

        // When: Finding unorganized podcasts
        let results = manager.findUnorganized()

        // Then: Should return empty array
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Conversion Tests

    func testConversion_DomainToEntity_PreservesAllFields() {
        // Given: A complete domain podcast
        let podcast = Podcast(
            id: "conv-test",
            title: "Conversion Test",
            author: "Test Author",
            description: "Test Description",
            artworkURL: URL(string: "https://example.com/art.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Tech", "News"],
            episodes: [],
            isSubscribed: true,
            dateAdded: Date(),
            folderId: "folder-1",
            tagIds: ["tag-1", "tag-2"]
        )

        // When: Adding and retrieving (triggers conversion)
        manager.add(podcast)
        let retrieved = manager.find(id: "conv-test")

        // Then: All fields should be preserved through conversion
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "conv-test")
        XCTAssertEqual(retrieved?.title, "Conversion Test")
        XCTAssertEqual(retrieved?.author, "Test Author")
        XCTAssertEqual(retrieved?.description, "Test Description")
        XCTAssertEqual(retrieved?.artworkURL?.absoluteString, "https://example.com/art.jpg")
        XCTAssertEqual(retrieved?.feedURL.absoluteString, "https://example.com/feed.xml")
        XCTAssertEqual(retrieved?.categories, ["Tech", "News"])
        XCTAssertEqual(retrieved?.isSubscribed, true)
        XCTAssertEqual(retrieved?.folderId, "folder-1")
        XCTAssertEqual(retrieved?.tagIds, ["tag-1", "tag-2"])
    }

    func testConversion_NilOptionalFields_HandledCorrectly() {
        // Given: A podcast with nil optional fields
        let podcast = Podcast(
            id: "nil-fields",
            title: "Minimal Podcast",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: Date(),
            folderId: nil,
            tagIds: []
        )

        // When: Adding and retrieving
        manager.add(podcast)
        let retrieved = manager.find(id: "nil-fields")

        // Then: Nil fields should be preserved
        XCTAssertNotNil(retrieved)
        XCTAssertNil(retrieved?.author)
        XCTAssertNil(retrieved?.description)
        XCTAssertNil(retrieved?.artworkURL)
        XCTAssertNil(retrieved?.folderId)
        XCTAssertEqual(retrieved?.tagIds, [])
    }

    // MARK: - Siri Snapshot Refresh

    func testSiriRefreshInvokedOnAddUpdateRemove() {
        // Given: A manager configured with a refresh spy
        let refresher = SiriSnapshotRefresherSpy()
        let manager = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher
        )
        let podcast = makeSamplePodcast(id: "siri-refresh", title: "Siri Refresh")

        // When: Adding, updating, and removing
        manager.add(podcast)
        XCTAssertEqual(refresher.refreshCount, 1)

        let updated = Podcast(
            id: podcast.id,
            title: "Updated Siri Refresh",
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: podcast.isSubscribed,
            dateAdded: podcast.dateAdded,
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
        manager.update(updated)
        XCTAssertEqual(refresher.refreshCount, 2)

        manager.remove(id: podcast.id)
        XCTAssertEqual(refresher.refreshCount, 3)
    }
}
