import Foundation
import CoreModels

/// Test spy that records `refreshAll()` calls for verification.
///
/// Use this in tests to verify that podcast managers correctly trigger
/// Siri snapshot refreshes after library mutations.
///
/// ## Usage
/// ```swift
/// let spy = SpySiriSnapshotRefresher()
/// let manager = InMemoryPodcastManager(siriSnapshotRefresher: spy)
///
/// manager.add(podcast)
///
/// XCTAssertEqual(spy.refreshCallCount, 1)
/// ```
///
/// @unchecked Sendable: Uses NSLock for thread-safe counting.
public final class SpySiriSnapshotRefresher: SiriSnapshotRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var refreshCallCountValue = 0

    public init() {}

    /// Number of times `refreshAll()` was called.
    public var refreshCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshCallCountValue
    }

    /// Records a refresh call (thread-safe).
    public func refreshAll() {
        lock.lock()
        refreshCallCountValue += 1
        lock.unlock()
    }

    /// Resets the call counter to zero.
    public func reset() {
        lock.lock()
        refreshCallCountValue = 0
        lock.unlock()
    }
}
