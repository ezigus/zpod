@preconcurrency import Foundation

/// Represents the playback state to be persisted and restored across app launches
public struct PlaybackResumeState: Codable, Equatable, Sendable {
  public var episodeId: String
  public var position: TimeInterval
  public var duration: TimeInterval
  public var timestamp: Date
  public var isPlaying: Bool
  
  public init(
    episodeId: String,
    position: TimeInterval,
    duration: TimeInterval,
    timestamp: Date = Date(),
    isPlaying: Bool = false
  ) {
    self.episodeId = episodeId
    self.position = position
    self.duration = duration
    self.timestamp = timestamp
    self.isPlaying = isPlaying
  }
  
  /// Check if this resume state is still valid (within 24 hours)
  public var isValid: Bool {
    let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
    return timestamp > twentyFourHoursAgo
  }
}
