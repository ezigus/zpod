import Foundation
@preconcurrency import Combine

/// Settings manager providing cascading resolution and reactive updates
@MainActor
public class SettingsManager: ObservableObject {
    internal let repository: SettingsRepository
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties for reactive UI
    @Published public private(set) var globalDownloadSettings: DownloadSettings
    @Published public private(set) var globalNotificationSettings: NotificationSettings
    @Published public private(set) var globalPlaybackSettings: PlaybackSettings
    
    public init(repository: SettingsRepository) {
        self.repository = repository
        
        // Load initial values from repository
        self.globalDownloadSettings = repository.loadGlobalDownloadSettings()
        self.globalNotificationSettings = repository.loadGlobalNotificationSettings()
        self.globalPlaybackSettings = repository.loadGlobalPlaybackSettings()
        
        // Subscribe to repository changes to update published properties
        repository.settingsChangedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.handleSettingsChange(change)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cascading Resolution
    
    /// Get effective download settings for a podcast (cascaded: podcast override → global → default)
    public func effectiveDownloadSettings(for podcastId: String) -> DownloadSettings {
        let podcastOverrides = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let global = globalDownloadSettings
        
        return DownloadSettings(
            autoDownloadEnabled: podcastOverrides?.autoDownloadEnabled ?? global.autoDownloadEnabled,
            wifiOnly: podcastOverrides?.wifiOnly ?? global.wifiOnly,
            maxConcurrentDownloads: global.maxConcurrentDownloads,  // Not overridable per-podcast
            retentionPolicy: podcastOverrides?.retentionPolicy ?? global.retentionPolicy,
            defaultUpdateFrequency: podcastOverrides?.updateFrequency ?? global.defaultUpdateFrequency
        )
    }
    
    /// Get effective playback settings for a podcast (cascaded: podcast override → global → default)
    public func effectivePlaybackSettings(for podcastId: String) -> PlaybackSettings {
        let podcastOverrides = repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        let global = globalPlaybackSettings
        
        // Create new PlaybackSettings combining global and podcast-specific values
        var podcastSpeeds = global.podcastPlaybackSpeeds
        var introSkips = global.introSkipDurations
        var outroSkips = global.outroSkipDurations
        
        // Apply podcast-specific overrides if present
        if let overrides = podcastOverrides {
            if let speed = overrides.playbackSpeed {
                podcastSpeeds[podcastId] = speed
            }
            if let introSkip = overrides.introSkipDuration {
                introSkips[podcastId] = introSkip
            }
            if let outroSkip = overrides.outroSkipDuration {
                outroSkips[podcastId] = outroSkip
            }
        }
        
        return PlaybackSettings(
            globalPlaybackSpeed: global.globalPlaybackSpeed,
            podcastPlaybackSpeeds: podcastSpeeds,
            skipForwardInterval: podcastOverrides?.skipForwardInterval ?? global.skipForwardInterval,
            skipBackwardInterval: podcastOverrides?.skipBackwardInterval ?? global.skipBackwardInterval,
            introSkipDurations: introSkips,
            outroSkipDurations: outroSkips,
            autoMarkAsPlayed: global.autoMarkAsPlayed,
            playedThreshold: global.playedThreshold
        )
    }
    
    /// Get effective notification settings for a podcast (cascaded: podcast custom sounds → global → default)
    public func effectiveNotificationSettings(for podcastId: String) -> NotificationSettings {
        let global = globalNotificationSettings
        
        // For now, only custom sounds are per-podcast; other settings are global
        return NotificationSettings(
            newEpisodeNotifications: global.newEpisodeNotifications,
            downloadCompleteNotifications: global.downloadCompleteNotifications,
            soundEnabled: global.soundEnabled,
            customSounds: global.customSounds
        )
    }
    
    /// Get effective update frequency for a podcast (cascaded: podcast override → global → default)
    public func effectiveUpdateFrequency(for podcastId: String) -> UpdateFrequency {
        let podcastOverrides = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let global = globalDownloadSettings
        
        return podcastOverrides?.updateFrequency ?? global.defaultUpdateFrequency
    }
    
    // MARK: - Mutation APIs
    
    /// Update global download settings
    public func updateGlobalDownloadSettings(_ settings: DownloadSettings) {
        let validatedSettings = DownloadSettings(
            autoDownloadEnabled: settings.autoDownloadEnabled,
            wifiOnly: settings.wifiOnly,
            maxConcurrentDownloads: settings.maxConcurrentDownloads,  // Validation happens in initializer
            retentionPolicy: settings.retentionPolicy,
            defaultUpdateFrequency: settings.defaultUpdateFrequency
        )
        
        repository.saveGlobalDownloadSettings(validatedSettings)
        globalDownloadSettings = validatedSettings
    }
    
    /// Update global playback settings
    public func updateGlobalPlaybackSettings(_ settings: PlaybackSettings) {
        repository.saveGlobalPlaybackSettings(settings)
        globalPlaybackSettings = settings
    }
    
    /// Update global notification settings
    public func updateGlobalNotificationSettings(_ settings: NotificationSettings) {
        repository.saveGlobalNotificationSettings(settings)
        globalNotificationSettings = settings
    }
    
    /// Update podcast-specific download settings (nil removes override)
    public func updatePodcastDownloadSettings(podcastId: String, _ settings: PodcastDownloadSettings?) {
        if let settings = settings {
            repository.savePodcastDownloadSettings(settings)
        } else {
            repository.removePodcastDownloadSettings(podcastId: podcastId)
        }
    }
    
    /// Update podcast-specific playback settings (nil removes override)
    public func updatePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings?) {
        if let settings = settings {
            repository.savePodcastPlaybackSettings(settings)
        } else {
            repository.removePodcastPlaybackSettings(podcastId: podcastId)
        }
    }
    
    // MARK: - Change Notifications
    
    /// Publisher for settings changes (forwarded from repository)
    public var settingsChangePublisher: AnyPublisher<SettingsChange, Never> {
        repository.settingsChangedPublisher
    }
    
    // MARK: - Private Methods
    
    private func handleSettingsChange(_ change: SettingsChange) {
        switch change {
        case .globalDownload(let settings):
            globalDownloadSettings = settings
        case .globalNotification(let settings):
            globalNotificationSettings = settings
        case .globalPlayback(let settings):
            globalPlaybackSettings = settings
        case .podcastDownload, .podcastPlayback:
            // Per-podcast changes don't update published global properties
            // They affect effective settings resolution only
            break
        }
    }
}
