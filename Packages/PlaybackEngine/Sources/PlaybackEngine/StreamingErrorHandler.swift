//
//  StreamingErrorHandler.swift
//  PlaybackEngine
//
//  Created for Issue 28.1 - Phase 3: Network Interruption Handling
//  Implements retry logic with exponential backoff for streaming errors
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CFNetwork)
import CFNetwork
#endif
import Combine
import OSLog

/// Retry state for streaming operations
public enum RetryState: Equatable, Sendable {
    case idle
    case retrying(attempt: Int)
    case failed
}

/// Protocol for handling streaming errors with retry logic
public protocol StreamingErrorHandling: Sendable {
    /// Current retry state
    var retryState: RetryState { get }

    /// Publisher for retry state changes
    var retryStatePublisher: AnyPublisher<RetryState, Never> { get }

    /// Handle a streaming error and determine if retry should occur
    /// - Parameter error: The error that occurred
    /// - Returns: True if a retry is scheduled, false if retry limit exceeded
    func handleError(_ error: Error) async -> Bool

    /// Reset retry state (call when playback succeeds)
    func reset()

    /// Cancel any pending retry
    func cancelRetry()
}

/// Handles streaming errors with exponential backoff retry logic
///
/// Retry schedule:
/// - First retry: 5 seconds
/// - Second retry: 15 seconds
/// - Third retry: 60 seconds
/// - After 3 attempts: fail permanently
///
/// **Testing**: Uses `DelayProvider` for deterministic testing (similar to `DeterministicTicker`).
/// Inject `InstantDelayProvider` in tests for instant, predictable retries.
///
/// **Issue**: #28.1 - Phase 3: Network Interruption Handling
public final class StreamingErrorHandler: StreamingErrorHandling, @unchecked Sendable {

    // MARK: - Private Types

    private struct RetryDecision {
        let shouldRetry: Bool
        let attempt: Int?
        let stateToSend: RetryState?
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "us.zig.zpod", category: "StreamingErrorHandler")

    /// Exponential backoff delays (in seconds) for truly transient errors
    /// Per spec: streaming-playback.md line 220
    /// Fast retries appropriate for brief timeouts and connection drops
    private let retryDelays: [TimeInterval] = [2.0, 5.0, 10.0]

    /// Maximum number of retry attempts
    private let maxRetries: Int = 3

    /// Delay provider for testable timing control
    private let delayProvider: DelayProvider

    /// Serial queue for thread-safe access to state
    private let stateQueue = DispatchQueue(label: "us.zig.zpod.streamingerrorhandler.state")

    /// Current retry attempt count
    private var _retryAttempt: Int = 0

    /// Task for pending retry operation
    private var retryTask: Task<Void, Never>?

    /// Subject for retry state updates
    private let retryStateSubject = CurrentValueSubject<RetryState, Never>(.idle)

    /// Closure to call when retry should be attempted
    public var onRetry: (() async -> Void)?

    // MARK: - StreamingErrorHandling

    public var retryState: RetryState {
        stateQueue.sync { retryStateSubject.value }
    }

    public var retryStatePublisher: AnyPublisher<RetryState, Never> {
        retryStateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// Initialize with a delay provider
    /// - Parameter delayProvider: Provider for delays (defaults to real delays)
    public init(delayProvider: DelayProvider = RealDelayProvider()) {
        self.delayProvider = delayProvider
    }

    // MARK: - Public Methods

    /// Handle a streaming error and schedule retry if within limit
    ///
    /// - Parameter error: The error that occurred
    /// - Returns: True if retry scheduled, false if retry limit exceeded
    public func handleError(_ error: Error) async -> Bool {
        let result: RetryDecision = stateQueue.sync {
            if _retryAttempt >= maxRetries {
                return RetryDecision(shouldRetry: false, attempt: nil, stateToSend: .failed)
            }
            _retryAttempt += 1
            return RetryDecision(shouldRetry: true, attempt: _retryAttempt, stateToSend: .retrying(attempt: _retryAttempt))
        }

        if let state = result.stateToSend {
            retryStateSubject.send(state)
        }

        guard result.shouldRetry, let attempt = result.attempt else {
            return false
        }

        let delay = retryDelays[min(attempt - 1, retryDelays.count - 1)]
        logger.info("Scheduling retry attempt \(attempt) after \(delay) seconds")

        // Cancel any previously scheduled retry before scheduling a new one
        retryTask?.cancel()

        // Schedule retry with exponential backoff using injected delay provider
        retryTask = Task { @MainActor in
            do {
                try await self.delayProvider.delay(seconds: delay)

                guard !Task.isCancelled else {
                    self.logger.info("Retry attempt \(attempt) was cancelled")
                    return
                }

                self.logger.info("Executing retry attempt \(attempt)")
                await self.onRetry?()
            } catch {
                self.logger.error("Retry delay interrupted: \(error.localizedDescription)")
            }
        }

        return true
    }

    /// Reset retry state after successful playback
    public func reset() {
        stateQueue.sync {
            _retryAttempt = 0
        }
        retryStateSubject.send(.idle)
        cancelRetry()
        logger.info("Retry state reset")
    }

    /// Cancel any pending retry operation
    public func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
        logger.info("Pending retry cancelled")
    }

    // MARK: - Helper Methods

    /// Determine if an error is retryable
    ///
    /// **Only truly transient errors should retry.**
    /// Offline state and permanent errors should be handled differently:
    /// - Offline state → Network monitor will trigger recovery
    /// - Permanent errors → Show error UI immediately
    ///
    /// Retryable errors (truly transient):
    /// - Brief network timeouts (data delay, not offline)
    /// - Transient connection loss (momentary drop)
    /// - Server temporarily unavailable (5xx errors)
    ///
    /// Non-retryable errors (handled separately):
    /// - **Offline state** (NSURLErrorNotConnectedToInternet) → Trigger offline UI, wait for network monitor
    /// - **DNS/Host failures** (bad URL, server down) → Fail fast with clear error
    /// - **Client errors** (401, 403, 404) → Permanent, show error immediately
    public static func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors (domain NSURLErrorDomain)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            // ONLY truly transient errors - retry quickly
            case NSURLErrorTimedOut,              // Brief data timeout (not offline)
                 NSURLErrorNetworkConnectionLost: // Momentary connection drop
                return true

            // Offline state - should trigger network monitor, NOT retry
            case NSURLErrorNotConnectedToInternet:
                return false

            // DNS/Host failures - usually permanent, NOT transient
            case NSURLErrorCannotFindHost,     // Bad URL or DNS misconfiguration
                 NSURLErrorCannotConnectToHost, // Server is down
                 NSURLErrorDNSLookupFailed:     // DNS infrastructure problem
                return false

            default:
                return false
            }
        }

        // HTTP errors (status codes)
        if let httpResponse = nsError.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse
            ?? nsError.userInfo["NSErrorFailingURLResponseKey"] as? HTTPURLResponse
        {
            let statusCode = httpResponse.statusCode

            // Retry server errors (5xx) - server might recover
            if (500...599).contains(statusCode) {
                return true
            }

            // Don't retry client errors (4xx) - these are permanent
            return false
        }

        // Unknown errors - default to not retryable
        return false
    }
}
