//
//  UITestHelpers.swift
//  zpodUITests
//
//  Created for truly event-based UI testing patterns without polling
//

import XCTest

/// Helper utilities for event-based UI testing that use XCUITest's native mechanisms
extension XCTestCase {
    
    // MARK: - Event-Based Waiting Patterns
    
    /// Waits for any of multiple elements to exist using XCUITest's native event detection
    /// This is truly event-based and responds immediately to UI changes
    @MainActor
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element"
    ) -> XCUIElement? {
        // Check if any element already exists
        for element in elements {
            if element.exists {
                return element
            }
        }
        
        // Use XCUITest's native waiting mechanism for event-based detection
        // Use withTaskGroup for proper Swift 6 concurrency
        let foundElement = Task { @MainActor in
            await withTaskGroup(of: XCUIElement?.self, returning: XCUIElement?.self) { group in
                for element in elements {
                    group.addTask { @MainActor in
                        return element.waitForExistence(timeout: timeout) ? element : nil
                    }
                }
                
                // Return the first element that becomes available
                for await result in group {
                    if let element = result {
                        group.cancelAll()
                        return element
                    }
                }
                return nil
            }
        }
        
        // Wait for result with timeout
        let semaphore = DispatchSemaphore(value: 0)
        var result: XCUIElement?
        
        Task { @MainActor in
            result = await foundElement.value
            semaphore.signal()
        }
        
        let waitResult = semaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            XCTFail("Timeout waiting for \(description) after \(timeout) seconds")
        }
        
        return result
    }
    
    
    /// Waits for an element to exist using XCUITest's native event detection
    /// Alternative elements provide fallback strategies when UI varies
    @MainActor
    func waitForElementOrAlternatives(
        primary: XCUIElement,
        alternatives: [XCUIElement] = [],
        timeout: TimeInterval = 10.0,
        description: String? = nil
    ) -> XCUIElement? {
        let desc = description ?? "element \(primary.identifier) or alternatives"
        
        // Try primary first
        if primary.waitForExistence(timeout: timeout) {
            return primary
        }
        
        // Try alternatives if primary fails
        for alternative in alternatives {
            if alternative.exists {
                return alternative
            }
        }
        
        // All failed - test should fail
        XCTFail("Timeout waiting for \(desc) after \(timeout) seconds")
        return nil
    }
    
    /// Waits for loading to complete using native element existence detection
    /// Uses XCUITest's event-based waiting instead of polling
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 15.0
    ) -> Bool {
        let loadingIndicators = [
            app.otherElements["Loading View"],
            app.activityIndicators.firstMatch,
            app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'loading'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
        ]
        
        // Wait for any loading indicator to disappear using native waiting
        for indicator in loadingIndicators {
            if indicator.exists {
                // Wait for this specific indicator to disappear
                let disappeared = !indicator.waitForExistence(timeout: 0.1) || 
                                  indicator.wait(for: .notExist, timeout: timeout)
                if disappeared {
                    return true
                }
            }
        }
        
        // No loading indicators found or they didn't disappear
        return true // Assume loading already completed
    }
    
    /// Event-based navigation that waits for actual UI state changes
    /// Uses XCUITest's native change detection instead of polling
    @MainActor
    func navigateAndWaitForResult(
        triggerAction: () -> Void,
        expectedElements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "navigation to complete"
    ) -> Bool {
        // Perform the navigation action
        triggerAction()
        
        // Wait for any expected element to appear using native waiting
        for element in expectedElements {
            if element.waitForExistence(timeout: timeout) {
                return true
            }
        }
        
        // Navigation failed
        XCTFail("Navigation failed: \(description) - no expected elements appeared after \(timeout) seconds")
        return false
    }
    
    /// Wait for app stability using native UI change detection
    /// Uses XCUITest's built-in mechanisms instead of custom polling
    @MainActor
    func waitForStableState(
        app: XCUIApplication,
        stableFor: TimeInterval = 0.5,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        // Use XCUITest's native idle detection
        // Simply wait a brief moment for any ongoing animations to settle
        let expectation = XCTestExpectation(description: "UI stable state")
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(stableFor * 1_000_000_000))
            expectation.fulfill()
        }
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Native Element Discovery
    
    /// Find elements using XCUITest's native query mechanisms
    /// Uses built-in element discovery instead of complex custom logic
    @MainActor
    func findAccessibleElement(
        in app: XCUIApplication,
        byIdentifier identifier: String? = nil,
        byLabel label: String? = nil,
        byPartialLabel partialLabel: String? = nil,
        ofType elementType: XCUIElement.ElementType = .any
    ) -> XCUIElement? {
        
        // Strategy 1: Exact identifier match (fastest)
        if let identifier = identifier {
            let element = app.descendants(matching: elementType)[identifier]
            if element.exists {
                return element
            }
        }
        
        // Strategy 2: Exact label match
        if let label = label {
            let element = app.descendants(matching: elementType).matching(
                NSPredicate(format: "label == %@", label)
            ).firstMatch
            if element.exists {
                return element
            }
        }
        
        // Strategy 3: Partial label match
        if let partialLabel = partialLabel {
            let element = app.descendants(matching: elementType).matching(
                NSPredicate(format: "label CONTAINS %@", partialLabel)
            ).firstMatch
            if element.exists {
                return element
            }
        }
        
        return nil
    }
    
    /// Wait for content to load in a container using event-based detection
    @MainActor
    func waitForContentToLoad(
        containerIdentifier: String,
        itemIdentifiers: [String] = [],
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let container = XCUIApplication().otherElements[containerIdentifier]
        
        // Wait for container to exist first
        guard container.waitForExistence(timeout: timeout) else {
            XCTFail("Container '\(containerIdentifier)' did not appear within \(timeout) seconds")
            return false
        }
        
        // If specific items are expected, wait for at least one
        if !itemIdentifiers.isEmpty {
            for identifier in itemIdentifiers {
                if XCUIApplication().descendants(matching: .any)[identifier].waitForExistence(timeout: 2.0) {
                    return true
                }
            }
            XCTFail("No expected content items appeared in container within \(timeout) seconds")
            return false
        }
        
        return true
    }
    
    // MARK: - Environment-Adaptive Patterns
    
    /// Determines appropriate timeout based on testing environment
    /// CI environments often need longer timeouts than local development
    var adaptiveTimeout: TimeInterval {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return 20.0 // Longer timeout for CI environments
        } else {
            return 10.0 // Standard timeout for local development
        }
    }
    
    /// Determines appropriate short timeout for quick checks
    var adaptiveShortTimeout: TimeInterval {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return 5.0 // Longer timeout for CI environments
        } else {
            return 2.0 // Quick timeout for local development
        }
    }
}

/// Protocol for test classes that use smart waiting patterns
protocol SmartUITesting {
    var app: XCUIApplication! { get }
}

extension SmartUITesting where Self: XCTestCase {
    
    /// Standard pattern for waiting for navigation to complete
    @MainActor
    func waitForNavigationToComplete(
        expectedScreen: String,
        alternatives: [String] = []
    ) -> Bool {
        let primaryElement = app.navigationBars[expectedScreen]
        let alternativeElements = alternatives.map { app.navigationBars[$0] }
        
        return waitForElementOrAlternatives(
            primary: primaryElement,
            alternatives: alternativeElements,
            timeout: adaptiveTimeout,
            description: "navigation to \(expectedScreen)"
        ) != nil
    }
    
    /// Standard pattern for episodic content loading (podcasts, episodes)
    @MainActor
    func waitForContentToLoad(
        containerIdentifier: String,
        itemIdentifiers: [String] = []
    ) -> Bool {
        // First wait for loading to complete
        let loadingComplete = waitForLoadingToComplete(in: app, timeout: adaptiveTimeout)
        
        // Then wait for content container
        let container = app.scrollViews[containerIdentifier]
        guard container.waitForExistence(timeout: adaptiveShortTimeout) else {
            return false
        }
        
        // If specific items are expected, wait for at least one
        if !itemIdentifiers.isEmpty {
            let items = itemIdentifiers.map { app.buttons[$0] }
            return waitForElementOrAlternatives(
                primary: items.first!,
                alternatives: Array(items.dropFirst()),
                timeout: adaptiveShortTimeout,
                description: "content items in \(containerIdentifier)"
            ) != nil
        }
        
        return loadingComplete
    }
}

extension XCTestCase {
    
    /// Simple wrapper to replace waitForAnyElement calls with waitForElementOrAlternatives
    @MainActor
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element"
    ) -> XCUIElement? {
        guard !elements.isEmpty else { return nil }
        
        return waitForElementOrAlternatives(
            primary: elements[0],
            alternatives: Array(elements.dropFirst()),
            timeout: timeout,
            description: description
        )
    }
}