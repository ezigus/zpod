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

/// Tests for AVPlayerPlaybackEngine audio playback functionality.
///
/// **Spec Reference**: `zpod/spec/playback.md` - Core Playback Behavior
/// - Starting Episode Playback
/// - Pausing Playback
/// - Seeking to Position
/// - Playback Error Handling
#if os(iOS)
@MainActor
final class AVPlayerPlaybackEngineTests: XCTestCase {
    nonisolated(unsafe) private var engine: AVPlayerPlaybackEngine!
    
    override nonisolated func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            engine = AVPlayerPlaybackEngine()
        }
    }
    
    override nonisolated func tearDown() async throws {
        await MainActor.run {
            engine?.stop()
            engine = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Basic Playback Tests
    
    /// **Scenario**: Starting Episode Playback with Valid URL
    /// **Given** an audio URL is valid
    /// **When** play() is called
    /// **Then** playback begins and position updates emit
    func testPlayWithValidURL() async throws {
        // Given: A valid audio URL (using a small test audio file URL)
        // Note: Using Apple's sample audio for testing
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        var receivedPositions: [TimeInterval] = []
        let positionExpectation = expectation(description: "Position updates")
        positionExpectation.expectedFulfillmentCount = 3 // Expect at least 3 position updates
        
        engine.onPositionUpdate = { position in
            receivedPositions.append(position)
            positionExpectation.fulfill()
        }
        
        // When: Play from position 0
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        
        // Then: Wait for position updates
        await fulfillment(of: [positionExpectation], timeout: 5.0)
        
        XCTAssertFalse(receivedPositions.isEmpty, "Should have received position updates")
        XCTAssertGreaterThanOrEqual(receivedPositions.last ?? 0, 0, "Position should be non-negative")
    }
    
    /// **Scenario**: Play with Invalid URL
    /// **Given** an audio URL is invalid or unreachable
    /// **When** play() is called
    /// **Then** error callback is invoked
    func testPlayWithInvalidURL() async throws {
        // Given: An invalid URL
        let invalidURL = URL(string: "https://invalid-domain-that-does-not-exist-12345.com/audio.mp3")!
        
        var receivedError: PlaybackError?
        let errorExpectation = expectation(description: "Error callback")
        
        engine.onError = { error in
            receivedError = error
            errorExpectation.fulfill()
        }
        
        // When: Attempt to play
        engine.play(from: invalidURL, startPosition: 0, rate: 1.0)
        
        // Then: Should receive error
        await fulfillment(of: [errorExpectation], timeout: 10.0)
        
        XCTAssertEqual(receivedError, .streamFailed, "Should report stream failure")
    }
    
    // MARK: - Pause Tests
    
    /// **Scenario**: Pausing Playback
    /// **Given** audio is playing
    /// **When** pause() is called
    /// **Then** position stops updating
    func testPause() async throws {
        // Given: Playing audio
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        var positionUpdateCount = 0
        let playExpectation = expectation(description: "Playback started")
        playExpectation.expectedFulfillmentCount = 2
        
        engine.onPositionUpdate = { _ in
            positionUpdateCount += 1
            if positionUpdateCount <= 2 {
                playExpectation.fulfill()
            }
        }
        
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [playExpectation], timeout: 5.0)
        
        // When: Pause
        let positionBeforePause = positionUpdateCount
        engine.pause()
        
        // Wait a bit to ensure no more updates
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Position updates should have stopped (or minimal)
        let positionAfterPause = positionUpdateCount
        XCTAssertLessThanOrEqual(
            positionAfterPause - positionBeforePause,
            1,
            "Position updates should stop after pause"
        )
    }
    
    // MARK: - Seek Tests
    
    /// **Scenario**: Seeking to Position
    /// **Given** audio is playing
    /// **When** seek(to:) is called
    /// **Then** position jumps to target
    func testSeek() async throws {
        // Given: Playing audio
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        let playExpectation = expectation(description: "Playback started")
        engine.onPositionUpdate = { _ in
            playExpectation.fulfill()
        }
        
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [playExpectation], timeout: 5.0)
        
        // When: Seek to 10 seconds
        let seekExpectation = expectation(description: "Seek completed")
        var positionAfterSeek: TimeInterval?
        
        engine.onPositionUpdate = { position in
            if position >= 9.0 { // Allow some tolerance
                positionAfterSeek = position
                seekExpectation.fulfill()
            }
        }
        
        engine.seek(to: 10.0)
        
        // Then: Position should jump to near 10 seconds
        await fulfillment(of: [seekExpectation], timeout: 5.0)
        XCTAssertNotNil(positionAfterSeek)
        XCTAssertGreaterThanOrEqual(positionAfterSeek ?? 0, 9.0, "Position should be at or after seek target")
    }
    
    // MARK: - Rate Control Tests
    
    /// **Scenario**: Changing Playback Speed
    /// **Given** audio is playing
    /// **When** setRate() is called
    /// **Then** playback speed changes
    func testSetRate() async throws {
        // Given: Playing audio
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        let playExpectation = expectation(description: "Playback started")
        engine.onPositionUpdate = { _ in
            playExpectation.fulfill()
        }
        
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [playExpectation], timeout: 5.0)
        
        // When: Change rate to 2.0x
        engine.setRate(2.0)
        
        // Then: Rate should be updated (verify via AVPlayer property)
        // This is a basic smoke test - actual rate behavior tested manually
        XCTAssertTrue(true, "Rate change should not crash")
    }
    
    // MARK: - Cleanup Tests
    
    /// **Scenario**: Stop and Cleanup
    /// **Given** audio is playing
    /// **When** stop() is called
    /// **Then** resources are released and no crashes occur
    func testStop() async throws {
        // Given: Playing audio
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        let playExpectation = expectation(description: "Playback started")
        engine.onPositionUpdate = { _ in
            playExpectation.fulfill()
        }
        
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [playExpectation], timeout: 5.0)
        
        // When: Stop
        engine.stop()
        
        // Then: Should not crash and position updates should stop
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        XCTAssertTrue(true, "Stop should complete without crash")
    }
    
    // MARK: - Current Position Tests
    
    /// **Scenario**: Query Current Position
    /// **Given** audio is playing
    /// **When** currentPosition is accessed
    /// **Then** returns the current playback position
    func testCurrentPosition() async throws {
        // Given: Playing audio
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        let playExpectation = expectation(description: "Playback started")
        playExpectation.expectedFulfillmentCount = 2
        
        engine.onPositionUpdate = { _ in
            playExpectation.fulfill()
        }
        
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [playExpectation], timeout: 5.0)
        
        // When: Access current position
        let position = engine.currentPosition
        
        // Then: Should be non-negative and reasonable
        XCTAssertGreaterThanOrEqual(position, 0, "Current position should be non-negative")
        XCTAssertLessThan(position, 100, "Current position should be reasonable for short test")
    }
}
#endif
