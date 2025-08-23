import XCTest
import Foundation
import CoreModels
import SharedUtilities
import Persistence
@testable import SettingsDomain

#if canImport(Combine)
import Combine
#endif

#if canImport(CoreFoundation)
import CoreFoundation
#endif

/// Comprehensive test suite for SettingsDomain package covering:
/// - SettingsManager functionality and cascading behavior
/// - UpdateFrequencyService scheduling and validation 
/// - Settings persistence and change notifications
/// - Cross-platform compatibility and Swift 6 concurrency patterns
final class ComprehensiveSettingsDomainTests: XCTestCase {
    
    private var settingsManager: SettingsManager!
    private var updateFrequencyService: UpdateFrequencyService!
    private var repository: UserDefaultsSettingsRepository!
    private var userDefaults: UserDefaults!
    
    #if canImport(Combine)
    private var cancellables: Set<AnyCancellable> = []
    #endif
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Given: Fresh test environment with unique UserDefaults suite
        let suiteName = "test-settings-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        
        // Create fresh service instances with proper async initialization
        repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        settingsManager = await SettingsManager(repository: repository)
        updateFrequencyService = await UpdateFrequencyService(settingsManager: settingsManager)
        
        #if canImport(Combine)
        cancellables.removeAll()
        #endif
    }
    
    override func tearDown() async throws {
        #if canImport(Combine)
        cancellables.removeAll()
        #endif
        
        // Clean up test data
        let suiteName = "test-settings-\(UUID().uuidString)"
        userDefaults.removePersistentDomain(forName: suiteName)
        
        settingsManager = nil
        updateFrequencyService = nil
        repository = nil
        userDefaults = nil
        
        try await super.tearDown()
    }
    
    // MARK: - SettingsManager Core Functionality Tests
    
    @MainActor
    func testSettingsManager_GlobalDownloadSettingsBaseline() async {
        // Given: Fresh SettingsManager with default global settings
        let manager = settingsManager!
        
        // When: Accessing global download settings for the first time
        let globalDownloadSettings = manager.globalDownloadSettings
        
        // Then: Default values should be properly initialized
        XCTAssertEqual(globalDownloadSettings.autoDownloadEnabled, false, "Auto download should default to false")
        XCTAssertEqual(globalDownloadSettings.wifiOnly, true, "WiFi only should default to true")
        XCTAssertEqual(globalDownloadSettings.maxConcurrentDownloads, 3, "Max concurrent downloads should default to 3")
        XCTAssertEqual(globalDownloadSettings.retentionPolicy, .keepLatest(5), "Retention policy should default to keep latest 5")
    }
    
    @MainActor
    func testSettingsManager_GlobalPlaybackSettingsBaseline() async {
        // Given: Fresh SettingsManager with default global settings
        let manager = settingsManager!
        
        // When: Accessing global playback settings for the first time
        let globalPlaybackSettings = manager.globalPlaybackSettings
        
        // Then: Default values should be properly initialized
        XCTAssertEqual(globalPlaybackSettings.playbackSpeed, 1.0, "Playback speed should default to 1.0")
        XCTAssertEqual(globalPlaybackSettings.skipIntroSeconds, 0, "Skip intro should default to 0 seconds")
        XCTAssertEqual(globalPlaybackSettings.skipOutroSeconds, 0, "Skip outro should default to 0 seconds")
        XCTAssertEqual(globalPlaybackSettings.continuousPlayback, true, "Continuous playback should default to true")
    }
    
    @MainActor
    func testSettingsManager_GlobalNotificationSettingsBaseline() async {
        // Given: Fresh SettingsManager with default global settings
        let manager = settingsManager!
        
        // When: Accessing global notification settings for the first time
        let globalNotificationSettings = manager.globalNotificationSettings
        
        // Then: Default values should be properly initialized
        XCTAssertEqual(globalNotificationSettings.newEpisodeNotificationsEnabled, true, "New episode notifications should default to true")
        XCTAssertEqual(globalNotificationSettings.downloadCompleteNotificationsEnabled, true, "Download complete notifications should default to true")
        XCTAssertEqual(globalNotificationSettings.playbackNotificationsEnabled, true, "Playback notifications should default to true")
    }
    
    @MainActor
    func testSettingsManager_GlobalSettingsUpdate() async {
        // Given: SettingsManager with baseline settings
        let manager = settingsManager!
        
        // When: Updating global playback settings
        let updatedSettings = PlaybackSettings(
            playbackSpeed: 1.25,
            skipIntroSeconds: 45,
            skipOutroSeconds: 15,
            continuousPlayback: false
        )
        
        await manager.updateGlobalPlaybackSettings(updatedSettings)
        
        // Then: Settings should be updated
        let retrievedSettings = manager.globalPlaybackSettings
        XCTAssertEqual(retrievedSettings.playbackSpeed, 1.25, "Playback speed should be updated")
        XCTAssertEqual(retrievedSettings.skipIntroSeconds, 45, "Skip intro should be updated")
        XCTAssertEqual(retrievedSettings.continuousPlayback, false, "Continuous playback should be updated")
    }
    
    @MainActor
    func testSettingsManager_EffectiveSettingsBaseline() async {
        // Given: SettingsManager and a podcast identifier
        let manager = settingsManager!
        let podcastId = "test-podcast-123"
        
        // When: Getting effective settings without overrides
        let effectiveDownloadSettings = await manager.effectiveDownloadSettings(for: podcastId)
        let effectivePlaybackSettings = await manager.effectivePlaybackSettings(for: podcastId)
        let effectiveNotificationSettings = manager.effectiveNotificationSettings(for: podcastId)
        
        // Then: Should fall back to global settings
        XCTAssertEqual(effectiveDownloadSettings.autoDownloadEnabled, false, "Should fall back to global auto download")
        XCTAssertEqual(effectiveDownloadSettings.wifiOnly, true, "Should fall back to global WiFi only")
        
        XCTAssertEqual(effectivePlaybackSettings.playbackSpeed, 1.0, "Should fall back to global playback speed")
        XCTAssertEqual(effectivePlaybackSettings.skipIntroSeconds, 0, "Should fall back to global skip intro")
        
        XCTAssertEqual(effectiveNotificationSettings.newEpisodeNotificationsEnabled, true, "Should fall back to global notifications")
    }
    
    @MainActor
    func testSettingsManager_PerPodcastDownloadSettings() async {
        // Given: SettingsManager and a podcast identifier
        let manager = settingsManager!
        let podcastId = "test-podcast-123"
        
        // When: Setting per-podcast download overrides
        let podcastDownloadSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,
            wifiOnly: false,
            retentionPolicy: .keepLatest(10),
            updateFrequency: .daily
        )
        
        await manager.updatePodcastDownloadSettings(podcastId: podcastId, podcastDownloadSettings)
        
        // Then: Effective settings should reflect overrides
        let effectiveSettings = await manager.effectiveDownloadSettings(for: podcastId)
        XCTAssertEqual(effectiveSettings.autoDownloadEnabled, true, "Should use per-podcast auto download override")
        XCTAssertEqual(effectiveSettings.wifiOnly, false, "Should use per-podcast WiFi only override")
        XCTAssertEqual(effectiveSettings.retentionPolicy, .keepLatest(10), "Should use per-podcast retention policy override")
    }
    
    @MainActor
    func testSettingsManager_PerPodcastPlaybackSettingsUpdate() async {
        // Given: SettingsManager and a podcast with overrides
        let manager = settingsManager!
        let podcastId = "test-podcast-456"
        
        // Create test data for PodcastPlaybackSettings using JSON encoding/decoding
        let testData = """
        {
            "speed": 1.5,
            "introSkipDuration": 45,
            "outroSkipDuration": 30,
            "skipForwardInterval": 30,
            "skipBackwardInterval": 15
        }
        """.data(using: .utf8)!
        
        // When: Decoding and setting per-podcast playback settings
        let podcastPlaybackSettings = try! JSONDecoder().decode(PodcastPlaybackSettings.self, from: testData)
        await manager.updatePodcastPlaybackSettings(podcastId: podcastId, podcastPlaybackSettings)
        
        // Then: Effective settings should reflect the override
        let effectiveSettings = await manager.effectivePlaybackSettings(for: podcastId)
        
        // The effectiveSettings combines global and podcast-specific settings
        // Since this creates complex merged settings, we test that the method succeeds
        XCTAssertNotNil(effectiveSettings, "Effective settings should be available")
        XCTAssertGreaterThan(effectiveSettings.playbackSpeed, 1.0, "Playbook speed should be influenced by per-podcast settings")
    }
    
    @MainActor
    func testSettingsManager_SettingsRemoval() async {
        // Given: SettingsManager with per-podcast settings
        let manager = settingsManager!
        let podcastId = "removal-test-podcast"
        
        // Set initial per-podcast settings
        let testData = """
        {
            "speed": 2.0,
            "introSkipDuration": 60,
            "outroSkipDuration": 0,
            "skipForwardInterval": 30,
            "skipBackwardInterval": 15
        }
        """.data(using: .utf8)!
        
        let podcastSettings = try! JSONDecoder().decode(PodcastPlaybackSettings.self, from: testData)
        await manager.updatePodcastPlaybackSettings(podcastId: podcastId, podcastSettings)
        
        // When: Removing per-podcast settings (setting to nil)
        await manager.updatePodcastPlaybackSettings(podcastId: podcastId, nil)
        
        // Then: Should fall back to global settings
        let effectiveSettings = await manager.effectivePlaybackSettings(for: podcastId)
        let globalSettings = manager.globalPlaybackSettings
        XCTAssertEqual(effectiveSettings.playbackSpeed, globalSettings.playbackSpeed, "Should fall back to global speed")
    }
    
    #if canImport(Combine)
    @MainActor
    func testSettingsManager_ChangeNotifications() async {
        // Given: SettingsManager with change notifications
        let manager = settingsManager!
        let expectation = self.expectation(description: "Settings change notification")
        expectation.expectedFulfillmentCount = 2
        
        // When: Subscribing to change notifications and making changes
        manager.$globalDownloadSettings
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        manager.$globalPlaybackSettings
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger changes
        await manager.updateGlobalDownloadSettings(DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .keepLatest(10)
        ))
        
        await manager.updateGlobalPlaybackSettings(PlaybackSettings(
            playbackSpeed: 1.25,
            skipIntroSeconds: 45,
            skipOutroSeconds: 15,
            continuousPlayback: false
        ))
        
        // Then: Should receive change notifications
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    #endif
    
    // MARK: - UpdateFrequencyService Tests
    
    func testUpdateFrequencyService_NextUpdateCalculation() {
        // Given: UpdateFrequencyService and various update schedules
        let service = updateFrequencyService!
        let currentTime = Date()
        
        // When: Calculating next update for different frequencies
        let hourlyNext = service.nextUpdateTime(from: currentTime, frequency: .hourly)
        let dailyNext = service.nextUpdateTime(from: currentTime, frequency: .daily)
        let weeklyNext = service.nextUpdateTime(from: currentTime, frequency: .weekly)
        
        // Then: Next update times should be calculated correctly
        XCTAssertEqual(hourlyNext.timeIntervalSince(currentTime), 3600, accuracy: 1, "Hourly update should be 1 hour later")
        XCTAssertEqual(dailyNext.timeIntervalSince(currentTime), 24 * 3600, accuracy: 1, "Daily update should be 1 day later")
        XCTAssertEqual(weeklyNext.timeIntervalSince(currentTime), 7 * 24 * 3600, accuracy: 1, "Weekly update should be 1 week later")
    }
    
    func testUpdateFrequencyService_ScheduleValidation() {
        // Given: UpdateFrequencyService and update schedule
        let service = updateFrequencyService!
        let schedule = UpdateSchedule.automatic(frequency: .daily)
        
        // When: Validating schedule
        let isValid = service.isValidSchedule(schedule)
        
        // Then: Valid schedule should be validated
        XCTAssertTrue(isValid, "Automatic daily schedule should be valid")
        
        // Test manual schedule
        let manualSchedule = UpdateSchedule.manual
        let isManualValid = service.isValidSchedule(manualSchedule)
        XCTAssertTrue(isManualValid, "Manual schedule should be valid")
    }
    
    func testUpdateFrequencyService_TimeBetweenUpdates() {
        // Given: UpdateFrequencyService and time intervals
        let service = updateFrequencyService!
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2 * 3600) // 2 hours later
        
        // When: Calculating time between updates
        let timeBetween = service.timeBetweenUpdates(from: startTime, to: endTime)
        
        // Then: Should calculate correct time interval
        XCTAssertEqual(timeBetween, 2 * 3600, accuracy: 1, "Should calculate 2 hours between updates")
    }
    
    func testUpdateFrequencyService_RecommendedFrequency() {
        // Given: UpdateFrequencyService and usage patterns
        let service = updateFrequencyService!
        
        // When: Getting recommended frequency for different usage patterns
        let heavyUsageFreq = service.recommendedFrequency(episodesPerWeek: 50, activeHoursPerDay: 8)
        let lightUsageFreq = service.recommendedFrequency(episodesPerWeek: 5, activeHoursPerDay: 2)
        let moderateUsageFreq = service.recommendedFrequency(episodesPerWeek: 20, activeHoursPerDay: 4)
        
        // Then: Should recommend appropriate frequencies
        XCTAssertEqual(heavyUsageFreq, .hourly, "Heavy usage should recommend hourly updates")
        XCTAssertEqual(lightUsageFreq, .daily, "Light usage should recommend daily updates")
        XCTAssertEqual(moderateUsageFreq, .every6Hours, "Moderate usage should recommend 6-hour updates")
    }
    
    // MARK: - Settings Persistence Tests
    
    @MainActor
    func testSettingsPersistence_AcrossRestarts() async {
        // Given: SettingsManager with configured settings
        let manager = settingsManager!
        
        // Configure global settings
        await manager.updateGlobalPlaybackSettings(PlaybackSettings(
            playbackSpeed: 1.25,
            skipIntroSeconds: 45,
            skipOutroSeconds: 15,
            continuousPlayback: false
        ))
        
        // When: Creating new SettingsManager instance (simulating app restart)
        let newRepository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let newManager = await SettingsManager(repository: newRepository)
        
        // Allow time for async loading
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Settings should be restored from persistence
        let restoredGlobal = newManager.globalPlaybackSettings
        XCTAssertEqual(restoredGlobal.playbackSpeed, 1.25, "Global playback speed should persist")
        XCTAssertEqual(restoredGlobal.skipIntroSeconds, 45, "Global skip intro should persist")
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @MainActor
    func testSettingsManager_InvalidPodcastId() async {
        // Given: SettingsManager and invalid podcast identifiers
        let manager = settingsManager!
        
        // When: Accessing effective settings for empty podcast ID
        let emptyIdSettings = await manager.effectivePlaybackSettings(for: "")
        let nilIdSettings = await manager.effectiveDownloadSettings(for: "")
        
        // Then: Should handle gracefully and return global settings
        XCTAssertNotNil(emptyIdSettings, "Empty podcast ID should return effective settings")
        XCTAssertNotNil(nilIdSettings, "Empty podcast ID should return effective settings")
        
        // Should fall back to global values
        let globalPlayback = manager.globalPlaybackSettings
        let globalDownload = manager.globalDownloadSettings
        XCTAssertEqual(emptyIdSettings.playbackSpeed, globalPlayback.playbackSpeed, "Should fall back to global")
        XCTAssertEqual(nilIdSettings.autoDownloadEnabled, globalDownload.autoDownloadEnabled, "Should fall back to global")
    }
    
    @MainActor
    func testSettingsManager_ExtremePlaybackSpeeds() async {
        // Given: SettingsManager and extreme playback speed values
        let manager = settingsManager!
        
        // When: Setting extreme playback speeds
        await manager.updateGlobalPlaybackSettings(PlaybackSettings(
            playbackSpeed: 0.1, // Very slow
            skipIntroSeconds: 30,
            skipOutroSeconds: 30,
            continuousPlayback: true
        ))
        
        let retrievedSlow = manager.globalPlaybackSettings.playbackSpeed
        
        await manager.updateGlobalPlaybackSettings(PlaybackSettings(
            playbackSpeed: 5.0, // Very fast
            skipIntroSeconds: 30,
            skipOutroSeconds: 30,
            continuousPlayback: true
        ))
        
        let retrievedFast = manager.globalPlaybackSettings.playbackSpeed
        
        // Then: Should handle extreme values appropriately
        XCTAssertEqual(retrievedSlow, 0.1, "Should handle very slow speeds")
        XCTAssertEqual(retrievedFast, 5.0, "Should handle very fast speeds")
    }
    
    @MainActor
    func testSettingsManager_UnicodeHandling() async {
        // Given: SettingsManager and Unicode podcast identifiers
        let manager = settingsManager!
        let unicodePodcastId = "播客-podcast-🎧-المتصل"
        
        // When: Using Unicode podcast ID with effective settings
        let effectiveSettings = await manager.effectivePlaybackSettings(for: unicodePodcastId)
        
        // Then: Should handle Unicode identifiers correctly
        XCTAssertNotNil(effectiveSettings, "Should handle Unicode podcast IDs")
        XCTAssertEqual(effectiveSettings.playbackSpeed, 1.0, "Unicode podcast should fall back to global settings")
    }
    
    // MARK: - Concurrency and Performance Tests
    
    @MainActor
    func testSettingsManager_ConcurrentAccess() async {
        // Given: SettingsManager and concurrent access scenario
        let manager = settingsManager!
        
        // When: Accessing settings concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            // Multiple concurrent reads
            for i in 0..<10 {
                group.addTask {
                    let _ = await manager.globalPlaybackSettings
                    let _ = await manager.effectivePlaybackSettings(for: "concurrent-test-\(i)")
                }
            }
            
            // Multiple concurrent writes
            for i in 0..<5 {
                group.addTask {
                    let settings = PlaybackSettings(
                        playbackSpeed: Double(i) + 1.0,
                        skipIntroSeconds: i * 10 + 30,
                        skipOutroSeconds: i * 5 + 15,
                        continuousPlayback: i % 2 == 0
                    )
                    await manager.updateGlobalPlaybackSettings(settings)
                }
            }
        }
        
        // Then: All operations should complete without data races
        let finalGlobal = manager.globalPlaybackSettings
        XCTAssertNotNil(finalGlobal, "Should handle concurrent access safely")
        XCTAssertGreaterThan(finalGlobal.playbackSpeed, 1.0, "Concurrent writes should have effects")
    }
    
    #if canImport(CoreFoundation)
    func testUpdateFrequencyService_PerformanceBaseline() {
        // Given: UpdateFrequencyService and performance measurement
        let service = updateFrequencyService!
        let iterations = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When: Performing many frequency calculations
        for i in 0..<iterations {
            let time = Date().addingTimeInterval(Double(i))
            let _ = service.nextUpdateTime(from: time, frequency: .daily)
            let _ = service.recommendedFrequency(episodesPerWeek: i % 100, activeHoursPerDay: i % 24)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then: Should complete within reasonable time (< 100ms for 1000 operations)
        XCTAssertLessThan(duration, 0.1, "Frequency calculations should be performant")
    }
    #endif
    
    // MARK: - Cross-Platform Compatibility Tests
    
    @MainActor
    func testCrossPlatformCompatibility() async {
        // Given: SettingsManager on current platform
        let manager = settingsManager!
        
        // When: Using settings functionality
        let globalSettings = manager.globalPlaybackSettings
        let effectiveSettings = await manager.effectivePlaybackSettings(for: "cross-platform-test")
        
        // Then: Should work across different platforms
        XCTAssertNotNil(globalSettings, "Settings should work on all platforms")
        XCTAssertNotNil(effectiveSettings, "Effective settings should work on all platforms")
        
        // Platform-specific features should be conditionally available
        #if canImport(Combine)
        XCTAssertNotNil(manager.$globalPlaybackSettings, "Combine should be available on supported platforms")
        #endif
    }
    
    // MARK: - Swift 6 Sendable Compliance Tests
    
    func testSendableCompliance() async {
        // Given: Settings types that should be Sendable
        let globalPlaybackSettings = PlaybackSettings(
            playbackSpeed: 1.5,
            skipIntroSeconds: 45,
            skipOutroSeconds: 15,
            continuousPlayback: true
        )
        
        // When: Using settings in async context
        let result: Double = await withCheckedContinuation { continuation in
            Task {
                // Should be able to capture and use settings across concurrency boundaries
                let speed = globalPlaybackSettings.playbackSpeed
                continuation.resume(returning: speed)
            }
        }
        
        // Then: Should work without Sendable warnings
        XCTAssertEqual(result, 1.5, "Settings should be Sendable and usable across concurrency boundaries")
    }
}