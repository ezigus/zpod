import Foundation
import CoreModels

/// Extension to SettingsManager providing convenience methods for service integration
@MainActor
extension SettingsManager {
    
    /// Check if auto-download is enabled for a specific podcast
    public func isAutoDownloadEnabled(for podcastId: String) -> Bool {
        return effectiveDownloadSettings(for: podcastId).autoDownloadEnabled
    }
    
    /// Check if downloads should be restricted to Wi-Fi for a specific podcast
    public func isWifiOnlyForDownloads(for podcastId: String) -> Bool {
        return effectiveDownloadSettings(for: podcastId).wifiOnly
    }
    
    /// Get the retention policy for a specific podcast
    public func retentionPolicy(for podcastId: String) -> RetentionPolicy {
        return effectiveDownloadSettings(for: podcastId).retentionPolicy
    }
    
    /// Get the effective playback speed for a specific podcast
    public func playbackSpeed(for podcastId: String) -> Float {
        return effectivePlaybackSettings(for: podcastId).playbackSpeed(for: podcastId)
    }
    
    /// Get the effective skip intervals for a specific podcast
    public func skipIntervals(for podcastId: String) -> (forward: TimeInterval, backward: TimeInterval) {
        let settings = effectivePlaybackSettings(for: podcastId)
        return (forward: settings.skipForwardInterval, backward: settings.skipBackwardInterval)
    }
    
    /// Get intro/outro skip durations for a specific podcast
    public func skipDurations(for podcastId: String) -> (intro: TimeInterval, outro: TimeInterval) {
        let settings = effectivePlaybackSettings(for: podcastId)
        return (
            intro: settings.introSkipDuration(for: podcastId),
            outro: settings.outroSkipDuration(for: podcastId)
        )
    }
    
    /// Check if new episode notifications are enabled for a specific podcast
    public func areNewEpisodeNotificationsEnabled(for podcastId: String) -> Bool {
        return effectiveNotificationSettings(for: podcastId).newEpisodeNotifications
    }
    
    /// Get custom notification sound for a specific podcast
    public func customNotificationSound(for podcastId: String) -> String? {
        return effectiveNotificationSettings(for: podcastId).customSounds[podcastId]
    }
    
    /// Update playback speed for a specific podcast while preserving other settings
    public func updatePlaybackSpeed(for podcastId: String, speed: Float) {
        let existing = repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        let updated = PodcastPlaybackSettings(
            podcastId: podcastId,
            playbackSpeed: speed,
            skipForwardInterval: existing?.skipForwardInterval,
            skipBackwardInterval: existing?.skipBackwardInterval,
            introSkipDuration: existing?.introSkipDuration,
            outroSkipDuration: existing?.outroSkipDuration
        )
        updatePodcastPlaybackSettings(podcastId: podcastId, updated)
    }
    
    /// Update auto-download setting for a specific podcast while preserving other settings
    public func updateAutoDownload(for podcastId: String, enabled: Bool) {
        let existing = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let updated = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: enabled,
            wifiOnly: existing?.wifiOnly,
            retentionPolicy: existing?.retentionPolicy
        )
        updatePodcastDownloadSettings(podcastId: podcastId, updated)
    }
    
    /// Update retention policy for a specific podcast while preserving other settings
    public func updateRetentionPolicy(for podcastId: String, policy: RetentionPolicy) {
        let existing = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let updated = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: existing?.autoDownloadEnabled,
            wifiOnly: existing?.wifiOnly,
            retentionPolicy: policy
        )
        updatePodcastDownloadSettings(podcastId: podcastId, updated)
    }
    
    /// Remove all podcast-specific overrides, falling back to global settings
    public func resetPodcastSettingsToGlobal(podcastId: String) {
        updatePodcastDownloadSettings(podcastId: podcastId, nil)
        updatePodcastPlaybackSettings(podcastId: podcastId, nil)
    }
    
    /// Get a summary of all overrides for a podcast
    public func overrideSummary(for podcastId: String) -> PodcastSettingsOverride {
        let downloadOverrides = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let playbackOverrides = repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        
        return PodcastSettingsOverride(
            podcastId: podcastId,
            hasDownloadOverrides: downloadOverrides != nil,
            hasPlaybackOverrides: playbackOverrides != nil,
            downloadOverrides: downloadOverrides,
            playbackOverrides: playbackOverrides
        )
    }
}

/// Summary of podcast-specific setting overrides
public struct PodcastSettingsOverride {
    public let podcastId: String
    public let hasDownloadOverrides: Bool
    public let hasPlaybackOverrides: Bool
    public let downloadOverrides: PodcastDownloadSettings?
    public let playbackOverrides: PodcastPlaybackSettings?
    
    /// Whether this podcast has any overrides at all
    public var hasAnyOverrides: Bool {
        return hasDownloadOverrides || hasPlaybackOverrides
    }
}