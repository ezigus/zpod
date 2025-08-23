import XCTest
import Foundation
@testable import Persistence
import CoreModels

final class BasicPersistenceTests: XCTestCase {
    
    var podcastRepository: UserDefaultsPodcastRepository!
    var episodeRepository: UserDefaultsEpisodeRepository!
    var userDefaults: UserDefaults!
    var suiteName: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Given: Fresh UserDefaults for each test
        suiteName = "test-basic-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        
        // Given: Fresh repositories
        podcastRepository = UserDefaultsPodcastRepository(userDefaults: userDefaults)
        episodeRepository = UserDefaultsEpisodeRepository(userDefaults: userDefaults)
    }
    
    override func tearDown() async throws {
        // Clean up UserDefaults
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        podcastRepository = nil
        episodeRepository = nil
        suiteName = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Podcast Repository Tests
    
    func testSavePodcast_Success() async throws {
        // Given: A podcast to save
        let podcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            author: "Test Author",
            description: "A test podcast",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            isSubscribed: true
        )
        
        // When: Saving the podcast
        try await podcastRepository.savePodcast(podcast)
        
        // Then: Should save without throwing
        // Success is indicated by no exception being thrown
    }
    
    func testSaveAndLoadPodcast_Success() async throws {
        // Given: A podcast to save and load
        let originalPodcast = Podcast(
            id: "save-load-test",
            title: "Save Load Test",
            author: "Test Author",
            description: "Testing save and load",
            feedURL: URL(string: "https://example.com/test.xml")!,
            isSubscribed: true
        )
        
        // When: Saving and loading the podcast
        try await podcastRepository.savePodcast(originalPodcast)
        let loadedPodcast = try await podcastRepository.loadPodcast(id: originalPodcast.id)
        
        // Then: Loaded podcast should match saved podcast
        XCTAssertNotNil(loadedPodcast, "Loaded podcast should not be nil")
        XCTAssertEqual(loadedPodcast?.id, originalPodcast.id, "Podcast ID should match")
        XCTAssertEqual(loadedPodcast?.title, originalPodcast.title, "Podcast title should match")
        XCTAssertEqual(loadedPodcast?.author, originalPodcast.author, "Podcast author should match")
        XCTAssertEqual(loadedPodcast?.description, originalPodcast.description, "Podcast description should match")
        XCTAssertEqual(loadedPodcast?.feedURL, originalPodcast.feedURL, "Podcast feed URL should match")
        XCTAssertEqual(loadedPodcast?.isSubscribed, originalPodcast.isSubscribed, "Subscription status should match")
    }
    
    func testLoadPodcast_NonExistent() async throws {
        // Given: A non-existent podcast ID
        let nonExistentId = "non-existent-podcast"
        
        // When: Loading non-existent podcast
        let podcast = try await podcastRepository.loadPodcast(id: nonExistentId)
        
        // Then: Should return nil
        XCTAssertNil(podcast, "Non-existent podcast should return nil")
    }
    
    // MARK: - Basic Episode Repository Tests
    
    func testSaveEpisode_Success() async throws {
        // Given: An episode to save
        let episode = Episode(
            id: "test-episode",
            title: "Test Episode",
            podcastID: "test-podcast",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800,
            description: "A test episode",
            audioURL: URL(string: "https://example.com/episode.mp3")
        )
        
        // When: Saving the episode
        try await episodeRepository.saveEpisode(episode)
        
        // Then: Should save without throwing
        // Success is indicated by no exception being thrown
    }
    
    func testSaveAndLoadEpisode_Success() async throws {
        // Given: An episode to save and load
        let originalEpisode = Episode(
            id: "save-load-episode",
            title: "Save Load Episode",
            podcastID: "test-podcast",
            playbackPosition: 1200,
            isPlayed: true,
            pubDate: Date(),
            duration: 2400,
            description: "Testing episode save and load",
            audioURL: URL(string: "https://example.com/test.mp3")
        )
        
        // When: Saving and loading the episode
        try await episodeRepository.saveEpisode(originalEpisode)
        let loadedEpisode = try await episodeRepository.loadEpisode(id: originalEpisode.id)
        
        // Then: Loaded episode should match saved episode
        XCTAssertNotNil(loadedEpisode, "Loaded episode should not be nil")
        XCTAssertEqual(loadedEpisode?.id, originalEpisode.id, "Episode ID should match")
        XCTAssertEqual(loadedEpisode?.title, originalEpisode.title, "Episode title should match")
        XCTAssertEqual(loadedEpisode?.description, originalEpisode.description, "Episode description should match")
        XCTAssertEqual(loadedEpisode?.duration, originalEpisode.duration, "Episode duration should match")
        XCTAssertEqual(loadedEpisode?.podcastID, originalEpisode.podcastID, "Episode podcast ID should match")
        XCTAssertEqual(loadedEpisode?.isPlayed, originalEpisode.isPlayed, "Episode played status should match")
        XCTAssertEqual(loadedEpisode?.playbackPosition, originalEpisode.playbackPosition, "Episode playback position should match")
    }
    
    func testLoadEpisode_NonExistent() async throws {
        // Given: A non-existent episode ID
        let nonExistentId = "non-existent-episode"
        
        // When: Loading non-existent episode
        let episode = try await episodeRepository.loadEpisode(id: nonExistentId)
        
        // Then: Should return nil
        XCTAssertNil(episode, "Non-existent episode should return nil")
    }
    
    // MARK: - File Manager Service Tests
    
    func testFileManagerService_Creation() async throws {
        // Given: FileManagerService constructor
        // When: Creating service
        let service = try await FileManagerService()
        
        // Then: Should create without throwing
        XCTAssertNotNil(service, "FileManagerService should be created successfully")
    }
    
    func testDownloadPath_Generation() async throws {
        // Given: FileManagerService and a download task
        let service = try await FileManagerService()
        let task = DownloadTask(
            id: "test-task",
            episodeId: "episode-123",
            podcastId: "podcast-456",
            audioURL: URL(string: "https://example.com/test.mp3")!,
            title: "Test Episode"
        )
        
        // When: Getting download path
        let path = await service.downloadPath(for: task)
        
        // Then: Path should be generated
        XCTAssertFalse(path.isEmpty, "Download path should not be empty")
        XCTAssertTrue(path.contains(task.podcastId), "Path should contain podcast ID")
        XCTAssertTrue(path.contains(task.episodeId), "Path should contain episode ID")
    }
    
    // MARK: - Storage Policy Evaluator Tests
    
    func testStoragePolicyEvaluator_Creation() async {
        // Given: StoragePolicyEvaluator constructor
        // When: Creating evaluator
        let evaluator = StoragePolicyEvaluator()
        
        // Then: Should create successfully
        XCTAssertNotNil(evaluator, "StoragePolicyEvaluator should be created successfully")
    }
    
    func testKeepLatestPolicy_EmptyEpisodes() async {
        // Given: Policy and empty episodes array
        let evaluator = StoragePolicyEvaluator()
        let policy = StoragePolicy.keepLatest(count: 2)
        
        // When: Evaluating policy with no episodes
        let actions = await evaluator.evaluatePolicy(policy, for: [])
        
        // Then: Should return no actions
        XCTAssertEqual(actions.count, 0, "Should return no actions for empty episodes array")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPodcastOperations() async throws {
        // Given: Multiple podcast operations
        let podcastIds = (0..<5).map { "concurrent-podcast-\($0)" }
        let podcasts = podcastIds.map { id in
            Podcast(
                id: id,
                title: "Concurrent Podcast \(id)",
                author: "Test Author",
                description: "Testing concurrent access",
                feedURL: URL(string: "https://example.com/\(id).xml")!,
                isSubscribed: true
            )
        }
        
        // When: Performing concurrent operations
        let repository = podcastRepository!
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Concurrent saves
            for podcast in podcasts {
                group.addTask {
                    try await repository.savePodcast(podcast)
                }
            }
            
            // Concurrent loads
            for podcastId in podcastIds {
                group.addTask {
                    _ = try await repository.loadPodcast(id: podcastId)
                }
            }
            
            try await group.waitForAll()
        }
        
        // Then: All operations should complete successfully
        // Verify some podcasts were saved correctly
        let loadedPodcast = try await podcastRepository.loadPodcast(id: podcastIds.first!)
        XCTAssertNotNil(loadedPodcast, "At least one podcast should be saved correctly")
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadPodcast_InvalidData() async throws {
        // Given: Invalid data in UserDefaults
        userDefaults.set("invalid-json-data", forKey: "podcast:invalid-podcast")
        
        // When: Loading podcast with invalid data
        do {
            let podcast = try await podcastRepository.loadPodcast(id: "invalid-podcast")
            XCTAssertNil(podcast, "Should return nil for invalid data")
        } catch {
            // Should either return nil or throw persistence error
            XCTFail("Should handle invalid data gracefully: \(error)")
        }
    }
}