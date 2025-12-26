import XCTest
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
@testable import zpod

final class Issue05SettingsIntegrationTests: XCTestCase {
  #if canImport(Combine)
    private var cancellables: Set<AnyCancellable>!
  #endif

  override func setUp() {
    super.setUp()
    #if canImport(Combine)
      cancellables = Set<AnyCancellable>()
    #endif
  }

  override func tearDown() {
    #if canImport(Combine)
      cancellables = nil
    #endif
    super.tearDown()
  }

  @MainActor
  private func makeManager(prefix: String) async -> (SettingsRepositoryHarness, SettingsManager) {
    let harness = makeSettingsRepository(prefix: prefix)
    let manager = SettingsManager(repository: harness.repository)
    await manager.waitForInitialLoad()
    return (harness, manager)
  }

  // MARK: - Playback Settings

  @MainActor
  func testPlaybackSettingsIntegrationWithSettingsManager() async {
    let (_, manager) = await makeManager(prefix: "test-playback-integration")
    let podcastId = "test-podcast-123"

    let globalPlayback = PlaybackSettings(
      globalPlaybackSpeed: 1.5,
      podcastPlaybackSpeeds: [:],
      skipForwardInterval: 30,
      skipBackwardInterval: 15,
      introSkipDurations: [:],
      outroSkipDurations: [:],
      autoMarkAsPlayed: true,
      playedThreshold: 0.9
    )
    await manager.updateGlobalPlaybackSettings(globalPlayback)

    let podcastOverrides = PodcastPlaybackSettings(
      podcastId: podcastId,
      playbackSpeed: 2.0,
      skipForwardInterval: 45,
      skipBackwardInterval: nil,
      introSkipDuration: 10,
      outroSkipDuration: 5
    )
    await manager.updatePodcastPlaybackSettings(podcastId: podcastId, podcastOverrides)

    let effective = await manager.effectivePlaybackSettings(for: podcastId)

    XCTAssertEqual(effective.globalPlaybackSpeed, 1.5)
    XCTAssertEqual(effective.autoMarkAsPlayed, true)
    XCTAssertEqual(effective.playedThreshold, 0.9)
    XCTAssertEqual(effective.playbackSpeed(for: podcastId), 2.0)
    XCTAssertEqual(effective.skipForwardInterval, 45)
    XCTAssertEqual(effective.skipBackwardInterval, 15)
    XCTAssertEqual(effective.introSkipDuration(for: podcastId), 10)
    XCTAssertEqual(effective.outroSkipDuration(for: podcastId), 5)
  }

  // MARK: - Download Settings

  @MainActor
  func testDownloadSettingsWithAutoDownloadService() async {
    let (_, manager) = await makeManager(prefix: "test-download-integration")
    let podcastId1 = "podcast-auto-enabled"
    let podcastId2 = "podcast-auto-disabled"

    let globalDownload = DownloadSettings(
      autoDownloadEnabled: false,
      wifiOnly: true,
      maxConcurrentDownloads: 3,
      retentionPolicy: .keepLatest(5)
    )
    await manager.updateGlobalDownloadSettings(globalDownload)

    let podcast1Override = PodcastDownloadSettings(
      podcastId: podcastId1,
      autoDownloadEnabled: true,
      wifiOnly: nil,
      retentionPolicy: .keepLatest(10)
    )
    await manager.updatePodcastDownloadSettings(podcastId: podcastId1, podcast1Override)

    let effective1 = await manager.effectiveDownloadSettings(for: podcastId1)
    let effective2 = await manager.effectiveDownloadSettings(for: podcastId2)

    XCTAssertEqual(effective1.autoDownloadEnabled, true)
    XCTAssertEqual(effective1.wifiOnly, true)
    XCTAssertEqual(effective1.retentionPolicy, .keepLatest(10))

    XCTAssertEqual(effective2.autoDownloadEnabled, false)
    XCTAssertEqual(effective2.wifiOnly, true)
    XCTAssertEqual(effective2.retentionPolicy, .keepLatest(5))
  }

  // MARK: - Notification Settings

  @MainActor
  func testNotificationSettingsWithCustomSounds() async {
    let (_, manager) = await makeManager(prefix: "test-notification-integration")
    let podcastId = "test-podcast-notifications"

    let globalNotifications = NotificationSettings(
      newEpisodeNotificationsEnabled: true,
      downloadCompleteNotificationsEnabled: false,
      playbackNotificationsEnabled: true,
      quietHoursEnabled: false,
      soundEnabled: true,
      customSounds: [podcastId: "custom-chime.wav"],
      deliverySchedule: .dailyDigest,
      focusModeIntegrationEnabled: false,
      liveActivitiesEnabled: true
    )
    await manager.updateGlobalNotificationSettings(globalNotifications)

    let effective = manager.effectiveNotificationSettings(for: podcastId)

    XCTAssertTrue(effective.newEpisodeNotificationsEnabled)
    XCTAssertFalse(effective.downloadCompleteNotificationsEnabled)
    XCTAssertEqual(effective.soundEnabled, true)
    XCTAssertEqual(effective.customSounds?[podcastId], "custom-chime.wav")
  }

  // MARK: - Appearance Settings

  @MainActor
  func testAppearanceSettingsIntegration() async {
    let (_, manager) = await makeManager(prefix: "test-appearance-integration")

    let appearance = AppearanceSettings(
      theme: .dark,
      preferredTint: .pink,
      typographyScale: 1.3,
      reduceMotionEnabled: true,
      reduceHapticsEnabled: true,
      highContrastEnabled: false
    )

    await manager.updateGlobalAppearanceSettings(appearance)

    XCTAssertEqual(manager.globalAppearanceSettings.theme, .dark)
    XCTAssertEqual(manager.globalAppearanceSettings.preferredTint, .pink)
    XCTAssertTrue(manager.globalAppearanceSettings.reduceMotionEnabled)
    XCTAssertEqual(manager.globalAppearanceSettings.typographyScale, 1.3, accuracy: 0.0001)
  }

  // MARK: - Smart List Automation

  @MainActor
  func testSmartListAutomationIntegration() async {
    let (_, manager) = await makeManager(prefix: "test-smartlist-integration")

    let automation = SmartListRefreshConfiguration(
      isEnabled: false,
      globalInterval: 1800,
      maxRefreshPerCycle: 3,
      refreshOnForeground: false,
      refreshOnNetworkChange: true
    )

    await manager.updateSmartListAutomationSettings(automation)

    XCTAssertFalse(manager.globalSmartListAutomationSettings.isEnabled)
    XCTAssertEqual(manager.globalSmartListAutomationSettings.globalInterval, 1800, accuracy: 0.001)
    XCTAssertEqual(manager.globalSmartListAutomationSettings.maxRefreshPerCycle, 3)
    XCTAssertTrue(manager.globalSmartListAutomationSettings.refreshOnNetworkChange)
  }

  // MARK: - Playback Presets

  @MainActor
  func testPlaybackPresetLibraryIntegration() async {
    let (_, manager) = await makeManager(prefix: "test-playback-presets-integration")

    let customPreset = PlaybackPreset(
      id: "evening",
      name: "Evening Wind Down",
      description: "Slower speed for winding down",
      playbackSpeed: 0.95,
      skipForwardInterval: 20,
      skipBackwardInterval: 10,
      skipIntroSeconds: 5,
      skipOutroSeconds: 10,
      continuousPlayback: false,
      crossFadeEnabled: true,
      crossFadeDuration: 0.8,
      autoMarkAsPlayed: false,
      playedThreshold: 0.92
    )

    let library = PlaybackPresetLibrary(
      builtInPresets: PlaybackPresetLibrary.defaultBuiltInPresets,
      customPresets: [customPreset],
      activePresetID: customPreset.id
    )

    await manager.playbackPresetConfigurationService.saveLibrary(library)

    let controller = manager.makePlaybackPresetConfigurationController()
    await controller.loadBaseline()
    XCTAssertEqual(controller.draftLibrary.activePresetID, customPreset.id)
  }

  // MARK: - Reactive Updates

  @MainActor
  func testSettingsManagerReactiveIntegration() async throws {
    #if !canImport(Combine)
      throw XCTSkip("Combine is not available on this platform")
    #else
      let (harness, manager) = await makeManager(prefix: "test-reactive-integration")
      let repository = harness.repository

      var publishedSettings: [DownloadSettings] = []
      var publishedChanges: [SettingsChange] = []

      manager.$globalDownloadSettings
        .sink { settings in
          publishedSettings.append(settings)
        }
        .store(in: &cancellables)

      let changeExpectation = expectation(description: "Received change notification")
      let changeTask = Task {
        let stream = await repository.settingsChangeStream()
        for await change in stream {
          publishedChanges.append(change)
          changeExpectation.fulfill()
          break
        }
      }

      let newSettings = DownloadSettings(
        autoDownloadEnabled: true,
        wifiOnly: false,
        maxConcurrentDownloads: 5,
        retentionPolicy: .deleteAfterDays(30)
      )
      await manager.updateGlobalDownloadSettings(newSettings)

      await fulfillment(of: [changeExpectation], timeout: 1.0)
      changeTask.cancel()

      XCTAssertEqual(publishedSettings.count, 2)
      XCTAssertEqual(publishedSettings.last, newSettings)

      XCTAssertEqual(publishedChanges.count, 1)
      if case .globalDownload(let settings) = publishedChanges.first {
        XCTAssertEqual(settings, newSettings)
      } else {
        XCTFail("Expected globalDownload change notification")
      }
    #endif
  }

  // MARK: - Persistence

  @MainActor
  func testSettingsPersistenceAcrossManagerInstances() async {
    let (harness, manager1) = await makeManager(prefix: "test-persistence")
    let repository = harness.repository
    let podcastId = "test-podcast-persistence"

    let downloadSettings = DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: false,
      maxConcurrentDownloads: 2,
      retentionPolicy: .deleteAfterPlayed
    )
    await manager1.updateGlobalDownloadSettings(downloadSettings)

    let podcastSettings = PodcastDownloadSettings(
      podcastId: podcastId,
      autoDownloadEnabled: false,
      wifiOnly: true,
      retentionPolicy: .keepLatest(20)
    )
    await manager1.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)

    let manager2 = SettingsManager(repository: repository)
    await manager2.waitForInitialLoad()

    XCTAssertEqual(manager2.globalDownloadSettings, downloadSettings)
    let effective = await manager2.effectiveDownloadSettings(for: podcastId)

    XCTAssertEqual(effective.autoDownloadEnabled, false)
    XCTAssertEqual(effective.wifiOnly, true)
    XCTAssertEqual(effective.maxConcurrentDownloads, 2)
    XCTAssertEqual(effective.retentionPolicy, .keepLatest(20))
  }

  // MARK: - Validation

  @MainActor
  func testSettingsValidationEdgeCases() async {
    let (_, manager) = await makeManager(prefix: "test-validation-edge")

    let largeDownloads = DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: false,
      maxConcurrentDownloads: 100,
      retentionPolicy: .keepLatest(1)
    )
    await manager.updateGlobalDownloadSettings(largeDownloads)

    var downloadSettings = manager.globalDownloadSettings
    XCTAssertEqual(downloadSettings.maxConcurrentDownloads, 10)

    let negativeRetention = DownloadSettings(
      autoDownloadEnabled: false,
      wifiOnly: true,
      maxConcurrentDownloads: 3,
      retentionPolicy: .keepLatest(-5)
    )
    await manager.updateGlobalDownloadSettings(negativeRetention)

    downloadSettings = manager.globalDownloadSettings
    XCTAssertEqual(downloadSettings.maxConcurrentDownloads, 3)
    XCTAssertEqual(downloadSettings.retentionPolicy, .keepLatest(1))

    let invalidSpeed = PodcastPlaybackSettings(
      podcastId: "test",
      playbackSpeed: 10.0,
      skipForwardInterval: -10,
      skipBackwardInterval: 1000,
      introSkipDuration: nil,
      outroSkipDuration: nil
    )
    await manager.updatePodcastPlaybackSettings(podcastId: "test", invalidSpeed)

    let playbackSettings = await manager.effectivePlaybackSettings(for: "test")
    XCTAssertEqual(playbackSettings.playbackSpeed(for: "test"), 5.0)
    XCTAssertEqual(playbackSettings.skipForwardInterval, 5)
    XCTAssertEqual(playbackSettings.skipBackwardInterval, 300)
  }
}
