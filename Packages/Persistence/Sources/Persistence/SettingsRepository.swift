import CoreModels
import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif
#if canImport(os)
  import os.log
#endif

/// Types of settings changes for change notifications
public enum SettingsChange: Equatable, Sendable {
  case globalDownload(DownloadSettings)
  case globalNotification(NotificationSettings)
  case globalPlayback(PlaybackSettings)
  case globalUI(UISettings)
  case globalAppearance(AppearanceSettings)
  case globalSmartListAutomation(SmartListRefreshConfiguration)
  case globalPlaybackPresets(PlaybackPresetLibrary)
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

  func loadGlobalUISettings() async -> UISettings
  func saveGlobalUISettings(_ settings: UISettings) async

  func loadGlobalAppearanceSettings() async -> AppearanceSettings
  func saveGlobalAppearanceSettings(_ settings: AppearanceSettings) async

  func loadSmartListAutomationSettings() async -> SmartListRefreshConfiguration
  func saveSmartListAutomationSettings(_ settings: SmartListRefreshConfiguration) async

  func loadPlaybackPresetLibrary() async -> PlaybackPresetLibrary
  func savePlaybackPresetLibrary(_ library: PlaybackPresetLibrary) async

  // Per-podcast overrides
  func loadPodcastDownloadSettings(podcastId: String) async -> PodcastDownloadSettings?
  func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async
  func removePodcastDownloadSettings(podcastId: String) async

  func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings?
  func savePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings) async
  func removePodcastPlaybackSettings(podcastId: String) async

  // Change notifications
  #if canImport(Combine)
    var settingsChangedPublisher: AnyPublisher<SettingsChange, Never> { get async }
  #endif
}

/// UserDefaults-based implementation of SettingsRepository
public actor UserDefaultsSettingsRepository: @preconcurrency SettingsRepository {
  private let userDefaults: UserDefaults
  #if canImport(Combine)
    private let settingsChangeSubject = PassthroughSubject<SettingsChange, Never>()
  #endif

  // Logger for settings-related errors
  #if canImport(os)
    private let logger = OSLog(
      subsystem: "com.zpodcastaddict.settings", category: "SettingsRepository")
  #endif

  public init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  public init(suiteName: String) {
    if let suiteDefaults = UserDefaults(suiteName: suiteName) {
      self.userDefaults = suiteDefaults
    } else {
      self.userDefaults = .standard
    }
  }

  // MARK: - Keys for UserDefaults storage

  private enum Keys {
    static let globalDownload = "global_download_settings"
    static let globalNotification = "global_notification_settings"
    static let globalPlayback = "global_playback_settings"
    static let globalUI = "global_ui_settings"
    static let globalAppearance = "global_appearance_settings"
    static let globalSmartListAutomation = "smart_list_background_configuration"
    static let playbackPresetLibrary = "playback_preset_library"
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
      #if canImport(os)
        #if canImport(os)
          os_log(
            "Failed to decode global download settings: %{public}@", log: logger, type: .error,
            error.localizedDescription)
        #endif
      #endif
      return DownloadSettings.default
    }
  }

  public func saveGlobalDownloadSettings(_ settings: DownloadSettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalDownload)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalDownload(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode global download settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadGlobalNotificationSettings() async -> NotificationSettings {
    guard let data = userDefaults.data(forKey: Keys.globalNotification) else {
      return NotificationSettings.default
    }

    do {
      return try JSONDecoder().decode(NotificationSettings.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode global notification settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return NotificationSettings.default
    }
  }

  public func saveGlobalNotificationSettings(_ settings: NotificationSettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalNotification)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalNotification(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode global notification settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadGlobalPlaybackSettings() async -> PlaybackSettings {
    guard let data = userDefaults.data(forKey: Keys.globalPlayback) else {
      return PlaybackSettings()
    }

    do {
      return try JSONDecoder().decode(PlaybackSettings.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode global playback settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return PlaybackSettings()
    }
  }

  public func saveGlobalPlaybackSettings(_ settings: PlaybackSettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalPlayback)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalPlayback(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode global playback settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadGlobalUISettings() async -> UISettings {
    loadGlobalUISettingsSync()
  }

  /// Synchronous version of loadGlobalUISettings for use during initialization
  /// where async context is not available or would cause race conditions.
  public func loadGlobalUISettingsSync() -> UISettings {
    guard let data = userDefaults.data(forKey: Keys.globalUI) else {
      return UISettings.default
    }

    do {
      return try JSONDecoder().decode(UISettings.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode global UI settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return UISettings.default
    }
  }

  public func saveGlobalUISettings(_ settings: UISettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalUI)
      userDefaults.synchronize()  // Force immediate write to disk for UI tests

      // Give UserDefaults a moment to fully persist (especially important for UI tests
      // that terminate the app immediately after saving)
      try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

      #if canImport(Combine)
        settingsChangeSubject.send(.globalUI(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode global UI settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadGlobalAppearanceSettings() async -> AppearanceSettings {
    guard let data = userDefaults.data(forKey: Keys.globalAppearance) else {
      return AppearanceSettings.default
    }

    do {
      return try JSONDecoder().decode(AppearanceSettings.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode global appearance settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return AppearanceSettings.default
    }
  }

  public func saveGlobalAppearanceSettings(_ settings: AppearanceSettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalAppearance)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalAppearance(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode global appearance settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadSmartListAutomationSettings() async -> SmartListRefreshConfiguration {
    guard let data = userDefaults.data(forKey: Keys.globalSmartListAutomation) else {
      return SmartListRefreshConfiguration()
    }

    do {
      return try JSONDecoder().decode(SmartListRefreshConfiguration.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode smart list automation settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return SmartListRefreshConfiguration()
    }
  }

  public func saveSmartListAutomationSettings(_ settings: SmartListRefreshConfiguration) async {
    do {
      let data = try JSONEncoder().encode(settings)
      userDefaults.set(data, forKey: Keys.globalSmartListAutomation)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalSmartListAutomation(settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode smart list automation settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func loadPlaybackPresetLibrary() async -> PlaybackPresetLibrary {
    guard let data = userDefaults.data(forKey: Keys.playbackPresetLibrary) else {
      return PlaybackPresetLibrary.default
    }

    do {
      return try JSONDecoder().decode(PlaybackPresetLibrary.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode playback preset library: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      return PlaybackPresetLibrary.default
    }
  }

  public func savePlaybackPresetLibrary(_ library: PlaybackPresetLibrary) async {
    do {
      let data = try JSONEncoder().encode(library)
      userDefaults.set(data, forKey: Keys.playbackPresetLibrary)
      #if canImport(Combine)
        settingsChangeSubject.send(.globalPlaybackPresets(library))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode playback preset library: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
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
      #if canImport(os)
        os_log(
          "Failed to decode podcast download settings for %{public}@: %{public}@", log: logger,
          type: .error, podcastId, error.localizedDescription)
      #endif
      return nil
    }
  }

  public func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async {
    do {
      let data = try JSONEncoder().encode(settings)
      let key = Keys.podcastDownloadPrefix + settings.podcastId
      userDefaults.set(data, forKey: key)
      #if canImport(Combine)
        settingsChangeSubject.send(.podcastDownload(settings.podcastId, settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode podcast download settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func removePodcastDownloadSettings(podcastId: String) async {
    let key = Keys.podcastDownloadPrefix + podcastId
    userDefaults.removeObject(forKey: key)
    #if canImport(Combine)
      settingsChangeSubject.send(.podcastDownload(podcastId, nil))
    #endif
  }

  public func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings? {
    let key = Keys.podcastPlaybackPrefix + podcastId
    guard let data = userDefaults.data(forKey: key) else {
      return nil
    }

    do {
      return try JSONDecoder().decode(PodcastPlaybackSettings.self, from: data)
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode podcast playback settings for %{public}@: %{public}@", log: logger,
          type: .error, podcastId, error.localizedDescription)
      #endif
      return nil
    }
  }

  public func savePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings)
    async
  {
    do {
      let data = try JSONEncoder().encode(settings)
      let key = Keys.podcastPlaybackPrefix + podcastId
      userDefaults.set(data, forKey: key)
      #if canImport(Combine)
        settingsChangeSubject.send(.podcastPlayback(podcastId, settings))
      #endif
    } catch {
      #if canImport(os)
        os_log(
          "Failed to encode podcast playback settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
    }
  }

  public func removePodcastPlaybackSettings(podcastId: String) async {
    let key = Keys.podcastPlaybackPrefix + podcastId
    userDefaults.removeObject(forKey: key)
    #if canImport(Combine)
      settingsChangeSubject.send(.podcastPlayback(podcastId, nil))
    #endif
  }

  // MARK: - Test Utilities

  public func clearAll() {
    userDefaults.removeObject(forKey: Keys.globalDownload)
    userDefaults.removeObject(forKey: Keys.globalNotification)
    userDefaults.removeObject(forKey: Keys.globalPlayback)
    userDefaults.removeObject(forKey: Keys.globalUI)
    userDefaults.removeObject(forKey: Keys.globalAppearance)
    userDefaults.removeObject(forKey: Keys.globalSmartListAutomation)
    userDefaults.removeObject(forKey: Keys.playbackPresetLibrary)

    let allKeys = userDefaults.dictionaryRepresentation().keys
    for key in allKeys {
      if key.hasPrefix(Keys.podcastDownloadPrefix) || key.hasPrefix(Keys.podcastPlaybackPrefix) {
        userDefaults.removeObject(forKey: key)
      }
    }
  }

  // MARK: - Change Notifications

  #if canImport(Combine)
    public var settingsChangedPublisher: AnyPublisher<SettingsChange, Never> {
      get async {
        return settingsChangeSubject.eraseToAnyPublisher()
      }
    }

    public func settingsChangeStream() -> AsyncStream<SettingsChange> {
      AsyncStream { continuation in
        let cancellable = settingsChangeSubject.sink { change in
          continuation.yield(change)
        }

        continuation.onTermination = { _ in
          cancellable.cancel()
        }
      }
    }
  #endif
}
