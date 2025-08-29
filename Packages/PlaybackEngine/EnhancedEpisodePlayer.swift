#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import CoreModels
import SettingsDomain

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
  private var stateManager: EpisodeStateManager?
  private var playbackSettings: CoreModels.PlaybackSettings?

  public init(stateManager: EpisodeStateManager? = nil, playbackSettings: CoreModels.PlaybackSettings? = nil) {
    self.stateManager = stateManager
    self.playbackSettings = playbackSettings
  }

  public func play(episode: Episode, duration: TimeInterval?) {
    currentEpisode = episode
    self.duration = max(0, duration ?? 0)
    position = 0
    
    // Set per-podcast speed if available, otherwise use global speed
    if let settings = playbackSettings {
      if let podcastSpeeds = settings.podcastPlaybackSpeeds,
         let podcastID = episode.podcastID,
         let podcastSpeed = podcastSpeeds[podcastID] {
        speed = Float(podcastSpeed)
      } else if let globalSpeed = settings.globalPlaybackSpeed {
        speed = Float(globalSpeed)
      }
    }
    
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
  public func setPlaybackSpeed(_ newSpeed: Float) { speed = max(0.8, min(newSpeed, 5.0)) }
  public func getCurrentPlaybackSpeed() -> Float { speed }
  public func jumpToChapter(_ chapter: Chapter) { seek(to: chapter.startTime) }
  public func markEpisodeAs(played: Bool) {
    guard let episode = currentEpisode, let stateManager = stateManager else { return }
    Task {
      await stateManager.setPlayedStatus(episode, isPlayed: played)
    }
  }
}
