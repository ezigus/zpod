//
//  SwipeActionSettingsTests.swift
//  CoreModelsTests
//
//  Created for Issue 02.1.6: Swipe Gestures and Quick Actions
//

import XCTest
@testable import CoreModels

final class SwipeActionSettingsTests: XCTestCase {
    
    // MARK: - SwipeActionType Tests
    
    func testSwipeActionTypeDisplayNames() {
        XCTAssertEqual(SwipeActionType.play.displayName, "Play")
        XCTAssertEqual(SwipeActionType.download.displayName, "Download")
        XCTAssertEqual(SwipeActionType.markPlayed.displayName, "Mark Played")
        XCTAssertEqual(SwipeActionType.markUnplayed.displayName, "Mark Unplayed")
        XCTAssertEqual(SwipeActionType.addToPlaylist.displayName, "Add to Playlist")
        XCTAssertEqual(SwipeActionType.favorite.displayName, "Favorite")
        XCTAssertEqual(SwipeActionType.archive.displayName, "Archive")
        XCTAssertEqual(SwipeActionType.delete.displayName, "Delete")
        XCTAssertEqual(SwipeActionType.share.displayName, "Share")
    }
    
    func testSwipeActionTypeIcons() {
        XCTAssertEqual(SwipeActionType.play.systemIcon, "play.fill")
        XCTAssertEqual(SwipeActionType.download.systemIcon, "arrow.down.circle.fill")
        XCTAssertEqual(SwipeActionType.delete.systemIcon, "trash.fill")
    }
    
    func testSwipeActionTypeDestructiveFlags() {
        XCTAssertTrue(SwipeActionType.delete.isDestructive)
        XCTAssertFalse(SwipeActionType.play.isDestructive)
        XCTAssertFalse(SwipeActionType.favorite.isDestructive)
    }
    
    // MARK: - SwipeActionSettings Tests
    
    func testDefaultSettings() {
        let settings = SwipeActionSettings.default
        
        XCTAssertEqual(settings.leadingActions, [.markPlayed])
        XCTAssertEqual(settings.trailingActions, [.delete, .archive])
        XCTAssertTrue(settings.allowFullSwipeLeading)
        XCTAssertFalse(settings.allowFullSwipeTrailing)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
    }
    
    func testPlaybackFocusedPreset() {
        let settings = SwipeActionSettings.playbackFocused
        
        XCTAssertEqual(settings.leadingActions, [.play, .addToPlaylist])
        XCTAssertEqual(settings.trailingActions, [.download, .favorite])
        XCTAssertTrue(settings.hapticFeedbackEnabled)
    }
    
    func testOrganizationFocusedPreset() {
        let settings = SwipeActionSettings.organizationFocused
        
        XCTAssertEqual(settings.leadingActions, [.markPlayed, .favorite])
        XCTAssertEqual(settings.trailingActions, [.archive, .delete])
        XCTAssertTrue(settings.hapticFeedbackEnabled)
    }
    
    func testDownloadFocusedPreset() {
        let settings = SwipeActionSettings.downloadFocused
        
        XCTAssertEqual(settings.leadingActions, [.download, .markPlayed])
        XCTAssertEqual(settings.trailingActions, [.archive, .delete])
        XCTAssertTrue(settings.hapticFeedbackEnabled)
    }
    
    func testCustomSettings() {
        let settings = SwipeActionSettings(
            leadingActions: [.play, .download],
            trailingActions: [.favorite, .archive, .delete],
            allowFullSwipeLeading: false,
            allowFullSwipeTrailing: true,
            hapticFeedbackEnabled: false
        )
        
        XCTAssertEqual(settings.leadingActions, [.play, .download])
        XCTAssertEqual(settings.trailingActions, [.favorite, .archive, .delete])
        XCTAssertFalse(settings.allowFullSwipeLeading)
        XCTAssertTrue(settings.allowFullSwipeTrailing)
        XCTAssertFalse(settings.hapticFeedbackEnabled)
    }
    
    func testActionLimitEnforcement() {
        // Should limit to max 3 actions per edge
        let settings = SwipeActionSettings(
            leadingActions: [.play, .download, .markPlayed, .favorite, .archive],
            trailingActions: [.delete, .share, .addToPlaylist, .markUnplayed],
            allowFullSwipeLeading: true,
            allowFullSwipeTrailing: false,
            hapticFeedbackEnabled: true
        )
        
        XCTAssertEqual(settings.leadingActions.count, 3)
        XCTAssertEqual(settings.trailingActions.count, 3)
        XCTAssertEqual(settings.leadingActions, [.play, .download, .markPlayed])
        XCTAssertEqual(settings.trailingActions, [.delete, .share, .addToPlaylist])
    }
    
    // MARK: - Codable Tests
    
    func testSwipeActionSettingsCodable() throws {
        let settings = SwipeActionSettings(
            leadingActions: [.play, .favorite],
            trailingActions: [.delete, .archive],
            allowFullSwipeLeading: true,
            allowFullSwipeTrailing: false,
            hapticFeedbackEnabled: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SwipeActionSettings.self, from: data)
        
        XCTAssertEqual(decoded.leadingActions, settings.leadingActions)
        XCTAssertEqual(decoded.trailingActions, settings.trailingActions)
        XCTAssertEqual(decoded.allowFullSwipeLeading, settings.allowFullSwipeLeading)
        XCTAssertEqual(decoded.allowFullSwipeTrailing, settings.allowFullSwipeTrailing)
        XCTAssertEqual(decoded.hapticFeedbackEnabled, settings.hapticFeedbackEnabled)
    }
    
    func testSwipeHapticStyleCodable() throws {
        let styles: [SwipeHapticStyle] = [.light, .medium, .heavy, .soft, .rigid]
        
        for style in styles {
            let encoder = JSONEncoder()
            let data = try encoder.encode(style)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(SwipeHapticStyle.self, from: data)
            
            XCTAssertEqual(decoded, style)
        }
    }
    
    // MARK: - Equatable Tests
    
    func testSwipeActionSettingsEquality() {
        let settings1 = SwipeActionSettings.default
        let settings2 = SwipeActionSettings.default
        let settings3 = SwipeActionSettings.playbackFocused
        
        XCTAssertEqual(settings1, settings2)
        XCTAssertNotEqual(settings1, settings3)
    }
    
    // MARK: - UISettings Tests
    
    func testUISettingsDefault() {
        let settings = UISettings.default
        
        XCTAssertEqual(settings.swipeActions, SwipeActionSettings.default)
        XCTAssertEqual(settings.hapticStyle, .medium)
    }
    
    func testUISettingsCustom() {
        let swipeSettings = SwipeActionSettings.playbackFocused
        let uiSettings = UISettings(
            swipeActions: swipeSettings,
            hapticStyle: .heavy
        )
        
        XCTAssertEqual(uiSettings.swipeActions, swipeSettings)
        XCTAssertEqual(uiSettings.hapticStyle, .heavy)
    }
    
    func testUISettingsCodable() throws {
        let swipeSettings = SwipeActionSettings(
            leadingActions: [.play],
            trailingActions: [.delete],
            allowFullSwipeLeading: true,
            allowFullSwipeTrailing: false,
            hapticFeedbackEnabled: true
        )
        let uiSettings = UISettings(
            swipeActions: swipeSettings,
            hapticStyle: .soft
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(uiSettings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UISettings.self, from: data)
        
        XCTAssertEqual(decoded.swipeActions, uiSettings.swipeActions)
        XCTAssertEqual(decoded.hapticStyle, uiSettings.hapticStyle)
    }
}
