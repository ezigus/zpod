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

        let schema = Schema([PodcastEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        repository = SwiftDataPodcastRepository(modelContainer: modelContainer)
    }

    override func tearDown() async throws {
        repository = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testAddAndFindPersistsPodcast() {
        let podcast = Self.makePodcast(id: "repo-1", title: "Repository Test")
        repository.add(podcast)

        let found = repository.find(id: podcast.id)
        XCTAssertNotNil(found, "Podcast should be persisted and retrievable")
        XCTAssertEqual(found?.title, podcast.title)
    }

    func testUpdatePreservesDateAddedAndHonorsSubscriptionChange() {
        let originalDate = Date(timeIntervalSince1970: 1234)
        let podcast = Self.makePodcast(id: "update-1", title: "Original", isSubscribed: true, dateAdded: originalDate)
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
        let podcast = Self.makePodcast(id: "delete-me")
        repository.add(podcast)
        XCTAssertNotNil(repository.find(id: podcast.id))

        repository.remove(id: podcast.id)

        XCTAssertNil(repository.find(id: podcast.id))
        XCTAssertFalse(repository.all().contains { $0.id == podcast.id })
    }

    func testOrganizationQueries() {
        repository.add(Self.makePodcast(id: "f1", folderId: "folder-1"))
        repository.add(Self.makePodcast(id: "f2", folderId: "folder-2"))
        repository.add(Self.makePodcast(id: "t1", tagIds: ["tag-1"]))
        repository.add(Self.makePodcast(id: "u1"))

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

        repository.add(Self.makePodcast(id: "root-pod", folderId: "root"))
        repository.add(Self.makePodcast(id: "child-pod", folderId: "child"))
        repository.add(Self.makePodcast(id: "grand-pod", folderId: "grand"))

        let results = repository.findByFolderRecursive(folderId: "root", folderManager: folderManager)
        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids, ["root-pod", "child-pod", "grand-pod"])
    }

    func testDuplicateAddIsIgnored() {
        let podcast = Self.makePodcast(id: "dup")
        repository.add(podcast)
        repository.add(Self.makePodcast(id: "dup", title: "Different Title"))

        let found = repository.find(id: "dup")
        XCTAssertEqual(found?.title, podcast.title, "Duplicate add should not overwrite existing data")
    }

    func testSaveFailureDoesNotRefreshSiri() {
        enum SaveError: Error { case simulated }
        let refresher = SiriSnapshotRefresherSpy()

        repository = SwiftDataPodcastRepository(
            modelContainer: modelContainer,
            siriSnapshotRefresher: refresher,
            saveHandler: { throw SaveError.simulated }
        )

        let podcast = Self.makePodcast(id: "fail-save")
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
                let podcast = Self.makePodcast(id: "concurrent-\(index)")
                repo.add(podcast)
                group.leave()
            }
        }

        group.wait()
        let allIds = Set(repository.all().map(\.id))
        XCTAssertEqual(allIds.count, 20)
        XCTAssertTrue(allIds.contains("concurrent-0"))
        XCTAssertTrue(allIds.contains("concurrent-19"))
    }

    // MARK: - Helpers

    private static func makePodcast(
        id: String = UUID().uuidString,
        title: String = "Sample Podcast",
        isSubscribed: Bool = true,
        folderId: String? = nil,
        tagIds: [String] = [],
        dateAdded: Date = Date()
    ) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: "Author",
            description: "Description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology"],
            episodes: [],
            isSubscribed: isSubscribed,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
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
