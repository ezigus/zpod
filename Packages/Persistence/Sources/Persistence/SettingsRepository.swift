#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import os.log
import CoreModels

/// Types of settings changes for change notifications
public enum SettingsChange: Equatable, Sendable {
    case globalDownload(DownloadSettings)
    case globalNotification(NotificationSettings)
    case globalPlayback(PlaybackSettings)
    case podcastDownload(String, PodcastDownloadSettings?)
    case podcastPlayback(String, PodcastPlaybackSettings?)
}

/// Protocol for settings persistence and retrieval
public protocol SettingsRepository: Sendable {
    // Global settings
    func loadGlobalDownloadSettings() async -> DownloadSettings
    func saveGlobalDownloadSettings(_ settings: DownloadSettings) async
    
    func loadGlobalNotificationSettings() async -> NotificationSettings
    func saveGlobalNotificationSettings(_ settings: NotificationSettings) async
    
    func loadGlobalPlaybackSettings() async -> PlaybackSettings
    func saveGlobalPlaybackSettings(_ settings: PlaybackSettings) async
    
    // Per-podcast overrides
    func loadPodcastDownloadSettings(podcastId: String) async -> PodcastDownloadSettings?
    func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async
    func removePodcastDownloadSettings(podcastId: String) async
    
    func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings?
    func savePodcastPlaybackSettings(_ settings: PodcastPlaybackSettings) async
    func removePodcastPlaybackSettings(podcastId: String) async
    
    // Change notifications
    var settingsChangedPublisher: AnyPublisher<SettingsChange, Never> { get async }
}

/// UserDefaults-based implementation of SettingsRepository
public actor UserDefaultsSettingsRepository: SettingsRepository {
    private let userDefaults: UserDefaults
    private let settingsChangeSubject = PassthroughSubject<SettingsChange, Never>()
    
    // Logger for settings-related errors
    private let logger = OSLog(subsystem: "com.zpodcastaddict.settings", category: "SettingsRepository")
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Keys for UserDefaults storage
    
    private enum Keys {
        static let globalDownload = "global_download_settings"
        static let globalNotification = "global_notification_settings"
        static let globalPlayback = "global_playback_settings"
        static let podcastDownloadPrefix = "podcast_download_"
        static let podcastPlaybackPrefix = "podcast_playback_"
    }
    
    // MARK: - Global Settings
    
    public func loadGlobalDownloadSettings() async -> DownloadSettings {
        guard let data = userDefaults.data(forKey: Keys.globalDownload) else {
            return DownloadSettings.default
        }
        
        do {
            return try JSONDecoder().decode(DownloadSettings.self, from: data)
        } catch {
            os_log("Failed to decode global download settings: %{public}@", log: logger, type: .error, error.localizedDescription)
            return DownloadSettings.default
        }
    }
    
    public func saveGlobalDownloadSettings(_ settings: DownloadSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.globalDownload)
            settingsChangeSubject.send(.globalDownload(settings))
        } catch {
            os_log("Failed to encode global download settings: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func loadGlobalNotificationSettings() async -> NotificationSettings {
        guard let data = userDefaults.data(forKey: Keys.globalNotification) else {
            return NotificationSettings.default
        }
        
        do {
            return try JSONDecoder().decode(NotificationSettings.self, from: data)
        } catch {
            os_log("Failed to decode global notification settings: %{public}@", log: logger, type: .error, error.localizedDescription)
            return NotificationSettings.default
        }
    }
    
    public func saveGlobalNotificationSettings(_ settings: NotificationSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.globalNotification)
            settingsChangeSubject.send(.globalNotification(settings))
        } catch {
            os_log("Failed to encode global notification settings: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func loadGlobalPlaybackSettings() async -> PlaybackSettings {
        guard let data = userDefaults.data(forKey: Keys.globalPlayback) else {
            return PlaybackSettings()
        }
        
        do {
            return try JSONDecoder().decode(PlaybackSettings.self, from: data)
        } catch {
            os_log("Failed to decode global playback settings: %{public}@", log: logger, type: .error, error.localizedDescription)
            return PlaybackSettings()
        }
    }
    
    public func saveGlobalPlaybackSettings(_ settings: PlaybackSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.globalPlayback)
            settingsChangeSubject.send(.globalPlayback(settings))
        } catch {
            os_log("Failed to encode global playback settings: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Per-Podcast Settings
    
    public func loadPodcastDownloadSettings(podcastId: String) async -> PodcastDownloadSettings? {
        let key = Keys.podcastDownloadPrefix + podcastId
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(PodcastDownloadSettings.self, from: data)
        } catch {
            os_log("Failed to decode podcast download settings for %{public}@: %{public}@", log: logger, type: .error, podcastId, error.localizedDescription)
            return nil
        }
    }
    
    public func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            let key = Keys.podcastDownloadPrefix + settings.podcastId
            userDefaults.set(data, forKey: key)
            settingsChangeSubject.send(.podcastDownload(settings.podcastId, settings))
        } catch {
            os_log("Failed to encode podcast download settings: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func removePodcastDownloadSettings(podcastId: String) async {
        let key = Keys.podcastDownloadPrefix + podcastId
        userDefaults.removeObject(forKey: key)
        settingsChangeSubject.send(.podcastDownload(podcastId, nil))
    }
    
    public func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings? {
        let key = Keys.podcastPlaybackPrefix + podcastId
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(PodcastPlaybackSettings.self, from: data)
        } catch {
            os_log("Failed to decode podcast playback settings for %{public}@: %{public}@", log: logger, type: .error, podcastId, error.localizedDescription)
            return nil
        }
    }
    
    public func savePodcastPlaybackSettings(_ settings: PodcastPlaybackSettings) async {
        do {
            let data = try JSONEncoder().encode(settings)
            let key = Keys.podcastPlaybackPrefix + settings.podcastId
            userDefaults.set(data, forKey: key)
            settingsChangeSubject.send(.podcastPlayback(settings.podcastId, settings))
        } catch {
            os_log("Failed to encode podcast playback settings: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func removePodcastPlaybackSettings(podcastId: String) async {
        let key = Keys.podcastPlaybackPrefix + podcastId
        userDefaults.removeObject(forKey: key)
        settingsChangeSubject.send(.podcastPlayback(podcastId, nil))
    }
    
    // MARK: - Change Notifications
    
    public var settingsChangedPublisher: AnyPublisher<SettingsChange, Never> {
        get async {
            return settingsChangeSubject.eraseToAnyPublisher()
        }
    }
}
