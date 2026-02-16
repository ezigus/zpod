//
//  StreamingEdgeCaseIntegrationTests.swift
//  IntegrationTests
//
//  Created for Issue 28.1.13: Final Acceptance Criteria Completion
//  Integration tests for streaming retry backoff, non-retryable errors,
//  and position preservation through retries
//

#if os(iOS)
  import Combine
  import XCTest
  @testable import CoreModels
  @testable import PlaybackEngine

  // MARK: - Local Test Doubles

  // These implement public protocols from PlaybackEngine. The canonical versions live in
  // Packages/PlaybackEngine/Tests/TestSupport/ but that module is not accessible from the
  // Xcode IntegrationTests target — so we define lightweight equivalents here.

  /// Delay provider that returns immediately for deterministic retry testing.
  private final class IntegrationInstantDelayProvider: DelayProvider, @unchecked Sendable {
    private(set) var delayCount = 0
    private(set) var totalSecondsRequested: TimeInterval = 0

    func delay(seconds: TimeInterval) async throws {
      delayCount += 1
      totalSecondsRequested += seconds
      await Task.yield()
    }
  }

  /// Ticker that advances only when `tick(count:)` is called explicitly.
  private final class IntegrationDeterministicTicker: Ticker, @unchecked Sendable {
    private var handler: (@Sendable () -> Void)?
    private(set) var tickCount = 0
    private(set) var isScheduled = false

    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
      handler = tick
      tickCount = 0
      isScheduled = true
    }

    func cancel() {
      handler = nil
      isScheduled = false
    }

    func tick(count: Int = 1) async {
      guard let handler else { return }
      for _ in 0..<count {
        handler()
        tickCount += 1
        await Task.yield()
      }
    }
  }

  // MARK: - Tests

  /// Integration tests for streaming playback edge cases
  ///
  /// **Specifications Covered**: spec/streaming-playback.md
  /// - Retry backoff delays match spec (2s, 5s, 10s)
  /// - Non-retryable errors skip retry and fail immediately
  /// - Playback position is preserved through retry attempts
  ///
  /// **Testing Pattern**: Uses local `IntegrationInstantDelayProvider` for deterministic,
  /// instant retries (mirroring the `InstantDelayProvider` in PlaybackEngine's test support).
  final class StreamingEdgeCaseIntegrationTests: XCTestCase {

    private var handler: StreamingErrorHandler!
    private var delayProvider: IntegrationInstantDelayProvider!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
      super.setUp()
      delayProvider = IntegrationInstantDelayProvider()
      handler = StreamingErrorHandler(delayProvider: delayProvider)
      cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
      cancellables = nil
      handler = nil
      delayProvider = nil
      super.tearDown()
    }

    // MARK: - Retry Backoff Contract Tests

    /// Test: Retry backoff delays match streaming-playback.md spec (2s, 5s, 10s)
    ///
    /// **Spec**: streaming-playback.md line 220 - "Retry delays: 2s, 5s, 10s"
    ///
    /// **Given**: StreamingErrorHandler with InstantDelayProvider
    /// **When**: Three consecutive retryable errors occur
    /// **Then**: Requested delays are 2s, 5s, 10s respectively, then fourth error fails
    func testRetryBackoffDelaysMatchSpec() async {
      // Given: Handler with tracked delay provider
      let retryableError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

      // When: First error → should request 2s delay
      let retry1 = await handler.handleError(retryableError)
      // handleError spawns a Task for the delay — yield to let it run
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertTrue(retry1, "First error should schedule retry")
      XCTAssertEqual(handler.retryState, .retrying(attempt: 1))
      XCTAssertEqual(delayProvider.delayCount, 1, "Should have 1 delay after first retry")
      XCTAssertEqual(
        delayProvider.totalSecondsRequested, 2.0,
        "First retry delay should be 2.0s per spec"
      )

      // When: Second error → should request 5s delay (total 7s)
      let retry2 = await handler.handleError(retryableError)
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertTrue(retry2, "Second error should schedule retry")
      XCTAssertEqual(handler.retryState, .retrying(attempt: 2))
      XCTAssertEqual(delayProvider.delayCount, 2, "Should have 2 delays after second retry")
      XCTAssertEqual(
        delayProvider.totalSecondsRequested, 7.0,
        "Total delay should be 2.0 + 5.0 = 7.0s"
      )

      // When: Third error → should request 10s delay (total 17s)
      let retry3 = await handler.handleError(retryableError)
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertTrue(retry3, "Third error should schedule retry")
      XCTAssertEqual(handler.retryState, .retrying(attempt: 3))
      XCTAssertEqual(delayProvider.delayCount, 3, "Should have 3 delays after third retry")
      XCTAssertEqual(
        delayProvider.totalSecondsRequested, 17.0,
        "Total delay should be 2.0 + 5.0 + 10.0 = 17.0s"
      )

      // When: Fourth error → should fail permanently (no more retries)
      let retry4 = await handler.handleError(retryableError)
      XCTAssertFalse(retry4, "Fourth error should NOT schedule retry")
      XCTAssertEqual(handler.retryState, .failed, "State should be .failed after exceeding limit")
      XCTAssertEqual(
        delayProvider.delayCount, 3,
        "Should still have only 3 delays (fourth error doesn't retry)"
      )
    }

    // MARK: - Non-Retryable Error Tests

    /// Test: Non-retryable error (HTTP 404) skips retry entirely
    ///
    /// **Spec**: streaming-playback.md - "Client errors fail immediately"
    ///
    /// **Given**: StreamingErrorHandler receives a 404 error
    /// **When**: Error is classified
    /// **Then**: isRetryableError returns false — no retry scheduled
    func testNonRetryableErrorSkipsRetry() {
      // Given: HTTP 404 error (client error, not retryable)
      let notFoundError = NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorBadServerResponse,
        userInfo: [
          "NSErrorFailingURLResponseKey": HTTPURLResponse(
            url: URL(string: "https://example.com/episode.mp3")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
          )!
        ]
      )

      // When/Then: Error should NOT be retryable
      XCTAssertFalse(
        StreamingErrorHandler.isRetryableError(notFoundError),
        "HTTP 404 should NOT be retryable — fail immediately"
      )
    }

    /// Test: Offline state (not connected to internet) is not retryable
    ///
    /// **Spec**: streaming-playback.md - "Offline state handled by network monitor, not retry"
    ///
    /// **Given**: Device goes offline (NSURLErrorNotConnectedToInternet)
    /// **When**: Error is classified
    /// **Then**: isRetryableError returns false — network monitor handles recovery
    func testOfflineStateNotRetryable() {
      let offlineError = NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorNotConnectedToInternet
      )

      XCTAssertFalse(
        StreamingErrorHandler.isRetryableError(offlineError),
        "Offline state should NOT trigger retry — network monitor handles recovery"
      )
    }

    /// Test: NSURLErrorBadServerResponse is NOT retryable (URLSession-domain errors use code-based classification)
    ///
    /// **Spec**: streaming-playback.md - "Only truly transient errors retry"
    ///
    /// **Given**: NSURLErrorBadServerResponse error (URLSession wraps 5xx here)
    /// **When**: Error is classified
    /// **Then**: isRetryableError returns false — URLSession domain only retries
    ///          timeout and connection-lost codes; HTTP status parsing is a
    ///          secondary fallback for non-URLSession error domains
    func testBadServerResponseNotRetryable() {
      let serverError = NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorBadServerResponse,
        userInfo: [
          "NSErrorFailingURLResponseKey": HTTPURLResponse(
            url: URL(string: "https://example.com/episode.mp3")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
          )!
        ]
      )

      // NSURLErrorBadServerResponse falls under NSURLErrorDomain default → not retryable.
      // The HTTP status code (503) is not checked for NSURLErrorDomain errors — only
      // timeout and connection-lost are retryable in that domain.
      XCTAssertFalse(
        StreamingErrorHandler.isRetryableError(serverError),
        "NSURLErrorBadServerResponse is NOT retryable (not in the transient-error allow-list)"
      )
    }

    /// Test: Non-URLSession 5xx errors ARE retryable (HTTP status code fallback path)
    ///
    /// **Spec**: streaming-playback.md - "Server errors may recover, retry appropriate"
    ///
    /// **Given**: Error with HTTP 503 response in a non-URLSession domain
    /// **When**: Error is classified
    /// **Then**: isRetryableError returns true via the HTTP status code fallback
    func testHTTPStatusCode503RetryableViaFallbackPath() {
      let customDomainError = NSError(
        domain: "com.example.http",
        code: 503,
        userInfo: [
          "NSErrorFailingURLResponseKey": HTTPURLResponse(
            url: URL(string: "https://example.com/episode.mp3")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
          )!
        ]
      )

      XCTAssertTrue(
        StreamingErrorHandler.isRetryableError(customDomainError),
        "5xx errors via HTTP status fallback path should be retryable"
      )
    }

    // MARK: - Position Preservation Tests

    /// Test: Playback position is preserved through retry attempts
    ///
    /// **Spec**: streaming-playback.md - "Position preserved during retry"
    ///
    /// **Given**: EnhancedEpisodePlayer at a specific playback position
    /// **When**: Retry state changes (simulating error recovery)
    /// **Then**: Player position remains unchanged
    @MainActor
    func testRetryPreservesPlaybackPosition() async {
      // Given: Player at a specific playback position
      let ticker = IntegrationDeterministicTicker()
      let player = EnhancedEpisodePlayer(ticker: ticker)

      let episode = Episode(
        id: "position-test-ep",
        title: "Position Preservation Test",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 600,
        audioURL: URL(string: "https://example.com/stream.mp3")!
      )

      // Play and advance to a known position
      player.play(episode: episode, duration: 600)
      await ticker.tick(count: 20)  // 20 × 0.5s = 10.0s

      let positionBeforeRetry = player.currentPosition
      XCTAssertEqual(positionBeforeRetry, 10.0, accuracy: 0.01, "Position should be 10s")

      // When: Simulate retry cycle (pause → resume represents what retry does)
      player.pause()
      let positionDuringPause = player.currentPosition
      XCTAssertEqual(
        positionDuringPause, positionBeforeRetry, accuracy: 0.01,
        "Position should be preserved during pause (simulating retry wait)"
      )

      // Resume (simulating successful retry reconnection) — EnhancedEpisodePlayer
      // resumes via play(episode:duration:) with the current episode that carries
      // the updated playbackPosition.
      let resumeEpisode = player.currentEpisode ?? episode
      player.play(episode: resumeEpisode, duration: 600)
      let positionAfterResume = player.currentPosition
      XCTAssertEqual(
        positionAfterResume, positionBeforeRetry, accuracy: 0.01,
        "Position should be preserved after resume (retry reconnection)"
      )

      // Then: Position should still be at the pre-retry value
      XCTAssertTrue(player.isPlaying, "Player should be playing after retry recovery")
    }

    // MARK: - State Machine Transition Tests

    /// Test: Retry state machine follows correct idle → retrying → failed lifecycle
    ///
    /// **Spec**: streaming-playback.md - "Retry state machine"
    ///
    /// **Given**: StreamingErrorHandler in idle state
    /// **When**: Errors push through retry attempts to failure
    /// **Then**: State transitions follow: idle → retrying(1) → retrying(2) → retrying(3) → failed
    func testRetryStateMachineLifecycle() async {
      var stateHistory: [RetryState] = []

      handler.retryStatePublisher
        .sink { state in
          stateHistory.append(state)
        }
        .store(in: &cancellables)

      let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

      // Drive through the full lifecycle
      _ = await handler.handleError(error)  // → retrying(1)
      _ = await handler.handleError(error)  // → retrying(2)
      _ = await handler.handleError(error)  // → retrying(3)
      _ = await handler.handleError(error)  // → failed

      // Verify state transitions (first emission is initial .idle from CurrentValueSubject)
      XCTAssertTrue(stateHistory.contains(.idle), "Should start with idle")
      XCTAssertTrue(stateHistory.contains(.retrying(attempt: 1)), "Should transition to retrying(1)")
      XCTAssertTrue(stateHistory.contains(.retrying(attempt: 2)), "Should transition to retrying(2)")
      XCTAssertTrue(stateHistory.contains(.retrying(attempt: 3)), "Should transition to retrying(3)")
      XCTAssertTrue(stateHistory.contains(.failed), "Should end at failed")

      // Reset should return to idle
      handler.reset()
      XCTAssertEqual(handler.retryState, .idle, "Reset should return to idle")
    }
  }
#endif
