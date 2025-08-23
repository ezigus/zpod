import XCTest
@testable import CoreModels
@testable import SharedUtilities
@testable import TestSupport
@testable import Persistence
@testable import SearchDomain
@testable import SettingsDomain

/// Integration tests demonstrating cross-package functionality
/// Tests the interaction between multiple packages in realistic workflows
final class CorePackageIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var searchIndex: SearchIndex!
    private var settingsManager: SettingsManager!
    private var userDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Given: Set up integration test environment with cross-package dependencies
        let suiteName = "integration-test-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        searchIndex = SearchIndex()
        settingsManager = SettingsManager(userDefaults: userDefaults)
    }
    
    override func tearDown() {
        // Clean up test data
        if let suiteName = userDefaults.userDefaults?.suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        
        podcastManager = nil
        folderManager = nil
        searchIndex = nil
        settingsManager = nil
        userDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Integration Test Cases
    
    func testSubscriptionWorkflow_CompleteFlow() async throws {
        // Given: A complete subscription workflow spanning multiple packages
        let testPodcast = Podcast(
            id: "integration-test-podcast",
            title: "Integration Test Podcast",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            description: "A podcast for testing cross-package integration"
        )
        
        // When: Adding podcast (CoreModels + TestSupport)
        try await podcastManager.addPodcast(testPodcast)
        
        // Then: Podcast should be stored and searchable
        let storedPodcasts = try await podcastManager.getAllPodcasts()
        XCTAssertEqual(storedPodcasts.count, 1)
        XCTAssertEqual(storedPodcasts.first?.id, testPodcast.id)
        
        // When: Indexing podcast for search (SearchDomain + CoreModels)
        await searchIndex.indexDocument(
            id: testPodcast.id,
            content: "\(testPodcast.title) \(testPodcast.description ?? "")"
        )
        
        // Then: Podcast should be findable through search
        let searchResults = await searchIndex.search(query: "Integration Test")
        XCTAssertFalse(searchResults.isEmpty)
        XCTAssertTrue(searchResults.contains(testPodcast.id))
    }
    
    func testOrganizationWorkflow_FoldersAndSettings() async throws {
        // Given: Organization workflow with folders and settings
        let categoryFolder = Folder(
            id: "tech-category",
            name: "Technology Podcasts",
            parentId: nil
        )
        
        let testPodcast = Podcast(
            id: "tech-podcast",
            title: "Tech Talk",
            feedURL: URL(string: "https://example.com/tech.xml")!,
            folderId: categoryFolder.id
        )
        
        // When: Creating folder structure (CoreModels + TestSupport)
        try folderManager.add(categoryFolder)
        try await podcastManager.addPodcast(testPodcast)
        
        // And: Setting up podcast-specific settings (SettingsDomain + CoreModels)
        let podcastSettings = PodcastPlaybackSettings(
            speed: 1.5,
            skipIntro: 30,
            skipOutro: 15,
            autoDownload: true
        )
        settingsManager.setPodcastSettings(podcastId: testPodcast.id, settings: podcastSettings)
        
        // Then: Complete organization should be maintained
        let folders = folderManager.getRootFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Technology Podcasts")
        
        let podcasts = try await podcastManager.getAllPodcasts()
        let organizedPodcast = podcasts.first { $0.id == testPodcast.id }
        XCTAssertEqual(organizedPodcast?.folderId, categoryFolder.id)
        
        let retrievedSettings = settingsManager.getPodcastSettings(podcastId: testPodcast.id)
        XCTAssertEqual(retrievedSettings.speed, 1.5)
        XCTAssertEqual(retrievedSettings.skipIntro, 30)
        XCTAssertTrue(retrievedSettings.autoDownload)
    }
    
    func testSearchAndOrganization_CrossPackageQueries() async throws {
        // Given: Multiple podcasts across different categories
        let techFolder = Folder(id: "tech", name: "Technology", parentId: nil)
        let newsFolder = Folder(id: "news", name: "News", parentId: nil)
        
        let techPodcast = Podcast(
            id: "swift-talk",
            title: "Swift Programming",
            feedURL: URL(string: "https://example.com/swift.xml")!,
            description: "Learn Swift programming language",
            folderId: techFolder.id
        )
        
        let newsPodcast = Podcast(
            id: "daily-news",
            title: "Daily Tech News",
            feedURL: URL(string: "https://example.com/news.xml")!,
            description: "Latest technology news and updates",
            folderId: newsFolder.id
        )
        
        // When: Setting up complete organization structure
        try folderManager.add(techFolder)
        try folderManager.add(newsFolder)
        try await podcastManager.addPodcast(techPodcast)
        try await podcastManager.addPodcast(newsPodcast)
        
        // And: Indexing all content for search
        await searchIndex.indexDocument(
            id: techPodcast.id,
            content: "\(techPodcast.title) \(techPodcast.description ?? "")"
        )
        await searchIndex.indexDocument(
            id: newsPodcast.id,
            content: "\(newsPodcast.title) \(newsPodcast.description ?? "")"
        )
        
        // Then: Should be able to search across organized content
        let swiftResults = await searchIndex.search(query: "Swift")
        XCTAssertTrue(swiftResults.contains(techPodcast.id))
        XCTAssertFalse(swiftResults.contains(newsPodcast.id))
        
        let techResults = await searchIndex.search(query: "technology")
        XCTAssertTrue(techResults.contains(newsPodcast.id))
        
        // And: Organization structure should be maintained
        let techFolderPodcasts = try await podcastManager.getAllPodcasts()
            .filter { $0.folderId == techFolder.id }
        XCTAssertEqual(techFolderPodcasts.count, 1)
        XCTAssertEqual(techFolderPodcasts.first?.title, "Swift Programming")
    }
    
    func testDataPersistence_SettingsAndState() async throws {
        // Given: Settings that should persist across app sessions
        let testPodcast = Podcast(
            id: "persistence-test",
            title: "Persistence Test Podcast",
            feedURL: URL(string: "https://example.com/persist.xml")!
        )
        
        // When: Setting up podcast with custom settings
        try await podcastManager.addPodcast(testPodcast)
        
        let customSettings = PodcastPlaybackSettings(
            speed: 2.0,
            skipIntro: 45,
            skipOutro: 30,
            autoDownload: false
        )
        settingsManager.setPodcastSettings(podcastId: testPodcast.id, settings: customSettings)
        
        // And: Simulating app restart by creating new managers with same UserDefaults
        let newSettingsManager = SettingsManager(userDefaults: userDefaults)
        
        // Then: Settings should persist
        let persistedSettings = newSettingsManager.getPodcastSettings(podcastId: testPodcast.id)
        XCTAssertEqual(persistedSettings.speed, 2.0)
        XCTAssertEqual(persistedSettings.skipIntro, 45)
        XCTAssertEqual(persistedSettings.skipOutro, 30)
        XCTAssertFalse(persistedSettings.autoDownload)
    }
    
    func testErrorHandling_CrossPackageResilience() async throws {
        // Given: Scenario that might cause errors across packages
        let invalidFolder = Folder(id: "", name: "", parentId: "non-existent")
        
        // When: Attempting invalid operations
        // Then: Should handle errors gracefully without crashing
        XCTAssertThrowsError(try folderManager.add(invalidFolder)) { error in
            XCTAssertTrue(error is FolderManager.Error)
        }
        
        // And: Valid operations should still work after error
        let validFolder = Folder(id: "valid", name: "Valid Folder", parentId: nil)
        XCTAssertNoThrow(try folderManager.add(validFolder))
        
        let folders = folderManager.getRootFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Valid Folder")
    }
    
    func testConcurrentOperations_ThreadSafety() async throws {
        // Given: Multiple concurrent operations across packages
        let podcastCount = 10
        let podcasts = (0..<podcastCount).map { index in
            Podcast(
                id: "concurrent-\(index)",
                title: "Concurrent Podcast \(index)",
                feedURL: URL(string: "https://example.com/concurrent\(index).xml")!
            )
        }
        
        // When: Adding podcasts concurrently
        await withTaskGroup(of: Void.self) { group in
            for podcast in podcasts {
                group.addTask {
                    try? await self.podcastManager.addPodcast(podcast)
                    await self.searchIndex.indexDocument(
                        id: podcast.id,
                        content: podcast.title
                    )
                }
            }
        }
        
        // Then: All operations should complete successfully
        let storedPodcasts = try await podcastManager.getAllPodcasts()
        XCTAssertEqual(storedPodcasts.count, podcastCount)
        
        // And: Search should find all indexed podcasts
        let searchResults = await searchIndex.search(query: "Concurrent")
        XCTAssertEqual(searchResults.count, podcastCount)
    }
}

// MARK: - Helper Extensions for Integration Testing

private extension UserDefaults {
    var userDefaults: UserDefaults? { self }
}