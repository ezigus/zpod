import XCTest
@testable import zpodLib
@testable import TestSupport
import CoreModels

/// Comprehensive unit tests for PodcastManager - testing protocol compliance and in-memory implementation
final class ComprehensivePodcastManagerTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var samplePodcasts: [Podcast]!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Given: Clean test environment
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        
        // Create sample test data
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
                feedURL: URL(string: "https://example.com/science.xml")!,
                folderId: nil,
                tagIds: []
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
        folderManager = nil
        samplePodcasts = nil
        super.tearDown()
    }
    
    // MARK: - Basic CRUD Operations
    
    func testAdd_ValidPodcast() {
        // Given: Fresh podcast manager
        let podcast = samplePodcasts[0]
        
        // When: Adding a valid podcast
        podcastManager.add(podcast)
        
        // Then: Podcast should be stored
        XCTAssertEqual(podcastManager.all().count, 1)
        XCTAssertEqual(podcastManager.find(id: podcast.id)?.title, podcast.title)
    }
    
    func testAdd_DuplicateId() {
        // Given: Podcast already exists
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        
        // When: Adding podcast with same ID
        let duplicate = Podcast(
            id: podcast.id,
            title: "Different Title",
            description: "Different description", 
            feedURL: URL(string: "https://different.com/feed.xml")!
        )
        podcastManager.add(duplicate)
        
        // Then: Original podcast should remain unchanged
        XCTAssertEqual(podcastManager.all().count, 1)
        XCTAssertEqual(podcastManager.find(id: podcast.id)?.title, podcast.title)
    }
    
    func testFind_ExistingPodcast() {
        // Given: Podcast in storage
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        
        // When: Finding by ID
        let found = podcastManager.find(id: podcast.id)
        
        // Then: Should return correct podcast
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, podcast.id)
        XCTAssertEqual(found?.title, podcast.title)
    }
    
    func testFind_NonExistentPodcast() {
        // Given: Empty storage
        
        // When: Finding non-existent podcast
        let found = podcastManager.find(id: "non-existent")
        
        // Then: Should return nil
        XCTAssertNil(found)
    }
    
    func testUpdate_ExistingPodcast() {
        // Given: Existing podcast
        let original = samplePodcasts[0]
        podcastManager.add(original)
        
        // When: Updating with modified data
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
        
        // Then: Changes should be applied
        let found = podcastManager.find(id: original.id)
        XCTAssertEqual(found?.title, "Updated Title")
        XCTAssertEqual(podcastManager.all().count, 1)
    }
    
    func testUpdate_NonExistentPodcast() {
        // Given: Empty storage
        let podcast = samplePodcasts[0]
        
        // When: Updating non-existent podcast
        podcastManager.update(podcast)
        
        // Then: No podcast should be added
        XCTAssertEqual(podcastManager.all().count, 0)
        XCTAssertNil(podcastManager.find(id: podcast.id))
    }
    
    func testRemove_ExistingPodcast() {
        // Given: Existing podcast
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        XCTAssertEqual(podcastManager.all().count, 1)
        
        // When: Removing podcast
        podcastManager.remove(id: podcast.id)
        
        // Then: Podcast should be gone
        XCTAssertEqual(podcastManager.all().count, 0)
        XCTAssertNil(podcastManager.find(id: podcast.id))
    }
    
    func testRemove_NonExistentPodcast() {
        // Given: Storage with one podcast
        podcastManager.add(samplePodcasts[0])
        let originalCount = podcastManager.all().count
        
        // When: Removing non-existent podcast
        podcastManager.remove(id: "non-existent")
        
        // Then: Storage should remain unchanged
        XCTAssertEqual(podcastManager.all().count, originalCount)
    }
    
    // MARK: - Collection Operations
    
    func testAll_EmptyStorage() {
        // Given: Empty storage
        
        // When: Getting all podcasts
        let all = podcastManager.all()
        
        // Then: Should return empty array
        XCTAssertTrue(all.isEmpty)
    }
    
    func testAll_MultiplePodcasts() {
        // Given: Multiple podcasts in storage
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Getting all podcasts
        let all = podcastManager.all()
        
        // Then: Should return all podcasts
        XCTAssertEqual(all.count, samplePodcasts.count)
        let allIds = Set(all.map { $0.id })
        let expectedIds = Set(samplePodcasts.map { $0.id })
        XCTAssertEqual(allIds, expectedIds)
    }
    
    // MARK: - Organization Filtering
    
    func testFindByFolder_DirectChildren() {
        // Given: Podcasts in different folders
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding podcasts in folder1
        let folder1Podcasts = podcastManager.findByFolder(folderId: "folder1")
        
        // Then: Should return only direct children
        XCTAssertEqual(folder1Podcasts.count, 2)
        let folder1Ids = Set(folder1Podcasts.map { $0.id })
        XCTAssertTrue(folder1Ids.contains("podcast1"))
        XCTAssertTrue(folder1Ids.contains("podcast3"))
    }
    
    func testFindByFolder_EmptyFolder() {
        // Given: Podcasts not in target folder
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding podcasts in empty folder
        let emptyFolderPodcasts = podcastManager.findByFolder(folderId: "empty-folder")
        
        // Then: Should return empty array
        XCTAssertTrue(emptyFolderPodcasts.isEmpty)
    }
    
    func testFindByFolderRecursive_WithHierarchy() throws {
        // Given: Folder hierarchy setup
        let parentFolder = Folder(id: "parent", name: "Parent", parentId: nil)
        let childFolder = Folder(id: "child", name: "Child", parentId: "parent")
        try folderManager.add(parentFolder)
        try folderManager.add(childFolder)
        
        // Podcasts in parent and child folders
        let parentPodcast = Podcast(
            id: "parent-podcast",
            title: "Parent Podcast",
            description: "In parent folder",
            feedURL: URL(string: "https://example.com/parent.xml")!,
            folderId: "parent"
        )
        let childPodcast = Podcast(
            id: "child-podcast", 
            title: "Child Podcast",
            description: "In child folder",
            feedURL: URL(string: "https://example.com/child.xml")!,
            folderId: "child"
        )
        
        podcastManager.add(parentPodcast)
        podcastManager.add(childPodcast)
        
        // When: Finding podcasts recursively in parent folder
        let recursivePodcasts = podcastManager.findByFolderRecursive(
            folderId: "parent", 
            folderManager: folderManager
        )
        
        // Then: Should return podcasts from parent and child folders
        XCTAssertEqual(recursivePodcasts.count, 2)
        let recursiveIds = Set(recursivePodcasts.map { $0.id })
        XCTAssertTrue(recursiveIds.contains("parent-podcast"))
        XCTAssertTrue(recursiveIds.contains("child-podcast"))
    }
    
    func testFindByTag_SingleTag() {
        // Given: Podcasts with various tags
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding podcasts with tag1
        let tag1Podcasts = podcastManager.findByTag(tagId: "tag1")
        
        // Then: Should return podcasts with that tag
        XCTAssertEqual(tag1Podcasts.count, 2)
        let tag1Ids = Set(tag1Podcasts.map { $0.id })
        XCTAssertTrue(tag1Ids.contains("podcast1"))
        XCTAssertTrue(tag1Ids.contains("podcast3"))
    }
    
    func testFindByTag_NonExistentTag() {
        // Given: Podcasts with various tags
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding podcasts with non-existent tag
        let nonExistentTagPodcasts = podcastManager.findByTag(tagId: "non-existent-tag")
        
        // Then: Should return empty array
        XCTAssertTrue(nonExistentTagPodcasts.isEmpty)
    }
    
    func testFindUnorganized_PodcastsWithoutFolderOrTags() {
        // Given: Mix of organized and unorganized podcasts
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding unorganized podcasts
        let unorganized = podcastManager.findUnorganized()
        
        // Then: Should return only podcast2 (no folder, no tags)
        XCTAssertEqual(unorganized.count, 1)
        XCTAssertEqual(unorganized.first?.id, "podcast2")
    }
    
    func testFindUnorganized_AllOrganized() {
        // Given: Only organized podcasts
        podcastManager.add(samplePodcasts[0]) // Has folder and tags
        podcastManager.add(samplePodcasts[2]) // Has folder and tags
        
        // When: Finding unorganized podcasts
        let unorganized = podcastManager.findUnorganized()
        
        // Then: Should return empty array
        XCTAssertTrue(unorganized.isEmpty)
    }
    
    // MARK: - Initialization & Edge Cases
    
    func testInitialization_WithInitialPodcasts() {
        // Given: Initial podcasts for manager
        let initialPodcasts = Array(samplePodcasts[0...1])
        
        // When: Creating manager with initial data
        let managerWithInitial = InMemoryPodcastManager(initial: initialPodcasts)
        
        // Then: Should contain initial podcasts
        XCTAssertEqual(managerWithInitial.all().count, 2)
        XCTAssertNotNil(managerWithInitial.find(id: initialPodcasts[0].id))
        XCTAssertNotNil(managerWithInitial.find(id: initialPodcasts[1].id))
    }
    
    func testInitialization_EmptyInitial() {
        // Given: Empty initial array
        let emptyInitial: [Podcast] = []
        
        // When: Creating manager with empty initial data
        let emptyManager = InMemoryPodcastManager(initial: emptyInitial)
        
        // Then: Should be empty
        XCTAssertTrue(emptyManager.all().isEmpty)
    }
    
    func testComplexScenario_MixedOperations() throws {
        // Given: Complex organizational structure
        let folder1 = Folder(id: "tech", name: "Technology", parentId: nil)
        let folder2 = Folder(id: "science", name: "Science", parentId: nil)
        try folderManager.add(folder1)
        try folderManager.add(folder2)
        
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Performing various operations
        let techPodcasts = podcastManager.findByFolder(folderId: "folder1")
        let taggedPodcasts = podcastManager.findByTag(tagId: "tag1")
        let unorganized = podcastManager.findUnorganized()
        
        // Update a podcast
        let updatedPodcast = Podcast(
            id: samplePodcasts[1].id,
            title: "Updated Science Today",
            description: samplePodcasts[1].description,
            artworkURL: samplePodcasts[1].artworkURL,
            feedURL: samplePodcasts[1].feedURL,
            folderId: "science",
            tagIds: ["science-tag"]
        )
        podcastManager.update(updatedPodcast)
        
        // Then: All operations should work correctly
        XCTAssertEqual(techPodcasts.count, 2)
        XCTAssertEqual(taggedPodcasts.count, 2)
        XCTAssertEqual(unorganized.count, 1)
        
        // After update, unorganized should be empty
        let newUnorganized = podcastManager.findUnorganized()
        XCTAssertTrue(newUnorganized.isEmpty)
        
        let updatedFound = podcastManager.find(id: samplePodcasts[1].id)
        XCTAssertEqual(updatedFound?.folderId, "science")
        XCTAssertEqual(updatedFound?.tagIds, ["science-tag"])
    }
    
    // MARK: - Thread Safety & Performance
    
    func testConcurrentAccess_ReadOperations() {
        // Given: Populated podcast manager
        samplePodcasts.forEach { podcastManager.add($0) }
        
        let expectation = XCTestExpectation(description: "Concurrent reads")
        expectation.expectedFulfillmentCount = 100
        
        // When: Multiple concurrent read operations
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let all = podcastManager.all()
            let first = podcastManager.find(id: samplePodcasts[0].id)
            let byFolder = podcastManager.findByFolder(folderId: "folder1")
            let byTag = podcastManager.findByTag(tagId: "tag1")
            let unorganized = podcastManager.findUnorganized()
            
            // Then: All operations should succeed
            XCTAssertEqual(all.count, 3)
            XCTAssertNotNil(first)
            XCTAssertEqual(byFolder.count, 2)
            XCTAssertEqual(byTag.count, 2)
            XCTAssertEqual(unorganized.count, 1)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Protocol Conformance Validation
    
    func testProtocolConformance_PodcastManaging() {
        // Given: Manager instance
        let manager: PodcastManaging = InMemoryPodcastManager()
        
        // When: Using through protocol interface
        let podcast = samplePodcasts[0]
        manager.add(podcast)
        let found = manager.find(id: podcast.id)
        
        // Then: Should work through protocol
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, podcast.id)
        XCTAssertEqual(manager.all().count, 1)
    }
}