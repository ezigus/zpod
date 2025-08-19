import XCTest
import Foundation
@preconcurrency import Combine
@testable import zpod

final class Issue05AcceptanceCriteriaTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Acceptance Criteria Tests for Issue 05
    
    @MainActor
    func testAcceptanceCriteria1_CascadingResolution() async {
        // Acceptance Criteria 1: "Global settings apply to all podcasts unless per-podcast override exists"
        
        // Given: Settings manager with global settings
        let userDefaults = UserDefaults(suiteName: "test-criteria-1")!
        userDefaults.removePersistentDomain(forName: "test-criteria-1")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcast1 = "podcast-without-override"
        let podcast2 = "podcast-with-override"
        
        // When: Set global settings
        let globalDownload = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 4,
            retentionPolicy: .keepLatest(8)
        )
        manager.updateGlobalDownloadSettings(globalDownload)
        
        // And: Set per-podcast override for one podcast only
        let podcastOverride = PodcastDownloadSettings(
            podcastId: podcast2,
            autoDownloadEnabled: false,  // Override global
            wifiOnly: true,  // Override global
            retentionPolicy: nil  // Use global
        )
        manager.updatePodcastDownloadSettings(podcastId: podcast2, podcastOverride)
        
        // Then: Podcast without override uses global settings
        let effective1 = manager.effectiveDownloadSettings(for: podcast1)
        XCTAssertEqual(effective1.autoDownloadEnabled, true)  // From global
        XCTAssertEqual(effective1.wifiOnly, false)  // From global
        XCTAssertEqual(effective1.retentionPolicy, .keepLatest(8))  // From global
        
        // And: Podcast with override uses cascaded settings
        let effective2 = manager.effectiveDownloadSettings(for: podcast2)
        XCTAssertEqual(effective2.autoDownloadEnabled, false)  // From override
        XCTAssertEqual(effective2.wifiOnly, true)  // From override
        XCTAssertEqual(effective2.retentionPolicy, .keepLatest(8))  // From global (override was nil)
    }
    
    @MainActor
    func testAcceptanceCriteria2_ChangeNotifications() async {
        // Acceptance Criteria 2: "Settings changes trigger UI updates through Combine publishers"
        
        // Given: Settings manager with subscribers
        let userDefaults = UserDefaults(suiteName: "test-criteria-2")!
        userDefaults.removePersistentDomain(forName: "test-criteria-2")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        var publishedDownloadSettings: [DownloadSettings] = []
        var publishedNotificationSettings: [NotificationSettings] = []
        var settingsChanges: [SettingsChange] = []
        
        // Subscribe to published properties (for UI updates)
        manager.$globalDownloadSettings
            .sink { settings in
                publishedDownloadSettings.append(settings)
            }
            .store(in: &cancellables)
        
        manager.$globalNotificationSettings
            .sink { settings in
                publishedNotificationSettings.append(settings)
            }
            .store(in: &cancellables)
        
        // Subscribe to change notifications (for service updates)
        manager.settingsChangePublisher
            .sink { change in
                settingsChanges.append(change)
            }
            .store(in: &cancellables)
        
        // When: Update settings
        let newDownloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: true,
            maxConcurrentDownloads: 2,
            retentionPolicy: .deleteAfterDays(7)
        )
        manager.updateGlobalDownloadSettings(newDownloadSettings)
        
        let newNotificationSettings = NotificationSettings(
            newEpisodeNotifications: false,
            downloadCompleteNotifications: true,
            soundEnabled: false,
            customSounds: ["test": "test.wav"]
        )
        manager.updateGlobalNotificationSettings(newNotificationSettings)
        
        // Then: UI updates should be triggered through published properties
        XCTAssertEqual(publishedDownloadSettings.count, 2)  // Initial + update
        XCTAssertEqual(publishedDownloadSettings.last, newDownloadSettings)
        
        XCTAssertEqual(publishedNotificationSettings.count, 2)  // Initial + update
        XCTAssertEqual(publishedNotificationSettings.last, newNotificationSettings)
        
        // And: Service updates should be triggered through change notifications
        XCTAssertEqual(settingsChanges.count, 2)
        XCTAssertTrue(settingsChanges.contains { change in
            if case .globalDownload(let settings) = change {
                return settings == newDownloadSettings
            }
            return false
        })
        XCTAssertTrue(settingsChanges.contains { change in
            if case .globalNotification(let settings) = change {
                return settings == newNotificationSettings
            }
            return false
        })
    }
    
    @MainActor
    func testAcceptanceCriteria3_Persistence() async {
        // Acceptance Criteria 3: "Settings survive app restart through UserDefaults storage"
        
        // Given: Settings manager that saves settings
        let userDefaults = UserDefaults(suiteName: "test-criteria-3")!
        userDefaults.removePersistentDomain(forName: "test-criteria-3")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager1 = SettingsManager(repository: repository)
        
        let podcastId = "test-podcast-persistence"
        
        // When: Save various settings
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .deleteAfterPlayed
        )
        manager1.updateGlobalDownloadSettings(downloadSettings)
        
        let notificationSettings = NotificationSettings(
            newEpisodeNotifications: false,
            downloadCompleteNotifications: true,
            soundEnabled: true,
            customSounds: [podcastId: "custom.wav"]
        )
        manager1.updateGlobalNotificationSettings(notificationSettings)
        
        let playbackSettings = PlaybackSettings(
            globalPlaybackSpeed: 1.8,
            podcastPlaybackSpeeds: [podcastId: 2.2],
            skipForwardInterval: 45,
            skipBackwardInterval: 20,
            introSkipDurations: [podcastId: 15],
            outroSkipDurations: [podcastId: 10],
            autoMarkAsPlayed: false,
            playedThreshold: 0.8
        )
        manager1.updateGlobalPlaybackSettings(playbackSettings)
        
        let podcastOverrides = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: false,
            wifiOnly: true,
            retentionPolicy: .keepLatest(20)
        )
        manager1.updatePodcastDownloadSettings(podcastId: podcastId, podcastOverrides)
        
        // Simulate app restart by creating new manager with same UserDefaults
        let manager2 = SettingsManager(repository: UserDefaultsSettingsRepository(userDefaults: userDefaults))
        
        // Capture isolated properties before XCTAssertEqual to avoid autoclosure isolation issues
        let gd = manager2.globalDownloadSettings
        let gn = manager2.globalNotificationSettings
        let gp = manager2.globalPlaybackSettings
        
        XCTAssertEqual(gd, downloadSettings)
        XCTAssertEqual(gn, notificationSettings)
        XCTAssertEqual(gp, playbackSettings)
        
        let restoredEffective = manager2.effectiveDownloadSettings(for: podcastId)
        XCTAssertEqual(restoredEffective.autoDownloadEnabled, false)  // From podcast override
        XCTAssertEqual(restoredEffective.wifiOnly, true)  // From podcast override
        XCTAssertEqual(restoredEffective.retentionPolicy, .keepLatest(20))  // From podcast override
    }
    
    @MainActor
    func testAcceptanceCriteria4_Validation() async {
        // Acceptance Criteria 4: "Invalid settings values are clamped to safe ranges"
        
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-criteria-4")!
        userDefaults.removePersistentDomain(forName: "test-criteria-4")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        // When: Attempt to set invalid values
        let invalidDownload = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: -10,  // Invalid: below minimum
            retentionPolicy: .keepLatest(-5)  // Invalid: negative
        )
        manager.updateGlobalDownloadSettings(invalidDownload)
        
        let invalidPlayback = PodcastPlaybackSettings(
            podcastId: "test",
            playbackSpeed: 15.0,  // Invalid: above maximum
            skipForwardInterval: -20,  // Invalid: negative
            skipBackwardInterval: 1000,  // Invalid: above maximum
            introSkipDuration: -5,  // Invalid: negative
            outroSkipDuration: nil
        )
        manager.updatePodcastPlaybackSettings(podcastId: "test", invalidPlayback)
        
        // Then: Values should be clamped to safe ranges
        let downloadSettings = manager.globalDownloadSettings
        XCTAssertEqual(downloadSettings.maxConcurrentDownloads, 1)
        XCTAssertEqual(downloadSettings.retentionPolicy, .keepLatest(1))
        
        let effectivePlayback = manager.effectivePlaybackSettings(for: "test")
        XCTAssertEqual(effectivePlayback.playbackSpeed(for: "test"), 5.0)
        XCTAssertEqual(effectivePlayback.skipForwardInterval, 5)
        XCTAssertEqual(effectivePlayback.skipBackwardInterval, 300)
        XCTAssertEqual(effectivePlayback.introSkipDuration(for: "test"), 0)
    }
    
    @MainActor
    func testAcceptanceCriteria5_BackwardCompatibility() async {
        // Acceptance Criteria 5: "Existing playback features continue working through new settings system"
        
        // Given: Settings manager with playback settings
        let userDefaults = UserDefaults(suiteName: "test-criteria-5")!
        userDefaults.removePersistentDomain(forName: "test-criteria-5")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId = "compatibility-test-podcast"
        
        // When: Set settings using the new framework
        let playbackSettings = PlaybackSettings(
            globalPlaybackSpeed: 1.5,
            podcastPlaybackSpeeds: [podcastId: 2.0],
            skipForwardInterval: 30,
            skipBackwardInterval: 15,
            introSkipDurations: [podcastId: 10],
            outroSkipDurations: [podcastId: 5],
            autoMarkAsPlayed: true,
            playedThreshold: 0.9
        )
        manager.updateGlobalPlaybackSettings(playbackSettings)
        
        // Then: Existing PlaybackSettings methods should work correctly
        let effective = manager.effectivePlaybackSettings(for: podcastId)
        
        // Test existing PlaybackSettings API compatibility
        XCTAssertEqual(effective.playbackSpeed(for: podcastId), 2.0)  // Per-podcast override
        XCTAssertEqual(effective.playbackSpeed(for: "other-podcast"), 1.5)  // Global default
        XCTAssertEqual(effective.skipForwardInterval, 30)
        XCTAssertEqual(effective.skipBackwardInterval, 15)
        XCTAssertEqual(effective.introSkipDuration(for: podcastId), 10)
        XCTAssertEqual(effective.outroSkipDuration(for: podcastId), 5)
        XCTAssertEqual(effective.autoMarkAsPlayed, true)
        XCTAssertEqual(effective.playedThreshold, 0.9)
        
        // Test that Codable encoding/decoding still works
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let encodedData = try encoder.encode(effective)
            let decodedSettings = try decoder.decode(PlaybackSettings.self, from: encodedData)
            
            XCTAssertEqual(effective, decodedSettings)
        } catch let error as NSError {
            XCTFail("Encoding/decoding failed: \(error)")
        }
    }
    
    @MainActor
    func testAcceptanceCriteria_ScopeRequirements() async {
        // Test that all scope requirements are met: playbackSpeedDefault, skipForwardInterval,
        // skipBackwardInterval, autoDownloadEnabled, wifiOnly, retentionPolicy, notificationPreferences
        
        // Given: Settings manager
        let userDefaults = UserDefaults(suiteName: "test-scope")!
        userDefaults.removePersistentDomain(forName: "test-scope")
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        
        let podcastId = "scope-test-podcast"
        
        // When: Configure all scope requirements
        
        // 1. playbackSpeedDefault (global and per-podcast)
        let playbackSettings = PlaybackSettings(globalPlaybackSpeed: 1.25)
        manager.updateGlobalPlaybackSettings(playbackSettings)
        manager.updatePlaybackSpeed(for: podcastId, speed: 1.75)
        
        // 2. skipForwardInterval, skipBackwardInterval
        let playbackWithSkips = PlaybackSettings(
            globalPlaybackSpeed: 1.25,
            skipForwardInterval: 45,
            skipBackwardInterval: 20
        )
        manager.updateGlobalPlaybackSettings(playbackWithSkips)
        
        // 3. autoDownloadEnabled, wifiOnly, retentionPolicy
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(10)
        )
        manager.updateGlobalDownloadSettings(downloadSettings)
        manager.updateAutoDownload(for: podcastId, enabled: false)  // Per-podcast override
        
        // 4. notificationPreferences
        let notificationSettings = NotificationSettings(
            newEpisodeNotifications: true,
            downloadCompleteNotifications: false,
            soundEnabled: true,
            customSounds: [podcastId: "custom-notification.wav"]
        )
        manager.updateGlobalNotificationSettings(notificationSettings)
        
        // Then: All scope requirements should be functional
        
        // Test playback speed (global and per-podcast)
        let speedOther = manager.playbackSpeed(for: "other-podcast")
        let speedPodcast = manager.playbackSpeed(for: podcastId)
        XCTAssertEqual(speedOther, 1.25)
        XCTAssertEqual(speedPodcast, 1.75)
        
        // Test skip intervals
        let intervals = manager.skipIntervals(for: podcastId)
        XCTAssertEqual(intervals.0, 45)
        XCTAssertEqual(intervals.1, 20)
        
        // Test download settings
        let autoOther = manager.isAutoDownloadEnabled(for: "other-podcast")
        let autoPodcast = manager.isAutoDownloadEnabled(for: podcastId)
        let wifiOnly = manager.isWifiOnlyForDownloads(for: podcastId)
        let policy = manager.retentionPolicy(for: podcastId)
        XCTAssertEqual(autoOther, true)
        XCTAssertEqual(autoPodcast, false)
        XCTAssertEqual(wifiOnly, false)
        XCTAssertEqual(policy, .keepLatest(10))
        
        // Test notification preferences
        let newEp = manager.areNewEpisodeNotificationsEnabled(for: podcastId)
        let customSound = manager.customNotificationSound(for: podcastId)
        let customSoundOther = manager.customNotificationSound(for: "other-podcast")
        XCTAssertEqual(newEp, true)
        XCTAssertEqual(customSound, "custom-notification.wav")
        XCTAssertNil(customSoundOther)
    }
}
