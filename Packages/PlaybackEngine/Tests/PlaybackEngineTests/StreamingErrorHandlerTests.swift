//
//  StreamingErrorHandlerTests.swift
//  PlaybackEngineTests
//
//  Created for Issue 28.1 - Phase 3: Network Interruption Handling
//  Tests exponential backoff retry logic for streaming errors
//

import XCTest
import Combine
@testable import PlaybackEngine
import TestSupport

/// Tests for StreamingErrorHandler's retry logic
///
/// **Spec**: streaming-playback.md - "Retry logic with exponential backoff"
///
/// **Testing Pattern**: Uses `InstantDelayProvider` for deterministic, instant retries
/// (following the established `DeterministicTicker` pattern).
final class StreamingErrorHandlerTests: XCTestCase {

    private var handler: StreamingErrorHandler!
    private var delayProvider: InstantDelayProvider!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        delayProvider = InstantDelayProvider()
        handler = StreamingErrorHandler(delayProvider: delayProvider)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        handler = nil
        delayProvider = nil
        super.tearDown()
    }

    // MARK: - Retry State Tests

    /// Test: Initial retry state is idle
    func testInitialRetryStateIsIdle() {
        // Then: State should be idle
        XCTAssertEqual(handler.retryState, .idle)
    }

    /// Test: First error schedules retry with attempt 1
    func testFirstErrorSchedulesRetry() async {
        // Given: Fresh handler
        XCTAssertEqual(handler.retryState, .idle)

        // When: First error occurs
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let didSchedule = await handler.handleError(error)

        // Then: Retry should be scheduled
        XCTAssertTrue(didSchedule, "First error should schedule retry")
        XCTAssertEqual(handler.retryState, .retrying(attempt: 1))
    }

    /// Test: Second error schedules retry with attempt 2
    func testSecondErrorSchedulesRetry() async {
        // Given: Handler that already had one retry
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)

        // When: Second error occurs
        let didSchedule = await handler.handleError(error)

        // Then: Second retry should be scheduled
        XCTAssertTrue(didSchedule, "Second error should schedule retry")
        XCTAssertEqual(handler.retryState, .retrying(attempt: 2))
    }

    /// Test: Third error schedules retry with attempt 3
    func testThirdErrorSchedulesRetry() async {
        // Given: Handler that already had two retries
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)

        // When: Third error occurs
        let didSchedule = await handler.handleError(error)

        // Then: Third retry should be scheduled
        XCTAssertTrue(didSchedule, "Third error should schedule retry")
        XCTAssertEqual(handler.retryState, .retrying(attempt: 3))
    }

    /// Test: Fourth error exceeds retry limit
    func testFourthErrorExceedsLimit() async {
        // Given: Handler that already had three retries
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)

        // When: Fourth error occurs
        let didSchedule = await handler.handleError(error)

        // Then: Retry should NOT be scheduled (limit exceeded)
        XCTAssertFalse(didSchedule, "Fourth error should not schedule retry")
        XCTAssertEqual(handler.retryState, .failed)
    }

    // MARK: - Reset Tests

    /// Test: Reset clears retry state
    func testResetClearsRetryState() async {
        // Given: Handler with some retries
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)
        XCTAssertEqual(handler.retryState, .retrying(attempt: 2))

        // When: Reset is called
        handler.reset()

        // Then: State should return to idle
        XCTAssertEqual(handler.retryState, .idle)

        // And: Next error should start from attempt 1
        _ = await handler.handleError(error)
        XCTAssertEqual(handler.retryState, .retrying(attempt: 1))
    }

    // MARK: - Cancel Tests

    /// Test: Cancel stops pending retry
    func testCancelStopsPendingRetry() async {
        // Given: Handler with retry callback
        var retryExecuted = false
        handler.onRetry = {
            retryExecuted = true
        }

        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)

        // When: Cancel is called immediately (before instant retry task completes)
        handler.cancelRetry()

        // Wait briefly for any pending tasks
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then: Retry should not have executed (was cancelled)
        XCTAssertFalse(retryExecuted, "Cancelled retry should not execute")
    }

    // MARK: - Retry Callback Tests

    /// Test: Retry callback is invoked after delay
    func testRetryCallbackInvoked() async {
        // Given: Handler with retry callback
        var retryExecuted = false

        handler.onRetry = {
            retryExecuted = true
        }

        // When: Error occurs (should schedule instant retry with InstantDelayProvider)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let didSchedule = await handler.handleError(error)

        // Wait briefly for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s for task scheduling

        // Then: Callback should be invoked instantly (no 5s wait!)
        XCTAssertTrue(didSchedule, "Retry should be scheduled")
        XCTAssertTrue(retryExecuted, "Retry callback should execute instantly")

        // Verify delay was requested (but instant)
        XCTAssertEqual(delayProvider.delayCount, 1, "Should have requested one delay")
        XCTAssertEqual(delayProvider.totalSecondsRequested, 5.0, "Should have requested 5s delay")
    }

    // MARK: - Publisher Tests

    /// Test: Publisher emits state changes
    func testPublisherEmitsStateChanges() async {
        // Given: Subscriber to retry state changes
        let expectation = XCTestExpectation(description: "Retrying state emitted")

        var retryingStateEmitted = false

        handler.retryStatePublisher
            .sink { state in
                if case .retrying(let attempt) = state, attempt == 1 {
                    retryingStateEmitted = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: Error occurs
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)

        // Then: Publisher should emit retrying state
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(retryingStateEmitted, "Retrying state should be emitted")
        XCTAssertEqual(handler.retryState, .retrying(attempt: 1))
    }

    /// Test: Publisher emits failed state when limit exceeded
    func testPublisherEmitsFailedState() async {
        // Given: Subscriber to retry state changes
        let expectation = XCTestExpectation(description: "Failed state emitted")

        var failedStateEmitted = false

        handler.retryStatePublisher
            .sink { state in
                if state == .failed {
                    failedStateEmitted = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: Four errors occur (exceeding limit)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)
        _ = await handler.handleError(error)

        // Then: Failed state should be emitted
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(failedStateEmitted, "Failed state should be emitted")
    }

    // MARK: - Retryable Error Tests

    /// Test: Network timeout errors are retryable
    func testNetworkTimeoutIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Cannot find host errors are retryable
    func testCannotFindHostIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Cannot connect to host errors are retryable
    func testCannotConnectToHostIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Network connection lost errors are retryable
    func testNetworkConnectionLostIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: DNS lookup failed errors are retryable
    func testDNSLookupFailedIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Not connected to internet errors are retryable
    func testNotConnectedToInternetIsRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Unknown domain errors are not retryable
    func testUnknownDomainErrorNotRetryable() {
        let error = NSError(domain: "com.example.unknown", code: 999)
        XCTAssertFalse(StreamingErrorHandler.isRetryableError(error))
    }

    /// Test: Non-network URL errors are not retryable
    func testNonNetworkURLErrorNotRetryable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        XCTAssertFalse(StreamingErrorHandler.isRetryableError(error))
    }
}
