import Foundation
import CoreModels
import Persistence
import SharedUtilities
#if canImport(Combine)
@preconcurrency import Combine
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Settings manager providing cascading resolution and reactive updates
@MainActor
public class SettingsManager {
    internal let repository: SettingsRepository
    #if canImport(Combine)
    private var cancellables = Set<AnyCancellable>()
    // Bridge subject to expose a synchronous publisher without awaiting the repository
    private let settingsChangeSubject = PassthroughSubject<SettingsChange, Never>()
    #endif
    
    // Published properties for reactive UI
    #if canImport(Combine)
    @Published public private(set) var globalDownloadSettings: DownloadSettings
    @Published public private(set) var globalNotificationSettings: NotificationSettings  
    @Published public private(set) var globalPlaybackSettings: PlaybackSettings
    @Published public private(set) var globalUISettings: UISettings
    #else
    public private(set) var globalDownloadSettings: DownloadSettings
    public private(set) var globalNotificationSettings: NotificationSettings
    public private(set) var globalPlaybackSettings: PlaybackSettings
    public private(set) var globalUISettings: UISettings
    #endif

    private let swipeConfigurationServiceImpl: SwipeConfigurationServicing
    public let featureConfigurationRegistry: FeatureConfigurationRegistry

    public var swipeConfigurationService: SwipeConfigurationServicing {
        swipeConfigurationServiceImpl
    }

    public func makeSwipeConfigurationController() -> SwipeConfigurationController {
        let controller = SwipeConfigurationController(service: swipeConfigurationServiceImpl)
        let configuration = SwipeConfiguration(
            swipeActions: globalUISettings.swipeActions,
            hapticStyle: globalUISettings.hapticStyle
        )
        controller.bootstrap(with: configuration)
        return controller
    }

    public func allFeatureDescriptors() async -> [FeatureConfigurationDescriptor] {
        await featureConfigurationRegistry.allDescriptors()
    }

    public func controller(forFeature id: String) async -> (any FeatureConfigurationControlling)? {
        await featureConfigurationRegistry.controller(for: id)
    }

    public init(repository: SettingsRepository) {
        self.repository = repository

        let swipeService = SwipeConfigurationService(repository: repository)
        self.swipeConfigurationServiceImpl = swipeService
        self.featureConfigurationRegistry = FeatureConfigurationRegistry(
            features: [SwipeConfigurationFeature(service: swipeService)]
        )

        // Initialize with defaults temporarily
        self.globalDownloadSettings = DownloadSettings.default
        self.globalNotificationSettings = NotificationSettings.default
        self.globalPlaybackSettings = PlaybackSettings()
        self.globalUISettings = UISettings.default
        
        // Load initial values from repository asynchronously after initialization
        Task {
            let downloadSettings = await repository.loadGlobalDownloadSettings()
            let notificationSettings = await repository.loadGlobalNotificationSettings()
            let playbackSettings = await repository.loadGlobalPlaybackSettings()
            let uiSettings = await repository.loadGlobalUISettings()
            
            await MainActor.run {
                self.globalDownloadSettings = downloadSettings
                self.globalNotificationSettings = notificationSettings
                self.globalPlaybackSettings = playbackSettings
                self.globalUISettings = uiSettings
            }
        }
        
        // Bridge repository change notifications to a synchronous publisher
        #if canImport(Combine)
        Task { [weak self] in
            guard let self else { return }
            let repoPublisher = await repository.settingsChangedPublisher
            await MainActor.run {
                repoPublisher
                    .sink { [weak self] change in
                        guard let self else { return }
                        Task { @MainActor in
                            await self.handleSettingsChange(change)
                            self.settingsChangeSubject.send(change)
                        }
                    }
                    .store(in: &self.cancellables)
            }
        }
        #endif
    }
    
    // MARK: - Cascading Resolution
    
    /// Get effective download settings for a podcast (cascaded: podcast override → global → default)
    public func effectiveDownloadSettings(for podcastId: String) async -> DownloadSettings {
        let podcastOverrides = await repository.loadPodcastDownloadSettings(podcastId: podcastId)
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
    public func effectivePlaybackSettings(for podcastId: String) async -> PlaybackSettings {
        let podcastOverrides = await repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        let global = globalPlaybackSettings
        
        // Create new PlaybackSettings combining global and podcast-specific values
        var podcastSpeeds = global.podcastPlaybackSpeeds
        var introSkips = global.introSkipDurations
        var outroSkips = global.outroSkipDurations
        
        // Apply podcast-specific overrides if present
        if let overrides = podcastOverrides {
            if let speed = overrides.speed {
                podcastSpeeds?[podcastId] = speed
            }
            if let introSkip = overrides.introSkipDuration {
                introSkips?[podcastId] = introSkip
            }
            if let outroSkip = overrides.outroSkipDuration {
                outroSkips?[podcastId] = outroSkip
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
            newEpisodeNotificationsEnabled: global.newEpisodeNotificationsEnabled,
            downloadCompleteNotificationsEnabled: global.downloadCompleteNotificationsEnabled,
            playbackNotificationsEnabled: global.playbackNotificationsEnabled,
            quietHoursEnabled: global.quietHoursEnabled,
            quietHoursStart: global.quietHoursStart,
            quietHoursEnd: global.quietHoursEnd,
            soundEnabled: global.soundEnabled,
            customSounds: global.customSounds
        )
    }
    
    /// Get effective update frequency for a podcast (cascaded: podcast override → global → default)
    public func effectiveUpdateFrequency(for podcastId: String) async -> UpdateFrequency {
        let podcastOverrides = await repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let global = globalDownloadSettings
        
        return podcastOverrides?.updateFrequency ?? global.defaultUpdateFrequency
    }
    
    // MARK: - Mutation APIs
    
    /// Update global download settings
    public func updateGlobalDownloadSettings(_ settings: DownloadSettings) async {
        let validatedSettings = DownloadSettings(
            autoDownloadEnabled: settings.autoDownloadEnabled,
            wifiOnly: settings.wifiOnly,
            maxConcurrentDownloads: settings.maxConcurrentDownloads,  // Validation happens in initializer
            retentionPolicy: settings.retentionPolicy,
            defaultUpdateFrequency: settings.defaultUpdateFrequency
        )
        
        await repository.saveGlobalDownloadSettings(validatedSettings)
        globalDownloadSettings = validatedSettings
    }
    
    /// Update global playback settings
    public func updateGlobalPlaybackSettings(_ settings: PlaybackSettings) async {
        await repository.saveGlobalPlaybackSettings(settings)
        globalPlaybackSettings = settings
    }
    
    /// Update global notification settings
    public func updateGlobalNotificationSettings(_ settings: NotificationSettings) async {
        await repository.saveGlobalNotificationSettings(settings)
        globalNotificationSettings = settings
    }
    
    /// Update global UI settings
    public func updateGlobalUISettings(_ settings: UISettings) async {
        await repository.saveGlobalUISettings(settings)
        globalUISettings = settings
    }

    public func loadPersistedUISettings() async -> UISettings {
        let settings = await repository.loadGlobalUISettings()
        return settings
    }
    
    /// Update podcast-specific download settings (nil removes override)
    public func updatePodcastDownloadSettings(podcastId: String, _ settings: PodcastDownloadSettings?) async {
        if let settings = settings {
            await repository.savePodcastDownloadSettings(settings)
        } else {
            await repository.removePodcastDownloadSettings(podcastId: podcastId)
        }
    }
    
    /// Update podcast-specific playback settings (nil removes override)
    public func updatePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings?) async {
        if let settings = settings {
            await repository.savePodcastPlaybackSettings(podcastId: podcastId, settings)
        } else {
            await repository.removePodcastPlaybackSettings(podcastId: podcastId)
        }
    }
    
    // MARK: - Change Notifications
    
    /// Publisher for settings changes (forwarded from repository via bridge)
    #if canImport(Combine)
    public var settingsChangePublisher: AnyPublisher<SettingsChange, Never> {
        settingsChangeSubject.eraseToAnyPublisher()
    }
    #endif
    
    // MARK: - Private Methods
    
    private func handleSettingsChange(_ change: SettingsChange) async {
        await MainActor.run {
            switch change {
            case .globalDownload(let settings):
                globalDownloadSettings = settings
            case .globalNotification(let settings):
                globalNotificationSettings = settings
            case .globalPlayback(let settings):
                globalPlaybackSettings = settings
            case .globalUI(let settings):
                globalUISettings = settings
            case .podcastDownload, .podcastPlayback:
                // Per-podcast changes don't update published global properties
                // They affect effective settings resolution only
                break
            }
        }
    }
}

// MARK: - ObservableObject Conformance
#if canImport(SwiftUI)
extension SettingsManager: ObservableObject {}
#endif
