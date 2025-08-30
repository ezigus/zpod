import XCTest
import TestSupport
import SearchDomain
@testable import zpodLib

/// Tests for content organization functionality including folders and tags
///
/// **Specifications Covered**: `spec/discovery.md` - Organization sections
/// - Folder hierarchy management for podcast organization
/// - Tag assignment and filtering for categorization  
/// - Podcast categorization and search within organized content
/// - Cross-organization search and filtering capabilities
final class ContentOrganizationTests: XCTestCase {
  
  // MARK: - Folder Model Tests
  // Covers: Folder-based organization from discovery spec
  
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
  // Covers: Tag-based categorization from discovery spec
  
  func testTagInitialization() {
    // Given: Valid tag parameters
    let id = "tag1"
    let name = "Technology"
    let color = "#FF5733"
    
    // When: Creating a tag
    let tag = Tag(id: id, name: name, color: color)
    
    // Then: All properties are set correctly
    XCTAssertEqual(tag.id, id)
    XCTAssertEqual(tag.name, name)
    XCTAssertEqual(tag.color, color)
  }
  
  func testTagDefaultColor() {
    // Given: Tag without specified color
    let tag = Tag(id: "tag1", name: "Technology")
    
    // Then: Default color is applied
    XCTAssertFalse(tag.color.isEmpty)
    XCTAssertTrue(tag.color.hasPrefix("#"))
  }
  
  func testTagCodable() throws {
    // Given: A tag
    let tag = Tag(id: "test1", name: "Test Tag", color: "#FF5733")
    
    // When: Encoding and decoding
    let data = try JSONEncoder().encode(tag)
    let decoded = try JSONDecoder().decode(Tag.self, from: data)
    
    // Then: Tag is unchanged
    XCTAssertEqual(tag, decoded)
  }
  
  // MARK: - Podcast Organization Tests
  // Covers: Podcast categorization from discovery spec
  
  func testPodcastOrganizationInitialization() {
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
  
  func testPodcastWithFolderAndTags() {
    // Given: Podcast with organization
    let podcast = Podcast(
      id: "podcast1",
      title: "Organized Podcast",
      feedURL: URL(string: "https://example.com/feed")!,
      folderId: "tech-folder",
      tagIds: ["tech", "news"]
    )
    
    // Then: Organization properties are set correctly
    XCTAssertEqual(podcast.folderId, "tech-folder")
    XCTAssertEqual(podcast.tagIds, ["tech", "news"])
  }
  
  func testPodcastCodableWithOrganization() throws {
    // Given: Podcast with organization (using fixed date to avoid floating-point precision issues)
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
  
  // MARK: - Folder Manager Tests
  // Covers: Folder hierarchy management from discovery spec
  
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
      XCTAssertEqual(error as? TestSupportError, .invalidParent("Parent folder 'nonexistent' does not exist"))
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
    
    // Then: Should detect circular reference
    XCTAssertThrowsError(try manager.update(updatedParent))
  }
  
  func testFolderManagerHierarchyNavigation() throws {
    // Given: Folder hierarchy
    let root = Folder(id: "root", name: "Root")
    let tech = Folder(id: "tech", name: "Technology", parentId: "root")
    let swift = Folder(id: "swift", name: "Swift", parentId: "tech")
    
    let manager = InMemoryFolderManager()
    try manager.add(root)
    try manager.add(tech)
    try manager.add(swift)
    
    // When: Navigating hierarchy
    let rootChildren = manager.getChildren(of: "root")
    let techChildren = manager.getChildren(of: "tech")
    let techDescendants = manager.getDescendants(of: "tech")
    
    // Then: Hierarchy should be correctly navigable
    XCTAssertEqual(rootChildren.count, 1)
    XCTAssertEqual(rootChildren.first?.name, "Technology")
    
    XCTAssertEqual(techChildren.count, 1)
    XCTAssertEqual(techChildren.first?.name, "Swift")
    
    XCTAssertEqual(techDescendants.count, 1)
    XCTAssertEqual(techDescendants.first?.name, "Swift")
  }
  
  // MARK: - Tag Manager Tests
  // Covers: Tag management from discovery spec
  
  func testTagManagerBasicOperations() throws {
    // Given: Empty tag manager
    let manager = InMemoryTagManager()
    let tag = Tag(id: "tag1", name: "Technology", color: "#FF5733")
    
    // When: Adding tag
    try manager.add(tag)
    
    // Then: Tag is stored
    XCTAssertEqual(manager.find(id: "tag1"), tag)
    XCTAssertEqual(manager.all().count, 1)
  }
  
  func testTagManagerUpdate() throws {
    // Given: Manager with existing tag
    let originalTag = Tag(id: "tag1", name: "Tech", color: "#FF5733")
    let manager = InMemoryTagManager(initial: [originalTag])
    
    // When: Updating tag
    let updatedTag = Tag(id: "tag1", name: "Technology", color: "#00FF00")
    try manager.update(updatedTag)
    
    // Then: Tag is updated
    let found = manager.find(id: "tag1")
    XCTAssertEqual(found?.name, "Technology")
    XCTAssertEqual(found?.color, "#00FF00")
  }
  
  func testTagManagerRemove() throws {
    // Given: Manager with existing tag
    let tag = Tag(id: "tag1", name: "Technology", color: "#FF5733")
    let manager = InMemoryTagManager(initial: [tag])
    
    // When: Removing tag
    try manager.remove(id: "tag1")
    
    // Then: Tag is removed
    XCTAssertNil(manager.find(id: "tag1"))
    XCTAssertTrue(manager.all().isEmpty)
  }
  
  // MARK: - Podcast Organization Integration Tests
  // Covers: Cross-organization search and filtering from discovery spec
  
  func testPodcastFolderOrganization() throws {
    // Given: Folder hierarchy and podcasts
    let rootFolder = Folder(id: "root", name: "Root")
    let techFolder = Folder(id: "tech", name: "Technology", parentId: "root")
    let swiftFolder = Folder(id: "swift", name: "Swift", parentId: "tech")
    
    let folderManager = InMemoryFolderManager()
    try folderManager.add(rootFolder)
    try folderManager.add(techFolder)
    try folderManager.add(swiftFolder)
    
    let podcastManager = InMemoryPodcastManager()
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Swift Weekly",
      feedURL: URL(string: "https://example.com/swift-weekly.xml")!,
      folderId: "swift"
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Tech Daily",
      feedURL: URL(string: "https://example.com/tech-daily.xml")!,
      folderId: "tech"
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    
    // When: Querying folder organization
    let swiftPodcasts = podcastManager.findByFolder(folderId: "swift")
    let techPodcastsRecursive = podcastManager.findByFolderRecursive(folderId: "tech", folderManager: folderManager)
    
    // Then: Organization should work correctly
    XCTAssertEqual(swiftPodcasts.count, 1)
    XCTAssertEqual(swiftPodcasts.first?.title, "Swift Weekly")
    
    XCTAssertEqual(techPodcastsRecursive.count, 2) // Both tech-level and swift-level podcasts
  }
  
  func testPodcastTagOrganization() {
    // Given: Podcasts with tags
    let podcastManager = InMemoryPodcastManager()
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Swift News",
      feedURL: URL(string: "https://example.com/swift.xml")!,
      tagIds: ["swift", "programming"]
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "iOS Development",
      feedURL: URL(string: "https://example.com/ios.xml")!,
      tagIds: ["ios", "programming"]
    )
    
    let podcast3 = Podcast(
      id: "podcast3",
      title: "Music Review",
      feedURL: URL(string: "https://example.com/music.xml")!,
      tagIds: ["music", "entertainment"]
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    podcastManager.add(podcast3)
    
    // When: Querying by tags
    let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
    let swiftPodcasts = podcastManager.findByTag(tagId: "swift")
    let entertainmentPodcasts = podcastManager.findByTag(tagId: "entertainment")
    
    // Then: Tag filtering should work correctly
    XCTAssertEqual(programmingPodcasts.count, 2)
    XCTAssertTrue(programmingPodcasts.contains { $0.title == "Swift News" })
    XCTAssertTrue(programmingPodcasts.contains { $0.title == "iOS Development" })
    
    XCTAssertEqual(swiftPodcasts.count, 1)
    XCTAssertEqual(swiftPodcasts.first?.title, "Swift News")
    
    XCTAssertEqual(entertainmentPodcasts.count, 1)
    XCTAssertEqual(entertainmentPodcasts.first?.title, "Music Review")
  }
  
  func testPodcastCombinedOrganization() throws {
    // Given: Podcasts with both folders and tags
    let folderManager = InMemoryFolderManager()
    let techFolder = Folder(id: "tech", name: "Technology")
    try folderManager.add(techFolder)
    
    let podcastManager = InMemoryPodcastManager()
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Swift & iOS",
      feedURL: URL(string: "https://example.com/swift-ios.xml")!,
      folderId: "tech",
      tagIds: ["swift", "ios"]
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Web Development",
      feedURL: URL(string: "https://example.com/web.xml")!,
      folderId: "tech",
      tagIds: ["javascript", "web"]
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    
    // When: Querying with combined criteria
    let techPodcasts = podcastManager.findByFolder(folderId: "tech")
    let swiftPodcasts = podcastManager.findByTag(tagId: "swift")
    let techSwiftPodcasts = podcastManager.findByFolderAndTag(folderId: "tech", tagId: "swift")
    
    // Then: Combined organization should work correctly
    XCTAssertEqual(techPodcasts.count, 2)
    XCTAssertEqual(swiftPodcasts.count, 1)
    XCTAssertEqual(techSwiftPodcasts.count, 1)
    XCTAssertEqual(techSwiftPodcasts.first?.title, "Swift & iOS")
  }
  
  // MARK: - Search Integration Tests
  // Covers: Search within organized content from discovery spec
  
  func testSearchWithinFolders() throws {
    // Given: Organized content with search index
    let folderManager = InMemoryFolderManager()
    let techFolder = Folder(id: "tech", name: "Technology")
    try folderManager.add(techFolder)
    
    let podcastManager = InMemoryPodcastManager()
    let searchIndex = SearchIndex()
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Swift Programming Guide",
      description: "Learn Swift programming",
      feedURL: URL(string: "https://example.com/swift.xml")!,
      folderId: "tech"
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Swift Music Review",
      description: "Reviews of Taylor Swift albums",
      feedURL: URL(string: "https://example.com/music.xml")!
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    searchIndex.indexPodcast(podcast1)
    searchIndex.indexPodcast(podcast2)
    
    // When: Searching within a specific folder
    let allSwiftResults = searchIndex.searchPodcasts(query: "Swift", folderId: nil)
    let techSwiftResults = searchIndex.searchPodcasts(query: "Swift", folderId: "tech")
    
    // Then: Folder-scoped search should work correctly
    XCTAssertEqual(allSwiftResults.count, 2)
    XCTAssertEqual(techSwiftResults.count, 1)
    XCTAssertEqual(techSwiftResults.first?.title, "Swift Programming Guide")
  }
  
  func testSearchWithTags() {
    // Given: Podcasts with tags and search index
    let podcastManager = InMemoryPodcastManager()
    let searchIndex = SearchIndex()
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "iOS Development Tips",
      description: "Tips for iOS developers",
      feedURL: URL(string: "https://example.com/ios.xml")!,
      tagIds: ["ios", "development"]
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Android Development",
      description: "Android programming guide",
      feedURL: URL(string: "https://example.com/android.xml")!,
      tagIds: ["android", "development"]
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    searchIndex.indexPodcast(podcast1)
    searchIndex.indexPodcast(podcast2)
    
    // When: Searching by tag
    let developmentResults = searchIndex.searchPodcasts(query: "development", tagId: "development")
    let iosResults = searchIndex.searchPodcasts(query: "development", tagId: "ios")
    
    // Then: Tag-scoped search should work correctly
    XCTAssertEqual(developmentResults.count, 2)
    XCTAssertEqual(iosResults.count, 1)
    XCTAssertEqual(iosResults.first?.title, "iOS Development Tips")
  }
  
  // MARK: - Acceptance Criteria Tests
  // Covers: Complete organization workflows from discovery specification
  
  func testAcceptanceCriteria_FolderHierarchyManagement() throws {
    // Given: User wants to organize podcasts in folder hierarchy
    let folderManager = InMemoryFolderManager()
    
    // When: Creating folder hierarchy
    let root = Folder(id: "root", name: "All Podcasts")
    let tech = Folder(id: "tech", name: "Technology", parentId: "root")
    let swift = Folder(id: "swift", name: "Swift", parentId: "tech")
    let ios = Folder(id: "ios", name: "iOS", parentId: "tech")
    
    try folderManager.add(root)
    try folderManager.add(tech)
    try folderManager.add(swift)
    try folderManager.add(ios)
    
    // Then: Hierarchy should be properly established
    let techChildren = folderManager.getChildren(of: "tech")
    let rootDescendants = folderManager.getDescendants(of: "root")
    
    XCTAssertEqual(techChildren.count, 2)
    XCTAssertTrue(techChildren.contains { $0.name == "Swift" })
    XCTAssertTrue(techChildren.contains { $0.name == "iOS" })
    
    XCTAssertEqual(rootDescendants.count, 3) // tech, swift, ios
  }
  
  func testAcceptanceCriteria_TagBasedCategorization() {
    // Given: User wants to categorize podcasts with tags
    let tagManager = InMemoryTagManager()
    let podcastManager = InMemoryPodcastManager()
    
    // When: Creating tags and organizing podcasts
    let programmingTag = Tag(id: "programming", name: "Programming", color: "#007ACC")
    let entertainmentTag = Tag(id: "entertainment", name: "Entertainment", color: "#FF6B6B")
    
    try? tagManager.add(programmingTag)
    try? tagManager.add(entertainmentTag)
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Code Talk",
      feedURL: URL(string: "https://example.com/code.xml")!,
      tagIds: ["programming"]
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Comedy Hour",
      feedURL: URL(string: "https://example.com/comedy.xml")!,
      tagIds: ["entertainment"]
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    
    // Then: Podcasts should be categorized by tags
    let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
    let entertainmentPodcasts = podcastManager.findByTag(tagId: "entertainment")
    
    XCTAssertEqual(programmingPodcasts.count, 1)
    XCTAssertEqual(programmingPodcasts.first?.title, "Code Talk")
    
    XCTAssertEqual(entertainmentPodcasts.count, 1)
    XCTAssertEqual(entertainmentPodcasts.first?.title, "Comedy Hour")
  }
  
  func testAcceptanceCriteria_CrossOrganizationSearch() throws {
    // Given: User wants to search across organized content
    let folderManager = InMemoryFolderManager()
    let podcastManager = InMemoryPodcastManager()
    let searchIndex = SearchIndex()
    
    // Create organization structure
    let techFolder = Folder(id: "tech", name: "Technology")
    try folderManager.add(techFolder)
    
    let podcast1 = Podcast(
      id: "podcast1",
      title: "Swift Programming",
      description: "Advanced Swift techniques",
      feedURL: URL(string: "https://example.com/swift.xml")!,
      folderId: "tech",
      tagIds: ["swift", "programming"]
    )
    
    let podcast2 = Podcast(
      id: "podcast2",
      title: "Python Programming",
      description: "Python development guide",
      feedURL: URL(string: "https://example.com/python.xml")!,
      tagIds: ["python", "programming"]
    )
    
    podcastManager.add(podcast1)
    podcastManager.add(podcast2)
    searchIndex.indexPodcast(podcast1)
    searchIndex.indexPodcast(podcast2)
    
    // When: Searching across different organization dimensions
    let allProgrammingResults = searchIndex.searchPodcasts(query: "programming")
    let techProgrammingResults = searchIndex.searchPodcasts(query: "programming", folderId: "tech")
    let swiftTagResults = searchIndex.searchPodcasts(query: "programming", tagId: "swift")
    
    // Then: Search should work across all organization methods
    XCTAssertEqual(allProgrammingResults.count, 2)
    XCTAssertEqual(techProgrammingResults.count, 1)
    XCTAssertEqual(swiftTagResults.count, 1)
    XCTAssertEqual(swiftTagResults.first?.title, "Swift Programming")
  }
}

// MARK: - Test Support Extensions
extension InMemoryPodcastManager {
  func findByFolderRecursive(folderId: String, folderManager: InMemoryFolderManager) -> [Podcast] {
    let directPodcasts = findByFolder(folderId: folderId)
    let childFolders = folderManager.getDescendants(of: folderId)
    let childPodcasts = childFolders.flatMap { folder in
      findByFolder(folderId: folder.id)
    }
    return directPodcasts + childPodcasts
  }
  
  func findByFolderAndTag(folderId: String, tagId: String) -> [Podcast] {
    return all().filter { podcast in
      podcast.folderId == folderId && podcast.tagIds.contains(tagId)
    }
  }
}

extension SearchIndex {
  func searchPodcasts(query: String, folderId: String? = nil) -> [Podcast] {
    // Basic search implementation for testing
    // In real implementation, this would use proper search indexing
    let allResults = searchPodcasts(query: query)
    
    if let folderId = folderId {
      return allResults.filter { $0.folderId == folderId }
    }
    
    return allResults
  }
  
  func searchPodcasts(query: String, tagId: String? = nil) -> [Podcast] {
    // Basic search implementation for testing
    let allResults = searchPodcasts(query: query)
    
    if let tagId = tagId {
      return allResults.filter { $0.tagIds.contains(tagId) }
    }
    
    return allResults
  }
}