import XCTest
@testable import zpodLib
@testable import TestSupport

/// Simple unit tests for main app functionality
final class SimpleAppTests: XCTestCase {
    
    func testBasicPodcastManager() {
        // Given: In-memory podcast manager
        let manager = InMemoryPodcastManager()
        
        // When: Adding a podcast
        let podcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            description: "A test podcast",
            feedURL: URL(string: "https://example.com/test.xml")!
        )
        manager.add(podcast)
        
        // Then: Should find the podcast
        let found = manager.find(id: "test-podcast")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Test Podcast")
    }
    
    func testBasicFolderManager() {
        // Given: In-memory folder manager
        let manager = InMemoryFolderManager()
        
        // When: Adding a folder
        let folder = Folder(id: "test-folder", name: "Test Folder", parentId: nil)
        manager.add(folder)
        
        // Then: Should find the folder
        let found = manager.find(id: "test-folder")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Test Folder")
    }
    
    func testBasicSettingsManager() async {
        // Given: Settings manager with user defaults
        let userDefaults = UserDefaults(suiteName: "test-settings")!
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        // When: Updating download settings
        let newSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .keepLatest(10),
            defaultUpdateFrequency: .daily
        )
        await manager.updateGlobalDownloadSettings(newSettings)
        
        // Then: Settings should be updated
        XCTAssertTrue(manager.globalDownloadSettings.autoDownloadEnabled)
        XCTAssertFalse(manager.globalDownloadSettings.wifiOnly)
        XCTAssertEqual(manager.globalDownloadSettings.maxConcurrentDownloads, 5)
        
        // Clean up
        userDefaults.removePersistentDomain(forName: "test-settings")
    }
    
    func testBasicDownloadQueueManager() {
        // Given: Download queue manager
        let manager = DownloadQueueManager()
        
        // When: Adding download task
        let downloadTask = DownloadTask(
            id: "test-download",
            episodeId: "test-episode",
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            fileSize: 50_000_000,
            priority: .high
        )
        manager.enqueue(downloadTask)
        
        // Then: Should be in queue
        let queuedTasks = manager.getQueuedTasks()
        XCTAssertEqual(queuedTasks.count, 1)
        XCTAssertEqual(queuedTasks.first?.id, "test-download")
    }
}