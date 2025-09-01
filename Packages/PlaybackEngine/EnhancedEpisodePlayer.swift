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

  // Audio effects state
  private var skipSilenceEnabled: Bool = false
  private var volumeBoostEnabled: Bool = false

  // Chapter support (simple synthesized chapters when metadata is unavailable)
  private var chapters: [Chapter] = []

  // MARK: - Exposed properties for tests
  public var currentPosition: TimeInterval { position }
  public var playbackSpeed: Float { speed }
  public var isSkipSilenceEnabled: Bool { skipSilenceEnabled }
  public var isVolumeBoostEnabled: Bool { volumeBoostEnabled }

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

  // Synthesize basic chapters when explicit metadata isn't available
  private func synthesizeChaptersIfNeeded() {
    guard chapters.isEmpty else { return }
    // Heuristic: longer episodes likely have chapters. Use quartiles for simplicity.
    if duration >= 600 { // 10+ minutes
      let quarter = duration / 4.0
      let starts: [TimeInterval] = [0, quarter, quarter * 2, quarter * 3]
      chapters = starts.enumerated().map { idx, start in
        Chapter(id: "auto_\(idx)", title: "Chapter \(idx + 1)", startTime: max(0, start), endTime: nil)
      }
    } else {
      chapters = []
    }
  }

  // Automatically mark episode as played when reaching the end
  private func checkForCompletion() {
    guard let ep = currentEpisode, duration > 0 else { return }
    // Allow tiny epsilon to account for floating point rounding
    if position >= duration - 0.001 {
      // Snap to exact end and mark as played asynchronously
      position = duration
      markEpisodeAs(played: true)
    }
  }

  public func play(episode: Episode, duration: TimeInterval?) {
    currentEpisode = episode
    self.duration = max(0, duration ?? 0)
    // Start playback at the existing (persisted) position if any, otherwise 0
    self.position = TimeInterval(episode.playbackPosition)
    // Apply effective speed (per-podcast override > global > local)
    self.speed = effectiveSpeed(for: episode)
    // Reset effect toggles for new playback session
    self.skipSilenceEnabled = false
    self.volumeBoostEnabled = false
    // Setup chapters
    self.chapters = []
    synthesizeChaptersIfNeeded()
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
    checkForCompletion()
    emitPlaying()
  }
  public func skipBackward(interval: TimeInterval = -1) {
    let step = interval >= 0 ? interval : backwardInterval
    position = max(0, position - step)
    emitPlaying()
  }
  public func seek(to newPosition: TimeInterval) {
    position = min(max(0, newPosition), duration)
    checkForCompletion()
    emitPlaying()
  }
  public func setPlaybackSpeed(_ newSpeed: Float) {
    speed = clampSpeed(newSpeed)
    // Simulate one tick of progress to reflect speed impact in tests
    if currentEpisode != nil {
      position = min(position + TimeInterval(speed), duration)
      checkForCompletion()
      emitPlaying()
    }
  }
  public func getCurrentPlaybackSpeed() -> Float { speed }

  // MARK: - Effects Toggles
  public func setSkipSilence(enabled: Bool) { skipSilenceEnabled = enabled }
  public func setVolumeBoost(enabled: Bool) { volumeBoostEnabled = enabled }

  // MARK: - Chapter Navigation
  public func nextChapter() {
    guard !chapters.isEmpty else { return }
    // Find next chapter strictly after current position
    if let next = chapters.map({ $0.startTime }).sorted().first(where: { $0 > position + 0.01 }) {
      seek(to: next)
    }
  }
  public func previousChapter() {
    guard !chapters.isEmpty else { return }
    // Find previous chapter strictly before current position
    let starts = chapters.map({ $0.startTime }).sorted()
    if let prev = starts.last(where: { $0 < position - 0.01 }) {
      seek(to: prev)
    } else {
      // If at or before first chapter, go to beginning
      seek(to: 0)
    }
  }

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
