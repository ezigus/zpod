//
//  InstantDelayProvider.swift
//  TestSupport
//
//  Created for Issue 28.1 - Phase 3: Network Interruption Handling
//  Provides instant delays for deterministic testing
//

import Foundation
@testable import PlaybackEngine

/// Test delay provider that returns immediately for instant, deterministic tests
///
/// Similar to `DeterministicTicker`, this allows tests to control timing precisely
/// without waiting for real delays.
///
/// Example:
/// ```swift
/// let delayProvider = InstantDelayProvider()
/// let handler = StreamingErrorHandler(delayProvider: delayProvider)
///
/// // Retry happens instantly instead of waiting 5 seconds
/// let didSchedule = await handler.handleError(error)
/// ```
///
/// ## Thread Safety
///
/// This class uses `@unchecked Sendable` because it is designed exclusively for single-actor
/// test contexts (following the same pattern as `DeterministicTicker`).
/// All calls must originate from the same actor context.
public final class InstantDelayProvider: DelayProvider, @unchecked Sendable {
    /// Number of delays that have been requested
    public private(set) var delayCount = 0

    /// Total seconds requested across all delays
    public private(set) var totalSecondsRequested: TimeInterval = 0

    public init() {}

    /// Returns immediately without any actual delay
    public func delay(seconds: TimeInterval) async throws {
        delayCount += 1
        totalSecondsRequested += seconds
        // Return immediately - no actual delay
        await Task.yield() // Yield to let other tasks run, but don't actually wait
    }
}
