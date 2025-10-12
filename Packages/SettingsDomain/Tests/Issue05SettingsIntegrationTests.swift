import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import zpod

final class Issue05SettingsIntegrationTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - PlaybackSettings Integration Tests
    
    @MainActor
    func testPlaybackSettingsIntegrationWithSettingsManager() {
        // Given: Settings manager with PlaybackSettings
        let userDefaults = UserDefaults(suiteName: "test-playback-integration")!
        userDefaults.removePersistentDomain(forName: "test-playback-integration")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId = "test-podcast-123"
        
        // When: Set global playback settings
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
        manager.updateGlobalPlaybackSettings(globalPlayback)
        
        // And: Set podcast-specific overrides
        let podcastOverrides = PodcastPlaybackSettings(
            podcastId: podcastId,
            playbackSpeed: 2.0,
            skipForwardInterval: 45,
            skipBackwardInterval: nil,  // Use global
            introSkipDuration: 10,
            outroSkipDuration: 5
        )
        manager.updatePodcastPlaybackSettings(podcastId: podcastId, podcastOverrides)
        
        // Then: Effective settings should cascade correctly
        let effective = manager.effectivePlaybackSettings(for: podcastId)
        
        // Global settings preserved
        XCTAssertEqual(effective.globalPlaybackSpeed, 1.5)
        XCTAssertEqual(effective.autoMarkAsPlayed, true)
        XCTAssertEqual(effective.playedThreshold, 0.9)
        
        // Podcast overrides applied
        XCTAssertEqual(effective.playbackSpeed(for: podcastId), 2.0)
        XCTAssertEqual(effective.skipForwardInterval, 45)
        XCTAssertEqual(effective.skipBackwardInterval, 15)  // From global
        XCTAssertEqual(effective.introSkipDuration(for: podcastId), 10)
        XCTAssertEqual(effective.outroSkipDuration(for: podcastId), 5)
    }
    
    @MainActor
    func testDownloadSettingsWithAutoDownloadService() {
        // Given: Settings manager with download settings
        let userDefaults = UserDefaults(suiteName: "test-download-integration")!
        userDefaults.removePersistentDomain(forName: "test-download-integration")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId1 = "podcast-auto-enabled"
        let podcastId2 = "podcast-auto-disabled"
        
        // When: Set global download settings (auto-download disabled)
        let globalDownload = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5)
        )
        manager.updateGlobalDownloadSettings(globalDownload)
        
        // And: Enable auto-download for one specific podcast
        let podcast1Override = PodcastDownloadSettings(
            podcastId: podcastId1,
            autoDownloadEnabled: true,
            wifiOnly: nil,  // Use global (true)
            retentionPolicy: .keepLatest(10)
        )
        manager.updatePodcastDownloadSettings(podcastId: podcastId1, podcast1Override)
        
        // Then: Effective settings should respect overrides
        let effective1 = manager.effectiveDownloadSettings(for: podcastId1)
        let effective2 = manager.effectiveDownloadSettings(for: podcastId2)
        
        // Podcast 1 has auto-download enabled via override
        XCTAssertEqual(effective1.autoDownloadEnabled, true)
        XCTAssertEqual(effective1.wifiOnly, true)  // From global
        XCTAssertEqual(effective1.retentionPolicy, .keepLatest(10))  // Override
        
        // Podcast 2 uses global settings (auto-download disabled)
        XCTAssertEqual(effective2.autoDownloadEnabled, false)
        XCTAssertEqual(effective2.wifiOnly, true)
        XCTAssertEqual(effective2.retentionPolicy, .keepLatest(5))
    }
    
    @MainActor
    func testNotificationSettingsWithCustomSounds() {
        // Given: Settings manager with notification settings
        let userDefaults = UserDefaults(suiteName: "test-notification-integration")!
        userDefaults.removePersistentDomain(forName: "test-notification-integration")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId = "test-podcast-notifications"
        
        // When: Set global notification settings with custom sounds
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
        manager.updateGlobalNotificationSettings(globalNotifications)
        
        // Then: Effective settings should include custom sound
        let effective = manager.effectiveNotificationSettings(for: podcastId)
        
        XCTAssertTrue(effective.newEpisodeNotificationsEnabled)
        XCTAssertFalse(effective.downloadCompleteNotificationsEnabled)
        XCTAssertEqual(effective.soundEnabled, true)
        XCTAssertEqual(effective.customSounds?[podcastId], "custom-chime.wav")
    }

    @MainActor
    func testAppearanceSettingsIntegration() async {
        let userDefaults = UserDefaults(suiteName: "test-appearance-integration")!
        userDefaults.removePersistentDomain(forName: "test-appearance-integration")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)

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
    
    @MainActor
    func testSettingsManagerReactiveIntegration() {
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-reactive-integration")!
        userDefaults.removePersistentDomain(forName: "test-reactive-integration")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        var publishedSettings: [DownloadSettings] = []
        var publishedChanges: [SettingsChange] = []
        
        // Subscribe to published properties and change notifications
        manager.$globalDownloadSettings
            .sink { settings in
                publishedSettings.append(settings)
            }
            .store(in: &cancellables)
        
        manager.settingsChangePublisher
            .sink { change in
                publishedChanges.append(change)
            }
            .store(in: &cancellables)
        
        // When: Update settings
        let newSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .deleteAfterDays(30)
        )
        manager.updateGlobalDownloadSettings(newSettings)
        
        // Then: Should receive reactive updates
        XCTAssertEqual(publishedSettings.count, 2)  // Initial + update
        XCTAssertEqual(publishedSettings.last, newSettings)
        
        XCTAssertEqual(publishedChanges.count, 1)
        if case .globalDownload(let settings) = publishedChanges.first {
            XCTAssertEqual(settings, newSettings)
        } else {
            XCTFail("Expected globalDownload change notification")
        }
    }
    
    @MainActor
    func testSettingsPersistenceAcrossManagerInstances() {
        // Given: Settings manager that saves settings
        let userDefaults = UserDefaults(suiteName: "test-persistence")!
        userDefaults.removePersistentDomain(forName: "test-persistence")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager1 = SettingsManager(repository: repository)
        
        let podcastId = "test-podcast-persistence"
        
        // When: Save settings and create new manager instance
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 2,
            retentionPolicy: .deleteAfterPlayed
        )
        manager1.updateGlobalDownloadSettings(downloadSettings)
        
        let podcastSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: false,
            wifiOnly: true,
            retentionPolicy: .keepLatest(20)
        )
        manager1.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)
        
        // Create new manager with same repository
        let manager2 = SettingsManager(repository: repository)
        
        // Then: Settings should persist across instances
        XCTAssertEqual(manager2.globalDownloadSettings, downloadSettings)
        let effective = manager2.effectiveDownloadSettings(for: podcastId)
        
        XCTAssertEqual(effective.autoDownloadEnabled, false)  // Podcast override
        XCTAssertEqual(effective.wifiOnly, true)  // Podcast override
        XCTAssertEqual(effective.maxConcurrentDownloads, 2)  // Global setting
        XCTAssertEqual(effective.retentionPolicy, .keepLatest(20))  // Podcast override
    }
    
    @MainActor
    func testSettingsValidationEdgeCases() {
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-validation-edge")!
        userDefaults.removePersistentDomain(forName: "test-validation-edge")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        // When: Test 1 - Very large concurrent downloads (should be clamped to 10)
        let largeDownloads = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 100,
            retentionPolicy: .keepLatest(1)
        )
        manager.updateGlobalDownloadSettings(largeDownloads)
        
        // Then: Large downloads should be clamped
        var downloadSettings = manager.globalDownloadSettings
        XCTAssertEqual(downloadSettings.maxConcurrentDownloads, 10)  // Clamped to max
        
        // When: Test 2 - Negative retention policy (should be clamped to 1)
        let negativeRetention = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(-5)
        )
        manager.updateGlobalDownloadSettings(negativeRetention)
        
        // Then: Negative retention should be clamped, concurrent downloads should be 3 (valid value)
        downloadSettings = manager.globalDownloadSettings
        XCTAssertEqual(downloadSettings.maxConcurrentDownloads, 3)  // Valid value
        XCTAssertEqual(downloadSettings.retentionPolicy, .keepLatest(1))  // Clamped to min
        
        // When: Test 3 - Invalid playback speed (should be clamped)
        let invalidSpeed = PodcastPlaybackSettings(
            podcastId: "test",
            playbackSpeed: 10.0,  // Should be clamped to 5.0
            skipForwardInterval: -10,  // Should be clamped to 5
            skipBackwardInterval: 1000,  // Should be clamped to 300
            introSkipDuration: nil,
            outroSkipDuration: nil
        )
        manager.updatePodcastPlaybackSettings(podcastId: "test", invalidSpeed)
        
        // Then: Playback settings should be properly validated and clamped
        let playbackSettings = manager.effectivePlaybackSettings(for: "test")
        XCTAssertEqual(playbackSettings.playbackSpeed(for: "test"), 5.0)  // Clamped to max
        XCTAssertEqual(playbackSettings.skipForwardInterval, 5)  // Clamped to min
        XCTAssertEqual(playbackSettings.skipBackwardInterval, 300)  // Clamped to max
    }
}
