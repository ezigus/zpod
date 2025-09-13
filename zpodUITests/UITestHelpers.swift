//
//  UITestHelpers.swift
//  zpodUITests
//
//  Protocol-driven event-based UI testing architecture with Swift 6 concurrency compliance
//

import XCTest

// MARK: - Core Testing Protocols

/// Foundation protocol for event-based UI testing
protocol UITestFoundation {
    var adaptiveTimeout: TimeInterval { get }
    var adaptiveShortTimeout: TimeInterval { get }
}

/// Protocol for element waiting capabilities - Swift 6 concurrency compliant
protocol ElementWaiting: UITestFoundation {
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval, description: String) -> Bool
    func waitForAnyElement(_ elements: [XCUIElement], timeout: TimeInterval, description: String) -> XCUIElement?
}

/// Protocol for navigation testing - Swift 6 concurrency compliant
protocol TestNavigation: UITestFoundation {
    func navigateAndVerify(action: () -> Void, expectedElement: XCUIElement, description: String) -> Bool
}

/// Composite protocol for smart UI testing - this is what test classes should conform to
protocol SmartUITesting: UITestFoundation, ElementWaiting, TestNavigation {}

// MARK: - Default Implementation

extension UITestFoundation {
    var adaptiveTimeout: TimeInterval {
        ProcessInfo.processInfo.environment["CI"] != nil ? 20.0 : 10.0
    }
    
    var adaptiveShortTimeout: TimeInterval {
        ProcessInfo.processInfo.environment["CI"] != nil ? 10.0 : 5.0
    }
}

extension ElementWaiting {
    
    /// Core event-based element waiting using XCUITest's native mechanisms
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0, description: String) -> Bool {
        let success: Bool
        if Thread.isMainThread {
            success = element.waitForExistence(timeout: timeout)
        } else {
            success = DispatchQueue.main.sync {
                element.waitForExistence(timeout: timeout)
            }
        }
        
        if !success {
            XCTFail("Element '\(description)' did not appear within \(timeout) seconds")
        }
        return success
    }
    
    /// Wait for any of multiple elements using native XCUITest event detection
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element"
    ) -> XCUIElement? {
        
        let checkAndWait: () -> XCUIElement? = {
            // Quick check for existing elements
            for element in elements {
                if element.exists {
                    return element
                }
            }
            
            // Use XCUITest's native waiting - simple and effective
            for element in elements {
                if element.waitForExistence(timeout: timeout) {
                    return element
                }
            }
            return nil
        }
        
        let result: XCUIElement?
        if Thread.isMainThread {
            result = checkAndWait()
        } else {
            result = DispatchQueue.main.sync(execute: checkAndWait)
        }
        
        if result == nil {
            XCTFail("No elements found for '\(description)' within \(timeout) seconds")
        }
        return result
    }
}

extension TestNavigation {
    
    /// Navigate and verify expected element appears using event-based detection
    func navigateAndVerify(
        action: () -> Void,
        expectedElement: XCUIElement, 
        description: String
    ) -> Bool {
        if Thread.isMainThread {
            action()
            return waitForElement(expectedElement, timeout: adaptiveTimeout, description: description)
        } else {
            return DispatchQueue.main.sync {
                action()
                return waitForElement(expectedElement, timeout: adaptiveTimeout, description: description)
            }
        }
    }
}

// MARK: - Utility Extensions for Common Patterns

extension XCTestCase {
    
    /// Find element by multiple strategies - event-based discovery
    @MainActor
    func findAccessibleElement(
        in app: XCUIApplication,
        byIdentifier identifier: String? = nil,
        byLabel label: String? = nil,
        byPartialLabel partialLabel: String? = nil,
        ofType elementType: XCUIElement.ElementType = .any
    ) -> XCUIElement? {
        
        // Try identifier first
        if let identifier = identifier {
            let element = app.descendants(matching: elementType)[identifier]
            if element.exists { return element }
        }
        
        // Try label
        if let label = label {
            let element = app.descendants(matching: elementType)[label]
            if element.exists { return element }
        }
        
        // Try partial label matching
        if let partialLabel = partialLabel {
            let elements = app.descendants(matching: elementType)
            for i in 0..<elements.count {
                let element = elements.element(boundBy: i)
                if element.label.contains(partialLabel) && element.exists {
                    return element
                }
            }
        }
        
        return nil
    }
    
    /// Wait for content to load with event-based detection
    @MainActor
    func waitForContentToLoad(
        containerIdentifier: String,
        itemIdentifiers: [String] = [],
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        
        // First wait for loading indicators to disappear
        let loadingIndicators = [
            app.otherElements["Loading View"],
            app.activityIndicators.firstMatch,
            app.staticTexts["Loading..."]
        ]
        
        // Wait for loading to complete (indicators to disappear)
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            let anyLoading = loadingIndicators.contains { $0.exists }
            if !anyLoading { break }
            Thread.sleep(forTimeInterval: 0.1) // Brief check interval
        }
        
        // Then wait for content container
        let container = app.scrollViews[containerIdentifier]
        guard container.waitForExistence(timeout: timeout) else {
            return false
        }
        
        // If specific items expected, wait for at least one
        if !itemIdentifiers.isEmpty {
            for identifier in itemIdentifiers {
                let item = app.buttons[identifier]
                if item.waitForExistence(timeout: timeout) {
                    return true
                }
            }
            return false
        }
        
        return true
    }
    
    /// Wait for stable UI state - ensures animations complete
    @MainActor
    func waitForStableState(
        app: XCUIApplication,
        stableFor: TimeInterval = 0.5,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let stabilityCheck = Date()
        
        // Give a brief moment for UI to stabilize
        Thread.sleep(forTimeInterval: stableFor)
        
        return Date().timeIntervalSince(stabilityCheck) >= stableFor
    }
    
    /// Wait for loading to complete - alias for waitForContentToLoad without container
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        return waitForContentToLoad(
            containerIdentifier: "Content Container",
            in: app,
            timeout: timeout
        )
    }
}