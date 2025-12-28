import Foundation
@testable import PlaybackEngine

/// A deterministic ticker for testing that allows manual control of tick advancement.
///
/// Unlike `TimerTicker` which fires based on real time, `DeterministicTicker` only
/// advances when `tick(count:)` is called explicitly. This enables:
/// - Fast test execution (no real-time delays)
/// - Deterministic results (no timing variance)
/// - Precise control over tick sequences
///
/// Example:
/// ```swift
/// let ticker = DeterministicTicker()
/// let player = EnhancedEpisodePlayer(ticker: ticker)
///
/// player.play(episode: episode, duration: 60)
/// ticker.tick(count: 2)  // Advance exactly 2 ticks (1.0 second at 0.5s interval)
/// XCTAssertEqual(player.currentPosition, 1.0, accuracy: 0.01)
/// ```
///
/// ## Thread Safety
///
/// This class uses `@unchecked Sendable` because it is designed exclusively for single-actor
/// test contexts. The following constraints MUST be followed:
///
/// 1. **Single-actor access only**: All calls to `schedule()`, `cancel()`, and `tick()` must
///    originate from the same actor context (typically `@MainActor` in tests).
///
/// 2. **No concurrent tick calls**: While `tick()` is async and uses `Task.yield()`, this only
///    yields to the scheduler—it does not introduce true concurrency. However, calling `tick()`
///    multiple times concurrently (from different tasks) is NOT supported and will violate
///    internal state invariants.
///
/// 3. **Test-only usage**: This ticker should never be used in production code. Use `TimerTicker`
///    for real-world scenarios.
///
/// If concurrent access is ever required, convert this to an actor or add explicit locking.
public final class DeterministicTicker: Ticker, @unchecked Sendable {
  private var handler: (@Sendable () -> Void)?
  public private(set) var tickCount = 0
  public private(set) var isScheduled = false

  public init() {}

  /// Schedule a handler to be called on each manual tick.
  /// - Parameters:
  ///   - interval: Ignored (deterministic ticker doesn't use real time)
  ///   - tick: Closure to call on each manual tick
  public func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
    handler = tick
    tickCount = 0
    isScheduled = true
  }

  /// Cancel the scheduled handler.
  public func cancel() {
    handler = nil
    isScheduled = false
  }

  /// Manually trigger N ticks for deterministic testing.
  ///
  /// Each tick calls the handler closure provided to `schedule(every:_:)`.
  /// The handler is expected to advance playback position by the tick interval.
  ///
  /// This method must be called from an async context because the handler may
  /// spawn async tasks that need to complete before the next tick.
  ///
  /// - Parameter count: Number of ticks to advance (default: 1)
  public func tick(count: Int = 1) async {
    guard let handler else { return }
    for _ in 0..<count {
      handler()
      tickCount += 1
      // Yield to let any async tasks spawned by the handler complete
      await Task.yield()
    }
  }
}
