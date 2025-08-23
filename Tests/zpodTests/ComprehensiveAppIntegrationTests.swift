import XCTest
@testable import zpodLib
@testable import TestSupport

/// Comprehensive integration tests demonstrating end-to-end workflows across all package boundaries  
final class ComprehensiveAppIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var playlistManager: InMemoryPlaylistManager!
    private var searchIndex: SearchIndex!
    private var settingsManager: SettingsManager!
    private var userDefaults: UserDefaults!
    private var downloadQueueManager: DownloadQueueManager!
    private var subscriptionService: SubscriptionService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Given: Complete application stack integration test environment
        let suiteName = "integration-test-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        
        // Initialize all managers and services
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        playlistManager = InMemoryPlaylistManager()
        searchIndex = SearchIndex()
        settingsManager = SettingsManager(userDefaults: userDefaults)
        downloadQueueManager = DownloadQueueManager()
        subscriptionService = SubscriptionService()
    }
    
    override func tearDown() {
        // Clean up test data
        if let suiteName = userDefaults.suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        
        podcastManager = nil
        folderManager = nil
        playlistManager = nil
        searchIndex = nil
        settingsManager = nil
        userDefaults = nil
        downloadQueueManager = nil
        subscriptionService = nil
        
        super.tearDown()
    }
    
    // MARK: - End-to-End User Journey Tests
    
    func testCompleteUserJourney_SubscriptionToPlaylist() {
        // Given: New user starting with empty library
        XCTAssertTrue(podcastManager.all().isEmpty)
        XCTAssertTrue(folderManager.getAll().isEmpty)
        
        // STEP 1: User creates organization structure
        // When: Creating folders for organization
        let techFolder = Folder(id: "tech", name: "Technology", parentId: nil)
        let scienceFolder = Folder(id: "science", name: "Science", parentId: nil)
        let subFolder = Folder(id: "ai-tech", name: "AI & ML", parentId: "tech")
        
        folderManager.add(techFolder)
        folderManager.add(scienceFolder)
        folderManager.add(subFolder)
        
        // Then: Folder hierarchy should be established
        XCTAssertEqual(folderManager.getAll().count, 3)
        XCTAssertEqual(folderManager.getChildren(of: "tech").count, 1)
        XCTAssertEqual(folderManager.getChildren(of: "tech").first?.name, "AI & ML")
        
        // STEP 2: User subscribes to podcasts and organizes them
        // When: Adding podcasts to organized folders
        let techPodcast = Podcast(
            id: "tech-podcast",
            title: "Tech News Daily",
            description: "Daily technology news and analysis",
            feedURL: URL(string: "https://example.com/tech-news.xml")!,
            imageURL: URL(string: "https://example.com/tech-news.jpg"),
            folderId: "tech",
            tagIds: ["news", "technology"]
        )
        
        let aiPodcast = Podcast(
            id: "ai-podcast", 
            title: "AI Insights",
            description: "Artificial Intelligence and Machine Learning discussions",
            feedURL: URL(string: "https://example.com/ai-insights.xml")!,
            imageURL: URL(string: "https://example.com/ai-insights.jpg"),
            folderId: "ai-tech",
            tagIds: ["ai", "machine-learning", "technology"]
        )
        
        let sciencePodcast = Podcast(
            id: "science-podcast",
            title: "Science Weekly",
            description: "Weekly roundup of scientific discoveries", 
            feedURL: URL(string: "https://example.com/science-weekly.xml")!,
            imageURL: URL(string: "https://example.com/science-weekly.jpg"),
            folderId: "science",
            tagIds: ["science", "research"]
        )
        
        podcastManager.add(techPodcast)
        podcastManager.add(aiPodcast)
        podcastManager.add(sciencePodcast)
        
        // Then: Podcasts should be organized correctly
        XCTAssertEqual(podcastManager.all().count, 3)
        XCTAssertEqual(podcastManager.findByFolder(folderId: "tech").count, 1)
        XCTAssertEqual(podcastManager.findByFolder(folderId: "ai-tech").count, 1)
        XCTAssertEqual(podcastManager.findByFolder(folderId: "science").count, 1)
        
        // Test recursive folder search
        let allTechPodcasts = podcastManager.findByFolderRecursive(folderId: "tech", folderManager: folderManager)
        XCTAssertEqual(allTechPodcasts.count, 2) // tech-podcast + ai-podcast
        
        // STEP 3: User creates episodes and manages downloads
        // When: Adding episodes for the podcasts
        let techEpisode1 = Episode(
            id: "tech-ep1",
            title: "Swift 6 Concurrency Updates",
            description: "Latest updates in Swift 6 concurrency model",
            mediaURL: URL(string: "https://example.com/tech-ep1.mp3")!,
            duration: 2400, // 40 minutes
            chapters: [
                Chapter(id: "tech-ch1", title: "Introduction", startTime: 0),
                Chapter(id: "tech-ch2", title: "Concurrency Changes", startTime: 300),
                Chapter(id: "tech-ch3", title: "Migration Guide", startTime: 1800)
            ],
            podcastId: "tech-podcast"
        )
        
        let techEpisode2 = Episode(
            id: "tech-ep2",
            title: "iOS 18 Features Overview",
            description: "Comprehensive look at new iOS 18 features",
            mediaURL: URL(string: "https://example.com/tech-ep2.mp3")!,
            duration: 3000, // 50 minutes
            podcastId: "tech-podcast"
        )
        
        let aiEpisode1 = Episode(
            id: "ai-ep1",
            title: "Large Language Models in 2024",
            description: "State of LLMs and future developments",
            mediaURL: URL(string: "https://example.com/ai-ep1.mp3")!,
            duration: 3600, // 60 minutes
            podcastId: "ai-podcast"
        )
        
        // STEP 4: User manages download queue
        // When: Creating download tasks for episodes
        let download1 = DownloadTask(
            id: "download-tech-ep1",
            episodeId: "tech-ep1",
            audioURL: techEpisode1.mediaURL!,
            fileSize: 45_000_000, // 45MB
            priority: .high
        )
        
        let download2 = DownloadTask(
            id: "download-tech-ep2", 
            episodeId: "tech-ep2",
            audioURL: techEpisode2.mediaURL!,
            fileSize: 55_000_000, // 55MB
            priority: .normal
        )
        
        let download3 = DownloadTask(
            id: "download-ai-ep1",
            episodeId: "ai-ep1", 
            audioURL: aiEpisode1.mediaURL!,
            fileSize: 65_000_000, // 65MB
            priority: .low
        )
        
        downloadQueueManager.enqueue(download1)
        downloadQueueManager.enqueue(download2)
        downloadQueueManager.enqueue(download3)
        
        // Then: Downloads should be queued in priority order
        let queuedDownloads = downloadQueueManager.getQueuedTasks()
        XCTAssertEqual(queuedDownloads.count, 3)
        XCTAssertEqual(queuedDownloads[0].priority, .high)
        XCTAssertEqual(queuedDownloads[1].priority, .normal)
        XCTAssertEqual(queuedDownloads[2].priority, .low)
        
        // STEP 5: User creates playlists and adds episodes
        // When: Creating different types of playlists
        let manualPlaylist = Playlist(
            id: "my-favorites",
            name: "My Favorites",
            description: "Manually curated favorite episodes",
            type: .manual,
            episodeIds: ["tech-ep1", "ai-ep1"],
            settings: PlaylistSettings(
                autoPlay: true,
                shuffleEnabled: false,
                repeatMode: .none
            )
        )
        
        let smartPlaylist = Playlist(
            id: "recent-tech",
            name: "Recent Tech Episodes", 
            description: "Auto-updating playlist of recent technology episodes",
            type: .smart,
            episodeIds: [],
            settings: PlaylistSettings(
                autoPlay: true,
                shuffleEnabled: false,
                repeatMode: .playlist
            ),
            smartCriteria: SmartPlaylistCriteria(
                maxEpisodes: 50,
                includePlayedEpisodes: false,
                criteria: [
                    .podcast(ids: ["tech-podcast", "ai-podcast"]),
                    .dateRange(from: Date().addingTimeInterval(-30*24*60*60), to: Date()) // Last 30 days
                ]
            )
        )
        
        playlistManager.create(manualPlaylist)
        playlistManager.create(smartPlaylist)
        
        // Then: Playlists should be created with correct structure
        XCTAssertEqual(playlistManager.getAll().count, 2)
        let favoritesPlaylist = playlistManager.get(id: "my-favorites")
        XCTAssertNotNil(favoritesPlaylist)
        XCTAssertEqual(favoritesPlaylist?.episodeIds.count, 2)
        XCTAssertTrue(favoritesPlaylist?.settings.autoPlay ?? false)
        
        let smartPlaylistRetrieved = playlistManager.get(id: "recent-tech")
        XCTAssertNotNil(smartPlaylistRetrieved)
        XCTAssertEqual(smartPlaylistRetrieved?.type, .smart)
        XCTAssertNotNil(smartPlaylistRetrieved?.smartCriteria)
        
        // STEP 6: User searches across content
        // When: Building search index with all content
        for podcast in podcastManager.all() {
            searchIndex.indexPodcast(podcast)
        }
        
        // Add episodes to search index (simulated)
        let allEpisodes = [techEpisode1, techEpisode2, aiEpisode1]
        for episode in allEpisodes {
            searchIndex.indexEpisode(episode)
        }
        
        // Then: Search should find relevant content
        let techResults = searchIndex.search(query: "swift concurrency")
        XCTAssertFalse(techResults.isEmpty)
        
        let aiResults = searchIndex.search(query: "machine learning")
        XCTAssertFalse(aiResults.isEmpty)
        
        // STEP 7: User configures global and per-podcast settings
        // When: Configuring global settings
        settingsManager.updateGlobalSettings(SettingsUpdate(
            updateFrequency: .sixHours,
            autoDownloadEnabled: true,
            downloadSettings: DownloadSettings(
                wifiOnly: true,
                deleteAfterPlaying: false,
                maxDownloadSize: 100_000_000 // 100MB
            )
        ))
        
        // Configure per-podcast settings override
        settingsManager.updatePodcastSettings(
            podcastId: "ai-podcast",
            settings: PodcastSettings(
                autoDownloadEnabled: false, // Override global setting
                updateFrequency: .daily,
                downloadSettings: DownloadSettings(
                    wifiOnly: true,
                    deleteAfterPlaying: true,
                    maxDownloadSize: 50_000_000 // 50MB
                )
            )
        )
        
        // Then: Settings should cascade correctly
        let globalSettings = settingsManager.getGlobalSettings()
        XCTAssertEqual(globalSettings.updateFrequency, .sixHours)
        XCTAssertTrue(globalSettings.autoDownloadEnabled)
        
        let aiPodcastSettings = settingsManager.getPodcastSettings(podcastId: "ai-podcast")
        XCTAssertNotNil(aiPodcastSettings)
        XCTAssertFalse(aiPodcastSettings?.autoDownloadEnabled ?? true) // Override
        XCTAssertEqual(aiPodcastSettings?.updateFrequency, .daily)
        
        // STEP 8: Verify complete integration
        // When: Performing complex cross-package queries
        let techFolderPodcasts = podcastManager.findByFolder(folderId: "tech")
        let techTaggedPodcasts = podcastManager.findByTag(tagId: "technology")
        let recentPlaylist = playlistManager.get(id: "recent-tech")
        let highPriorityDownloads = downloadQueueManager.getQueuedTasks().filter { $0.priority == .high }
        
        // Then: All cross-package functionality should work together
        XCTAssertEqual(techFolderPodcasts.count, 1)
        XCTAssertEqual(techTaggedPodcasts.count, 2) // Both tech and ai podcasts have technology tag
        XCTAssertNotNil(recentPlaylist)
        XCTAssertEqual(highPriorityDownloads.count, 1)
        
        // Final verification: User library is properly organized and functional
        XCTAssertEqual(podcastManager.all().count, 3)
        XCTAssertEqual(folderManager.getAll().count, 3)
        XCTAssertEqual(playlistManager.getAll().count, 2)
        XCTAssertEqual(downloadQueueManager.getQueuedTasks().count, 3)
    }
    
    // MARK: - Cross-Package Data Flow Tests
    
    func testCrossPackageDataFlow_SubscriptionWorkflow() {
        // Given: Subscription service and podcast manager integration
        
        // When: User subscribes to new podcast through subscription service
        let feedURL = URL(string: "https://example.com/new-podcast.xml")!
        
        // Simulate subscription service processing
        let newPodcast = Podcast(
            id: "new-subscription",
            title: "New Podcast",
            description: "Recently subscribed podcast",
            feedURL: feedURL,
            imageURL: URL(string: "https://example.com/new-podcast.jpg")
        )
        
        // Subscription service would normally parse feed and create podcast
        podcastManager.add(newPodcast)
        
        // Download service creates automatic download tasks for recent episodes
        let recentEpisode = Episode(
            id: "recent-ep",
            title: "Latest Episode",
            description: "Most recent episode",
            mediaURL: URL(string: "https://example.com/recent-ep.mp3")!,
            duration: 1800,
            podcastId: "new-subscription"
        )
        
        let autoDownloadTask = DownloadTask(
            id: "auto-download-recent",
            episodeId: "recent-ep",
            audioURL: recentEpisode.mediaURL!,
            fileSize: 35_000_000,
            priority: .normal
        )
        
        downloadQueueManager.enqueue(autoDownloadTask)
        
        // Search index automatically indexes new content
        searchIndex.indexPodcast(newPodcast)
        searchIndex.indexEpisode(recentEpisode)
        
        // Then: All systems should be updated with new subscription
        XCTAssertEqual(podcastManager.all().count, 1)
        XCTAssertEqual(downloadQueueManager.getQueuedTasks().count, 1)
        
        let searchResults = searchIndex.search(query: "recent")
        XCTAssertFalse(searchResults.isEmpty)
    }
    
    func testCrossPackageDataFlow_PlaylistAndDownloadIntegration() {
        // Given: Podcast with episodes and download management
        let podcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            description: "Testing playlist and download integration",
            feedURL: URL(string: "https://example.com/test.xml")!
        )
        podcastManager.add(podcast)
        
        let episodes = [
            Episode(
                id: "ep1",
                title: "Episode 1",
                description: "First episode",
                mediaURL: URL(string: "https://example.com/ep1.mp3")!,
                duration: 1800,
                podcastId: "test-podcast"
            ),
            Episode(
                id: "ep2",
                title: "Episode 2",
                description: "Second episode",
                mediaURL: URL(string: "https://example.com/ep2.mp3")!,
                duration: 2100,
                podcastId: "test-podcast"
            ),
            Episode(
                id: "ep3",
                title: "Episode 3",
                description: "Third episode",
                mediaURL: URL(string: "https://example.com/ep3.mp3")!,
                duration: 1950,
                podcastId: "test-podcast"
            )
        ]
        
        // When: User creates playlist and initiates downloads
        let playlist = Playlist(
            id: "test-playlist",
            name: "Test Playlist",
            description: "Testing integration",
            type: .manual,
            episodeIds: ["ep1", "ep2", "ep3"],
            settings: PlaylistSettings(
                autoPlay: true,
                shuffleEnabled: false,
                repeatMode: .none
            )
        )
        playlistManager.create(playlist)
        
        // Create download tasks for playlist episodes
        for (index, episode) in episodes.enumerated() {
            let downloadTask = DownloadTask(
                id: "download-\(episode.id)",
                episodeId: episode.id,
                audioURL: episode.mediaURL!,
                fileSize: Int64(40_000_000 + index * 5_000_000), // Varying sizes
                priority: index == 0 ? .high : .normal // First episode high priority
            )
            downloadQueueManager.enqueue(downloadTask)
        }
        
        // Update settings to prefer downloaded episodes in playlists
        settingsManager.updateGlobalSettings(SettingsUpdate(
            updateFrequency: .daily,
            autoDownloadEnabled: true,
            downloadSettings: DownloadSettings(
                wifiOnly: true,
                deleteAfterPlaying: false,
                maxDownloadSize: 200_000_000
            )
        ))
        
        // Then: Integration should work seamlessly
        let createdPlaylist = playlistManager.get(id: "test-playlist")
        XCTAssertNotNil(createdPlaylist)
        XCTAssertEqual(createdPlaylist?.episodeIds.count, 3)
        
        let queuedDownloads = downloadQueueManager.getQueuedTasks()
        XCTAssertEqual(queuedDownloads.count, 3)
        XCTAssertEqual(queuedDownloads[0].priority, .high) // First episode
        
        let globalSettings = settingsManager.getGlobalSettings()
        XCTAssertTrue(globalSettings.autoDownloadEnabled)
        XCTAssertEqual(globalSettings.downloadSettings.maxDownloadSize, 200_000_000)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentOperations_ThreadSafety() {
        // Given: Multiple concurrent operations across packages
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 9 // 3 operations * 3 iterations
        
        // When: Performing concurrent operations across all packages
        DispatchQueue.concurrentPerform(iterations: 3) { iteration in
            // Concurrent podcast operations
            DispatchQueue.global().async {
                let podcast = Podcast(
                    id: "concurrent-podcast-\(iteration)",
                    title: "Concurrent Podcast \(iteration)",
                    description: "Testing concurrent access",
                    feedURL: URL(string: "https://example.com/concurrent\(iteration).xml")!
                )
                self.podcastManager.add(podcast)
                expectation.fulfill()
            }
            
            // Concurrent folder operations
            DispatchQueue.global().async {
                let folder = Folder(
                    id: "concurrent-folder-\(iteration)",
                    name: "Concurrent Folder \(iteration)",
                    parentId: nil
                )
                self.folderManager.add(folder)
                expectation.fulfill()
            }
            
            // Concurrent download operations
            DispatchQueue.global().async {
                let download = DownloadTask(
                    id: "concurrent-download-\(iteration)",
                    episodeId: "episode-\(iteration)",
                    audioURL: URL(string: "https://example.com/concurrent\(iteration).mp3")!,
                    fileSize: Int64(30_000_000 + iteration * 10_000_000),
                    priority: .normal
                )
                self.downloadQueueManager.enqueue(download)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: All operations should complete successfully
        XCTAssertEqual(podcastManager.all().count, 3)
        XCTAssertEqual(folderManager.getAll().count, 3)
        XCTAssertEqual(downloadQueueManager.getQueuedTasks().count, 3)
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformanceIntegration_LargeDatasets() {
        // Given: Large dataset for performance testing
        let podcastCount = 100
        let episodesPerPodcast = 20
        let folderCount = 20
        
        // When: Creating large dataset
        measure {
            // Create folder hierarchy
            for i in 0..<folderCount {
                let folder = Folder(
                    id: "folder-\(i)",
                    name: "Folder \(i)",
                    parentId: i > 0 && i % 5 == 0 ? "folder-\(i-5)" : nil
                )
                folderManager.add(folder)
            }
            
            // Create podcasts and episodes
            for podcastIndex in 0..<podcastCount {
                let podcast = Podcast(
                    id: "podcast-\(podcastIndex)",
                    title: "Podcast \(podcastIndex)",
                    description: "Performance test podcast \(podcastIndex)",
                    feedURL: URL(string: "https://example.com/podcast\(podcastIndex).xml")!,
                    folderId: "folder-\(podcastIndex % folderCount)",
                    tagIds: ["tag\(podcastIndex % 10)"]
                )
                podcastManager.add(podcast)
                
                // Add to search index
                searchIndex.indexPodcast(podcast)
                
                // Create episodes
                for episodeIndex in 0..<episodesPerPodcast {
                    let episode = Episode(
                        id: "episode-\(podcastIndex)-\(episodeIndex)",
                        title: "Episode \(episodeIndex) of Podcast \(podcastIndex)",
                        description: "Performance test episode",
                        mediaURL: URL(string: "https://example.com/ep\(podcastIndex)-\(episodeIndex).mp3")!,
                        duration: TimeInterval(1800 + episodeIndex * 60),
                        podcastId: "podcast-\(podcastIndex)"
                    )
                    
                    searchIndex.indexEpisode(episode)
                    
                    // Create download task
                    if episodeIndex < 5 { // Only recent episodes
                        let download = DownloadTask(
                            id: "download-\(podcastIndex)-\(episodeIndex)",
                            episodeId: episode.id,
                            audioURL: episode.mediaURL!,
                            fileSize: Int64(40_000_000 + episodeIndex * 1_000_000),
                            priority: episodeIndex == 0 ? .high : .normal
                        )
                        downloadQueueManager.enqueue(download)
                    }
                }
            }
        }
        
        // Then: Performance should be acceptable for large datasets
        XCTAssertEqual(podcastManager.all().count, podcastCount)
        XCTAssertEqual(folderManager.getAll().count, folderCount)
        XCTAssertEqual(downloadQueueManager.getQueuedTasks().count, podcastCount * 5) // 5 downloads per podcast
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery_DataInconsistency() {
        // Given: Intentionally inconsistent data state
        
        // Create podcast without corresponding folder
        let orphanPodcast = Podcast(
            id: "orphan-podcast",
            title: "Orphan Podcast",
            description: "Podcast with non-existent folder",
            feedURL: URL(string: "https://example.com/orphan.xml")!,
            folderId: "non-existent-folder", // Folder doesn't exist
            tagIds: ["orphan-tag"]
        )
        podcastManager.add(orphanPodcast)
        
        // Create download task for non-existent episode
        let orphanDownload = DownloadTask(
            id: "orphan-download",
            episodeId: "non-existent-episode",
            audioURL: URL(string: "https://example.com/non-existent.mp3")!,
            fileSize: 50_000_000,
            priority: .normal
        )
        downloadQueueManager.enqueue(orphanDownload)
        
        // Create playlist with non-existent episodes
        let orphanPlaylist = Playlist(
            id: "orphan-playlist",
            name: "Orphan Playlist",
            description: "Playlist with non-existent episodes",
            type: .manual,
            episodeIds: ["non-existent-1", "non-existent-2"],
            settings: PlaylistSettings(autoPlay: false, shuffleEnabled: false, repeatMode: .none)
        )
        playlistManager.create(orphanPlaylist)
        
        // When: System attempts to handle inconsistent data
        let folderPodcasts = podcastManager.findByFolder(folderId: "non-existent-folder")
        let queuedDownloads = downloadQueueManager.getQueuedTasks()
        let retrievedPlaylist = playlistManager.get(id: "orphan-playlist")
        
        // Then: System should handle gracefully without crashing
        XCTAssertEqual(folderPodcasts.count, 1) // Should still return podcast even with invalid folder
        XCTAssertEqual(queuedDownloads.count, 1) // Download task should exist even with invalid episode
        XCTAssertNotNil(retrievedPlaylist) // Playlist should exist even with invalid episodes
        XCTAssertEqual(retrievedPlaylist?.episodeIds.count, 2) // Episode IDs preserved
    }
    
    // MARK: - Settings Cascade Integration Tests
    
    func testSettingsCascade_ComplexHierarchy() {
        // Given: Complex podcast and folder hierarchy with cascading settings
        
        // Create folder hierarchy
        let rootFolder = Folder(id: "media", name: "Media", parentId: nil)
        let techFolder = Folder(id: "tech", name: "Technology", parentId: "media")
        let scienceFolder = Folder(id: "science", name: "Science", parentId: "media")
        
        folderManager.add(rootFolder)
        folderManager.add(techFolder)
        folderManager.add(scienceFolder)
        
        // Create podcasts in different folders
        let techPodcast = Podcast(
            id: "tech-podcast",
            title: "Tech Podcast",
            description: "Technology discussions",
            feedURL: URL(string: "https://example.com/tech.xml")!,
            folderId: "tech"
        )
        
        let sciencePodcast = Podcast(
            id: "science-podcast",
            title: "Science Podcast", 
            description: "Science discussions",
            feedURL: URL(string: "https://example.com/science.xml")!,
            folderId: "science"
        )
        
        podcastManager.add(techPodcast)
        podcastManager.add(sciencePodcast)
        
        // When: Configuring cascading settings
        
        // Global settings
        settingsManager.updateGlobalSettings(SettingsUpdate(
            updateFrequency: .twelveHours,
            autoDownloadEnabled: true,
            downloadSettings: DownloadSettings(
                wifiOnly: true,
                deleteAfterPlaying: false,
                maxDownloadSize: 100_000_000
            )
        ))
        
        // Override for tech podcast only
        settingsManager.updatePodcastSettings(
            podcastId: "tech-podcast",
            settings: PodcastSettings(
                autoDownloadEnabled: true, // Same as global
                updateFrequency: .hourly, // More frequent than global
                downloadSettings: DownloadSettings(
                    wifiOnly: false, // Override: allow cellular
                    deleteAfterPlaying: true, // Override: delete after playing
                    maxDownloadSize: 150_000_000 // Override: larger size
                )
            )
        )
        
        // Science podcast inherits global settings (no override)
        
        // Then: Settings should cascade correctly
        let globalSettings = settingsManager.getGlobalSettings()
        XCTAssertEqual(globalSettings.updateFrequency, .twelveHours)
        XCTAssertTrue(globalSettings.autoDownloadEnabled)
        XCTAssertTrue(globalSettings.downloadSettings.wifiOnly)
        
        // Tech podcast should have overridden settings
        let techSettings = settingsManager.getPodcastSettings(podcastId: "tech-podcast")
        XCTAssertNotNil(techSettings)
        XCTAssertEqual(techSettings?.updateFrequency, .hourly)
        XCTAssertFalse(techSettings?.downloadSettings.wifiOnly ?? true)
        XCTAssertTrue(techSettings?.downloadSettings.deleteAfterPlaying ?? false)
        XCTAssertEqual(techSettings?.downloadSettings.maxDownloadSize, 150_000_000)
        
        // Science podcast should inherit global settings
        let scienceSettings = settingsManager.getPodcastSettings(podcastId: "science-podcast")
        XCTAssertNil(scienceSettings) // No override, uses global
        
        // Verify effective settings would cascade from global for science podcast
        let effectiveGlobalDownloadSettings = globalSettings.downloadSettings
        XCTAssertTrue(effectiveGlobalDownloadSettings.wifiOnly)
        XCTAssertFalse(effectiveGlobalDownloadSettings.deleteAfterPlaying)
        XCTAssertEqual(effectiveGlobalDownloadSettings.maxDownloadSize, 100_000_000)
    }
    
    // MARK: - Complete Application State Tests
    
    func testCompleteApplicationState_SaveAndRestore() {
        // Given: Fully populated application state
        
        // Create comprehensive state
        let folder1 = Folder(id: "folder1", name: "Folder 1", parentId: nil)
        let folder2 = Folder(id: "folder2", name: "Folder 2", parentId: "folder1")
        folderManager.add(folder1)
        folderManager.add(folder2)
        
        let podcast1 = Podcast(
            id: "podcast1",
            title: "Podcast 1",
            description: "First podcast",
            feedURL: URL(string: "https://example.com/p1.xml")!,
            folderId: "folder1",
            tagIds: ["tag1"]
        )
        podcastManager.add(podcast1)
        
        let playlist1 = Playlist(
            id: "playlist1",
            name: "Playlist 1",
            description: "First playlist",
            type: .manual,
            episodeIds: ["ep1", "ep2"],
            settings: PlaylistSettings(autoPlay: true, shuffleEnabled: false, repeatMode: .none)
        )
        playlistManager.create(playlist1)
        
        let download1 = DownloadTask(
            id: "download1",
            episodeId: "ep1",
            audioURL: URL(string: "https://example.com/ep1.mp3")!,
            fileSize: 50_000_000,
            priority: .high
        )
        downloadQueueManager.enqueue(download1)
        
        settingsManager.updateGlobalSettings(SettingsUpdate(
            updateFrequency: .daily,
            autoDownloadEnabled: true,
            downloadSettings: DownloadSettings(
                wifiOnly: true,
                deleteAfterPlaying: false,
                maxDownloadSize: 100_000_000
            )
        ))
        
        // When: Simulating app state preservation (checking current state)
        let allPodcasts = podcastManager.all()
        let allFolders = folderManager.getAll()
        let allPlaylists = playlistManager.getAll()
        let allDownloads = downloadQueueManager.getQueuedTasks()
        let currentSettings = settingsManager.getGlobalSettings()
        
        // Then: Complete state should be consistent and retrievable
        XCTAssertEqual(allPodcasts.count, 1)
        XCTAssertEqual(allFolders.count, 2)
        XCTAssertEqual(allPlaylists.count, 1)
        XCTAssertEqual(allDownloads.count, 1)
        XCTAssertEqual(currentSettings.updateFrequency, .daily)
        
        // Verify relationships are maintained
        let folder1Podcasts = podcastManager.findByFolder(folderId: "folder1")
        XCTAssertEqual(folder1Podcasts.count, 1)
        XCTAssertEqual(folder1Podcasts.first?.id, "podcast1")
        
        let children = folderManager.getChildren(of: "folder1")
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.id, "folder2")
        
        let retrievedPlaylist = playlistManager.get(id: "playlist1")
        XCTAssertNotNil(retrievedPlaylist)
        XCTAssertEqual(retrievedPlaylist?.episodeIds.count, 2)
        
        // Verify cross-package consistency
        XCTAssertEqual(allPodcasts.first?.folderId, "folder1")
        XCTAssertEqual(allDownloads.first?.episodeId, "ep1")
        XCTAssertTrue(retrievedPlaylist?.episodeIds.contains("ep1") ?? false)
    }
}