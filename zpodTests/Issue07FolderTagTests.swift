import XCTest
@testable import zpod

final class Issue07FolderTagTests: XCTestCase {
  
  // MARK: - Folder Model Tests
  
  func testFolderInitialization() {
    // Given: Valid folder parameters
    let id = "folder1"
    let name = "Tech Podcasts"
    let parentId = "parent1"
    let dateCreated = Date()
    
    // When: Creating a folder
    let folder = Folder(id: id, name: name, parentId: parentId, dateCreated: dateCreated)
    
    // Then: All properties are set correctly
    XCTAssertEqual(folder.id, id)
    XCTAssertEqual(folder.name, name)
    XCTAssertEqual(folder.parentId, parentId)
    XCTAssertEqual(folder.dateCreated, dateCreated)
    XCTAssertFalse(folder.isRoot)
  }
  
  func testFolderRootFolder() {
    // Given: Folder without parent
    let folder = Folder(id: "root1", name: "Root Folder")
    
    // Then: Folder is marked as root
    XCTAssertTrue(folder.isRoot)
    XCTAssertNil(folder.parentId)
  }
  
  func testFolderCodable() throws {
    // Given: A folder
    let folder = Folder(id: "test1", name: "Test Folder", parentId: "parent1")
    
    // When: Encoding and decoding
    let data = try JSONEncoder().encode(folder)
    let decoded = try JSONDecoder().decode(Folder.self, from: data)
    
    // Then: Folder is unchanged
    XCTAssertEqual(folder, decoded)
  }
  
  // MARK: - Tag Model Tests
  
  func testTagInitialization() {
    // Given: Valid tag parameters
    let id = "tag1"
    let name = "Educational"
    let dateCreated = Date()
    
    // When: Creating a tag
    let tag = Tag(id: id, name: name, dateCreated: dateCreated)
    
    // Then: All properties are set correctly
    XCTAssertEqual(tag.id, id)
    XCTAssertEqual(tag.name, name)
    XCTAssertEqual(tag.dateCreated, dateCreated)
  }
  
  func testTagCodable() throws {
    // Given: A tag
    let tag = Tag(id: "test1", name: "Test Tag")
    
    // When: Encoding and decoding
    let data = try JSONEncoder().encode(tag)
    let decoded = try JSONDecoder().decode(Tag.self, from: data)
    
    // Then: Tag is unchanged
    XCTAssertEqual(tag, decoded)
  }
  
  // MARK: - Extended Podcast Model Tests
  
  func testPodcastWithOrganization() {
    // Given: Podcast with organization properties
    let podcast = Podcast(
      id: "podcast1",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed")!,
      folderId: "folder1",
      tagIds: ["tag1", "tag2"]
    )
    
    // Then: Organization properties are set
    XCTAssertEqual(podcast.folderId, "folder1")
    XCTAssertEqual(podcast.tagIds, ["tag1", "tag2"])
  }
  
  func testPodcastWithoutOrganization() {
    // Given: Podcast without organization
    let podcast = Podcast(
      id: "podcast1",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed")!
    )
    
    // Then: Organization properties have default values
    XCTAssertNil(podcast.folderId)
    XCTAssertTrue(podcast.tagIds.isEmpty)
  }
  
  func testPodcastCodableWithOrganization() throws {
    // Given: Podcast with organization (using fixed date to avoid floating-point precision issues)
    // 1692147600.0 represents August 16, 2023, 12:00:00 UTC
    let fixedDateTimestamp: TimeInterval = 1692147600.0
    let fixedDate = Date(timeIntervalSince1970: fixedDateTimestamp)
    let podcast = Podcast(
      id: "test1",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed")!,
      dateAdded: fixedDate,
      folderId: "folder1",
      tagIds: ["tag1", "tag2"]
    )
    
    // When: Encoding and decoding
    let data = try JSONEncoder().encode(podcast)
    let decoded = try JSONDecoder().decode(Podcast.self, from: data)
    
    // Then: Podcast is unchanged
    XCTAssertEqual(podcast, decoded)
  }
  
  func testPodcastBackwardCompatibility() throws {
    // Given: JSON without organization fields (simulating old data)
    let json = """
    {
      "id": "test1",
      "title": "Test Podcast",
      "feedURL": "https://example.com/feed",
      "categories": [],
      "episodes": [],
      "isSubscribed": false,
      "dateAdded": 1640995200.0
    }
    """
    
    // When: Decoding
    let data = json.data(using: .utf8)!
    let podcast = try JSONDecoder().decode(Podcast.self, from: data)
    
    // Then: Organization fields have default values
    XCTAssertNil(podcast.folderId)
    XCTAssertTrue(podcast.tagIds.isEmpty)
  }
  
  // MARK: - FolderManager Tests
  
  func testFolderManagerAddFolder() throws {
    // Given: Empty folder manager
    let manager = InMemoryFolderManager()
    let folder = Folder(id: "folder1", name: "Test Folder")
    
    // When: Adding folder
    try manager.add(folder)
    
    // Then: Folder is stored
    XCTAssertEqual(manager.find(id: "folder1"), folder)
    XCTAssertEqual(manager.all().count, 1)
  }
  
  func testFolderManagerPreventDuplicates() throws {
    // Given: Manager with existing folder
    let folder = Folder(id: "folder1", name: "Test Folder")
    let manager = InMemoryFolderManager(initial: [folder])
    
    // When: Adding same folder again
    try manager.add(folder)
    
    // Then: Only one folder exists
    XCTAssertEqual(manager.all().count, 1)
  }
  
  func testFolderManagerParentValidation() {
    // Given: Manager without parent folder
    let manager = InMemoryFolderManager()
    let child = Folder(id: "child1", name: "Child", parentId: "nonexistent")
    
    // When & Then: Adding child with non-existent parent throws error
    XCTAssertThrowsError(try manager.add(child)) { error in
      XCTAssertEqual(error as? FolderError, .parentNotFound("nonexistent"))
    }
  }
  
  func testFolderManagerCircularReferenceDetection() throws {
    // Given: Manager with parent folder
    let parent = Folder(id: "parent1", name: "Parent")
    let manager = InMemoryFolderManager(initial: [parent])
    
    // When: Creating child and trying to make parent child of child
    let child = Folder(id: "child1", name: "Child", parentId: "parent1")
    try manager.add(child)
    
    let updatedParent = Folder(id: "parent1", name: "Parent", parentId: "child1")
    
    // Then: Update throws circular reference error
    XCTAssertThrowsError(try manager.update(updatedParent)) { error in
      XCTAssertEqual(error as? FolderError, .circularReference("parent1"))
    }
  }
  
  func testFolderManagerGetChildren() throws {
    // Given: Hierarchical folder structure
    let root = Folder(id: "root", name: "Root")
    let child1 = Folder(id: "child1", name: "Child 1", parentId: "root")
    let child2 = Folder(id: "child2", name: "Child 2", parentId: "root")
    let grandchild = Folder(id: "grandchild", name: "Grandchild", parentId: "child1")
    
    let manager = InMemoryFolderManager(initial: [root, child1, child2, grandchild])
    
    // When: Getting children of root
    let children = manager.getChildren(of: "root")
    
    // Then: Only direct children are returned
    XCTAssertEqual(children.count, 2)
    XCTAssertTrue(children.contains(child1))
    XCTAssertTrue(children.contains(child2))
    XCTAssertFalse(children.contains(grandchild))
  }
  
  func testFolderManagerGetDescendants() throws {
    // Given: Hierarchical folder structure
    let root = Folder(id: "root", name: "Root")
    let child1 = Folder(id: "child1", name: "Child 1", parentId: "root")
    let child2 = Folder(id: "child2", name: "Child 2", parentId: "root")
    let grandchild = Folder(id: "grandchild", name: "Grandchild", parentId: "child1")
    
    let manager = InMemoryFolderManager(initial: [root, child1, child2, grandchild])
    
    // When: Getting descendants of root
    let descendants = manager.getDescendants(of: "root")
    
    // Then: All descendants are returned
    XCTAssertEqual(descendants.count, 3)
    XCTAssertTrue(descendants.contains(child1))
    XCTAssertTrue(descendants.contains(child2))
    XCTAssertTrue(descendants.contains(grandchild))
  }
  
  func testFolderManagerGetRootFolders() {
    // Given: Mixed folder structure
    let root1 = Folder(id: "root1", name: "Root 1")
    let root2 = Folder(id: "root2", name: "Root 2")
    let child = Folder(id: "child1", name: "Child", parentId: "root1")
    
    let manager = InMemoryFolderManager(initial: [root1, root2, child])
    
    // When: Getting root folders
    let roots = manager.getRootFolders()
    
    // Then: Only root folders are returned
    XCTAssertEqual(roots.count, 2)
    XCTAssertTrue(roots.contains(root1))
    XCTAssertTrue(roots.contains(root2))
    XCTAssertFalse(roots.contains(child))
  }
  
  func testFolderManagerRemoveWithChildren() throws {
    // Given: Folder with children
    let parent = Folder(id: "parent", name: "Parent")
    let child = Folder(id: "child", name: "Child", parentId: "parent")
    let manager = InMemoryFolderManager(initial: [parent, child])
    
    // When & Then: Removing parent with children throws error
    XCTAssertThrowsError(try manager.remove(id: "parent")) { error in
      XCTAssertEqual(error as? FolderError, .hasChildren("parent"))
    }
    
    // But removing child first should work
    try manager.remove(id: "child")
    try manager.remove(id: "parent")
    XCTAssertNil(manager.find(id: "parent"))
  }
  
  // MARK: - TagManager Tests
  
  func testTagManagerBasicOperations() {
    // Given: Empty tag manager
    let manager = InMemoryTagManager()
    let tag = Tag(id: "tag1", name: "Educational")
    
    // When: Adding tag
    manager.add(tag)
    
    // Then: Tag is stored and can be retrieved
    XCTAssertEqual(manager.find(id: "tag1"), tag)
    XCTAssertEqual(manager.all().count, 1)
    
    // When: Updating tag
    let updatedTag = Tag(id: "tag1", name: "Educational Updated")
    manager.update(updatedTag)
    
    // Then: Tag is updated
    XCTAssertEqual(manager.find(id: "tag1")?.name, "Educational Updated")
    
    // When: Removing tag
    manager.remove(id: "tag1")
    
    // Then: Tag is removed
    XCTAssertNil(manager.find(id: "tag1"))
    XCTAssertEqual(manager.all().count, 0)
  }
  
  func testTagManagerPreventDuplicates() {
    // Given: Manager with existing tag
    let tag = Tag(id: "tag1", name: "Educational")
    let manager = InMemoryTagManager(initial: [tag])
    
    // When: Adding same tag again
    manager.add(tag)
    
    // Then: Only one tag exists
    XCTAssertEqual(manager.all().count, 1)
  }
  
  // MARK: - PodcastManager Organization Filtering Tests
  
  func testPodcastManagerFindByFolder() {
    // Given: Podcasts in different folders
    let podcast1 = Podcast(id: "p1", title: "Podcast 1", feedURL: URL(string: "https://example.com/1")!, folderId: "folder1")
    let podcast2 = Podcast(id: "p2", title: "Podcast 2", feedURL: URL(string: "https://example.com/2")!, folderId: "folder1")
    let podcast3 = Podcast(id: "p3", title: "Podcast 3", feedURL: URL(string: "https://example.com/3")!, folderId: "folder2")
    
    let manager = InMemoryPodcastManager(initial: [podcast1, podcast2, podcast3])
    
    // When: Finding podcasts by folder
    let folder1Podcasts = manager.findByFolder(folderId: "folder1")
    
    // Then: Only podcasts in specified folder are returned
    XCTAssertEqual(folder1Podcasts.count, 2)
    XCTAssertTrue(folder1Podcasts.contains(podcast1))
    XCTAssertTrue(folder1Podcasts.contains(podcast2))
    XCTAssertFalse(folder1Podcasts.contains(podcast3))
  }
  
  func testPodcastManagerFindByFolderRecursive() {
    // Given: Hierarchical folder structure and podcasts
    let root = Folder(id: "root", name: "Root")
    let child = Folder(id: "child", name: "Child", parentId: "root")
    let folderManager = InMemoryFolderManager(initial: [root, child])
    
    let podcastInRoot = Podcast(id: "p1", title: "Podcast 1", feedURL: URL(string: "https://example.com/1")!, folderId: "root")
    let podcastInChild = Podcast(id: "p2", title: "Podcast 2", feedURL: URL(string: "https://example.com/2")!, folderId: "child")
    let podcastElsewhere = Podcast(id: "p3", title: "Podcast 3", feedURL: URL(string: "https://example.com/3")!, folderId: "other")
    
    let podcastManager = InMemoryPodcastManager(initial: [podcastInRoot, podcastInChild, podcastElsewhere])
    
    // When: Finding podcasts recursively
    let rootPodcasts = podcastManager.findByFolderRecursive(folderId: "root", folderManager: folderManager)
    
    // Then: Podcasts from root and all descendants are returned
    XCTAssertEqual(rootPodcasts.count, 2)
    XCTAssertTrue(rootPodcasts.contains(podcastInRoot))
    XCTAssertTrue(rootPodcasts.contains(podcastInChild))
    XCTAssertFalse(rootPodcasts.contains(podcastElsewhere))
  }
  
  func testPodcastManagerFindByTag() {
    // Given: Podcasts with different tags
    let podcast1 = Podcast(id: "p1", title: "Podcast 1", feedURL: URL(string: "https://example.com/1")!, tagIds: ["tech", "education"])
    let podcast2 = Podcast(id: "p2", title: "Podcast 2", feedURL: URL(string: "https://example.com/2")!, tagIds: ["tech"])
    let podcast3 = Podcast(id: "p3", title: "Podcast 3", feedURL: URL(string: "https://example.com/3")!, tagIds: ["entertainment"])
    
    let manager = InMemoryPodcastManager(initial: [podcast1, podcast2, podcast3])
    
    // When: Finding podcasts by tag
    let techPodcasts = manager.findByTag(tagId: "tech")
    let educationPodcasts = manager.findByTag(tagId: "education")
    
    // Then: Only podcasts with specified tag are returned
    XCTAssertEqual(techPodcasts.count, 2)
    XCTAssertTrue(techPodcasts.contains(podcast1))
    XCTAssertTrue(techPodcasts.contains(podcast2))
    
    XCTAssertEqual(educationPodcasts.count, 1)
    XCTAssertTrue(educationPodcasts.contains(podcast1))
  }
  
  func testPodcastManagerFindUnorganized() {
    // Given: Mix of organized and unorganized podcasts
    let organized1 = Podcast(id: "p1", title: "Podcast 1", feedURL: URL(string: "https://example.com/1")!, folderId: "folder1")
    let organized2 = Podcast(id: "p2", title: "Podcast 2", feedURL: URL(string: "https://example.com/2")!, tagIds: ["tech"])
    let unorganized1 = Podcast(id: "p3", title: "Podcast 3", feedURL: URL(string: "https://example.com/3")!)
    let unorganized2 = Podcast(id: "p4", title: "Podcast 4", feedURL: URL(string: "https://example.com/4")!)
    
    let manager = InMemoryPodcastManager(initial: [organized1, organized2, unorganized1, unorganized2])
    
    // When: Finding unorganized podcasts
    let unorganized = manager.findUnorganized()
    
    // Then: Only podcasts without folder or tags are returned
    XCTAssertEqual(unorganized.count, 2)
    XCTAssertTrue(unorganized.contains(unorganized1))
    XCTAssertTrue(unorganized.contains(unorganized2))
    XCTAssertFalse(unorganized.contains(organized1))
    XCTAssertFalse(unorganized.contains(organized2))
  }
  
  // MARK: - Integration Tests (Given/When/Then from Specs)
  
  func testOrganizingPodcastsIntoFolders() throws {
    // Given: User has multiple podcasts
    let podcast1 = Podcast(id: "p1", title: "Tech Talk", feedURL: URL(string: "https://example.com/1")!)
    let podcast2 = Podcast(id: "p2", title: "Science Hour", feedURL: URL(string: "https://example.com/2")!)
    
    let podcastManager = InMemoryPodcastManager(initial: [podcast1, podcast2])
    let folderManager = InMemoryFolderManager()
    
    // When: User creates folders
    let techFolder = Folder(id: "tech", name: "Technology")
    try folderManager.add(techFolder)
    
    // And: Assigns podcasts to folders
    let organizedPodcast1 = Podcast(
      id: podcast1.id,
      title: podcast1.title,
      feedURL: podcast1.feedURL,
      folderId: "tech"
    )
    podcastManager.update(organizedPodcast1)
    
    // Then: Podcasts can be viewed and managed by folder
    let techPodcasts = podcastManager.findByFolder(folderId: "tech")
    XCTAssertEqual(techPodcasts.count, 1)
    XCTAssertEqual(techPodcasts.first?.title, "Tech Talk")
    
    let unorganizedPodcasts = podcastManager.findUnorganized()
    XCTAssertEqual(unorganizedPodcasts.count, 1)
    XCTAssertEqual(unorganizedPodcasts.first?.title, "Science Hour")
  }
  
  func testApplyingCustomTagsForOrganization() {
    // Given: Multiple podcasts
    let podcast1 = Podcast(id: "p1", title: "Daily News", feedURL: URL(string: "https://example.com/1")!)
    let podcast2 = Podcast(id: "p2", title: "Comedy Hour", feedURL: URL(string: "https://example.com/2")!)
    
    let podcastManager = InMemoryPodcastManager(initial: [podcast1, podcast2])
    let tagManager = InMemoryTagManager()
    
    // When: User applies tags/groups
    let dailyTag = Tag(id: "daily", name: "Daily")
    let entertainmentTag = Tag(id: "entertainment", name: "Entertainment")
    tagManager.add(dailyTag)
    tagManager.add(entertainmentTag)
    
    let taggedPodcast1 = Podcast(
      id: podcast1.id,
      title: podcast1.title,
      feedURL: podcast1.feedURL,
      tagIds: ["daily"]
    )
    let taggedPodcast2 = Podcast(
      id: podcast2.id,
      title: podcast2.title,
      feedURL: podcast2.feedURL,
      tagIds: ["daily", "entertainment"]
    )
    
    podcastManager.update(taggedPodcast1)
    podcastManager.update(taggedPodcast2)
    
    // Then: Can filter/organize library
    let dailyPodcasts = podcastManager.findByTag(tagId: "daily")
    XCTAssertEqual(dailyPodcasts.count, 2)
    
    let entertainmentPodcasts = podcastManager.findByTag(tagId: "entertainment")
    XCTAssertEqual(entertainmentPodcasts.count, 1)
    XCTAssertEqual(entertainmentPodcasts.first?.title, "Comedy Hour")
  }
}
