import CoreModels
import Foundation
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
    @Published public private(set) var globalAppearanceSettings: AppearanceSettings
    @Published public private(set) var globalSmartListAutomationSettings:
      SmartListRefreshConfiguration
    @Published public private(set) var playbackPresetLibrary: PlaybackPresetLibrary
    @Published public private(set) var globalPlaybackSettings: PlaybackSettings
    @Published public private(set) var globalUISettings: UISettings
  #else
    public private(set) var globalDownloadSettings: DownloadSettings
    public private(set) var globalNotificationSettings: NotificationSettings
    public private(set) var globalAppearanceSettings: AppearanceSettings
    public private(set) var globalSmartListAutomationSettings: SmartListRefreshConfiguration
    public private(set) var playbackPresetLibrary: PlaybackPresetLibrary
    public private(set) var globalPlaybackSettings: PlaybackSettings
    public private(set) var globalUISettings: UISettings
  #endif

  private let notificationsConfigurationServiceImpl: NotificationsConfigurationServicing
  private let appearanceConfigurationServiceImpl: AppearanceConfigurationServicing
  private let smartListAutomationServiceImpl: SmartListAutomationConfigurationServicing
  private let playbackPresetConfigurationServiceImpl: PlaybackPresetConfigurationServicing
  private let swipeConfigurationServiceImpl: SwipeConfigurationServicing
  private let playbackConfigurationServiceImpl: PlaybackConfigurationServicing
  private let downloadConfigurationServiceImpl: DownloadConfigurationServicing
  public lazy var featureConfigurationRegistry: FeatureConfigurationRegistry =
    buildFeatureRegistry()
  private var featureControllerCache: [String: any FeatureConfigurationControlling] = [:]

  public var notificationsConfigurationService: NotificationsConfigurationServicing {
    notificationsConfigurationServiceImpl
  }

  public var appearanceConfigurationService: AppearanceConfigurationServicing {
    appearanceConfigurationServiceImpl
  }

  public var smartListAutomationService: SmartListAutomationConfigurationServicing {
    smartListAutomationServiceImpl
  }

  public var playbackPresetConfigurationService: PlaybackPresetConfigurationServicing {
    playbackPresetConfigurationServiceImpl
  }

  public var swipeConfigurationService: SwipeConfigurationServicing {
    swipeConfigurationServiceImpl
  }

  public var playbackConfigurationService: PlaybackConfigurationServicing {
    playbackConfigurationServiceImpl
  }

  public var downloadConfigurationService: DownloadConfigurationServicing {
    downloadConfigurationServiceImpl
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

  public func makeNotificationsConfigurationController() -> NotificationsConfigurationController {
    let controller = NotificationsConfigurationController(
      service: notificationsConfigurationServiceImpl)
    controller.bootstrap(with: globalNotificationSettings)
    return controller
  }

  public func makeAppearanceConfigurationController() -> AppearanceConfigurationController {
    let controller = AppearanceConfigurationController(service: appearanceConfigurationServiceImpl)
    controller.bootstrap(with: globalAppearanceSettings)
    return controller
  }

  public func makeSmartListAutomationConfigurationController()
    -> SmartListAutomationConfigurationController
  {
    let controller = SmartListAutomationConfigurationController(
      service: smartListAutomationServiceImpl)
    controller.bootstrap(with: globalSmartListAutomationSettings)
    return controller
  }

  public func makePlaybackPresetConfigurationController() -> PlaybackPresetConfigurationController {
    let controller = PlaybackPresetConfigurationController(
      service: playbackPresetConfigurationServiceImpl,
      applyPresetHandler: { [weak self] preset, library in
        guard let self else { return }
        self.didUpdatePlaybackPresetLibrary(library, activePreset: preset)
      }
    )
    controller.bootstrap(with: playbackPresetLibrary)
    return controller
  }

  public func makePlaybackConfigurationController() -> PlaybackConfigurationController {
    let controller = PlaybackConfigurationController(service: playbackConfigurationServiceImpl)
    controller.bootstrap(with: globalPlaybackSettings)
    return controller
  }

  public func makeDownloadConfigurationController() -> DownloadConfigurationController {
    let controller = DownloadConfigurationController(service: downloadConfigurationServiceImpl)
    controller.bootstrap(with: globalDownloadSettings)
    return controller
  }

  public func allFeatureDescriptors() async -> [FeatureConfigurationDescriptor] {
    await featureConfigurationRegistry.allDescriptors()
  }

  public func allFeatureSections() async -> [FeatureConfigurationSection] {
    await featureConfigurationRegistry.groupedDescriptors()
  }

  public func controller(forFeature id: String, useCache: Bool = true) async -> (
    any FeatureConfigurationControlling
  )? {
    if useCache, let cached = featureControllerCache[id] {
      return cached
    }

    let controller: any FeatureConfigurationControlling

    if id == "notifications" {
      controller = makeNotificationsConfigurationController()
    } else if id == "appearance" {
      controller = makeAppearanceConfigurationController()
    } else if id == "smartListAutomation" {
      controller = makeSmartListAutomationConfigurationController()
    } else if id == "swipeActions" {
      controller = makeSwipeConfigurationController()
    } else if id == "playbackPreferences" {
      controller = makePlaybackConfigurationController()
    } else if id == "playbackPresets" {
      controller = makePlaybackPresetConfigurationController()
    } else if id == "downloadPolicies" {
      controller = makeDownloadConfigurationController()
    } else {
      guard let resolved = await featureConfigurationRegistry.controller(for: id) else {
        return nil
      }
      controller = resolved
    }

    if useCache {
      featureControllerCache[id] = controller
    }

    return controller
  }

  public init(repository: SettingsRepository) {
    self.repository = repository

    let notificationsService = NotificationsConfigurationService(repository: repository)
    let appearanceService = AppearanceConfigurationService(repository: repository)
    let smartListService = SmartListAutomationConfigurationService(repository: repository)
    let playbackPresetService = PlaybackPresetConfigurationService(repository: repository)
    let swipeService = SwipeConfigurationService(repository: repository)
    let playbackService = PlaybackConfigurationService(repository: repository)
    let downloadService = DownloadConfigurationService(repository: repository)
    self.notificationsConfigurationServiceImpl = notificationsService
    self.appearanceConfigurationServiceImpl = appearanceService
    self.smartListAutomationServiceImpl = smartListService
    self.playbackPresetConfigurationServiceImpl = playbackPresetService
    self.swipeConfigurationServiceImpl = swipeService
    self.playbackConfigurationServiceImpl = playbackService
    self.downloadConfigurationServiceImpl = downloadService
    // Initialize with defaults temporarily
    self.globalDownloadSettings = DownloadSettings.default
    self.globalNotificationSettings = NotificationSettings.default
    self.globalAppearanceSettings = AppearanceSettings.default
    self.globalSmartListAutomationSettings = SmartListRefreshConfiguration()
    self.playbackPresetLibrary = PlaybackPresetLibrary.default
    self.globalPlaybackSettings = PlaybackSettings()
    self.globalUISettings = UISettings.default

    // Load initial values from repository asynchronously after initialization
    Task {
      let downloadSettings = await repository.loadGlobalDownloadSettings()
      let notificationSettings = await repository.loadGlobalNotificationSettings()
      let appearanceSettings = await repository.loadGlobalAppearanceSettings()
      let smartListAutomationSettings = await repository.loadSmartListAutomationSettings()
      let presetLibrary = await repository.loadPlaybackPresetLibrary()
      let playbackSettings = await repository.loadGlobalPlaybackSettings()
      let uiSettings = await repository.loadGlobalUISettings()

      await MainActor.run {
        self.globalDownloadSettings = downloadSettings
        self.globalNotificationSettings = notificationSettings
        self.globalAppearanceSettings = appearanceSettings
        self.globalSmartListAutomationSettings = smartListAutomationSettings
        self.playbackPresetLibrary = presetLibrary
        self.globalPlaybackSettings = playbackSettings
        self.globalUISettings = uiSettings
      }
    }  // Bridge repository change notifications to a synchronous publisher
    #if canImport(Combine)
      Task { [weak self] in
        let repoPublisher = await repository.settingsChangedPublisher
        await MainActor.run { [weak self] in
          guard let self = self else { return }
          repoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
              guard let self = self else { return }
              self.applyRepositoryChange(change)
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
      customSounds: global.customSounds,
      deliverySchedule: global.deliverySchedule,
      focusModeIntegrationEnabled: global.focusModeIntegrationEnabled,
      liveActivitiesEnabled: global.liveActivitiesEnabled
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

  /// Update global appearance settings
  public func updateGlobalAppearanceSettings(_ settings: AppearanceSettings) async {
    await repository.saveGlobalAppearanceSettings(settings)
    globalAppearanceSettings = settings
  }

  /// Update smart list automation settings
  public func updateSmartListAutomationSettings(_ settings: SmartListRefreshConfiguration) async {
    await repository.saveSmartListAutomationSettings(settings)
    globalSmartListAutomationSettings = settings
  }

  /// Update global UI settings
  public func updateGlobalUISettings(_ settings: UISettings) async {
    let configuration = SwipeConfiguration(
      swipeActions: settings.swipeActions,
      hapticStyle: settings.hapticStyle
    )

    do {
      try await swipeConfigurationServiceImpl.save(configuration)
    } catch {
      await repository.saveGlobalUISettings(settings)
    }

    globalUISettings = settings
  }

  public func loadPersistedUISettings() async -> UISettings {
    let settings = await repository.loadGlobalUISettings()
    return settings
  }

  /// Update podcast-specific download settings (nil removes override)
  public func updatePodcastDownloadSettings(podcastId: String, _ settings: PodcastDownloadSettings?)
    async
  {
    if let settings = settings {
      await repository.savePodcastDownloadSettings(settings)
    } else {
      await repository.removePodcastDownloadSettings(podcastId: podcastId)
    }
  }

  /// Update podcast-specific playback settings (nil removes override)
  public func updatePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings?)
    async
  {
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

  private func handleSettingsChange(_ change: SettingsChange) {
    switch change {
    case .globalDownload(let settings):
      globalDownloadSettings = settings
    case .globalNotification(let settings):
      globalNotificationSettings = settings
    case .globalAppearance(let settings):
      globalAppearanceSettings = settings
    case .globalSmartListAutomation(let settings):
      globalSmartListAutomationSettings = settings
    case .globalPlaybackPresets(let library):
      playbackPresetLibrary = library
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

#if canImport(Combine)
  extension SettingsManager {
    @MainActor
    private func applyRepositoryChange(_ change: SettingsChange) {
      handleSettingsChange(change)
      settingsChangeSubject.send(change)
    }
  }
#else
  extension SettingsManager {
    @MainActor
    private func applyRepositoryChange(_ change: SettingsChange) {
      handleSettingsChange(change)
    }
  }
#endif

extension SettingsManager {
  fileprivate func didUpdatePlaybackPresetLibrary(
    _ library: PlaybackPresetLibrary, activePreset: PlaybackPreset?
  ) {
    playbackPresetLibrary = library
    var targetSettings = globalPlaybackSettings
    if let preset = activePreset {
      targetSettings = preset.applying(to: targetSettings)
    } else {
      targetSettings.activePresetID = nil
    }
    Task { await updateGlobalPlaybackSettings(targetSettings) }
  }

  fileprivate func buildFeatureRegistry() -> FeatureConfigurationRegistry {
    FeatureConfigurationRegistry(
      features: [
        NotificationsConfigurationFeature(service: notificationsConfigurationServiceImpl),
        AppearanceConfigurationFeature(service: appearanceConfigurationServiceImpl),
        SmartListAutomationConfigurationFeature(service: smartListAutomationServiceImpl),
        PlaybackPresetConfigurationFeature(
          service: playbackPresetConfigurationServiceImpl,
          applyPresetHandler: { [weak self] preset, library in
            guard let self else { return }
            self.didUpdatePlaybackPresetLibrary(library, activePreset: preset)
          }
        ),
        SwipeConfigurationFeature(service: swipeConfigurationServiceImpl),
        PlaybackConfigurationFeature(service: playbackConfigurationServiceImpl),
        DownloadConfigurationFeature(service: downloadConfigurationServiceImpl),
      ]
    )
  }
}

// MARK: - ObservableObject Conformance
#if canImport(SwiftUI)
  extension SettingsManager: ObservableObject {}
#endif

// MARK: - Placeholder Feature

final class PlaceholderConfigurableFeature: ConfigurableFeature, @unchecked Sendable {
  let descriptor: FeatureConfigurationDescriptor

  init(descriptor: FeatureConfigurationDescriptor) {
    self.descriptor = descriptor
  }

  func isAvailable() async -> Bool { true }

  @MainActor
  func makeController() -> any FeatureConfigurationControlling {
    PlaceholderConfigurationController()
  }
}

@MainActor
private final class PlaceholderConfigurationController: FeatureConfigurationControlling {
  func resetToBaseline() async {}
}
