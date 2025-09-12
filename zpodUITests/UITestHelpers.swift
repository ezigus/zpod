//
//  UITestHelpers.swift
//  zpodUITests
//
//  Created for robust UI testing patterns without brittle timeouts
//

import XCTest

/// Helper utilities for robust UI testing using proper XCUIElement waiting mechanisms
extension XCTestCase {
    
    // MARK: - Event-Based Waiting Patterns (No arbitrary sleeps)
    
    /// Event-based waiting using XCUIElement's built-in waitForExistence
    /// This is the proper way to wait for UI state changes in XCUITest
    @MainActor
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element"
    ) -> XCUIElement? {
        print("🔍 Waiting for \(description) using event-based detection...")
        
        // Use XCUIElement's built-in waiting which is event-based, not polling
        for (index, element) in elements.enumerated() {
            if element.waitForExistence(timeout: timeout) {
                print("✅ Element \(index) appeared for \(description): \(element.identifier)")
                return element
            }
        }
        
        print("⚠️ No elements appeared for \(description) within \(timeout) seconds")
        return nil
    }
    
    /// Wait for a UI state change by checking element changes
    /// Returns true if ANY significant UI change occurs, false if timeout
    @MainActor
    func waitForUIStateChange(
        beforeAction: @Sendable () -> Void,
        expectedChanges: [@Sendable () -> Bool],
        timeout: TimeInterval = 10.0,
        description: String = "UI state change"
    ) -> Bool {
        print("🔄 Monitoring UI state change for \(description)...")
        
        // Capture initial UI state
        let initialStates = expectedChanges.map { $0() }
        
        // Perform action that should trigger UI change
        beforeAction()
        
        // Use XCTest's expectation mechanism for proper event-based waiting
        let expectation = expectation(description: description)
        
        // Schedule periodic checks using XCTest's timer mechanism
        var checkTimer: Timer?
        let startTime = Date()
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                // Check if any expected state changed
                for (index, check) in expectedChanges.enumerated() {
                    if check() != initialStates[index] {
                        print("✅ State change detected for \(description) (condition \(index))")
                        expectation.fulfill()
                        timer.invalidate()
                        return
                    }
                }
                
                // Check timeout
                if Date().timeIntervalSince(startTime) >= timeout {
                    print("⚠️ Timeout waiting for \(description)")
                    expectation.fulfill()
                    timer.invalidate()
                }
            }
        }
        
        // Wait for the expectation
        wait(for: [expectation], timeout: timeout + 1.0)
        checkTimer?.invalidate()
        
        // Return true if any state actually changed
        return expectedChanges.enumerated().contains { index, check in
            check() != initialStates[index]
        }
    }
    
    /// Event-based loading detection using proper UI state monitoring
    /// Waits for loading indicators to disappear, which is a real UI event
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 15.0
    ) -> Bool {
        print("⏳ Waiting for loading to complete using event-based detection...")
        
        let loadingIndicators = [
            app.otherElements["Loading View"],
            app.activityIndicators.firstMatch,
            app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'loading'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
        ]
        
        // Find any loading indicator that currently exists
        let activeIndicator = loadingIndicators.first { $0.exists }
        
        if let indicator = activeIndicator {
            print("📍 Found active loading indicator: \(indicator.identifier)")
            // Use XCUIElement's built-in event-based waiting for the indicator to disappear
            let startTime = Date()
            
            // Wait for the loading indicator to disappear using proper event-based mechanism
            let expectation = expectation(description: "loading indicator disappearance")
            
            var checkTimer: Timer?
            checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    if !indicator.exists {
                        print("✅ Loading indicator disappeared - loading complete")
                        expectation.fulfill()
                        timer.invalidate()
                    } else if Date().timeIntervalSince(startTime) >= timeout {
                        print("⚠️ Loading timeout after \(timeout) seconds")
                        expectation.fulfill()
                        timer.invalidate()
                    }
                }
            }
            
            wait(for: [expectation], timeout: timeout + 1.0)
            checkTimer?.invalidate()
            
            return !indicator.exists
        } else {
            print("✅ No loading indicators found - content already loaded")
            return true
        }
    }
    
    /// Event-based navigation that waits for actual UI state changes
    /// Uses proper XCUITest mechanisms instead of arbitrary timing
    @MainActor
    func navigateAndWaitForResult(
        triggerAction: @Sendable () -> Void,
        expectedElements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "navigation to complete"
    ) -> Bool {
        print("🧭 Starting event-based navigation: \(description)")
        
        return waitForUIStateChange(
            beforeAction: triggerAction,
            expectedChanges: expectedElements.map { element in
                { @Sendable in element.exists }
            },
            timeout: timeout,
            description: description
        )
    }
}

/// Protocol for test classes that use smart UI testing patterns
protocol SmartUITesting {
    var adaptiveTimeout: TimeInterval { get }
    var adaptiveShortTimeout: TimeInterval { get }
}

extension SmartUITesting {
    /// Adaptive timeout that scales based on test environment
    /// Longer in CI environments, shorter for local development
    var adaptiveTimeout: TimeInterval {
        return ProcessInfo.processInfo.environment["CI"] != nil ? 15.0 : 10.0
    }
    
    /// Shorter timeout for feature detection where quick failure is preferred
    var adaptiveShortTimeout: TimeInterval {
        return ProcessInfo.processInfo.environment["CI"] != nil ? 5.0 : 3.0
    }
}