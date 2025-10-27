import CoreModels
import Foundation
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
  nonisolated func settingsChangeStream() -> AsyncStream<SettingsChange>
}

/// UserDefaults-based implementation of SettingsRepository
public actor UserDefaultsSettingsRepository: @preconcurrency SettingsRepository {
  private let userDefaults: UserDefaults
  private var changeContinuations: [UUID: AsyncStream<SettingsChange>.Continuation] = [:]

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

  private func broadcast(_ change: SettingsChange) {
    for continuation in changeContinuations.values {
      continuation.yield(change)
    }
  }

  private func addContinuation(id: UUID, continuation: AsyncStream<SettingsChange>.Continuation) {
    changeContinuations[id] = continuation
  }

  private func removeContinuation(id: UUID) {
    changeContinuations.removeValue(forKey: id)
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
      broadcast(.globalDownload(settings))

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
      broadcast(.globalNotification(settings))

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
      broadcast(.globalPlayback(settings))

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
      #if DEBUG
        print("🔍 SettingsRepository: No data found for key '\(Keys.globalUI)', returning default")
      #endif
      return UISettings.default
    }

    #if DEBUG
      print(
        "🔍 SettingsRepository: Found data for key '\(Keys.globalUI)', size: \(data.count) bytes")
    #endif

    do {
      let settings = try JSONDecoder().decode(UISettings.self, from: data)
      #if DEBUG
        print(
          "🔍 SettingsRepository: Decoded UISettings - hapticFeedbackEnabled: \(settings.swipeActions.hapticFeedbackEnabled)"
        )
      #endif
      return settings
    } catch {
      #if canImport(os)
        os_log(
          "Failed to decode global UI settings: %{public}@", log: logger, type: .error,
          error.localizedDescription)
      #endif
      #if DEBUG
        print("🔍 SettingsRepository: Decode failed: \(error), returning default")
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

      broadcast(.globalUI(settings))

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
      broadcast(.globalAppearance(settings))

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
      broadcast(.globalSmartListAutomation(settings))

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
      broadcast(.globalPlaybackPresets(library))

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
      broadcast(.podcastDownload(settings.podcastId, settings))

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
    broadcast(.podcastDownload(podcastId, nil))

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
      broadcast(.podcastPlayback(podcastId, settings))

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
    broadcast(.podcastPlayback(podcastId, nil))

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

  public nonisolated func settingsChangeStream() -> AsyncStream<SettingsChange> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await self.addContinuation(id: id, continuation: continuation) }
      continuation.onTermination = { _ in
        Task { await self.removeContinuation(id: id) }
      }
    }
  }
}
