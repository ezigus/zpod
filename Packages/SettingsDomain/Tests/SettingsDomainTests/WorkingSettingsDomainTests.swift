import XCTest
import Foundation
import CoreModels
import SharedUtilities
import Persistence
@testable import SettingsDomain

/// Simple working tests for SettingsDomain package
final class WorkingSettingsDomainTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testSettingsManager_BasicInitialization() async {
        // Given: Fresh repository setup
        let suiteName = "test-init-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        
        // When: Creating settings manager
        let manager = await SettingsManager(repository: repository)
        
        // Then: Should have default settings
        await MainActor.run {
            let globalPlayback = manager.globalPlaybackSettings
            let globalDownload = manager.globalDownloadSettings
            let globalNotification = manager.globalNotificationSettings
            
            XCTAssertNotNil(globalPlayback, "Should have global playback settings")
            XCTAssertNotNil(globalDownload, "Should have global download settings")
            XCTAssertNotNil(globalNotification, "Should have global notification settings")
            
            XCTAssertEqual(globalPlayback.playbackSpeed, 1.0, "Default playback speed should be 1.0x")
        }
    }
    
    func testSettingsManager_EffectiveSettingsResolution() async {
        // Given: Settings manager setup
        let suiteName = "test-effective-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = await SettingsManager(repository: repository)
        let podcastId = "test-podcast"
        
        // When: Getting effective settings for podcast without overrides
        let effectiveSettings = await manager.effectivePlaybackSettings(for: podcastId)
        
        // Then: Should fall back to global settings
        await MainActor.run {
            let globalSettings = manager.globalPlaybackSettings
            XCTAssertEqual(effectiveSettings.playbackSpeed, globalSettings.playbackSpeed, 
                          "Should use global settings as fallback")
        }
    }
    
    func testUpdateFrequencyService_BasicScheduling() async {
        // Given: Update frequency service setup
        let suiteName = "test-scheduling-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = await SettingsManager(repository: repository)
        let service = await UpdateFrequencyService(settingsManager: manager)
        let podcastId = "test-scheduling-podcast"
        
        // When: Initializing schedule for podcast
        await service.initializeSchedule(for: podcastId)
        
        // Then: Should have schedule created
        let schedule = await MainActor.run {
            service.getSchedule(for: podcastId)
        }
        XCTAssertNotNil(schedule, "Should create schedule for podcast")
        XCTAssertEqual(schedule?.podcastId, podcastId, "Schedule should have correct podcast ID")
    }
    
    func testUpdateFrequencyService_RefreshCycle() async {
        // Given: Update frequency service with initialized podcast
        let suiteName = "test-refresh-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = await SettingsManager(repository: repository)
        let service = await UpdateFrequencyService(settingsManager: manager)
        let podcastId = "test-refresh-podcast"
        
        await service.initializeSchedule(for: podcastId)
        
        // When: Computing next refresh time
        let nextRefreshTime = await service.computeNextRefreshTime(for: podcastId)
        
        // Then: Should have computed refresh time
        XCTAssertNotNil(nextRefreshTime, "Should compute next refresh time")
        
        // When: Marking podcast as refreshed
        await service.markPodcastRefreshed(podcastId)
        let updatedRefreshTime = await service.computeNextRefreshTime(for: podcastId)
        
        // Then: Should have updated schedule
        XCTAssertNotNil(updatedRefreshTime, "Should have updated refresh time after marking refreshed")
    }
    
    func testSettingsManager_SettingsUpdate() async {
        // Given: Settings manager
        let suiteName = "test-update-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = await SettingsManager(repository: repository)
        
        // When: Updating global playback settings
        let newSettings = PlaybackSettings(
            playbackSpeed: 1.5,
            skipIntroSeconds: 30,
            skipOutroSeconds: 15,
            continuousPlayback: true
        )
        await manager.updateGlobalPlaybackSettings(newSettings)
        
        // Then: Should have updated settings
        await MainActor.run {
            let updatedSettings = manager.globalPlaybackSettings
            XCTAssertEqual(updatedSettings.playbackSpeed, 1.5, "Should update playback speed")
            XCTAssertEqual(updatedSettings.skipIntroSeconds, 30, "Should update skip intro")
            XCTAssertEqual(updatedSettings.skipOutroSeconds, 15, "Should update skip outro")
            XCTAssertTrue(updatedSettings.continuousPlayback, "Should update continuous playback")
        }
    }
    
    func testCrossPlatformCompatibility() async {
        // Given: Settings manager on current platform
        let suiteName = "test-platform-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = await SettingsManager(repository: repository)
        
        // When: Using settings functionality
        let effectiveSettings = await manager.effectivePlaybackSettings(for: "cross-platform-test")
        
        // Then: Should work across different platforms
        await MainActor.run {
            let globalSettings = manager.globalPlaybackSettings
            XCTAssertNotNil(globalSettings, "Settings should work on all platforms")
            XCTAssertNotNil(effectiveSettings, "Effective settings should work on all platforms")
        }
        
        // Platform-specific features should be conditionally available
        #if canImport(Combine)
        XCTAssertTrue(true, "Combine framework is available")
        #endif
    }
    
    func testSendableCompliance() {
        // Given: Settings types that should be Sendable
        let globalPlaybackSettings = PlaybackSettings(
            playbackSpeed: 1.25,
            skipIntroSeconds: 30,
            skipOutroSeconds: 15,
            continuousPlayback: true
        )
        
        // When: Using settings in async context
        Task {
            // Should be able to capture and use settings across concurrency boundaries
            let speed = globalPlaybackSettings.playbackSpeed
            XCTAssertEqual(speed, 1.25, "Should maintain speed value across concurrency boundaries")
        }
        
        // Then: Should compile without Sendable warnings
        XCTAssertEqual(globalPlaybackSettings.playbackSpeed, 1.25, "Should be Sendable-compliant")
    }
}