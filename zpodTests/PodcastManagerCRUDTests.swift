import XCTest
@testable import zpod

final class PodcastManagerCRUDTests: XCTestCase {
    // MARK: - Properties
    private var podcastManager: zpod.InMemoryPodcastManager!
    private var samplePodcasts: [Podcast]!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        podcastManager = zpod.InMemoryPodcastManager()
        samplePodcasts = [
            Podcast(
                id: "podcast1",
                title: "Tech News",
                description: "Latest technology news",
                feedURL: URL(string: "https://example.com/tech.xml")!,
                folderId: "folder1",
                tagIds: ["tag1", "tag2"]
            ),
            Podcast(
                id: "podcast2",
                title: "Science Today",
                description: "Daily science updates",
                feedURL: URL(string: "https://example.com/science.xml")!
            ),
            Podcast(
                id: "podcast3",
                title: "Music Reviews",
                description: "Album and track reviews",
                feedURL: URL(string: "https://example.com/music.xml")!,
                folderId: "folder1",
                tagIds: ["tag1"]
            )
        ]
    }

    override func tearDown() {
        podcastManager = nil
        samplePodcasts = nil
        super.tearDown()
    }

    // MARK: - Basic CRUD Operations

    func testAdd_ValidPodcast() {
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        XCTAssertEqual(podcastManager.all().count, 1)
        XCTAssertEqual(podcastManager.find(id: podcast.id)?.title, podcast.title)
    }

    func testAdd_DuplicateId() {
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)

        let duplicate = Podcast(
            id: podcast.id,
            title: "Different Title",
            description: "Different description",
            feedURL: URL(string: "https://different.com/feed.xml")!
        )
        podcastManager.add(duplicate)

        XCTAssertEqual(podcastManager.all().count, 1)
        XCTAssertEqual(podcastManager.find(id: podcast.id)?.title, podcast.title)
    }

    func testFind_ExistingPodcast() {
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        let found = podcastManager.find(id: podcast.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, podcast.id)
        XCTAssertEqual(found?.title, podcast.title)
    }

    func testFind_NonExistentPodcast() {
        let found = podcastManager.find(id: "non-existent")
        XCTAssertNil(found)
    }

    func testUpdate_ExistingPodcast() {
        let original = samplePodcasts[0]
        podcastManager.add(original)

        let updated = Podcast(
            id: original.id,
            title: "Updated Title",
            description: original.description,
            artworkURL: original.artworkURL,
            feedURL: original.feedURL,
            folderId: original.folderId,
            tagIds: original.tagIds
        )
        podcastManager.update(updated)

        let found = podcastManager.find(id: original.id)
        XCTAssertEqual(found?.title, "Updated Title")
        XCTAssertEqual(podcastManager.all().count, 1)
    }

    func testUpdate_NonExistentPodcast() {
        let podcast = samplePodcasts[0]
        podcastManager.update(podcast)
        XCTAssertEqual(podcastManager.all().count, 0)
        XCTAssertNil(podcastManager.find(id: podcast.id))
    }

    func testRemove_ExistingPodcast() {
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        XCTAssertEqual(podcastManager.all().count, 1)
        podcastManager.remove(id: podcast.id)
        XCTAssertEqual(podcastManager.all().count, 0)
        XCTAssertNil(podcastManager.find(id: podcast.id))
    }

    func testRemove_NonExistentPodcast() {
        podcastManager.add(samplePodcasts[0])
        let originalCount = podcastManager.all().count
        podcastManager.remove(id: "non-existent")
        XCTAssertEqual(podcastManager.all().count, originalCount)
    }

    // MARK: - Collection Operations

    func testAll_EmptyStorage() {
        let all = podcastManager.all()
        XCTAssertTrue(all.isEmpty)
    }

    func testAll_MultiplePodcasts() {
        samplePodcasts.forEach { podcastManager.add($0) }
        let all = podcastManager.all()
        XCTAssertEqual(all.count, samplePodcasts.count)
        let allIds = Set(all.map { $0.id })
        let expectedIds = Set(samplePodcasts.map { $0.id })
        XCTAssertEqual(allIds, expectedIds)
    }

    // MARK: - Initialization & Protocol Conformance

    func testInitialization_WithInitialPodcasts() {
        let initialPodcasts = Array(samplePodcasts[0...1])
        let managerWithInitial = zpod.InMemoryPodcastManager(initial: initialPodcasts)
        XCTAssertEqual(managerWithInitial.all().count, 2)
        XCTAssertNotNil(managerWithInitial.find(id: initialPodcasts[0].id))
        XCTAssertNotNil(managerWithInitial.find(id: initialPodcasts[1].id))
    }

    func testInitialization_EmptyInitial() {
        let emptyManager = zpod.InMemoryPodcastManager(initial: [])
        XCTAssertTrue(emptyManager.all().isEmpty)
    }

    func testProtocolConformance_PodcastManaging() {
        let manager: PodcastManaging = zpod.InMemoryPodcastManager()
        let podcast = samplePodcasts[0]
        manager.add(podcast)
        let found = manager.find(id: podcast.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, podcast.id)
        XCTAssertEqual(manager.all().count, 1)
    }

    // MARK: - Thread Safety (read-only scenario)

    func testConcurrentAccess_ReadOperations() async {
        samplePodcasts.forEach { podcastManager.add($0) }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { [self] in
                    let all = self.podcastManager.all()
                    let first = self.podcastManager.find(id: self.samplePodcasts[0].id)
                    let byFolder = self.podcastManager.findByFolder(folderId: "folder1")
                    let byTag = self.podcastManager.findByTag(tagId: "tag1")
                    let unorganized = self.podcastManager.findUnorganized()

                    XCTAssertEqual(all.count, 3)
                    XCTAssertNotNil(first)
                    XCTAssertEqual(byFolder.count, 2)
                    XCTAssertEqual(byTag.count, 2)
                    XCTAssertEqual(unorganized.count, 1)
                }
            }
        }
    }
}
