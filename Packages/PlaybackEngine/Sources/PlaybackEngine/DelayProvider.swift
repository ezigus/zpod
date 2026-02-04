//
//  DelayProvider.swift
//  PlaybackEngine
//
//  Created for Issue 28.1 - Phase 3: Network Interruption Handling
//  Provides abstraction for delays to enable deterministic testing
//

import Foundation

/// Protocol for providing delays in a testable way
///
/// This abstraction allows production code to use real delays while tests
/// can use instant delays for fast, deterministic execution.
///
/// Similar to the `Ticker` protocol pattern used for playback position advancement.
public protocol DelayProvider: Sendable {
    /// Delay execution for the specified duration
    /// - Parameter seconds: Number of seconds to delay
    func delay(seconds: TimeInterval) async throws
}

/// Production delay provider that uses real Task.sleep
public struct RealDelayProvider: DelayProvider {
    public init() {}

    public func delay(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
