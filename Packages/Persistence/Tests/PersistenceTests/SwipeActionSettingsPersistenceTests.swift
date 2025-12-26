//
//  SwipeActionSettingsPersistenceTests.swift
//  PersistenceTests
//
//  Created for Issue 02.1.6: Swipe Gestures and Quick Actions
//

import XCTest
@testable import Persistence
@testable import CoreModels

final class SwipeActionSettingsPersistenceTests: XCTestCase {
    private var repository: UserDefaultsSettingsRepository!
    private var harness: UserDefaultsTestHarness!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = makeUserDefaultsHarness(prefix: "swipe-settings")
        repository = UserDefaultsSettingsRepository(suiteName: harness.suiteName)
    }

    override func tearDownWithError() throws {
        repository = nil
        harness = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Global UI Settings Tests
    
    func testLoadDefaultUISettings() async throws {
        // When no settings are saved, should return default
        let settings = await repository.loadGlobalUISettings()
        
        XCTAssertEqual(settings, UISettings.default)
        XCTAssertEqual(settings.swipeActions, SwipeActionSettings.default)
        XCTAssertEqual(settings.hapticStyle, .medium)
    }
    
    func testSaveAndLoadUISettings() async throws {
        // Given: Custom UI settings
        let swipeSettings = SwipeActionSettings(
            leadingActions: [.play, .download],
            trailingActions: [.favorite, .archive],
            allowFullSwipeLeading: false,
            allowFullSwipeTrailing: true,
            hapticFeedbackEnabled: false
        )
        let uiSettings = UISettings(
            swipeActions: swipeSettings,
            hapticStyle: .heavy
        )
        
        // When: Save settings
        await repository.saveGlobalUISettings(uiSettings)
        
        // Then: Load and verify
        let loaded = await repository.loadGlobalUISettings()
        XCTAssertEqual(loaded.swipeActions.leadingActions, swipeSettings.leadingActions)
        XCTAssertEqual(loaded.swipeActions.trailingActions, swipeSettings.trailingActions)
        XCTAssertEqual(loaded.swipeActions.allowFullSwipeLeading, swipeSettings.allowFullSwipeLeading)
        XCTAssertEqual(loaded.swipeActions.allowFullSwipeTrailing, swipeSettings.allowFullSwipeTrailing)
        XCTAssertEqual(loaded.swipeActions.hapticFeedbackEnabled, swipeSettings.hapticFeedbackEnabled)
        XCTAssertEqual(loaded.hapticStyle, .heavy)
    }
    
    func testUpdateUISettings() async throws {
        // Given: Initial settings
        let initialSettings = UISettings(
            swipeActions: SwipeActionSettings.default,
            hapticStyle: .light
        )
        await repository.saveGlobalUISettings(initialSettings)
        
        // When: Update to different settings
        let updatedSettings = UISettings(
            swipeActions: SwipeActionSettings.playbackFocused,
            hapticStyle: .rigid
        )
        await repository.saveGlobalUISettings(updatedSettings)
        
        // Then: Should load updated settings
        let loaded = await repository.loadGlobalUISettings()
        XCTAssertEqual(loaded.swipeActions, SwipeActionSettings.playbackFocused)
        XCTAssertEqual(loaded.hapticStyle, .rigid)
    }
    
    func testPresetSettingsPersistence() async throws {
        // Test that all preset configurations can be saved and loaded
        let presets: [(String, SwipeActionSettings)] = [
            ("default", .default),
            ("playback", .playbackFocused),
            ("organization", .organizationFocused),
            ("download", .downloadFocused)
        ]
        
        for (name, preset) in presets {
            let uiSettings = UISettings(swipeActions: preset, hapticStyle: .medium)
            await repository.saveGlobalUISettings(uiSettings)
            
            let loaded = await repository.loadGlobalUISettings()
            XCTAssertEqual(loaded.swipeActions, preset, "Failed to persist \(name) preset")
        }
    }
    
    func testHapticStylePersistence() async throws {
        let styles: [SwipeHapticStyle] = [.light, .medium, .heavy, .soft, .rigid]
        
        for style in styles {
            let uiSettings = UISettings(
                swipeActions: SwipeActionSettings.default,
                hapticStyle: style
            )
            await repository.saveGlobalUISettings(uiSettings)
            
            let loaded = await repository.loadGlobalUISettings()
            XCTAssertEqual(loaded.hapticStyle, style)
        }
    }
    
    // MARK: - Change Notifications Tests
    
    #if canImport(Combine)
    func testUISettingsChangeNotification() async throws {
        let expectation = XCTestExpectation(description: "Settings change notification")
        
        let stream = await repository.settingsChangeStream()
        let listener = Task {
            for await change in stream {
                if case .globalUI(let settings) = change,
                   settings.hapticStyle == .heavy {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        let newSettings = UISettings(
            swipeActions: SwipeActionSettings.default,
            hapticStyle: .heavy
        )
        await repository.saveGlobalUISettings(newSettings)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        listener.cancel()
    }
    #endif
    
    // MARK: - Edge Cases
    
    func testEmptyActionsLists() async throws {
        // Test with empty action lists
        let swipeSettings = SwipeActionSettings(
            leadingActions: [],
            trailingActions: [],
            allowFullSwipeLeading: true,
            allowFullSwipeTrailing: true,
            hapticFeedbackEnabled: true
        )
        let uiSettings = UISettings(swipeActions: swipeSettings, hapticStyle: .medium)
        
        await repository.saveGlobalUISettings(uiSettings)
        
        let loaded = await repository.loadGlobalUISettings()
        XCTAssertEqual(loaded.swipeActions.leadingActions, [])
        XCTAssertEqual(loaded.swipeActions.trailingActions, [])
    }
    
    func testMaximumActionsLists() async throws {
        // Test with maximum (3) actions per side
        let swipeSettings = SwipeActionSettings(
            leadingActions: [.play, .download, .markPlayed],
            trailingActions: [.delete, .archive, .favorite],
            allowFullSwipeLeading: true,
            allowFullSwipeTrailing: false,
            hapticFeedbackEnabled: true
        )
        let uiSettings = UISettings(swipeActions: swipeSettings, hapticStyle: .medium)
        
        await repository.saveGlobalUISettings(uiSettings)
        
        let loaded = await repository.loadGlobalUISettings()
        XCTAssertEqual(loaded.swipeActions.leadingActions.count, 3)
        XCTAssertEqual(loaded.swipeActions.trailingActions.count, 3)
    }
    
    func testCorruptedDataFallback() async throws {
        // Save corrupted data directly to UserDefaults
        let corruptedData = Data([0xFF, 0xFF, 0xFF])
        harness.userDefaults.set(corruptedData, forKey: "global_ui_settings")
        
        // Should return default when data is corrupted
        let loaded = await repository.loadGlobalUISettings()
        XCTAssertEqual(loaded, UISettings.default)
    }
}
