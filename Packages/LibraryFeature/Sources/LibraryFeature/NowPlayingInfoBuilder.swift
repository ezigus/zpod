import CoreModels
import Foundation
import PlaybackEngine

public struct NowPlayingInfoSnapshot: Equatable, Sendable {
  public let title: String
  public let podcastTitle: String
  public let duration: TimeInterval
  public let elapsed: TimeInterval
  public let playbackRate: Float
  public let artworkURL: URL?

  public init(
    title: String,
    podcastTitle: String,
    duration: TimeInterval,
    elapsed: TimeInterval,
    playbackRate: Float,
    artworkURL: URL?
  ) {
    self.title = title
    self.podcastTitle = podcastTitle
    self.duration = duration
    self.elapsed = elapsed
    self.playbackRate = playbackRate
    self.artworkURL = artworkURL
  }
}

public struct NowPlayingInfoBuilder: Sendable {
  public init() {}

  public func makeSnapshot(from state: EpisodePlaybackState) -> NowPlayingInfoSnapshot? {
    switch state {
    case .idle:
      return nil
    case .playing(let episode, let position, let duration):
      return makeSnapshot(
        episode: episode,
        position: position,
        duration: duration,
        playbackRate: 1.0
      )
    case .paused(let episode, let position, let duration):
      return makeSnapshot(
        episode: episode,
        position: position,
        duration: duration,
        playbackRate: 0.0
      )
    case .finished(let episode, let duration):
      return makeSnapshot(
        episode: episode,
        position: duration,
        duration: duration,
        playbackRate: 0.0
      )
    case .failed(let episode, let position, let duration, _):
      return makeSnapshot(
        episode: episode,
        position: position,
        duration: duration,
        playbackRate: 0.0
      )
    }
  }

  private func makeSnapshot(
    episode: Episode,
    position: TimeInterval,
    duration: TimeInterval,
    playbackRate: Float
  ) -> NowPlayingInfoSnapshot {
    let normalizedDuration = max(duration, 0)
    let normalizedPosition = min(max(position, 0), normalizedDuration > 0 ? normalizedDuration : position)

    return NowPlayingInfoSnapshot(
      title: episode.title,
      podcastTitle: episode.podcastTitle,
      duration: normalizedDuration,
      elapsed: normalizedPosition,
      playbackRate: playbackRate,
      artworkURL: episode.artworkURL
    )
  }
}
