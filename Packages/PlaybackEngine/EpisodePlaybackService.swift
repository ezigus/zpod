#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation

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
  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> { get }
  func play(episode: Episode, duration: TimeInterval?)
  func pause()
}

/// Extended playback service protocol for advanced features
@MainActor
public protocol ExtendedEpisodePlaybackService: EpisodePlaybackService {
  func seek(to time: TimeInterval)
  func skipForward()
  func skipBackward()
  func setPlaybackSpeed(_ speed: Float)
  func getCurrentPlaybackSpeed() -> Float
  func jumpToChapter(_ chapter: Chapter)
  func markEpisodeAs(played: Bool)
}

/// Default ticker using a repeating Timer (not used in tests; tests inject ManualTicker).
public final class TimerTicker: Ticker, @unchecked Sendable {
  private let lock = NSLock()
  private var timer: Timer?

  public init() {}

  public func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
    lock.lock()
    defer { lock.unlock() }
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in tick() }
    RunLoop.main.add(timer!, forMode: .common)
  }

  public func cancel() {
    lock.lock()
    defer { lock.unlock() }
    timer?.invalidate()
    timer = nil
  }

  deinit {
    lock.lock()
    timer?.invalidate()
    lock.unlock()
  }
}

/// Stub player simulating playback progression without audio output.
@MainActor
public final class StubEpisodePlayer: EpisodePlaybackService {
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>
  private let ticker: Ticker
  private var currentEpisode: Episode
  private var duration: TimeInterval = 0
  private var position: TimeInterval = 0
  private var playing = false
  private var generation = 0

  public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }

  public init(initialEpisode: Episode? = nil, ticker: Ticker) {
    let ep = initialEpisode ?? Episode(id: "stub", title: "Stub")
    self.currentEpisode = ep
    self.ticker = ticker
    self.subject = CurrentValueSubject(.idle(ep))
  }

  public func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    let normalized = (maybeDuration ?? 300) > 0 ? (maybeDuration ?? 300) : 300
    
    // Check if we're restarting a finished episode
    if case .finished(let finishedEp, _) = subject.value, finishedEp.id == episode.id {
      position = 0
    }
    
    // Check if switching episodes
    if episode.id != currentEpisode.id {
      currentEpisode = episode
      position = 0
    } else if playing {
      // Already playing same episode - no-op
      return
    }
    
    duration = normalized
    generation &+= 1
    playing = true
    
    emit(.playing(currentEpisode, position: position, duration: duration))
    
    let localGen = generation
    ticker.schedule(every: 1.0) { [weak self] in
      guard let self = self else { return }
      self.tickNonisolated(expectedGeneration: localGen)
    }
  }

  public func pause() {
    guard playing else { return }
    playing = false
    generation &+= 1  // invalidate scheduled ticks
    ticker.cancel()
    emit(.paused(currentEpisode, position: position, duration: duration))
  }

  nonisolated private func tickNonisolated(expectedGeneration: Int) {
    MainActor.assumeIsolated {
      self.tick(expectedGeneration: expectedGeneration)
    }
  }

  private func tick(expectedGeneration: Int) {
    guard playing, expectedGeneration == generation else { return }
    position += 1
    if position >= duration {
      position = duration
      playing = false
      ticker.cancel()
      emit(.finished(currentEpisode, duration: duration))
    } else {
      emit(.playing(currentEpisode, position: position, duration: duration))
    }
  }

  private func emit(_ state: EpisodePlaybackState) {
    subject.send(state)
  }
}
