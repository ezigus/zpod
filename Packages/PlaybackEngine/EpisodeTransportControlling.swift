import Foundation

/// Protocol exposing transport controls required by compact playback UIs such as the mini-player.
/// Conforming types must already guarantee main-actor confinement through `EpisodePlaybackService`.
@MainActor
public protocol EpisodeTransportControlling: AnyObject {
  /// Skips playback forward by the provided interval (uses service defaults when nil).
  func skipForward(interval: TimeInterval?)

  /// Skips playback backward by the provided interval (uses service defaults when nil).
  func skipBackward(interval: TimeInterval?)

  /// Seeks to an absolute playback position.
  func seek(to position: TimeInterval)
}

