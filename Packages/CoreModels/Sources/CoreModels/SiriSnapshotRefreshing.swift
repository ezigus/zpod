import Foundation

/// Protocol for refreshing Siri media library snapshots.
///
/// Implementations persist podcast/episode metadata to shared storage (e.g., app groups)
/// so that Siri intents can resolve media queries without launching the main app.
///
/// ## Usage
/// Production code provides a `SiriSnapshotCoordinator` that writes to UserDefaults.
/// Test code can use a spy implementation to verify refresh calls without side effects.
///
/// ## Thread Safety
/// Implementations should be thread-safe (`Sendable`) as refresh may be called from any context.
public protocol SiriSnapshotRefreshing: Sendable {
    /// Refreshes all podcast snapshots for Siri media queries.
    ///
    /// Called after library mutations (add, update, remove) to keep Siri's view in sync.
    func refreshAll()
}
