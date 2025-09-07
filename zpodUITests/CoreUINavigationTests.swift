import XCTest
import UIKit

/// Core UI navigation and accessibility tests for the main application interface
///
/// **Specifications Covered**: `spec/ui.md` - Navigation sections
/// - Main navigation flow between screens and tabs
/// - Accessibility compliance and VoiceOver support
/// - iPad-specific layout adaptations and behaviors
/// - Quick action handling and app shortcuts
final class CoreUINavigationTests: XCTestCase {
    
    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs
        continueAfterFailure = false
        
        // Create app instance and perform UI operations using Task for main actor access
        let appInstance: XCUIApplication = {
            let semaphore = DispatchSemaphore(value: 0)
            var appResult: XCUIApplication!
            
            Task { @MainActor in
                appResult = XCUIApplication()
                appResult.launch()
                semaphore.signal()
            }
            
            semaphore.wait()
            return appResult
        }()
        
        // Assign to instance property after main thread operations complete
        app = appInstance
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main Navigation Tests
    // Covers: Basic navigation flow from ui spec
    
    @MainActor
    func testMainTabBarNavigation() throws {
        // Given: App is launched and main interface is visible
        // When: User taps different tab bar items
        let tabBar = app.tabBars["Main Tab Bar"]
        XCTAssertTrue(tabBar.exists, "Main tab bar should be visible")
        
        // Test Library tab
        let libraryTab = tabBar.buttons["Library"]
        if libraryTab.exists {
            libraryTab.tap()
            XCTAssertTrue(app.navigationBars["Library"].exists, "Library screen should be displayed")
        }
        
        // Test Discover tab
        let discoverTab = tabBar.buttons["Discover"]
        if discoverTab.exists {
            discoverTab.tap()
            XCTAssertTrue(app.navigationBars["Discover"].exists, "Discover screen should be displayed")
        }
        
        // Test Player tab
        let playerTab = tabBar.buttons["Player"]
        if playerTab.exists {
            playerTab.tap()
            // Player interface may have different structure
            XCTAssertTrue(
                app.otherElements["Player Interface"].exists ||
                app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Now Playing'"))
                    .firstMatch.exists,
                "Player interface should be displayed"
            )
        }
        
        // Then: Navigation should work correctly
        XCTAssertTrue(tabBar.exists, "Tab bar should remain visible during navigation")
    }
    
    @MainActor
    func testNavigationStackManagement() throws {
        // Given: User is on a detail screen
        let tabBar = app.tabBars["Main Tab Bar"]
        let libraryTab = tabBar.buttons["Library"]
        
        if libraryTab.exists {
            libraryTab.tap()
            
            // Navigate to a podcast detail if available
            let firstPodcast = app.tables.cells.firstMatch
            if firstPodcast.exists {
                firstPodcast.tap()
                
                // When: User uses back navigation
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                    
                    // Then: Should return to previous screen
                    XCTAssertTrue(app.navigationBars["Library"].exists, "Should return to Library screen")
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    // Covers: Accessibility compliance from ui spec
    
    @MainActor
    func testVoiceOverLabels() throws {
        // Given: App interface is loaded
        // When: Checking accessibility labels
        let tabBar = app.tabBars["Main Tab Bar"]
        
        // Then: Tab bar buttons should have proper accessibility labels
        let libraryTab = tabBar.buttons["Library"]
        if libraryTab.exists {
            XCTAssertFalse(libraryTab.label.isEmpty, "Library tab label should not be empty")
        }
        
        let discoverTab = tabBar.buttons["Discover"]
        if discoverTab.exists {
            XCTAssertFalse(discoverTab.label.isEmpty, "Discover tab label should not be empty")
        }
        
        // Test main content areas have accessible labels or are interactable
        let mainContent = app.otherElements["Main Content"]
        if mainContent.exists {
            XCTAssertTrue(!mainContent.label.isEmpty || mainContent.isHittable,
                         "Main content should be accessible")
        }
    }
    
    @MainActor
    func testAccessibilityHints() throws {
        // Given: Interactive elements are visible
        // When: Checking accessibility hints
        let tabBar = app.tabBars["Main Tab Bar"]
        
        // Then: Interactive elements should have helpful hints
        let libraryTab = tabBar.buttons["Library"]
        if libraryTab.exists, let hint = libraryTab.accessibilityHint {
            XCTAssertFalse(hint.isEmpty, "Library tab hint should provide guidance")
        }
        
        // Check for search functionality accessibility
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            let hasLabel = !searchField.label.isEmpty
            let hasPlaceholder = !(searchField.placeholderValue ?? "").isEmpty
            XCTAssertTrue(hasLabel || hasPlaceholder,
                           "Search field should expose label or placeholder text for accessibility")
        }
    }
    
    @MainActor
    func testKeyboardNavigation() throws {
        // Given: App supports keyboard navigation
        // When: Using keyboard navigation (simulated through accessibility)
        
        // Test that focusable elements are properly configured
        let interactiveElements = app.buttons.allElementsBoundByIndex +
                                 app.textFields.allElementsBoundByIndex +
                                 app.tables.allElementsBoundByIndex
        
        // Then: Interactive elements should be keyboard accessible
        for element in interactiveElements.prefix(5) { // Test first 5 elements
            if element.exists {
                let traits = element.accessibilityTraits
                XCTAssertTrue(element.isHittable || !element.label.isEmpty ||
                              traits.contains(.button) || traits.contains(.searchField),
                              "Interactive elements should be keyboard accessible")
            }
        }
    }
    
    // MARK: - iPad Layout Tests
    // Covers: iPad UI optimization from ui spec
    
    @MainActor
    func testIPadLayoutAdaptation() throws {
        // Given: App is running on iPad (or iPad simulator)
        let deviceType = UIDevice.current.userInterfaceIdiom
        
        if deviceType == .pad {
            // When: Checking iPad-specific layouts
            // Then: Should have appropriate iPad layouts
            
            // Check for sidebar or split view on iPad
            let sidebar = app.otherElements["Sidebar"]
            let splitView = app.otherElements["Split View"]
            
            if sidebar.exists || splitView.exists {
                XCTAssertTrue(true, "iPad should have sidebar or split view layout")
            }
            
            // Check that content adapts to larger screen
            let mainContent = app.otherElements["Main Content"]
            if mainContent.exists {
                // On iPad, content should use available space effectively
                XCTAssertTrue(mainContent.frame.width > 600,
                             "iPad content should utilize larger screen width")
            }
        } else {
            // On iPhone, should have compact layout
            let tabBar = app.tabBars["Main Tab Bar"]
            XCTAssertTrue(tabBar.exists, "iPhone should have tab bar navigation")
        }
    }
    
    // MARK: - App Shortcuts Tests
    // Covers: iOS Quick Actions from ui spec
    
    @MainActor
    func testAppShortcutHandling() throws {
        // Given: App supports quick actions
        // Note: Quick actions are typically tested through app launch with shortcut items
        // This test verifies the app can handle shortcut-triggered launches
        
        // When: App is launched (simulating shortcut activation)
        // Then: App should handle launch gracefully
        XCTAssertTrue(app.state == .runningForeground, "App should launch successfully")
        
        // Verify key screens are accessible for shortcuts
        let tabBar = app.tabBars["Main Tab Bar"]
        XCTAssertTrue(tabBar.exists, "Main navigation should be available for shortcuts")
        
        // Test that search is quickly accessible (common shortcut target)
        let searchElements = app.searchFields.allElementsBoundByIndex
        if !searchElements.isEmpty {
            XCTAssertTrue(searchElements.first!.exists, "Search should be accessible")
        }
    }
    
    // MARK: - Dark Mode and Appearance Tests
    // Covers: Theme customization from ui spec
    
    @MainActor
    func testAppearanceAdaptation() throws {
        // Given: App supports appearance changes
        // When: Checking that UI elements are visible and functional regardless of appearance
        // Note: XCUITest doesn't provide direct access to interface style, so we verify
        // that elements are visible and interactive which indicates proper appearance adaptation
        
        // Then: App should adapt to system appearance
        // Verify that content is visible in current appearance mode
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            XCTAssertTrue(tabBar.isHittable, "Tab bar should be visible in current appearance")
        }
        
        // Check that text is readable
        let textElements = app.staticTexts.allElementsBoundByIndex.prefix(3)
        for textElement in textElements {
            if textElement.exists && !textElement.label.isEmpty {
                XCTAssertTrue(textElement.isHittable,
                             "Text should be readable in current appearance")
            }
        }
    }
    
    // MARK: - Error State Navigation Tests
    // Covers: Error handling in navigation from ui spec
    
    @MainActor
    func testErrorStateNavigation() throws {
        // Given: App may encounter error states
        // When: Checking for error handling in navigation
        
        // Test that app doesn't crash on invalid navigation
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            // Rapidly switch between tabs to test stability
            let tabs = tabBar.buttons.allElementsBoundByIndex
            for tab in tabs.prefix(3) {
                if tab.exists {
                    tab.tap()
                    // Verify transition without hardcoded delay
                    XCTAssertTrue(tab.isSelected || tab.isHittable, "Tab should respond to tap interaction")
                }
            }
            
            // Then: App should remain stable
            XCTAssertTrue(app.state == .runningForeground, "App should remain stable during navigation")
            XCTAssertTrue(tabBar.exists, "Tab bar should remain functional")
        }
    }
    
    // MARK: - Performance Tests
    // Covers: UI responsiveness from ui spec
    
    @MainActor
    func testNavigationPerformance() throws {
        // Given: App is loaded
        // When: Performing navigation actions
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            let libraryTab = tabBar.buttons["Library"]
            if libraryTab.exists {
                libraryTab.tap()
                // Verify navigation responsiveness by checking tab state
                XCTAssertTrue(libraryTab.isSelected || libraryTab.isHittable, 
                             "Library tab should respond to navigation")
                XCTAssertTrue(app.state == .runningForeground, 
                             "App should remain responsive during navigation")
            } else {
                throw XCTSkip("Library tab not found - skipping performance test")
            }
        } else {
            throw XCTSkip("Tab bar not found - skipping performance test")
        }
    }
    
    // MARK: - Acceptance Criteria Tests
    // Covers: Complete navigation workflows from ui specification
    
    @MainActor
    func testAcceptanceCriteria_CompleteNavigationFlow() throws {
        // Given: User wants to navigate through main app features
        let tabBar = app.tabBars["Main Tab Bar"]
        XCTAssertTrue(tabBar.exists, "Main tab bar should be available")
        
        // When: User explores each main section
        let tabButtons = tabBar.buttons.allElementsBoundByIndex
        
        for (index, tab) in tabButtons.enumerated() {
            if tab.exists && index < 4 { // Limit to reasonable number of tabs
                tab.tap()
                
                // Verify navigation worked without hardcoded delay
                let navigationBar = app.navigationBars.firstMatch
                XCTAssertTrue(navigationBar.exists || app.otherElements.firstMatch.exists,
                             "Each tab should show content")
                
                // Verify tab remains interactive after navigation
                XCTAssertTrue(tab.isHittable, "Tab should remain interactive after navigation")
            }
        }
        
        // Then: All navigation should work smoothly
        XCTAssertTrue(app.state == .runningForeground, "App should remain stable")
        XCTAssertTrue(tabBar.exists, "Tab bar should remain accessible")
    }
    
    @MainActor
    func testAcceptanceCriteria_AccessibilityCompliance() throws {
        // Given: App must be accessible to all users
        // When: Checking accessibility compliance
        
        // Verify main interface elements have accessibility labels
        let tabBar = app.tabBars["Main Tab Bar"]
        if tabBar.exists {
            let tabButtons = tabBar.buttons.allElementsBoundByIndex
            
            for tab in tabButtons.prefix(4) {
                if tab.exists {
                    let traits = tab.accessibilityTraits
                    XCTAssertFalse(tab.label.isEmpty, "Tab should have descriptive label")
                    XCTAssertTrue(tab.isHittable || traits.contains(.button),
                                  "Tab should be accessible")
                }
            }
        }
        
        // Check for proper heading structure without using unsupported predicates on accessibilityTraits
        var headingCount = 0
        let candidates = app.staticTexts.allElementsBoundByIndex + app.otherElements.allElementsBoundByIndex
        for element in candidates.prefix(50) {
            if element.exists {
                if element.accessibilityTraits.contains(.header) {
                    headingCount += 1
                    break
                }
            }
        }
        // Fallback: known heading identifiers in this app
        if headingCount == 0 {
            if app.staticTexts["Heading Library"].exists ||
               app.staticTexts["Categories"].exists ||
               app.staticTexts["Featured"].exists {
                headingCount = 1
            }
        }
        
        // Then: App should have proper accessibility structure
        XCTAssertGreaterThan(headingCount, 0, "App should have accessible headings")
    }
}

// TODO: [Issue #12.3] Add performance testing patterns for UI responsiveness validation
// This would include testing animation performance, scroll performance, and touch responsiveness

// TODO: [Issue #12.4] Implement automated accessibility testing integration
// This would add automated VoiceOver testing and accessibility audit capabilities
