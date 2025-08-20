import Foundation
import CoreModels
import Persistence
import SharedUtilities
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
        Task {
            let downloadSettings = await repository.loadGlobalDownloadSettings()
            let notificationSettings = await repository.loadGlobalNotificationSettings()
            let playbackSettings = await repository.loadGlobalPlaybackSettings()
            
            await MainActor.run {
                self.globalDownloadSettings = downloadSettings
                self.globalNotificationSettings = notificationSettings
                self.globalPlaybackSettings = playbackSettings
            }
        }
        
        // Initialize with defaults temporarily
        self.globalDownloadSettings = DownloadSettings()
        self.globalNotificationSettings = NotificationSettings()
        self.globalPlaybackSettings = PlaybackSettings()
        
        // Subscribe to repository changes to update published properties
        Task {
            for await change in await repository.settingsChangedStream {
                await handleSettingsChange(change)
            }
        }
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
            await repository.savePodcastPlaybackSettings(settings)
        } else {
            await repository.removePodcastPlaybackSettings(podcastId: podcastId)
        }
    }
    
    // MARK: - Change Notifications
    
    /// Publisher for settings changes (forwarded from repository)
    public var settingsChangePublisher: AnyPublisher<SettingsChange, Never> {
        // Create a publisher from the async stream
        return Publishers.AsyncStreamPublisher(
            stream: Task {
                await repository.settingsChangedStream
            }.value
        )
        .eraseToAnyPublisher()
    }
    
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
            case .podcastDownload, .podcastPlayback:
                // Per-podcast changes don't update published global properties
                // They affect effective settings resolution only
                break
            }
        }
    }
}

// MARK: - AsyncStreamPublisher Helper
extension Publishers {
    struct AsyncStreamPublisher<Element>: Publisher where Element: Sendable {
        typealias Output = Element
        typealias Failure = Never
        
        let stream: AsyncStream<Element>
        
        func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Element == S.Input {
            let subscription = AsyncStreamSubscription(stream: stream, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
    }
}

final class AsyncStreamSubscription<S: Subscriber>: Subscription where S.Input: Sendable, S.Failure == Never {
    private let subscriber: S
    private let stream: AsyncStream<S.Input>
    private var task: Task<Void, Never>?
    
    init(stream: AsyncStream<S.Input>, subscriber: S) {
        self.stream = stream
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard task == nil else { return }
        
        task = Task {
            for await element in stream {
                _ = subscriber.receive(element)
            }
            subscriber.receive(completion: .finished)
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}