import Foundation

/// Settings for podcast playback preferences
public struct PlaybackSettings: Codable, Equatable, Sendable {
    /// Global default playback speed (0.8x to 5.0x)
    public let globalPlaybackSpeed: Float
    
    /// Per-podcast playback speeds (podcast ID -> speed)
    public let podcastPlaybackSpeeds: [String: Float]
    
    /// Custom skip forward interval in seconds
    public let skipForwardInterval: TimeInterval
    
    /// Custom skip backward interval in seconds
    public let skipBackwardInterval: TimeInterval
    
    /// Per-podcast intro skip durations (podcast ID -> seconds)
    public let introSkipDurations: [String: TimeInterval]
    
    /// Per-podcast outro skip durations (podcast ID -> seconds)
    public let outroSkipDurations: [String: TimeInterval]
    
    /// Whether to mark episodes as played automatically when finished
    public let autoMarkAsPlayed: Bool
    
    /// Threshold for considering an episode "played" (as percentage 0.0-1.0)
    public let playedThreshold: Float
    
    public init(
        globalPlaybackSpeed: Float = 1.0,
        podcastPlaybackSpeeds: [String: Float] = [:],
        skipForwardInterval: TimeInterval = 30,
        skipBackwardInterval: TimeInterval = 15,
        introSkipDurations: [String: TimeInterval] = [:],
        outroSkipDurations: [String: TimeInterval] = [:],
        autoMarkAsPlayed: Bool = true,
        playedThreshold: Float = 0.9
    ) {
        self.globalPlaybackSpeed = max(0.8, min(5.0, globalPlaybackSpeed))
        self.podcastPlaybackSpeeds = podcastPlaybackSpeeds
        self.skipForwardInterval = max(5, min(300, skipForwardInterval))
        self.skipBackwardInterval = max(5, min(300, skipBackwardInterval))
        self.introSkipDurations = introSkipDurations
        self.outroSkipDurations = outroSkipDurations
        self.autoMarkAsPlayed = autoMarkAsPlayed
        self.playedThreshold = max(0.0, min(1.0, playedThreshold))
    }
    
    /// Get effective playback speed for a podcast (per-podcast override or global default)
    public func playbackSpeed(for podcastId: String) -> Float {
        return podcastPlaybackSpeeds[podcastId] ?? globalPlaybackSpeed
    }
    
    /// Get intro skip duration for a podcast
    public func introSkipDuration(for podcastId: String) -> TimeInterval {
        return introSkipDurations[podcastId] ?? 0
    }
    
    /// Get outro skip duration for a podcast
    public func outroSkipDuration(for podcastId: String) -> TimeInterval {
        return outroSkipDurations[podcastId] ?? 0
    }
}
