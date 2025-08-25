import XCTest
@testable import CoreModels
@testable import TestSupport
@testable import SearchDomain

/// Simplified integration tests demonstrating cross-package functionality
final class SimpleCoreIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: TestSupport.InMemoryFolderManager!
    private var searchIndex: SearchIndex!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()
        folderManager = TestSupport.InMemoryFolderManager()
        searchIndex = SearchIndex()
    }
    
    // MARK: - Cross-Package Integration Tests
    
    func testBasicPodcastAndFolderIntegration() throws {
        // Given: Podcast and folder management integration
        let testFolder = Folder(
            id: "test-folder",
            name: "Test Folder",
            parentId: nil
        )
        
        let testPodcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            description: "A podcast for testing",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            folderId: testFolder.id
        )
        
        // When: Adding folder and podcast
        try folderManager.add(testFolder)
        podcastManager.add(testPodcast)
        
        // Then: Should be properly organized
        let folderPodcasts = podcastManager.findByFolder(folderId: testFolder.id)
        XCTAssertEqual(folderPodcasts.count, 1)
        XCTAssertEqual(folderPodcasts.first?.title, "Test Podcast")
        
        let allFolders = folderManager.all()
        XCTAssertEqual(allFolders.count, 1)
        XCTAssertEqual(allFolders.first?.name, "Test Folder")
    }
    
    func testSearchIndexIntegration() throws {
        // Given: Podcast for search integration
        let testPodcast = Podcast(
            id: "searchable-podcast",
            title: "Swift Programming Guide",
            description: "Learn Swift programming",
            feedURL: URL(string: "https://example.com/swift.xml")!
        )
        
        // When: Adding to manager and search index
        podcastManager.add(testPodcast)
        
        let searchableDoc = SearchableDocument(
            id: testPodcast.id,
            type: .podcast,
            fields: [
                .title: testPodcast.title,
                .description: testPodcast.description ?? ""
            ],
            sourceObject: testPodcast
        )
        searchIndex.addDocument(searchableDoc)
        
        // Then: Should be searchable
        let swiftResults = searchIndex.findDocuments(for: "Swift")
        XCTAssertFalse(swiftResults.isEmpty)
        XCTAssertTrue(swiftResults.contains { $0.id == testPodcast.id })
        
        let programmingResults = searchIndex.findDocuments(for: "programming")
        XCTAssertFalse(programmingResults.isEmpty)
        XCTAssertTrue(programmingResults.contains { $0.id == testPodcast.id })
    }
    
    func testComplexOrganizationStructure() throws {
        // Given: Complex folder hierarchy with multiple podcasts
        let rootFolder = Folder(id: "root", name: "Root", parentId: nil)
        let techFolder = Folder(id: "tech", name: "Technology", parentId: "root")
        let swiftFolder = Folder(id: "swift", name: "Swift", parentId: "tech")
        
        try folderManager.add(rootFolder)
        try folderManager.add(techFolder)
        try folderManager.add(swiftFolder)
        
        let podcast1 = Podcast(
            id: "podcast1",
            title: "Swift Weekly",
            description: "Swift news",
            feedURL: URL(string: "https://example.com/swift-weekly.xml")!,
            folderId: "swift"
        )
        
        let podcast2 = Podcast(
            id: "podcast2",
            title: "Tech Daily",
            description: "Daily tech news",
            feedURL: URL(string: "https://example.com/tech-daily.xml")!,
            folderId: "tech"
        )
        
        podcastManager.add(podcast1)
        podcastManager.add(podcast2)
        
        // When: Querying folder structure
        let rootChildren = folderManager.getChildren(of: "root")
        let techDescendants = folderManager.getDescendants(of: "tech")
        let swiftPodcasts = podcastManager.findByFolder(folderId: "swift")
        let techPodcastsRecursive = podcastManager.findByFolderRecursive(folderId: "tech", folderManager: folderManager)
        
        // Then: Structure should be maintained
        XCTAssertEqual(rootChildren.count, 1)
        XCTAssertEqual(rootChildren.first?.name, "Technology")
        
        XCTAssertEqual(techDescendants.count, 1)
        XCTAssertEqual(techDescendants.first?.name, "Swift")
        
        XCTAssertEqual(swiftPodcasts.count, 1)
        XCTAssertEqual(swiftPodcasts.first?.title, "Swift Weekly")
        
        XCTAssertEqual(techPodcastsRecursive.count, 2) // Both tech-level and swift-level podcasts
    }
}