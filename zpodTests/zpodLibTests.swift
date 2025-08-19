import XCTest
@testable import zpodLib
import CoreModels
import SharedUtilities
import Persistence
import TestSupport

final class zpodLibTests: XCTestCase {
    
    func testPackageIntegration() async throws {
        // Test that all packages work together
        let podcast = TestFixtures.samplePodcast1
        let episode = TestFixtures.sampleEpisode1
        let userDefaults = TestUtilities.createTestUserDefaults(for: "integration")
        defer { TestUtilities.cleanupTestUserDefaults(userDefaults) }
        
        // Test persistence
        let podcastRepo = UserDefaultsPodcastRepository(userDefaults: userDefaults)
        let episodeRepo = UserDefaultsEpisodeRepository(userDefaults: userDefaults)
        
        try await podcastRepo.store(podcast)
        try await episodeRepo.store(episode)
        
        let storedPodcast = try await podcastRepo.fetch(by: podcast.id)
        let storedEpisode = try await episodeRepo.fetch(by: episode.id)
        
        XCTAssertEqual(storedPodcast?.id, podcast.id)
        XCTAssertEqual(storedEpisode?.id, episode.id)
    }
    
    func testValidationUtilities() {
        // Test validation utilities from SharedUtilities
        XCTAssertTrue(ValidationUtils.isValidURL("https://example.com/feed.xml"))
        XCTAssertFalse(ValidationUtils.isValidURL("invalid"))
        XCTAssertEqual(ValidationUtils.clamp(5, min: 0, max: 10), 5)
        XCTAssertEqual(ValidationUtils.clamp(-1, min: 0, max: 10), 0)
    }
    
    func testCoreModels() {
        // Test core models are accessible and functional
        let episode = Episode(
            id: "test",
            title: "Test Episode",
            playbackPosition: 100
        )
        
        let updatedEpisode = episode.withPlaybackPosition(200)
        XCTAssertEqual(updatedEpisode.playbackPosition, 200)
        
        let playedEpisode = episode.withPlayedStatus(true)
        XCTAssertTrue(playedEpisode.isPlayed)
    }
    
    func testErrorHandling() {
        let error = CommonError.networkError("Connection timeout")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Connection timeout"))
    }
    
    func testLogger() {
        let logger = Logger(subsystem: "zpodLib")
        // Test logging doesn't crash
        logger.info("Package integration test")
        logger.debug("Debug message")
    }
}