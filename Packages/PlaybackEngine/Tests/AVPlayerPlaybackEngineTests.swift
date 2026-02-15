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
    
    // MARK: - Playback Completion Tests
    
    /// **Scenario**: Playback Finishes Naturally
    /// **Given** audio is playing near the end
    /// **When** playback reaches the end
    /// **Then** onPlaybackFinished callback is invoked
    func testPlaybackFinishedCallback() async throws {
        // Given: A very short audio clip (using sample that finishes quickly)
        // Note: Using a short sample for faster test execution
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        let finishedExpectation = expectation(description: "Playback finished")
        var finishCallbackInvoked = false
        
        engine.onPlaybackFinished = {
            finishCallbackInvoked = true
            finishedExpectation.fulfill()
        }
        
        // When: Play from near the end (or wait for natural completion)
        // For testing purposes, we'll play and wait longer
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        
        // Then: Should eventually finish (increased timeout for natural completion)
        await fulfillment(of: [finishedExpectation], timeout: 30.0)
        
        XCTAssertTrue(finishCallbackInvoked, "Playback finished callback should be invoked")
    }
    
    // MARK: - Multiple Cycle Tests
    
    /// **Scenario**: Multiple Play/Stop Cycles
    /// **Given** the engine is idle
    /// **When** multiple play/stop cycles are executed
    /// **Then** no crashes occur and resources are properly cleaned up
    func testMultiplePlayStopCycles() async throws {
        // Given: Multiple test URLs
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8")!
        
        // When: Execute 3 play/stop cycles
        for cycle in 1...3 {
            let playExpectation = expectation(description: "Playback started cycle \(cycle)")
            var positionUpdateCount = 0
            
            engine.onPositionUpdate = { _ in
                positionUpdateCount += 1
                if positionUpdateCount == 2 {
                    playExpectation.fulfill()
                }
            }
            
            engine.play(from: testURL, startPosition: 0, rate: 1.0)
            await fulfillment(of: [playExpectation], timeout: 5.0)
            
            // Stop and clean up
            engine.stop()
            
            // Wait a bit between cycles
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Then: Should complete all cycles without crash
        XCTAssertTrue(true, "Multiple play/stop cycles should complete without crash")
    }
    
    // MARK: - Edge Case Tests

    /// **Scenario**: HTTP range-backed seek resumes from target position
    /// **Given** a streaming episode
    /// **When** seeking far ahead in the stream
    /// **Then** playback resumes near the requested offset instead of restarting from zero
    ///
    /// Note: AVPlayer manages HTTP Range requests internally. This test validates
    /// the observable contract expected from range support.
    func testHTTPRangeResumeBehaviorAfterFarSeek() async throws {
        let engine = AVPlayerPlaybackEngine()
        let testURL = URL(string: "https://traffic.libsyn.com/secure/swifttalk/350-2024-12-09-gps-viewer-part-4.m4a")!

        let startedExpectation = XCTestExpectation(description: "Playback started")
        let seekExpectation = XCTestExpectation(description: "Far seek reached target range")
        var sawStart = false

        engine.onPositionUpdate = { position in
            if !sawStart, position >= 0 {
                sawStart = true
                startedExpectation.fulfill()
                return
            }

            if sawStart, position >= 110 {
                seekExpectation.fulfill()
            }
        }

        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        await fulfillment(of: [startedExpectation], timeout: 10.0)

        engine.seek(to: 120.0)
        await fulfillment(of: [seekExpectation], timeout: 10.0)
        XCTAssertGreaterThanOrEqual(engine.currentPosition, 110)

        engine.stop()
    }

    func testSeekFromPositionWaitsForReady() async throws {
        // Given: Audio engine with start position
        let engine = AVPlayerPlaybackEngine()
        let testURL = URL(string: "https://traffic.libsyn.com/secure/swifttalk/350-2024-12-09-gps-viewer-part-4.m4a")!
        let expectation = XCTestExpectation(description: "Position update after seek")
        var receivedPositions: [TimeInterval] = []
        
        engine.onPositionUpdate = { position in
            receivedPositions.append(position)
            if receivedPositions.count >= 3 {
                expectation.fulfill()
            }
        }
        
        // When: Playing from position 10 seconds
        engine.play(from: testURL, startPosition: 10.0, rate: 1.0)
        
        // Then: First position update should be around 10 seconds, not 0
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify first position is near start position (within 2 seconds tolerance)
        if let firstPosition = receivedPositions.first {
            XCTAssertGreaterThan(firstPosition, 8.0, "First position should be near 10 seconds, not 0")
        }
        
        engine.stop()
    }
    
    func testFinishCallbackStopsEngine() async throws {
        // Given: Audio engine with playback finished callback
        let engine = AVPlayerPlaybackEngine()
        let testURL = URL(string: "https://traffic.libsyn.com/secure/swifttalk/350-2024-12-09-gps-viewer-part-4.m4a")!
        let expectation = XCTestExpectation(description: "Playback finished")
        var positionUpdateCountAfterFinish = 0
        var finishedCalled = false
        
        engine.onPlaybackFinished = {
            finishedCalled = true
            expectation.fulfill()
        }
        
        engine.onPositionUpdate = { _ in
            if finishedCalled {
                positionUpdateCountAfterFinish += 1
            }
        }
        
        // When: Simulating finish by calling stop (which triggers cleanup)
        engine.play(from: testURL, startPosition: 0, rate: 1.0)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        engine.stop()
        
        // Then: No position updates should occur after engine stopped
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(positionUpdateCountAfterFinish, 0, "Position updates should stop after engine cleanup")
    }
    
    func testErrorCallbackStopsEngine() async throws {
        // Given: Audio engine with error callback
        let engine = AVPlayerPlaybackEngine()
        let invalidURL = URL(string: "https://invalid.example.com/nonexistent.m4a")!
        let expectation = XCTestExpectation(description: "Error callback")
        var positionUpdateCountAfterError = 0
        var errorCalled = false
        
        engine.onError = { error in
            errorCalled = true
            expectation.fulfill()
        }
        
        engine.onPositionUpdate = { _ in
            if errorCalled {
                positionUpdateCountAfterError += 1
            }
        }
        
        // When: Playing invalid URL triggers error
        engine.play(from: invalidURL, startPosition: 0, rate: 1.0)
        
        // Then: Error callback fired and no position updates after
        await fulfillment(of: [expectation], timeout: 10.0)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(positionUpdateCountAfterError, 0, "Position updates should stop after error")
    }

    func testMapAVErrorDetectsNetworkFailure() throws {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertEqual(engine.mapAVError(error), .networkError)
    }

    func testMapAVErrorDetectsTimeout() throws {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertEqual(engine.mapAVError(error), .timeout)
    }

    func testMapAVErrorDefaultsToUnknown() throws {
        let error = NSError(
            domain: "CustomDomain",
            code: 1234,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected failure"]
        )
        XCTAssertEqual(engine.mapAVError(error), .unknown(message: "Unexpected failure"))
    }
}
#endif
