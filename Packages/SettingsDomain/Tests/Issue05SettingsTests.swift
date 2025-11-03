import XCTest
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
@testable import zpod

final class Issue05SettingsTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - DownloadSettings Tests
    
    func testDownloadSettingsDefaults() {
        // Given: DownloadSettings default values
        let settings = DownloadSettings.default
        
        // Then: Should have expected default values
        XCTAssertEqual(settings.autoDownloadEnabled, false)
        XCTAssertEqual(settings.wifiOnly, true)
        XCTAssertEqual(settings.maxConcurrentDownloads, 3)
        XCTAssertEqual(settings.retentionPolicy, .keepLatest(5))
    }
    
    func testDownloadSettingsCodable() throws {
        // Given: DownloadSettings with custom values
        let original = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .deleteAfterDays(30)
        )
        
        // When: Encode and decode
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DownloadSettings.self, from: data)
        
        // Then: Should round-trip correctly
        XCTAssertEqual(original, decoded)
    }
    
    func testRetentionPolicyCodable() throws {
        let policies: [RetentionPolicy] = [
            .keepAll,
            .keepLatest(10),
            .deleteAfterDays(7),
            .deleteAfterPlayed
        ]
        
        for policy in policies {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(RetentionPolicy.self, from: data)
            XCTAssertEqual(policy, decoded)
        }
    }
    
    // MARK: - PodcastDownloadSettings Tests
    
    func testPodcastDownloadSettingsWithOverrides() {
        // Given: Podcast settings with some overrides
        let settings = PodcastDownloadSettings(
            podcastId: "test-podcast-1",
            autoDownloadEnabled: true,
            wifiOnly: nil,  // Use global
            retentionPolicy: .keepLatest(10)
        )
        
        // Then: Should have expected values
        XCTAssertEqual(settings.podcastId, "test-podcast-1")
        XCTAssertEqual(settings.autoDownloadEnabled, true)
        XCTAssertNil(settings.wifiOnly)
        XCTAssertEqual(settings.retentionPolicy, .keepLatest(10))
    }
    
    func testPodcastDownloadSettingsCodable() throws {
        // Given: PodcastDownloadSettings with mixed overrides
        let original = PodcastDownloadSettings(
            podcastId: "test-podcast-1",
            autoDownloadEnabled: false,
            wifiOnly: true,
            retentionPolicy: nil
        )
        
        // When: Encode and decode
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PodcastDownloadSettings.self, from: data)
        
        // Then: Should round-trip correctly
        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - NotificationSettings Tests
    
    func testNotificationSettingsDefaults() {
        // Given: NotificationSettings default values
        let settings = NotificationSettings.default
        
        // Then: Should have expected default values
        XCTAssertTrue(settings.newEpisodeNotificationsEnabled)
        XCTAssertTrue(settings.downloadCompleteNotificationsEnabled)
        XCTAssertTrue(settings.playbackNotificationsEnabled)
        XCTAssertNil(settings.soundEnabled)
        XCTAssertNil(settings.customSounds)
        XCTAssertEqual(settings.deliverySchedule, .immediate)
        XCTAssertFalse(settings.focusModeIntegrationEnabled)
        XCTAssertTrue(settings.liveActivitiesEnabled)
    }
    
    func testNotificationSettingsWithCustomSounds() {
        // Given: NotificationSettings with custom sounds
        let customSounds = [
            "podcast-1": "chime.wav",
            "podcast-2": "bell.wav"
        ]
        let settings = NotificationSettings(
            newEpisodeNotificationsEnabled: true,
            downloadCompleteNotificationsEnabled: true,
            playbackNotificationsEnabled: true,
            quietHoursEnabled: false,
            soundEnabled: true,
            customSounds: customSounds,
            deliverySchedule: .batched,
            focusModeIntegrationEnabled: true,
            liveActivitiesEnabled: false
        )
        
        // Then: Should have expected values
        XCTAssertEqual(settings.customSounds?["podcast-1"], "chime.wav")
        XCTAssertEqual(settings.customSounds?["podcast-2"], "bell.wav")
        XCTAssertEqual(settings.deliverySchedule, .batched)
        XCTAssertTrue(settings.focusModeIntegrationEnabled)
        XCTAssertFalse(settings.liveActivitiesEnabled)
    }
    
    func testNotificationSettingsCodable() throws {
        // Given: NotificationSettings with custom sounds
        let original = NotificationSettings(
            newEpisodeNotificationsEnabled: false,
            downloadCompleteNotificationsEnabled: true,
            playbackNotificationsEnabled: false,
            quietHoursEnabled: true,
            quietHoursStart: "20:00",
            quietHoursEnd: "07:00",
            soundEnabled: false,
            customSounds: ["test": "sound.wav"],
            deliverySchedule: .weeklySummary,
            focusModeIntegrationEnabled: true,
            liveActivitiesEnabled: false
        )
        
        // When: Encode and decode
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: data)
        
        // Then: Should round-trip correctly
        XCTAssertEqual(original, decoded)
    }

    func testAppearanceSettingsDefaults() {
        let settings = AppearanceSettings.default

        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.preferredTint, .accent)
        XCTAssertEqual(settings.typographyScale, 1.0, accuracy: 0.0001)
        XCTAssertFalse(settings.reduceMotionEnabled)
        XCTAssertFalse(settings.reduceHapticsEnabled)
        XCTAssertFalse(settings.highContrastEnabled)
    }

    func testAppearanceSettingsCodable() throws {
        let original = AppearanceSettings(
            theme: .highContrast,
            preferredTint: .orange,
            typographyScale: 1.35,
            reduceMotionEnabled: true,
            reduceHapticsEnabled: true,
            highContrastEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppearanceSettings.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testSmartListRefreshConfigurationCodable() throws {
        let original = SmartListRefreshConfiguration(
            isEnabled: false,
            globalInterval: 1800,
            maxRefreshPerCycle: 4,
            refreshOnForeground: false,
            refreshOnNetworkChange: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SmartListRefreshConfiguration.self, from: data)

        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - UserDefaultsSettingsRepository Tests
    
    func testUserDefaultsSettingsRepositorySaveLoadGlobalDownloadSettings() {
        // Given: Repository with test UserDefaults
        let userDefaults = UserDefaults(suiteName: "test-settings")!
        userDefaults.removePersistentDomain(forName: "test-settings")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        let originalSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 2,
            retentionPolicy: .deleteAfterDays(14)
        )
        
        // When: Save and load settings
        repository.saveGlobalDownloadSettings(originalSettings)
        let loadedSettings = repository.loadGlobalDownloadSettings()
        
        // Then: Should load same settings
        XCTAssertEqual(loadedSettings, originalSettings)
    }
    
    func testUserDefaultsSettingsRepositorySaveLoadGlobalNotificationSettings() {
        // Given: Repository with test UserDefaults
        let userDefaults = UserDefaults(suiteName: "test-notifications")!
        userDefaults.removePersistentDomain(forName: "test-notifications")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        let originalSettings = NotificationSettings(
            newEpisodeNotificationsEnabled: false,
            downloadCompleteNotificationsEnabled: true,
            playbackNotificationsEnabled: true,
            soundEnabled: false,
            customSounds: ["test": "test.wav"],
            deliverySchedule: .dailyDigest,
            focusModeIntegrationEnabled: true,
            liveActivitiesEnabled: false
        )

        // When: Save and load settings
        repository.saveGlobalNotificationSettings(originalSettings)
        let loadedSettings = repository.loadGlobalNotificationSettings()

        // Then: Should load same settings
        XCTAssertEqual(loadedSettings, originalSettings)
    }

    func testUserDefaultsSettingsRepositorySaveLoadAppearanceSettings() {
        let userDefaults = UserDefaults(suiteName: "test-appearance")!
        userDefaults.removePersistentDomain(forName: "test-appearance")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)

        let originalSettings = AppearanceSettings(
            theme: .dark,
            preferredTint: .purple,
            typographyScale: 1.25,
            reduceMotionEnabled: true,
            reduceHapticsEnabled: false,
            highContrastEnabled: true
        )

        repository.saveGlobalAppearanceSettings(originalSettings)
        let loadedSettings = repository.loadGlobalAppearanceSettings()

        XCTAssertEqual(loadedSettings, originalSettings)
    }

    func testUserDefaultsSettingsRepositorySaveLoadSmartListAutomationSettings() async {
        let userDefaults = UserDefaults(suiteName: "test-smartlist")!
        userDefaults.removePersistentDomain(forName: "test-smartlist")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)

        let originalSettings = SmartListRefreshConfiguration(
            isEnabled: false,
            globalInterval: 1200,
            maxRefreshPerCycle: 2,
            refreshOnForeground: true,
            refreshOnNetworkChange: false
        )

        await repository.saveSmartListAutomationSettings(originalSettings)
        let loadedSettings = await repository.loadSmartListAutomationSettings()

        XCTAssertEqual(loadedSettings, originalSettings)
    }

    func testUserDefaultsSettingsRepositorySaveLoadPlaybackPresetLibrary() async {
        let userDefaults = UserDefaults(suiteName: "test-playback-presets")!
        userDefaults.removePersistentDomain(forName: "test-playback-presets")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)

        let customPreset = PlaybackPreset(
            id: "custom",
            name: "Morning Walk",
            description: "Balanced for morning walks",
            playbackSpeed: 1.2,
            skipForwardInterval: 40,
            skipBackwardInterval: 20,
            skipIntroSeconds: 10,
            skipOutroSeconds: 10,
            continuousPlayback: true,
            crossFadeEnabled: true,
            crossFadeDuration: 1.0,
            autoMarkAsPlayed: true,
            playedThreshold: 0.88
        )

        let originalLibrary = PlaybackPresetLibrary(
            builtInPresets: PlaybackPresetLibrary.defaultBuiltInPresets,
            customPresets: [customPreset],
            activePresetID: customPreset.id
        )

        await repository.savePlaybackPresetLibrary(originalLibrary)
        let loadedLibrary = await repository.loadPlaybackPresetLibrary()

        XCTAssertEqual(loadedLibrary, originalLibrary)
    }
    
    func testUserDefaultsSettingsRepositorySaveLoadPodcastDownloadSettings() {
        // Given: Repository with test UserDefaults
        let userDefaults = UserDefaults(suiteName: "test-podcast")!
        userDefaults.removePersistentDomain(forName: "test-podcast")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        let podcastId = "test-podcast-1"
        let originalSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,
            wifiOnly: nil,
            retentionPolicy: .keepLatest(15)
        )
        
        // When: Save and load podcast settings
        repository.savePodcastDownloadSettings(originalSettings)
        let loadedSettings = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        
        // Then: Should load same settings
        XCTAssertEqual(loadedSettings, originalSettings)
    }
    
    func testUserDefaultsSettingsRepositoryRemovePodcastSettings() {
        // Given: Repository with saved podcast settings
        let userDefaults = UserDefaults(suiteName: "test-remove")!
        userDefaults.removePersistentDomain(forName: "test-remove")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        let podcastId = "test-podcast-1"
        let settings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,
            wifiOnly: false,
            retentionPolicy: .keepAll
        )
        repository.savePodcastDownloadSettings(settings)
        
        // When: Remove podcast settings
        repository.removePodcastDownloadSettings(podcastId: podcastId)
        let loadedSettings = repository.loadPodcastDownloadSettings(podcastId: podcastId)
        
        // Then: Should return nil
        XCTAssertNil(loadedSettings)
    }
    
    func testUserDefaultsSettingsRepositoryChangeNotifications() {
        // Given: Repository with test UserDefaults
        let userDefaults = UserDefaults(suiteName: "test-changes")!
        userDefaults.removePersistentDomain(forName: "test-changes")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        var receivedChanges: [SettingsChange] = []
        let expectation = expectation(description: "settings change received")
        let changeTask = Task {
            let stream = repository.settingsChangeStream()
            for await change in stream {
                receivedChanges.append(change)
                expectation.fulfill()
                break
            }
        }
        
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 1,
            retentionPolicy: .keepAll
        )
        
        // When: Save global download settings
        await repository.saveGlobalDownloadSettings(downloadSettings)

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should receive change notification
        XCTAssertEqual(receivedChanges.count, 1)
        if case .globalDownload(let settings) = receivedChanges.first {
            XCTAssertEqual(settings, downloadSettings)
        } else {
            XCTFail("Expected globalDownload change notification")
        }

        changeTask.cancel()
    }
    
    func testUserDefaultsSettingsRepositoryCorruptedDataFallback() {
        // Given: Repository with corrupted UserDefaults data
        let userDefaults = UserDefaults(suiteName: "test-corrupted")!
        userDefaults.removePersistentDomain(forName: "test-corrupted")
        userDefaults.set("invalid json", forKey: "global_download_settings")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        // When: Load settings with corrupted data
        let loadedSettings = repository.loadGlobalDownloadSettings()
        
        // Then: Should fallback to default values
        XCTAssertEqual(loadedSettings, DownloadSettings.default)
    }
    
    // MARK: - SettingsManager Tests
    
    @MainActor
    func testSettingsManagerInitialization() {
        // Given: Repository with default settings
        let userDefaults = UserDefaults(suiteName: "test-manager-init")!
        userDefaults.removePersistentDomain(forName: "test-manager-init")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        // When: Create settings manager
        let manager = SettingsManager(repository: repository)
        
        // Then: Should initialize with default values
        XCTAssertEqual(manager.globalDownloadSettings, DownloadSettings.default)
        XCTAssertEqual(manager.globalNotificationSettings, NotificationSettings.default)
        XCTAssertEqual(manager.globalPlaybackSettings, PlaybackSettings())
    }
    
    @MainActor
    func testSettingsManagerEffectiveDownloadSettingsGlobalOnly() {
        // Given: Settings manager with global settings only
        let userDefaults = UserDefaults(suiteName: "test-manager-global")!
        userDefaults.removePersistentDomain(forName: "test-manager-global")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .deleteAfterDays(7)
        )
        
        // When: Update global settings and get effective settings
        manager.updateGlobalDownloadSettings(globalSettings)
        let effective = manager.effectiveDownloadSettings(for: "any-podcast")
        
        // Then: Should return global settings
        XCTAssertEqual(effective, globalSettings)
    }
    
    @MainActor
    func testSettingsManagerEffectiveDownloadSettingsWithPodcastOverride() {
        // Given: Settings manager with global and podcast-specific settings
        let userDefaults = UserDefaults(suiteName: "test-manager-override")!
        userDefaults.removePersistentDomain(forName: "test-manager-override")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5)
        )
        
        let podcastId = "test-podcast"
        let podcastOverride = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,  // Override global
            wifiOnly: nil,  // Use global
            retentionPolicy: .keepLatest(10)  // Override global
        )
        
        // When: Update settings and get effective settings
        manager.updateGlobalDownloadSettings(globalSettings)
        manager.updatePodcastDownloadSettings(podcastId: podcastId, podcastOverride)
        let effective = manager.effectiveDownloadSettings(for: podcastId)
        
        // Then: Should cascade overrides correctly
        XCTAssertEqual(effective.autoDownloadEnabled, true)  // From override
        XCTAssertEqual(effective.wifiOnly, true)  // From global
        XCTAssertEqual(effective.maxConcurrentDownloads, 3)  // From global
        XCTAssertEqual(effective.retentionPolicy, .keepLatest(10))  // From override
    }
    
    @MainActor
    func testSettingsManagerReactiveUpdates() {
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-manager-reactive")!
        userDefaults.removePersistentDomain(forName: "test-manager-reactive")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        var publishedDownloadSettings: [DownloadSettings] = []
        manager.$globalDownloadSettings
            .sink { settings in
                publishedDownloadSettings.append(settings)
            }
            .store(in: &cancellables)
        
        let newSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 1,
            retentionPolicy: .deleteAfterPlayed
        )
        
        // When: Update global download settings
        manager.updateGlobalDownloadSettings(newSettings)
        
        // Then: Should publish updated settings
        XCTAssertEqual(publishedDownloadSettings.count, 2)  // Initial + update
        XCTAssertEqual(publishedDownloadSettings.last, newSettings)
    }
    
    @MainActor
    func testSettingsManagerChangePublisher() {
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-manager-changes")!
        userDefaults.removePersistentDomain(forName: "test-manager-changes")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        var receivedChanges: [SettingsChange] = []
        manager.settingsChangePublisher
            .sink { change in
                receivedChanges.append(change)
            }
            .store(in: &cancellables)
        
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 2,
            retentionPolicy: .keepAll
        )
        
        // When: Update settings through manager
        manager.updateGlobalDownloadSettings(downloadSettings)
        
        // Then: Should receive change notification
        XCTAssertEqual(receivedChanges.count, 1)
        if case .globalDownload(let settings) = receivedChanges.first {
            XCTAssertEqual(settings, downloadSettings)
        } else {
            XCTFail("Expected globalDownload change notification")
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testEndToEndSettingsFlow() {
        // Given: Complete settings stack
        let userDefaults = UserDefaults(suiteName: "test-e2e")!
        userDefaults.removePersistentDomain(forName: "test-e2e")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId = "test-podcast"
        
        // When: Set global and podcast-specific settings
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 4,
            retentionPolicy: .deleteAfterDays(30)
        )
        manager.updateGlobalDownloadSettings(globalSettings)
        
        let podcastSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,
            wifiOnly: nil,
            retentionPolicy: .keepLatest(20)
        )
        manager.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)
        
        // Then: Effective settings should cascade correctly
        let effective = manager.effectiveDownloadSettings(for: podcastId)
        XCTAssertEqual(effective.autoDownloadEnabled, true)  // Podcast override
        XCTAssertEqual(effective.wifiOnly, true)  // Global setting
        XCTAssertEqual(effective.maxConcurrentDownloads, 4)  // Global setting
        XCTAssertEqual(effective.retentionPolicy, .keepLatest(20))  // Podcast override
        
        // And: Settings should persist across manager instances
        let newManager = SettingsManager(repository: repository)
        let persistedEffective = newManager.effectiveDownloadSettings(for: podcastId)
        XCTAssertEqual(persistedEffective, effective)
    }
    
    @MainActor
    func testSettingsValidationAndClamping() {
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-validation")!
        userDefaults.removePersistentDomain(forName: "test-validation")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        // When: Attempt to set invalid download settings
        let invalidSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: -5,  // Invalid: should be clamped
            retentionPolicy: .keepLatest(-1)  // Invalid: should be clamped
        )
        
        manager.updateGlobalDownloadSettings(invalidSettings)
        let effective = manager.globalDownloadSettings
        
        // Then: Invalid values should be clamped to valid ranges
        XCTAssertEqual(effective.maxConcurrentDownloads, 1)  // Clamped to minimum
        XCTAssertEqual(effective.retentionPolicy, .keepLatest(1))  // Clamped to minimum
    }
}
