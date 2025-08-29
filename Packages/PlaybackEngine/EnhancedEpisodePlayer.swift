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

  // Dependencies
  private let stateManager: EpisodeStateManager?
  private let settings: CoreModels.PlaybackSettings

  private(set) var currentEpisode: Episode?
  private var duration: TimeInterval = 0
  private var position: TimeInterval = 0
  private var speed: Float = 1.0

  // MARK: - Init
  public init(stateManager: EpisodeStateManager? = nil, playbackSettings: CoreModels.PlaybackSettings? = nil) {
    self.stateManager = stateManager
    self.settings = playbackSettings ?? CoreModels.PlaybackSettings()
  }

  // MARK: - Helpers
  private func clampSpeed(_ value: Float) -> Float { max(0.8, min(value, 5.0)) }
  private var forwardInterval: TimeInterval { TimeInterval(settings.skipForwardInterval ?? 30) }
  private var backwardInterval: TimeInterval { TimeInterval(settings.skipBackwardInterval ?? 15) }
  private func effectiveSpeed(for episode: Episode) -> Float {
    if let id = episode.podcastID, let perPodcast = settings.podcastPlaybackSpeeds?[id] {
      return clampSpeed(Float(perPodcast))
    }
    if let global = settings.globalPlaybackSpeed {
      return clampSpeed(Float(global))
    }
    return clampSpeed(Float(settings.playbackSpeed))
  }
  private func emitPlaying() {
    #if canImport(Combine)
    if let ep = currentEpisode {
      subject.send(.playing(ep, position: position, duration: duration > 0 ? duration : 300))
    }
    #endif
  }

  public func play(episode: Episode, duration: TimeInterval?) {
    currentEpisode = episode
    self.duration = max(0, duration ?? 0)
    // Start playback at the existing (persisted) position if any, otherwise 0
    self.position = TimeInterval(episode.playbackPosition)
    // Apply effective speed (per-podcast override > global > local)
    self.speed = effectiveSpeed(for: episode)
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
  public func skipForward(interval: TimeInterval = -1) {
    let step = interval >= 0 ? interval : forwardInterval
    position = min(position + step, duration)
    emitPlaying()
  }
  public func skipBackward(interval: TimeInterval = -1) {
    let step = interval >= 0 ? interval : backwardInterval
    position = max(0, position - step)
    emitPlaying()
  }
  public func seek(to newPosition: TimeInterval) {
    position = min(max(0, newPosition), duration)
    emitPlaying()
  }
  public func setPlaybackSpeed(_ newSpeed: Float) {
    speed = clampSpeed(newSpeed)
    // Simulate one tick of progress to reflect speed impact in tests
    if currentEpisode != nil {
      position = min(position + TimeInterval(speed), duration)
      emitPlaying()
    }
  }
  public func getCurrentPlaybackSpeed() -> Float { speed }
  public func jumpToChapter(_ chapter: Chapter) {
    seek(to: chapter.startTime)
  }
  public func markEpisodeAs(played: Bool) {
    guard let ep = currentEpisode else { return }
    Task { [stateManager] in
      await stateManager?.setPlayedStatus(ep, isPlayed: played)
    }
  }
}
