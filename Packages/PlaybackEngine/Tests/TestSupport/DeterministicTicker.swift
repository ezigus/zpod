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
/// @unchecked Sendable: This class is used exclusively in test contexts where a single
/// test case controls the ticker instance. All operations (schedule, cancel, tick) are
/// called from the test's main actor context sequentially, making concurrent access impossible.
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
