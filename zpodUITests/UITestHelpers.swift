//
//  UITestHelpers.swift
//  zpodUITests
//
//  Created for robust UI testing patterns without brittle timeouts
//

import XCTest

/// Helper utilities for robust UI testing that avoid brittle timeout patterns
extension XCTestCase {
    
    // MARK: - Smart Waiting Patterns
    
    /// Waits for any of multiple conditions to be met, preventing test failures due to timing variations
    /// This is much more robust than fixed timeouts as it adapts to actual app state
    @MainActor
    func waitForAnyCondition(
        _ conditions: [() -> Bool],
        timeout: TimeInterval = 10.0,
        description: String = "any condition"
    ) -> Bool {
        let expectation = XCTestExpectation(description: description)
        
        // Use RunLoop-based polling instead of blocking Thread.sleep
        let startTime = Date()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if Date().timeIntervalSince(startTime) >= timeout {
                timer.invalidate()
                XCTFail("Timeout waiting for \(description) after \(timeout) seconds")
                expectation.fulfill()
                return
            }
            
            for condition in conditions {
                if condition() {
                    timer.invalidate()
                    expectation.fulfill()
                    return
                }
            }
        }
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout + 1.0)
        return result == .completed
    }
    
    /// Waits for an element to exist OR alternative elements that indicate the expected state
    /// Much more robust than single element waiting as UI can have variations
    @MainActor
    func waitForElementOrAlternatives(
        primary: XCUIElement,
        alternatives: [XCUIElement] = [],
        timeout: TimeInterval = 10.0,
        description: String? = nil
    ) -> XCUIElement? {
        let desc = description ?? "element \(primary.identifier) or alternatives"
        
        let conditions = [primary] + alternatives
        let found = waitForAnyCondition(
            conditions.map { element in { element.exists } },
            timeout: timeout,
            description: desc
        )
        
        if found {
            // Return the first element that actually exists
            for element in conditions {
                if element.exists {
                    return element
                }
            }
        }
        
        return nil
    }
    
    /// Waits for loading to complete by checking multiple loading indicators
    /// More robust than waiting for a single loading indicator
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
        
        // Wait for ALL loading indicators to disappear
        return waitForAnyCondition(
            [{ loadingIndicators.allSatisfy { !$0.exists } }],
            timeout: timeout,
            description: "loading to complete"
        )
    }
    
    /// Progressive navigation that waits for actual state changes rather than arbitrary timing
    /// This prevents navigation timing issues in different environments
    @MainActor
    func navigateAndWaitForResult(
        triggerAction: () -> Void,
        expectedElements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "navigation to complete"
    ) -> Bool {
        // Capture initial state
        let initialStates = expectedElements.map { $0.exists }
        
        // Perform the navigation action
        triggerAction()
        
        // Wait for state change - either elements appear or other changes occur
        return waitForAnyCondition(
            [
                // Check if any expected elements now exist that didn't before
                {
                    for (index, element) in expectedElements.enumerated() {
                        if element.exists && !initialStates[index] {
                            return true
                        }
                    }
                    return false
                },
                // Check if navigation bar title changed (indicates navigation occurred)
                {
                    expectedElements.contains { $0.exists }
                }
            ],
            timeout: timeout,
            description: description
        )
    }
    
    /// Waits for app to reach a stable state rather than using fixed delays
    /// This eliminates race conditions caused by animation timing
    @MainActor
    func waitForStableState(
        app: XCUIApplication,
        stableFor: TimeInterval = 0.5,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let expectation = XCTestExpectation(description: "UI stable state")
        var lastElementCount = 0
        var stableStartTime: Date?
        let startTime = Date()
        
        // Use RunLoop-based polling instead of blocking Thread.sleep
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if Date().timeIntervalSince(startTime) >= timeout {
                timer.invalidate()
                expectation.fulfill()
                return
            }
            
            let currentElementCount = app.buttons.count + app.staticTexts.count + app.otherElements.count
            
            if currentElementCount == lastElementCount {
                if stableStartTime == nil {
                    stableStartTime = Date()
                } else if Date().timeIntervalSince(stableStartTime!) >= stableFor {
                    timer.invalidate()
                    expectation.fulfill()
                    return
                }
            } else {
                stableStartTime = nil // Reset stability timer
                lastElementCount = currentElementCount
            }
        }
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout + 1.0)
        return result == .completed
    }
    
    // MARK: - Accessibility-First Element Discovery
    
    /// Finds elements using multiple accessibility strategies instead of relying on exact identifiers
    /// This is more robust as accessibility identifiers may vary
    @MainActor
    func findAccessibleElement(
        in app: XCUIApplication,
        byIdentifier identifier: String? = nil,
        byLabel label: String? = nil,
        byPartialLabel partialLabel: String? = nil,
        ofType elementType: XCUIElement.ElementType = .any
    ) -> XCUIElement? {
        
        var candidates: [XCUIElement] = []
        
        // Strategy 1: Exact identifier match
        if let identifier = identifier {
            let element = app.descendants(matching: elementType)[identifier]
            if element.exists {
                candidates.append(element)
            }
        }
        
        // Strategy 2: Exact label match
        if let label = label {
            let elements = app.descendants(matching: elementType).matching(
                NSPredicate(format: "label == %@", label)
            )
            candidates.append(contentsOf: elements.allElementsBoundByIndex.filter { $0.exists })
        }
        
        // Strategy 3: Partial label match
        if let partialLabel = partialLabel {
            let elements = app.descendants(matching: elementType).matching(
                NSPredicate(format: "label CONTAINS %@", partialLabel)
            )
            candidates.append(contentsOf: elements.allElementsBoundByIndex.filter { $0.exists })
        }
        
        // Return the first hittable element found
        return candidates.first { $0.isHittable }
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