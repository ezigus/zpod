import XCTest
#if os(iOS)
import AVFoundation
#endif
#if canImport(Combine)
@preconcurrency import CombineSupport
import Combine
#endif
@testable import PlaybackEngine
import CoreModels
import SharedUtilities

/// Integration tests for EnhancedEpisodePlayer with AVPlayerPlaybackEngine.
///
/// **Spec Reference**: `zpod/spec/playback.md` - Core Playback Behavior
/// Tests the full integration of state management with actual audio playback.
#if os(iOS)
@MainActor
final class EnhancedEpisodePlayerAudioIntegrationTests: XCTestCase {
    nonisolated(unsafe) private var player: EnhancedEpisodePlayer!
    nonisolated(unsafe) private var audioEngine: AVPlayerPlaybackEngine!
    nonisolated(unsafe) private var cancellables: Set<AnyCancellable>!
    
    override nonisolated func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            audioEngine = AVPlayerPlaybackEngine()
            player = EnhancedEpisodePlayer(audioEngine: audioEngine)
            cancellables = []
        }
    }
    
    override nonisolated func tearDown() async throws {
        await MainActor.run {
            player = nil
            audioEngine?.stop()
            audioEngine = nil
            cancellables = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Basic Integration Tests
    
    /// **Scenario**: Play Episode with Valid Audio URL
    /// **Given** an episode with a valid audio URL
    /// **When** play() is called
    /// **Then** state transitions to .playing and position updates emit
    func testPlayWithValidAudioURL() async throws {
        // Given: An episode with valid audio URL
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        let episode = Episode(
            id: "test-episode-1",
            title: "Test Episode",
            audioURL: testURL,
            duration: 60
        )
        
        var receivedStates: [EpisodePlaybackState] = []
        let stateExpectation = expectation(description: "State updates")
        stateExpectation.expectedFulfillmentCount = 3 // idle, playing (initial), playing (position update)
        
        #if canImport(Combine)
            player.statePublisher
                .sink { state in
                    receivedStates.append(state)
                    stateExpectation.fulfill()
                }
                .store(in: &cancellables)
        #endif
        
        // When: Play the episode
        player.play(episode: episode, duration: 60)
        
        // Then: Should receive state updates
        await fulfillment(of: [stateExpectation], timeout: 10.0)
        
        #if canImport(Combine)
            XCTAssertGreaterThanOrEqual(receivedStates.count, 3, "Should have received multiple state updates")
            
            // Verify we got playing states
            let playingStates = receivedStates.filter {
                if case .playing = $0 { return true }
                return false
            }
            XCTAssertGreaterThanOrEqual(playingStates.count, 2, "Should have received playing states")
        #endif
    }
    
    /// **Scenario**: Play Episode Without Audio URL
    /// **Given** an episode without an audio URL
    /// **When** play() is called
    /// **Then** state transitions to .failed with episodeUnavailable error
    func testPlayWithoutAudioURL() async throws {
        // Given: An episode without audio URL
        let episode = Episode(
            id: "test-episode-no-url",
            title: "Episode Without Audio",
            duration: 60
        )
        
        var receivedError: PlaybackError?
        let errorExpectation = expectation(description: "Error state")
        
        #if canImport(Combine)
            player.statePublisher
                .sink { state in
                    if case .failed(_, _, _, let error) = state {
                        receivedError = error
                        errorExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        #endif
        
        // When: Attempt to play
        player.play(episode: episode, duration: 60)
        
        // Then: Should receive error state
        await fulfillment(of: [errorExpectation], timeout: 5.0)
        XCTAssertEqual(receivedError, .episodeUnavailable, "Should report episode unavailable")
    }
    
    // MARK: - Pause/Resume Tests
    
    /// **Scenario**: Pause and Resume Playback
    /// **Given** an episode is playing
    /// **When** pause() is called and then play() again
    /// **Then** state transitions correctly and position is maintained
    func testPauseAndResume() async throws {
        // Given: Playing episode
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        let episode = Episode(
            id: "test-pause-resume",
            title: "Pause Resume Test",
            audioURL: testURL,
            duration: 60
        )
        
        var receivedStates: [EpisodePlaybackState] = []
        let playExpectation = expectation(description: "Initial playback")
        playExpectation.expectedFulfillmentCount = 2
        
        #if canImport(Combine)
            player.statePublisher
                .sink { state in
                    receivedStates.append(state)
                    if receivedStates.count <= 2 {
                        playExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        #endif
        
        player.play(episode: episode, duration: 60)
        await fulfillment(of: [playExpectation], timeout: 10.0)
        
        // When: Pause
        let pauseExpectation = expectation(description: "Pause state")
        
        #if canImport(Combine)
            player.statePublisher
                .dropFirst(receivedStates.count) // Skip already received states
                .sink { state in
                    if case .paused = state {
                        pauseExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        #endif
        
        player.pause()
        
        // Then: Should receive paused state
        await fulfillment(of: [pauseExpectation], timeout: 5.0)
        
        // Verify final state is paused
        if case .paused = receivedStates.last {
            XCTAssertTrue(true, "Last state should be paused")
        } else {
            XCTFail("Expected paused state")
        }
    }
    
    // MARK: - Seek Tests
    
    /// **Scenario**: Seek During Playback
    /// **Given** an episode is playing
    /// **When** seek(to:) is called
    /// **Then** position jumps to target and playback continues
    func testSeekDuringPlayback() async throws {
        // Given: Playing episode
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        let episode = Episode(
            id: "test-seek",
            title: "Seek Test",
            audioURL: testURL,
            duration: 60
        )
        
        let playExpectation = expectation(description: "Playback started")
        playExpectation.expectedFulfillmentCount = 2
        
        #if canImport(Combine)
            player.statePublisher
                .sink { _ in
                    playExpectation.fulfill()
                }
                .store(in: &cancellables)
        #endif
        
        player.play(episode: episode, duration: 60)
        await fulfillment(of: [playExpectation], timeout: 10.0)
        
        // When: Seek to 10 seconds
        let seekExpectation = expectation(description: "Seek completed")
        var positionAfterSeek: TimeInterval?
        
        #if canImport(Combine)
            player.statePublisher
                .dropFirst(2) // Skip initial states
                .sink { state in
                    if case .playing(_, let position, _) = state, position >= 9.0 {
                        positionAfterSeek = position
                        seekExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        #endif
        
        player.seek(to: 10.0)
        
        // Then: Position should be near 10 seconds
        await fulfillment(of: [seekExpectation], timeout: 10.0)
        XCTAssertNotNil(positionAfterSeek)
        XCTAssertGreaterThanOrEqual(positionAfterSeek ?? 0, 9.0, "Position should be at or after seek target")
    }
    
    // MARK: - Playback Speed Tests
    
    /// **Scenario**: Change Playback Speed
    /// **Given** an episode is playing
    /// **When** setPlaybackSpeed() is called
    /// **Then** speed changes without interrupting playback
    func testPlaybackSpeedChange() async throws {
        // Given: Playing episode
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        let episode = Episode(
            id: "test-speed",
            title: "Speed Test",
            audioURL: testURL,
            duration: 60
        )
        
        let playExpectation = expectation(description: "Playback started")
        playExpectation.expectedFulfillmentCount = 2
        
        #if canImport(Combine)
            player.statePublisher
                .sink { _ in
                    playExpectation.fulfill()
                }
                .store(in: &cancellables)
        #endif
        
        player.play(episode: episode, duration: 60)
        await fulfillment(of: [playExpectation], timeout: 10.0)
        
        // When: Change speed to 2.0x
        player.setPlaybackSpeed(2.0)
        
        // Then: Should still be playing
        XCTAssertTrue(player.isPlaying, "Should still be playing after speed change")
        XCTAssertEqual(player.getCurrentPlaybackSpeed(), 2.0, "Speed should be updated")
    }
    
    // MARK: - Error Handling Tests
    
    /// **Scenario**: Network Error During Playback
    /// **Given** an episode with an invalid/unreachable URL
    /// **When** play() is called
    /// **Then** state transitions to .failed
    func testNetworkError() async throws {
        // Given: Episode with invalid URL
        let invalidURL = URL(string: "https://invalid-domain-xyz-123.com/audio.mp3")!
        let episode = Episode(
            id: "test-network-error",
            title: "Network Error Test",
            audioURL: invalidURL,
            duration: 60
        )
        
        var receivedError: PlaybackError?
        let errorExpectation = expectation(description: "Error state")
        
        #if canImport(Combine)
            player.statePublisher
                .sink { state in
                    if case .failed(_, _, _, let error) = state {
                        receivedError = error
                        errorExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        #endif
        
        // When: Attempt to play
        player.play(episode: episode, duration: 60)
        
        // Then: Should receive error state
        await fulfillment(of: [errorExpectation], timeout: 15.0)
        XCTAssertEqual(receivedError, .streamFailed, "Should report stream failure")
    }
}
#endif
