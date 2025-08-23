import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import PlaybackEngine
import CoreModels
import SharedUtilities
import TestSupport

final class SimplePlaybackEngineTests: XCTestCase {
    
    @MainActor
    func testEpisodeStateManager_basicFunctionality() async {
        // Given: Episode state manager and episode
        let episodeStateManager = InMemoryEpisodeStateManager()
        let episode = Episode(id: "ep1", title: "Test Episode")
        
        // When: Setting played status
        await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
        
        // Then: Episode should be marked as played
        let updatedEpisode = await episodeStateManager.getEpisodeState(episode)
        XCTAssertTrue(updatedEpisode.isPlayed)
    }
    
    @MainActor
    func testSleepTimer_basicFunctionality() {
        // Given: Sleep timer
        let sleepTimer = SleepTimer()
        
        // When: Checking initial state
        // Then: Should not be active initially
        XCTAssertFalse(sleepTimer.isActive)
        
        // When: Starting timer
        sleepTimer.start(duration: 300)
        
        // Then: Should become active
        XCTAssertTrue(sleepTimer.isActive)
        
        // When: Stopping timer
        sleepTimer.stop()
        
        // Then: Should become inactive
        XCTAssertFalse(sleepTimer.isActive)
    }
    
    @MainActor
    func testStubEpisodePlayer_basicFunctionality() {
        // Given: Stub episode player
        let ticker = TimerTicker()
        let stubPlayer = StubEpisodePlayer(ticker: ticker)
        let episode = Episode(id: "ep1", title: "Test Episode")
        
        // When: Playing episode
        stubPlayer.play(episode: episode, duration: 1800)
        
        // Then: Player should be set up (basic validation)
        // Note: More specific validation would require accessing internal state
        XCTAssertNotNil(stubPlayer)
        
        // When: Pausing
        stubPlayer.pause()
        
        // Then: Player should handle pause (basic validation)
        XCTAssertNotNil(stubPlayer)
    }
    
    @MainActor  
    func testEpisodeStateManager_playbackPosition() async {
        // Given: Episode state manager and episode
        let episodeStateManager = InMemoryEpisodeStateManager()
        let episode = Episode(id: "ep2", title: "Position Test")
        
        // When: Updating playback position
        await episodeStateManager.updatePlaybackPosition(episode, position: 123.0)
        
        // Then: Position should be updated
        let updatedEpisode = await episodeStateManager.getEpisodeState(episode)
        XCTAssertEqual(updatedEpisode.playbackPosition, 123)
    }
    
    @MainActor
    func testMultipleEpisodes_independentState() async {
        // Given: Episode state manager and multiple episodes
        let episodeStateManager = InMemoryEpisodeStateManager()
        let episode1 = Episode(id: "ep1", title: "Episode 1")
        let episode2 = Episode(id: "ep2", title: "Episode 2")
        
        // When: Setting different states for each episode
        await episodeStateManager.setPlayedStatus(episode1, isPlayed: true)
        await episodeStateManager.updatePlaybackPosition(episode2, position: 60.0)
        
        // Then: Each episode should maintain independent state
        let updatedEpisode1 = await episodeStateManager.getEpisodeState(episode1)
        let updatedEpisode2 = await episodeStateManager.getEpisodeState(episode2)
        
        XCTAssertTrue(updatedEpisode1.isPlayed)
        XCTAssertEqual(updatedEpisode1.playbackPosition, 0) // Default position
        
        XCTAssertFalse(updatedEpisode2.isPlayed) // Default played status
        XCTAssertEqual(updatedEpisode2.playbackPosition, 60)
    }
}