#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
import Foundation
import CoreModels

/// Represents playback lifecycle states for an episode.
public enum EpisodePlaybackState: Equatable, Sendable {
  case idle(Episode)
  case playing(Episode, position: TimeInterval, duration: TimeInterval)
  case paused(Episode, position: TimeInterval, duration: TimeInterval)
  case finished(Episode, duration: TimeInterval)
}

/// Abstraction for time tick generation - allows deterministic tests.
public protocol Ticker: Sendable {
  func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void)
  func cancel()
}

/// Protocol for a playback service with extended controls for speed, seeking, and episode management.
@MainActor
public protocol EpisodePlaybackService {
  #if canImport(Combine)
  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> { get }
  #endif
  func play(episode: Episode, duration: TimeInterval?)
  func pause()
}

/// Basic implementation for testing and cross-platform compatibility
@MainActor
public final class StubEpisodePlayer: EpisodePlaybackService {
  #if canImport(Combine)
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>
  
  public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }
  #endif
  
  private let ticker: Ticker
  private var currentEpisode: Episode
  private var isPlaying = false
  private var currentPosition: TimeInterval = 0
  private var currentDuration: TimeInterval = 300
  private var generation = 0

  public init(initialEpisode: Episode? = nil, ticker: Ticker) {
    let ep = initialEpisode ?? Episode(id: "stub", title: "Stub", description: "Stub episode")
    self.currentEpisode = ep
    self.ticker = ticker
    #if canImport(Combine)
    self.subject = CurrentValueSubject(.idle(ep))
    #endif
  }

  public func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    let normalized = (maybeDuration ?? 300) > 0 ? (maybeDuration ?? 300) : 300
    currentEpisode = episode
    isPlaying = true
    currentDuration = normalized
    currentPosition = 0
    generation += 1
    
    #if canImport(Combine)
    subject.send(.playing(episode, position: 0, duration: normalized))
    #endif
  }

  public func pause() {
    isPlaying = false
    #if canImport(Combine)
    subject.send(.paused(currentEpisode, position: currentPosition, duration: currentDuration))
    #endif
  }
}

extension StubEpisodePlayer: EpisodeTransportControlling {
  public func skipForward(interval: TimeInterval?) {
    let delta = interval ?? 30
    currentPosition = min(currentPosition + delta, currentDuration)
    emitTransportState()
  }

  public func skipBackward(interval: TimeInterval?) {
    let delta = interval ?? 15
    currentPosition = max(currentPosition - delta, 0)
    emitTransportState()
  }

  public func seek(to position: TimeInterval) {
    currentPosition = min(max(position, 0), currentDuration)
    emitTransportState()
  }

  private func emitTransportState() {
    #if canImport(Combine)
      if isPlaying {
        subject.send(.playing(currentEpisode, position: currentPosition, duration: currentDuration))
      } else {
        subject.send(.paused(currentEpisode, position: currentPosition, duration: currentDuration))
      }
    #endif
  }
}

/// Simple timer-based ticker for testing
/// 
/// @unchecked Sendable: This class manages a single Timer instance that is accessed
/// from a single actor context. Timer invalidation and assignment are atomic operations,
/// making cross-actor access safe despite Timer not being Sendable.
public final class TimerTicker: Ticker, @unchecked Sendable {
  private var timer: Timer?
  
  public init() {}
  
  public func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
    cancel()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      tick()
    }
  }
  
  public func cancel() {
    timer?.invalidate()
    timer = nil
  }
}
