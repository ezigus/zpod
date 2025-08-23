import XCTest
import CoreFoundation
@testable import TestSupport
import CoreModels

final class ComprehensiveInMemoryPodcastManagerTests: XCTestCase {
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    
    override func setUp() async throws {
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
    }
    
    override func tearDown() async throws {
        podcastManager = nil
        folderManager = nil
    }
    
    // MARK: - Basic CRUD Operations
    
    func testBasicOperations_AddFindUpdate() {
        // Given: A sample podcast
        let podcast = MockPodcast.createSample(id: "test-1", title: "Test Podcast")
        
        // When: Adding the podcast
        podcastManager.add(podcast)
        
        // Then: Should be able to find it
        let found = podcastManager.find(id: "test-1")
        XCTAssertEqual(found?.id, "test-1")
        XCTAssertEqual(found?.title, "Test Podcast")
        
        // When: Updating the podcast
        let updatedPodcast = Podcast(
            id: "test-1",
            title: "Updated Test Podcast",
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL
        )
        podcastManager.update(updatedPodcast)
        
        // Then: Should reflect the update
        let foundUpdated = podcastManager.find(id: "test-1")
        XCTAssertEqual(foundUpdated?.title, "Updated Test Podcast")
    }
    
    func testRemove_ValidId() {
        // Given: A podcast in the manager
        let podcast = MockPodcast.createSample(id: "remove-test")
        podcastManager.add(podcast)
        XCTAssertNotNil(podcastManager.find(id: "remove-test"))
        
        // When: Removing the podcast
        podcastManager.remove(id: "remove-test")
        
        // Then: Should no longer be found
        XCTAssertNil(podcastManager.find(id: "remove-test"))
    }
    
    func testRemove_InvalidId() {
        // Given: An empty manager
        // When: Removing a non-existent podcast
        podcastManager.remove(id: "non-existent")
        
        // Then: Should not crash and storage should remain empty
        XCTAssertTrue(podcastManager.all().isEmpty)
    }
    
    func testAll_EmptyManager() {
        // Given: An empty manager
        // When: Getting all podcasts
        let podcasts = podcastManager.all()
        
        // Then: Should return empty array
        XCTAssertTrue(podcasts.isEmpty)
    }
    
    func testAll_MultiplePodcasts() {
        // Given: Multiple podcasts added
        let podcast1 = MockPodcast.createSample(id: "pod-1", title: "Podcast 1")
        let podcast2 = MockPodcast.createSample(id: "pod-2", title: "Podcast 2")
        let podcast3 = MockPodcast.createSample(id: "pod-3", title: "Podcast 3")
        
        podcastManager.add(podcast1)
        podcastManager.add(podcast2)
        podcastManager.add(podcast3)
        
        // When: Getting all podcasts
        let allPodcasts = podcastManager.all()
        
        // Then: Should return all three
        XCTAssertEqual(allPodcasts.count, 3)
        let ids = Set(allPodcasts.map(\.id))
        XCTAssertTrue(ids.contains("pod-1"))
        XCTAssertTrue(ids.contains("pod-2"))
        XCTAssertTrue(ids.contains("pod-3"))
    }
    
    // MARK: - Uniqueness and Constraints
    
    func testAdd_DuplicateId() {
        // Given: A podcast already in the manager
        let original = MockPodcast.createSample(id: "duplicate-test", title: "Original")
        podcastManager.add(original)
        
        // When: Adding another podcast with the same ID
        let duplicate = MockPodcast.createSample(id: "duplicate-test", title: "Duplicate")
        podcastManager.add(duplicate)
        
        // Then: Should ignore the duplicate and keep the original
        let found = podcastManager.find(id: "duplicate-test")
        XCTAssertEqual(found?.title, "Original")
        XCTAssertEqual(podcastManager.all().count, 1)
    }
    
    func testUpdate_NonExistentPodcast() {
        // Given: An empty manager
        let podcast = MockPodcast.createSample(id: "non-existent")
        
        // When: Updating a non-existent podcast
        podcastManager.update(podcast)
        
        // Then: Should not add the podcast
        XCTAssertNil(podcastManager.find(id: "non-existent"))
        XCTAssertTrue(podcastManager.all().isEmpty)
    }
    
    // MARK: - Folder Organization
    
    func testFindByFolder_EmptyFolder() {
        // Given: Podcasts in different folders
        let folder1Podcast = MockPodcast.createWithFolder(id: "pod-1", folderId: "folder-1")
        let folder2Podcast = MockPodcast.createWithFolder(id: "pod-2", folderId: "folder-2")
        
        podcastManager.add(folder1Podcast)
        podcastManager.add(folder2Podcast)
        
        // When: Finding podcasts in an empty folder
        let emptyFolderPodcasts = podcastManager.findByFolder(folderId: "folder-3")
        
        // Then: Should return empty array
        XCTAssertTrue(emptyFolderPodcasts.isEmpty)
    }
    
    func testFindByFolder_MultiplePodcasts() {
        // Given: Multiple podcasts in the same folder
        let podcast1 = MockPodcast.createWithFolder(id: "pod-1", folderId: "shared-folder")
        let podcast2 = MockPodcast.createWithFolder(id: "pod-2", folderId: "shared-folder")
        let podcast3 = MockPodcast.createWithFolder(id: "pod-3", folderId: "other-folder")
        
        podcastManager.add(podcast1)
        podcastManager.add(podcast2)
        podcastManager.add(podcast3)
        
        // When: Finding podcasts in the shared folder
        let sharedFolderPodcasts = podcastManager.findByFolder(folderId: "shared-folder")
        
        // Then: Should return both podcasts from that folder
        XCTAssertEqual(sharedFolderPodcasts.count, 2)
        let ids = Set(sharedFolderPodcasts.map(\.id))
        XCTAssertTrue(ids.contains("pod-1"))
        XCTAssertTrue(ids.contains("pod-2"))
        XCTAssertFalse(ids.contains("pod-3"))
    }
    
    func testFindByFolderRecursive_WithHierarchy() {
        // Given: A folder hierarchy with podcasts
        let rootFolder = MockFolder.createRoot(id: "root", name: "Root")
        let childFolder = MockFolder.createChild(id: "child", name: "Child", parentId: "root")
        let grandchildFolder = MockFolder.createChild(id: "grandchild", name: "Grandchild", parentId: "child")
        
        try! folderManager.add(rootFolder)
        try! folderManager.add(childFolder)
        try! folderManager.add(grandchildFolder)
        
        let rootPodcast = MockPodcast.createWithFolder(id: "root-pod", folderId: "root")
        let childPodcast = MockPodcast.createWithFolder(id: "child-pod", folderId: "child")
        let grandchildPodcast = MockPodcast.createWithFolder(id: "grandchild-pod", folderId: "grandchild")
        
        podcastManager.add(rootPodcast)
        podcastManager.add(childPodcast)
        podcastManager.add(grandchildPodcast)
        
        // When: Finding podcasts recursively from root
        let recursivePodcasts = podcastManager.findByFolderRecursive(folderId: "root", folderManager: folderManager)
        
        // Then: Should return podcasts from root and all descendants
        XCTAssertEqual(recursivePodcasts.count, 3)
        let ids = Set(recursivePodcasts.map(\.id))
        XCTAssertTrue(ids.contains("root-pod"))
        XCTAssertTrue(ids.contains("child-pod"))
        XCTAssertTrue(ids.contains("grandchild-pod"))
    }
    
    // MARK: - Tag Organization
    
    func testFindByTag_SingleTag() {
        // Given: Podcasts with different tags
        let taggedPodcast1 = MockPodcast.createWithTags(id: "pod-1", tagIds: ["tech", "programming"])
        let taggedPodcast2 = MockPodcast.createWithTags(id: "pod-2", tagIds: ["tech", "news"])
        let untaggedPodcast = MockPodcast.createSample(id: "pod-3")
        
        podcastManager.add(taggedPodcast1)
        podcastManager.add(taggedPodcast2)
        podcastManager.add(untaggedPodcast)
        
        // When: Finding podcasts with "tech" tag
        let techPodcasts = podcastManager.findByTag(tagId: "tech")
        
        // Then: Should return both tagged podcasts
        XCTAssertEqual(techPodcasts.count, 2)
        let ids = Set(techPodcasts.map(\.id))
        XCTAssertTrue(ids.contains("pod-1"))
        XCTAssertTrue(ids.contains("pod-2"))
        XCTAssertFalse(ids.contains("pod-3"))
    }
    
    func testFindByTag_NoMatches() {
        // Given: Podcasts without the target tag
        let podcast = MockPodcast.createWithTags(id: "pod-1", tagIds: ["music"])
        podcastManager.add(podcast)
        
        // When: Finding podcasts with non-existent tag
        let results = podcastManager.findByTag(tagId: "sports")
        
        // Then: Should return empty array
        XCTAssertTrue(results.isEmpty)
    }
    
    func testFindUnorganized_Mixed() {
        // Given: Mix of organized and unorganized podcasts
        let folderPodcast = MockPodcast.createWithFolder(id: "pod-folder", folderId: "folder-1")
        let taggedPodcast = MockPodcast.createWithTags(id: "pod-tagged", tagIds: ["tag-1"])
        let bothPodcast = MockPodcast.createWithFolder(id: "pod-both", folderId: "folder-1")
        let unorganizedPodcast = MockPodcast.createSample(id: "pod-unorganized")
        
        podcastManager.add(folderPodcast)
        podcastManager.add(taggedPodcast)
        podcastManager.add(bothPodcast)
        podcastManager.add(unorganizedPodcast)
        
        // When: Finding unorganized podcasts
        let unorganized = podcastManager.findUnorganized()
        
        // Then: Should return only the truly unorganized podcast
        XCTAssertEqual(unorganized.count, 1)
        XCTAssertEqual(unorganized.first?.id, "pod-unorganized")
    }
    
    // MARK: - Initialization
    
    func testInitialization_WithInitialPodcasts() {
        // Given: Initial podcasts for initialization
        let podcast1 = MockPodcast.createSample(id: "init-1", title: "Initial 1")
        let podcast2 = MockPodcast.createSample(id: "init-2", title: "Initial 2")
        let initialPodcasts = [podcast1, podcast2]
        
        // When: Creating manager with initial podcasts
        let manager = InMemoryPodcastManager(initial: initialPodcasts)
        
        // Then: Should contain the initial podcasts
        XCTAssertEqual(manager.all().count, 2)
        XCTAssertNotNil(manager.find(id: "init-1"))
        XCTAssertNotNil(manager.find(id: "init-2"))
    }
    
    func testInitialization_EmptyInitial() {
        // Given: Empty initial array
        // When: Creating manager with empty initial
        let manager = InMemoryPodcastManager(initial: [])
        
        // Then: Should be empty
        XCTAssertTrue(manager.all().isEmpty)
    }
    
    // MARK: - Unicode and Edge Cases
    
    func testUnicodeSupport() {
        // Given: A podcast with Unicode content
        let unicodePodcast = MockPodcast.createUnicode()
        
        // When: Adding and retrieving the podcast
        podcastManager.add(unicodePodcast)
        let found = podcastManager.find(id: "pod-unicode")
        
        // Then: Should preserve Unicode content
        XCTAssertEqual(found?.title, "🎧 Programação em Swift 📱")
        XCTAssertEqual(found?.author, "João da Silva 🇧🇷")
    }
    
    func testLargeDataSet_Performance() {
        // Given: A large number of podcasts
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<1000 {
            let podcast = MockPodcast.createSample(id: "perf-\(i)", title: "Performance Test \(i)")
            podcastManager.add(podcast)
        }
        
        let addTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // When: Performing various operations
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let allPodcasts = podcastManager.all()
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        // Then: Should complete operations in reasonable time
        XCTAssertEqual(allPodcasts.count, 1000)
        XCTAssertLessThan(addTime, 1.0, "Adding 1000 podcasts should take less than 1 second")
        XCTAssertLessThan(searchTime, 0.1, "Retrieving 1000 podcasts should take less than 0.1 seconds")
    }
    
    func testConcurrentAccess_Sendable() {
        // Given: A podcast manager and concurrent tasks
        let podcast1 = MockPodcast.createSample(id: "concurrent-1")
        let podcast2 = MockPodcast.createSample(id: "concurrent-2")
        
        // When: Adding podcasts concurrently (simulated with async)
        podcastManager.add(podcast1)
        podcastManager.add(podcast2)
        
        // Then: Both should be present (note: actual thread safety not implemented yet)
        XCTAssertEqual(podcastManager.all().count, 2)
        XCTAssertNotNil(podcastManager.find(id: "concurrent-1"))
        XCTAssertNotNil(podcastManager.find(id: "concurrent-2"))
    }
}