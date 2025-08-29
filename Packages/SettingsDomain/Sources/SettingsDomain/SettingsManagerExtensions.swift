import Foundation
import CoreModels

/// Extension to SettingsManager providing convenience methods for service integration
@MainActor
extension SettingsManager {
    
    /// Check if auto-download is enabled for a specific podcast
    public func isAutoDownloadEnabled(for podcastId: String) async -> Bool {
        let settings = await effectiveDownloadSettings(for: podcastId)
        return settings.autoDownloadEnabled
    }
    
    /// Check if downloads should be restricted to Wi-Fi for a specific podcast
    public func isWifiOnlyForDownloads(for podcastId: String) async -> Bool {
        let settings = await effectiveDownloadSettings(for: podcastId)
        return settings.wifiOnly
    }
    
    /// Get the retention policy for a specific podcast
    public func retentionPolicy(for podcastId: String) async -> RetentionPolicy {
        let settings = await effectiveDownloadSettings(for: podcastId)
        return settings.retentionPolicy
    }
    
    /// Get the effective playback speed for a specific podcast
    public func playbackSpeed(for podcastId: String) async -> Float {
        let settings = await effectivePlaybackSettings(for: podcastId)
        return Float(settings.playbackSpeed)
    }
    
    /// Get the effective skip intervals for a specific podcast
    public func skipIntervals(for podcastId: String) async -> (forward: TimeInterval, backward: TimeInterval) {
        let settings = await effectivePlaybackSettings(for: podcastId)
        return (
            forward: TimeInterval(settings.skipForwardInterval ?? 30),
            backward: TimeInterval(settings.skipBackwardInterval ?? 15)
        )
    }
    
    /// Get intro/outro skip durations for a specific podcast
    public func skipDurations(for podcastId: String) async -> (intro: TimeInterval, outro: TimeInterval) {
        let settings = await effectivePlaybackSettings(for: podcastId)
        return (
            intro: TimeInterval(settings.introSkipDurations?[podcastId] ?? settings.skipIntroSeconds),
            outro: TimeInterval(settings.outroSkipDurations?[podcastId] ?? settings.skipOutroSeconds)
        )
    }
    
    /// Check if new episode notifications are enabled for a specific podcast
    public func areNewEpisodeNotificationsEnabled(for podcastId: String) -> Bool {
        return effectiveNotificationSettings(for: podcastId).newEpisodeNotificationsEnabled
    }
    
    /// Get custom notification sound for a specific podcast
    public func customNotificationSound(for podcastId: String) -> String? {
        return effectiveNotificationSettings(for: podcastId).customSounds?[podcastId]
    }
    
    /// Get the maximum number of concurrent downloads allowed
    public var maxConcurrentDownloads: Int {
        return globalDownloadSettings.maxConcurrentDownloads
    }
    
    /// Get the auto-mark as played threshold
    public var playedThreshold: TimeInterval {
        return globalPlaybackSettings.playedThreshold ?? 0.9
    }
    
    /// Check if auto-mark as played is enabled globally
    public var isAutoMarkAsPlayedEnabled: Bool {
        return globalPlaybackSettings.autoMarkAsPlayed ?? false
    }
}