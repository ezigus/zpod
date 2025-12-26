//
//  UISettingsIntegrationTests.swift
//  SettingsDomainTests
//
//  Integration tests for Issue 02.1.6.1: Settings architecture support for swipe gesture configuration
//

import XCTest
@testable import SettingsDomain
@testable import Persistence
@testable import CoreModels
#if canImport(Combine)
import CombineSupport
#endif

@MainActor
final class UISettingsIntegrationTests: XCTestCase {
    
    var userDefaults: UserDefaults!
    var repository: UserDefaultsSettingsRepository!
    var settingsManager: SettingsManager!
    
    override func setUp() async throws {
        // Use a unique suite name for isolation
        let suiteName = "test.ui.settings.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        settingsManager = SettingsManager(repository: repository)
    }
    
    override func tearDown() async throws {
        if let suiteName = userDefaults.dictionaryRepresentation().keys.first {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        repository = nil
        settingsManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSettingsManagerInitializationWithUISettings() async throws {
        // Given: Fresh settings manager
        // When: Manager is initialized
        // Then: Should have default UI settings without crashing
        
        // Wait briefly for async initialization to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(settingsManager.globalUISettings.swipeActions, SwipeActionSettings.default)
        XCTAssertEqual(settingsManager.globalUISettings.hapticStyle, .medium)
    }
    
    func testSettingsManagerLoadsPersistedUISettings() async throws {
        // Given: UI settings saved in repository
        let customSwipeActions = SwipeActionSettings(
            leadingActions: [.play, .download],
            trailingActions: [.favorite, .archive],
            allowFullSwipeLeading: false,
            allowFullSwipeTrailing: true,
            hapticFeedbackEnabled: false
        )
        let customUISettings = UISettings(
            swipeActions: customSwipeActions,
            hapticStyle: .heavy
        )
        await repository.saveGlobalUISettings(customUISettings)
        
        // When: Create a new settings manager
        let newManager = SettingsManager(repository: repository)
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Should load the persisted settings
        XCTAssertEqual(newManager.globalUISettings.swipeActions.leadingActions, customSwipeActions.leadingActions)
        XCTAssertEqual(newManager.globalUISettings.swipeActions.trailingActions, customSwipeActions.trailingActions)
        XCTAssertEqual(newManager.globalUISettings.hapticStyle, .heavy)
    }
    
    // MARK: - Update and Persistence Tests
    
    func testUpdateGlobalUISettings() async throws {
        // Given: Settings manager with default UI settings
        try await Task.sleep(nanoseconds: 100_000_000)
        let initialSettings = settingsManager.globalUISettings
        XCTAssertEqual(initialSettings, UISettings.default)
        
        // When: Update UI settings
        let newSwipeActions = SwipeActionSettings.playbackFocused
        let newUISettings = UISettings(
            swipeActions: newSwipeActions,
            hapticStyle: .soft
        )
        await settingsManager.updateGlobalUISettings(newUISettings)
        
        // Then: Settings should be updated
        XCTAssertEqual(settingsManager.globalUISettings.swipeActions, newSwipeActions)
        XCTAssertEqual(settingsManager.globalUISettings.hapticStyle, .soft)
        
        // And: Settings should persist
        let loadedSettings = await repository.loadGlobalUISettings()
        XCTAssertEqual(loadedSettings.swipeActions, newSwipeActions)
        XCTAssertEqual(loadedSettings.hapticStyle, .soft)
    }
    
    func testMultipleUISettingsUpdates() async throws {
        // Test that multiple updates work correctly
        let presets: [(SwipeActionSettings, SwipeHapticStyle)] = [
            (.default, .medium),
            (.playbackFocused, .heavy),
            (.organizationFocused, .light),
            (.downloadFocused, .rigid)
        ]
        
        for (swipeActions, hapticStyle) in presets {
            let uiSettings = UISettings(swipeActions: swipeActions, hapticStyle: hapticStyle)
            await settingsManager.updateGlobalUISettings(uiSettings)
            
            // Verify immediate update
            XCTAssertEqual(settingsManager.globalUISettings.swipeActions, swipeActions)
            XCTAssertEqual(settingsManager.globalUISettings.hapticStyle, hapticStyle)
            
            // Verify persistence
            let loaded = await repository.loadGlobalUISettings()
            XCTAssertEqual(loaded.swipeActions, swipeActions)
            XCTAssertEqual(loaded.hapticStyle, hapticStyle)
        }
    }
    
    // MARK: - Change Notification Tests
    
    #if canImport(Combine)
    func testUISettingsChangeNotifications() async throws {
        // Given: Settings manager with change publisher
        var receivedChanges: [SettingsChange] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = XCTestExpectation(description: "UI settings change notification")
        expectation.expectedFulfillmentCount = 1
        
        let listener = Task {
            let stream = await repository.settingsChangeStream()
            for await change in stream {
                receivedChanges.append(change)
                if case .globalUI = change {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        // When: Update UI settings
        let newSettings = UISettings(
            swipeActions: SwipeActionSettings.playbackFocused,
            hapticStyle: .heavy
        )
        await settingsManager.updateGlobalUISettings(newSettings)
        
        // Then: Should receive change notification
        await fulfillment(of: [expectation], timeout: 2.0)
        listener.cancel()
        
        let uiChanges = receivedChanges.compactMap { change -> UISettings? in
            if case .globalUI(let settings) = change {
                return settings
            }
            return nil
        }
        
        XCTAssertFalse(uiChanges.isEmpty, "Should have received at least one UI settings change")
        XCTAssertEqual(uiChanges.last?.swipeActions, SwipeActionSettings.playbackFocused)
        XCTAssertEqual(uiChanges.last?.hapticStyle, .heavy)
        
        cancellables.forEach { $0.cancel() }
    }
    
    @MainActor
    func testPublishedPropertyUpdates() async throws {
        // Test that @Published property triggers observers
        var observedSettings: [UISettings] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = XCTestExpectation(description: "Published property update")
        expectation.expectedFulfillmentCount = 2 // Initial + update
        
        settingsManager.$globalUISettings
            .sink { settings in
                observedSettings.append(settings)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Update settings
        let newSettings = UISettings(
            swipeActions: SwipeActionSettings.organizationFocused,
            hapticStyle: .soft
        )
        await settingsManager.updateGlobalUISettings(newSettings)
        
        // Then: Should observe changes
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertEqual(observedSettings.count, 2)
        XCTAssertEqual(observedSettings.first, UISettings.default)
        XCTAssertEqual(observedSettings.last?.swipeActions, SwipeActionSettings.organizationFocused)
        
        cancellables.forEach { $0.cancel() }
    }
    #endif
    
    // MARK: - Coexistence Tests
    
    func testUISettingsCoexistWithOtherSettings() async throws {
        // Given: Multiple settings types configured
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let downloadSettings = DownloadSettings(
            autoDownloadEnabled: true,
            wifiOnly: false,
            maxConcurrentDownloads: 5,
            retentionPolicy: .keepLatest(10),
            defaultUpdateFrequency: .hourly
        )
        
        let playbackSettings = PlaybackSettings(
            globalPlaybackSpeed: 1.5,
            skipForwardInterval: 30,
            skipBackwardInterval: 15
        )
        
        let uiSettings = UISettings(
            swipeActions: SwipeActionSettings.downloadFocused,
            hapticStyle: .rigid
        )
        
        // When: Update all settings
        await settingsManager.updateGlobalDownloadSettings(downloadSettings)
        await settingsManager.updateGlobalPlaybackSettings(playbackSettings)
        await settingsManager.updateGlobalUISettings(uiSettings)
        
        // Then: All settings should be preserved independently
        XCTAssertEqual(settingsManager.globalDownloadSettings.autoDownloadEnabled, true)
        XCTAssertEqual(settingsManager.globalDownloadSettings.maxConcurrentDownloads, 5)
        
        XCTAssertEqual(settingsManager.globalPlaybackSettings.globalPlaybackSpeed, 1.5)
        XCTAssertEqual(settingsManager.globalPlaybackSettings.skipForwardInterval, 30)
        
        XCTAssertEqual(settingsManager.globalUISettings.swipeActions, SwipeActionSettings.downloadFocused)
        XCTAssertEqual(settingsManager.globalUISettings.hapticStyle, .rigid)
    }
    
    func testNoCrashOnStartupWithUISettings() async throws {
        // This test specifically addresses the crash scenario from Issue 02.1.6.1
        // Given: Repository with UI settings already saved
        let savedSettings = UISettings(
            swipeActions: SwipeActionSettings.playbackFocused,
            hapticStyle: .heavy
        )
        await repository.saveGlobalUISettings(savedSettings)
        
        // When: Create multiple new settings managers (simulating app restarts)
        for _ in 1...5 {
            let manager = SettingsManager(repository: repository)
            
            // Wait for initialization
            try await Task.sleep(nanoseconds: 100_000_000)
            
            // Then: Should not crash and should load settings correctly
            XCTAssertEqual(manager.globalUISettings.swipeActions, SwipeActionSettings.playbackFocused)
            XCTAssertEqual(manager.globalUISettings.hapticStyle, .heavy)
        }
    }
}
