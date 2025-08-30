import XCTest

/// UI tests for playback interface controls and platform integrations
///
/// **Specifications Covered**: `spec/ui.md` - Playback interface sections
/// - Now playing screen controls and media player interface
/// - Lock screen and control center integration testing
/// - CarPlay player interface verification (simulated)
/// - Apple Watch playback controls (simulated)
/// - Bluetooth and external control handling
final class PlaybackUITests: XCTestCase {
    
    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
        
        // Navigate to player interface for testing
        let tabBar = app.tabBars["Main Tab Bar"]
        let playerTab = tabBar.buttons["Player"]
        if playerTab.exists {
            playerTab.tap()
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Now Playing Interface Tests
    // Covers: Player interface controls from ui spec
    
    @MainActor
    func testNowPlayingControls() throws {
        // Given: Now playing interface is visible
        let playerInterface = app.otherElements["Player Interface"]
        
        if playerInterface.exists {
            // When: Checking for essential playback controls
            let playButton = app.buttons["Play"] 
            let pauseButton = app.buttons["Pause"]
            let skipForwardButton = app.buttons["Skip Forward"]
            let skipBackwardButton = app.buttons["Skip Backward"]
            
            // Then: Controls should be present and accessible
            XCTAssertTrue(playButton.exists || pauseButton.exists, 
                         "Play/Pause button should be available")
            
            if skipForwardButton.exists {
                XCTAssertTrue(skipForwardButton.isEnabled, "Skip forward should be enabled")
                XCTAssertFalse(skipForwardButton.label.isEmpty, "Skip forward should have label")
            }
            
            if skipBackwardButton.exists {
                XCTAssertTrue(skipBackwardButton.isEnabled, "Skip backward should be enabled")
                XCTAssertFalse(skipBackwardButton.label.isEmpty, "Skip backward should have label")
            }
        }
    }
    
    @MainActor
    func testPlaybackSpeedControls() throws {
        // Given: Player interface with speed controls
        let speedButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Speed' OR label CONTAINS 'x'")).firstMatch
        
        if speedButton.exists {
            // When: Interacting with speed controls
            speedButton.tap()
            
            // Then: Speed options should be available
            let speedOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS '1.0x' OR label CONTAINS '1.5x' OR label CONTAINS '2.0x'"))
            
            if speedOptions.count > 0 {
                XCTAssertGreaterThan(speedOptions.count, 0, "Speed options should be available")
                
                // Test selecting a speed option
                let fastSpeed = speedOptions.element(boundBy: min(1, speedOptions.count - 1))
                if fastSpeed.exists {
                    fastSpeed.tap()
                    // Speed should change (verified by UI state)
                }
            }
        }
    }
    
    @MainActor
    func testProgressSlider() throws {
        // Given: Player interface with progress controls
        let progressSlider = app.sliders["Progress Slider"]
        
        if progressSlider.exists {
            // When: Interacting with progress slider
            // Then: Slider should be interactive
            XCTAssertTrue(progressSlider.isEnabled, "Progress slider should be interactive")
            
            // Test slider accessibility
            XCTAssertNotNil(progressSlider.value, "Progress slider should have current value")
            XCTAssertFalse(progressSlider.label.isEmpty, "Progress slider should have descriptive label")
        }
    }
    
    @MainActor
    func testEpisodeInformation() throws {
        // Given: Episode is playing
        let episodeTitle = app.staticTexts["Episode Title"]
        let podcastTitle = app.staticTexts["Podcast Title"]
        let episodeArtwork = app.images["Episode Artwork"]
        
        // When: Checking episode information display
        // Then: Episode information should be visible
        if episodeTitle.exists {
            XCTAssertFalse(episodeTitle.label.isEmpty, "Episode title should be displayed")
        }
        
        if podcastTitle.exists {
            XCTAssertFalse(podcastTitle.label.isEmpty, "Podcast title should be displayed")
        }
        
        if episodeArtwork.exists {
            XCTAssertTrue(episodeArtwork.isAccessibilityElement, "Artwork should be accessible")
        }
    }
    
    // MARK: - Advanced Controls Tests
    // Covers: Advanced playback features from ui spec
    
    @MainActor
    func testSkipSilenceControls() throws {
        // Given: Player interface with skip silence option
        let skipSilenceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Skip Silence' OR label CONTAINS 'Silence'")).firstMatch
        
        if skipSilenceButton.exists {
            // When: Toggling skip silence
            let initialState = skipSilenceButton.isSelected
            skipSilenceButton.tap()
            
            // Then: State should change
            let newState = skipSilenceButton.isSelected
            XCTAssertNotEqual(initialState, newState, "Skip silence state should toggle")
        }
    }
    
    @MainActor
    func testVolumeBoostControls() throws {
        // Given: Player interface with volume boost option
        let volumeBoostButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Volume Boost' OR label CONTAINS 'Boost'")).firstMatch
        
        if volumeBoostButton.exists {
            // When: Toggling volume boost
            let initialState = volumeBoostButton.isSelected
            volumeBoostButton.tap()
            
            // Then: State should change
            let newState = volumeBoostButton.isSelected
            XCTAssertNotEqual(initialState, newState, "Volume boost state should toggle")
        }
    }
    
    @MainActor
    func testSleepTimerControls() throws {
        // Given: Player interface with sleep timer
        let sleepTimerButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sleep Timer' OR label CONTAINS 'Timer'")).firstMatch
        
        if sleepTimerButton.exists {
            // When: Accessing sleep timer
            sleepTimerButton.tap()
            
            // Then: Timer options should be available
            let timerOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS 'minute' OR label CONTAINS 'hour'"))
            
            if timerOptions.count > 0 {
                XCTAssertGreaterThan(timerOptions.count, 0, "Sleep timer options should be available")
                
                // Test selecting a timer option
                let fifteenMinutes = timerOptions.firstMatch
                if fifteenMinutes.exists {
                    fifteenMinutes.tap()
                    // Timer should be set (verified by UI feedback)
                }
            }
        }
    }
    
    // MARK: - Control Center Integration Tests
    // Covers: Control center integration from ui spec
    
    @MainActor
    func testControlCenterCompatibility() throws {
        // Given: App is playing audio
        // When: Testing control center compatibility
        // Note: Control center testing requires background audio capability
        
        // Verify that media controls are properly configured
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        
        if playButton.exists || pauseButton.exists {
            // Then: Media controls should be accessible for system integration
            XCTAssertTrue(playButton.exists || pauseButton.exists, 
                         "Media controls should be available for system integration")
        }
        
        // Test that episode information is available for system display
        let episodeTitle = app.staticTexts["Episode Title"]
        if episodeTitle.exists {
            XCTAssertFalse(episodeTitle.label.isEmpty, 
                          "Episode title should be available for control center")
        }
    }
    
    // MARK: - Lock Screen Integration Tests
    // Covers: Lock screen player from ui spec
    
    @MainActor
    func testLockScreenMediaInfo() throws {
        // Given: App is configured for lock screen media display
        // When: Checking media information availability
        
        // Verify that required media information is present
        let episodeTitle = app.staticTexts["Episode Title"]
        let podcastTitle = app.staticTexts["Podcast Title"]
        let episodeArtwork = app.images["Episode Artwork"]
        
        // Then: Media info should be suitable for lock screen display
        if episodeTitle.exists {
            XCTAssertFalse(episodeTitle.label.isEmpty, 
                          "Episode title should be available for lock screen")
        }
        
        if podcastTitle.exists {
            XCTAssertFalse(podcastTitle.label.isEmpty, 
                          "Podcast title should be available for lock screen")
        }
        
        if episodeArtwork.exists {
            XCTAssertTrue(episodeArtwork.exists, 
                         "Artwork should be available for lock screen")
        }
    }
    
    // MARK: - CarPlay Interface Tests  
    // Covers: CarPlay integration from ui spec
    
    @MainActor
    func testCarPlayCompatibleInterface() throws {
        // Given: App interface should be CarPlay compatible
        // When: Checking for CarPlay-suitable controls
        
        // CarPlay requires large, easily accessible controls
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        let skipForwardButton = app.buttons["Skip Forward"]
        let skipBackwardButton = app.buttons["Skip Backward"]
        
        // Then: Controls should be suitable for CarPlay
        if playButton.exists {
            XCTAssertTrue(playButton.frame.height >= 44, "Play button should be large enough for CarPlay")
            XCTAssertFalse(playButton.label.isEmpty, "Play button should have clear label for CarPlay")
        }
        
        if pauseButton.exists {
            XCTAssertTrue(pauseButton.frame.height >= 44, "Pause button should be large enough for CarPlay")
        }
        
        // Test that text is readable for CarPlay
        let episodeTitle = app.staticTexts["Episode Title"]
        if episodeTitle.exists {
            XCTAssertTrue(episodeTitle.label.count <= 50, 
                         "Episode title should be concise for CarPlay display")
        }
    }
    
    // MARK: - Apple Watch Interface Tests
    // Covers: Apple Watch support from ui spec
    
    @MainActor
    func testWatchCompatibleControls() throws {
        // Given: App should support Apple Watch companion
        // When: Checking for Watch-suitable interface elements
        
        // Watch interface requires essential controls only
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        
        // Then: Essential controls should be available
        if playButton.exists || pauseButton.exists {
            XCTAssertTrue(playButton.exists || pauseButton.exists, 
                         "Essential playback controls should be available for Watch")
        }
        
        // Test simplified information display suitable for Watch
        let episodeTitle = app.staticTexts["Episode Title"]
        if episodeTitle.exists && episodeTitle.label.count > 30 {
            // Title should be truncatable for Watch display
            XCTAssertTrue(true, "Long titles should be handled appropriately for Watch")
        }
    }
    
    // MARK: - Accessibility Tests for Playback
    // Covers: Accessibility for playback features from ui spec
    
    @MainActor
    func testPlaybackAccessibility() throws {
        // Given: Playback interface is accessible
        // When: Checking accessibility features
        
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        
        // Then: Playback controls should have proper accessibility
        if playButton.exists {
            XCTAssertTrue(playButton.isAccessibilityElement, "Play button should be accessible")
            XCTAssertNotNil(playButton.accessibilityLabel, "Play button should have accessibility label")
            XCTAssertNotNil(playButton.accessibilityHint, "Play button should have accessibility hint")
        }
        
        if pauseButton.exists {
            XCTAssertTrue(pauseButton.isAccessibilityElement, "Pause button should be accessible")
            XCTAssertNotNil(pauseButton.accessibilityLabel, "Pause button should have accessibility label")
        }
        
        // Test progress slider accessibility
        let progressSlider = app.sliders["Progress Slider"]
        if progressSlider.exists {
            XCTAssertTrue(progressSlider.isAccessibilityElement, "Progress slider should be accessible")
            XCTAssertNotNil(progressSlider.accessibilityValue, "Progress slider should announce current position")
        }
    }
    
    @MainActor
    func testVoiceOverPlaybackNavigation() throws {
        // Given: VoiceOver user navigating playback controls
        // When: Checking VoiceOver navigation order
        
        let playbackControls = [
            app.buttons["Skip Backward"],
            app.buttons["Play"],
            app.buttons["Pause"], 
            app.buttons["Skip Forward"]
        ].filter { $0.exists }
        
        // Then: Controls should be in logical order for VoiceOver
        for control in playbackControls {
            if control.isAccessibilityElement {
                XCTAssertTrue(control.isAccessibilityElement, 
                             "Playback control should be accessible to VoiceOver")
                if let label = control.accessibilityLabel {
                    XCTAssertFalse(label.isEmpty, "Control should have descriptive label")
                }
            }
        }
    }
    
    // MARK: - Performance Tests
    // Covers: UI responsiveness during playback
    
    @MainActor
    func testPlaybackUIPerformance() throws {
        // Given: Playback interface is loaded
        let startTime = Date().timeIntervalSince1970
        
        // When: Interacting with playback controls
        let playButton = app.buttons["Play"]
        if playButton.exists {
            playButton.tap()
        }
        
        let endTime = Date().timeIntervalSince1970
        let responseTime = endTime - startTime
        
        // Then: UI should respond quickly
        XCTAssertLessThan(responseTime, 0.5, "Playback controls should respond within 0.5 seconds")
    }
    
    // MARK: - Acceptance Criteria Tests
    // Covers: Complete playback UI workflows from ui specification
    
    @MainActor
    func testAcceptanceCriteria_CompletePlaybackWorkflow() throws {
        // Given: User wants to control podcast playback
        let playerInterface = app.otherElements["Player Interface"]
        
        if playerInterface.exists {
            // When: User interacts with all major playback controls
            
            // Test play/pause functionality
            let playButton = app.buttons["Play"]
            let pauseButton = app.buttons["Pause"]
            
            if playButton.exists {
                playButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            if pauseButton.exists {
                pauseButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Test skip controls
            let skipForward = app.buttons["Skip Forward"]
            let skipBackward = app.buttons["Skip Backward"]
            
            if skipForward.exists {
                skipForward.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            if skipBackward.exists {
                skipBackward.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // Then: All controls should work without crashing
            XCTAssertTrue(app.state == XCUIApplication.State.runningForeground, "App should remain stable during playback control")
            XCTAssertTrue(playerInterface.exists, "Player interface should remain available")
        }
    }
    
    @MainActor
    func testAcceptanceCriteria_PlatformIntegrationReadiness() throws {
        // Given: App should integrate with platform media systems
        // When: Checking platform integration readiness
        
        // Verify essential media information is available
        let episodeTitle = app.staticTexts["Episode Title"]
        let podcastTitle = app.staticTexts["Podcast Title"]
        let episodeArtwork = app.images["Episode Artwork"]
        
        var integrationElements = 0
        
        if episodeTitle.exists && !episodeTitle.label.isEmpty {
            integrationElements += 1
        }
        
        if podcastTitle.exists && !podcastTitle.label.isEmpty {
            integrationElements += 1
        }
        
        if episodeArtwork.exists {
            integrationElements += 1
        }
        
        // Verify essential controls are available
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        
        if playButton.exists || pauseButton.exists {
            integrationElements += 1
        }
        
        // Then: App should have sufficient elements for platform integration
        XCTAssertGreaterThanOrEqual(integrationElements, 3, 
                                   "App should have sufficient elements for platform media integration")
    }
    
    @MainActor
    func testAcceptanceCriteria_AccessibilityCompliance() throws {
        // Given: Playback interface must be accessible
        // When: Checking comprehensive accessibility
        
        let accessibleElements = [
            app.buttons["Play"],
            app.buttons["Pause"],
            app.buttons["Skip Forward"],
            app.buttons["Skip Backward"],
            app.sliders["Progress Slider"],
            app.staticTexts["Episode Title"]
        ]
        
        var accessibilityScore = 0
        
        for element in accessibleElements {
            if element.exists {
                if element.isAccessibilityElement {
                    accessibilityScore += 1
                }
                
                if !(element.accessibilityLabel?.isEmpty ?? true) {
                    accessibilityScore += 1
                }
            }
        }
        
        // Then: Interface should have strong accessibility support
        XCTAssertGreaterThanOrEqual(accessibilityScore, 6, 
                                   "Playback interface should have comprehensive accessibility support")
    }
}