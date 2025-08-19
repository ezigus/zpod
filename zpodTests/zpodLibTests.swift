import XCTest
@testable import zpodLib
import CoreModels
import SharedUtilities
import Persistence
import TestSupport
@preconcurrency import Foundation

final class zpodLibTests: XCTestCase {
    
    func testPackageIntegration() async throws {
        // Test that all packages work together
        let podcast = MockPodcast.createSample()
        let episode = MockEpisode.createSample(podcastID: podcast.id)
        let userDefaults = UserDefaults(suiteName: "integration-test")!
        defer { userDefaults.removePersistentDomain(forName: "integration-test") }
        
        // Test persistence
        let podcastRepo = UserDefaultsPodcastRepository(userDefaults: userDefaults)
        let episodeRepo = UserDefaultsEpisodeRepository(userDefaults: userDefaults)
        
        try await podcastRepo.savePodcast(podcast)
        try await episodeRepo.saveEpisode(episode)
        
        let storedPodcast = try await podcastRepo.loadPodcast(id: podcast.id)
        let storedEpisode = try await episodeRepo.loadEpisode(id: episode.id)
        
        XCTAssertEqual(storedPodcast?.id, podcast.id)
        XCTAssertEqual(storedEpisode?.id, episode.id)
    }
    
    func testValidationUtilities() {
        // Test validation utilities from SharedUtilities
        XCTAssertTrue(ValidationUtilities.isValidURL("https://example.com/feed.xml"))
        XCTAssertFalse(ValidationUtilities.isValidURL(""))
        XCTAssertEqual(ValidationUtilities.clamp(5, min: 0, max: 10), 5)
        XCTAssertEqual(ValidationUtilities.clamp(-1, min: 0, max: 10), 0)
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
        let error = SharedError.networkError("Connection timeout")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Connection timeout"))
    }
    
    func testLogger() {
        // Test logging doesn't crash
        Logger.log("Package integration test")
        Logger.log("Debug message", level: .debug)
    }
}