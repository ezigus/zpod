#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import CoreModels

/// Enhanced episode player providing advanced controls.
@MainActor
public final class EnhancedEpisodePlayer: EpisodePlaybackService {
  #if canImport(Combine)
  private let subject = CurrentValueSubject<EpisodePlaybackState, Never>(.idle(Episode(id: "none", title: "")))
  public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> { subject.eraseToAnyPublisher() }
  #endif

  private(set) var currentEpisode: Episode?
  private var duration: TimeInterval = 0
  private var position: TimeInterval = 0
  private var speed: Float = 1.0

  public init() {}

  public func play(episode: Episode, duration: TimeInterval?) {
    currentEpisode = episode
    self.duration = max(0, duration ?? 0)
    position = 0
    #if canImport(Combine)
    subject.send(.playing(episode, position: position, duration: self.duration > 0 ? self.duration : 300))
    #endif
  }

  public func pause() {
    guard let ep = currentEpisode else { return }
    #if canImport(Combine)
    subject.send(.paused(ep, position: position, duration: max(duration, 300)))
    #endif
  }

  // MARK: - Enhanced Controls
  public func skipForward(interval: TimeInterval = 30) { position = min(position + interval, duration) }
  public func skipBackward(interval: TimeInterval = 15) { position = max(0, position - interval) }
  public func seek(to newPosition: TimeInterval) { position = min(max(0, newPosition), duration) }
  public func setPlaybackSpeed(_ newSpeed: Float) { speed = max(0.5, min(newSpeed, 3.0)) }
  public func getCurrentPlaybackSpeed() -> Float { speed }
  public func jumpToChapter(_ chapter: Chapter) { seek(to: chapter.startTime) }
  public func markEpisodeAs(played: Bool) {
    // No-op stub for now; state persistence done via EpisodeStateManager in real impl
  }
}
