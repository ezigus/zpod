//
//  UITestHelpers.swift
//  zpodUITests
//
//  Event-driven UI testing architecture using XCTestExpectation patterns
//  No artificial wait states - relies on natural system events
//

import XCTest

// MARK: - Core Testing Protocols

/// Foundation protocol for event-based UI testing
protocol UITestFoundation {
    var adaptiveTimeout: TimeInterval { get }
    var adaptiveShortTimeout: TimeInterval { get }
}

/// Protocol for element waiting capabilities using XCTestExpectation patterns
@MainActor protocol ElementWaiting: UITestFoundation {
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval, description: String) -> Bool
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval,
        description: String,
        failOnTimeout: Bool
    ) -> XCUIElement?
}

/// Protocol for navigation testing using event-driven patterns
@MainActor protocol TestNavigation: ElementWaiting {
    func navigateAndVerify(action: @MainActor @escaping () -> Void, expectedElement: XCUIElement, description: String) -> Bool
}

/// Composite protocol for smart UI testing - this is what test classes should conform to
@MainActor protocol SmartUITesting: TestNavigation {}

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
    
    /// Core event-based element waiting using XCUITest's native event detection
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0, description: String) -> Bool {
        // Use XCUITest's native event-based waiting - no artificial timeouts
        let success = element.waitForExistence(timeout: timeout)
        
        if !success {
            XCTFail("Element '\(description)' did not appear within \(timeout) seconds")
        }
        return success
    }
    
    /// Wait for any element using XCTestExpectation pattern
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element",
        failOnTimeout: Bool = true
    ) -> XCUIElement? {
        guard !elements.isEmpty else {
            XCTFail("No elements provided for 'waitForAnyElement' (\(description))")
            return nil
        }
        
        // Fast path: something already exists
        for element in elements where element.exists {
            return element
        }
        
        // Use XCTestExpectation for proper event-driven waiting
        let expectation = XCTestExpectation(description: "Wait for \(description)")
        var foundElement: XCUIElement?
        
        func checkElements() {
            for element in elements where element.exists {
                foundElement = element
                expectation.fulfill()
                return
            }
            
            // Schedule next check using run loop - no Thread.sleep
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                checkElements()
            }
        }
        
        checkElements()
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        
        if result != .completed {
            if failOnTimeout {
                let debugSummaries = elements.enumerated().map { idx, el in
                    "[\(idx)] id='\(el.identifier)' exists=\(el.exists) hittable=\(el.isHittable)"
                }.joined(separator: "\n")
                XCTFail("No elements found for '\(description)' within timeout (\(timeout)s). Debug:\n\(debugSummaries)")
            }
        }

        return foundElement
    }
}

extension TestNavigation {
    
    /// Navigate and verify using pure event detection
    func navigateAndVerify(
        action: @MainActor @escaping () -> Void,
        expectedElement: XCUIElement,
        description: String
    ) -> Bool {
        action()
        return waitForElement(expectedElement, timeout: adaptiveTimeout, description: description)
    }
    
    /// Navigate and wait for result using XCTestExpectation pattern
    func navigateAndWaitForResult(
        triggerAction: @MainActor @escaping () -> Void,
        expectedElements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String
    ) -> Bool {
        triggerAction()
        
        let foundElement = waitForAnyElement(expectedElements, timeout: timeout, description: description)
        return foundElement != nil
    }
}

// MARK: - Utility Extensions Using Event-Driven Patterns

extension XCTestCase {
    
    /// Find element using immediate detection - no artificial waiting
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
    
    /// Resolve a container element by accessibility identifier independent of backing UIKit type.
    /// The episode list now renders as a `UITableView` on iPhone; legacy tests expected a scroll view.
    /// This helper keeps identifiers stable while the implementation evolves.
    @MainActor
    func findContainerElement(
        in app: XCUIApplication,
        identifier: String
    ) -> XCUIElement? {
        let orderedQueries: [XCUIElementQuery] = [
            app.scrollViews,
            app.tables,
            app.collectionViews,
            app.otherElements,
            app.cells,
            app.staticTexts
        ]

        for query in orderedQueries {
            let element = query[identifier]
            if element.exists {
                return element
            }
        }

        let anyMatch = app.descendants(matching: .any)[identifier]
        return anyMatch.exists ? anyMatch : nil
    }
    
    /// Wait for loading completion using XCTestExpectation pattern
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        // Common containers to check for
        let commonContainers = [
            "Content Container",
            "Episode Cards Container",
            "Library Content",
            "Podcast List Container"
        ]
        
        // Use XCTestExpectation for event-driven waiting
        let expectation = XCTestExpectation(description: "App loading completes")
        
        func checkForLoading() {
            // Check if any common container appears
            for containerIdentifier in commonContainers {
                if let container = findContainerElement(in: app, identifier: containerIdentifier),
                   container.exists {
                    expectation.fulfill()
                    return
                }
            }
            
            // Fallback: check if main navigation elements are present
            let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
            let navigationBar = app.navigationBars.firstMatch
            
            if (libraryTab.exists && libraryTab.isHittable) ||
               (navigationBar.exists && navigationBar.isHittable) {
                expectation.fulfill()
                return
            }
            
            // Schedule next check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                checkForLoading()
            }
        }
        
        checkForLoading()
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}

// MARK: - Smart UI Testing Extensions

extension SmartUITesting where Self: XCTestCase {
    
    /// Wait for content using XCTestExpectation pattern
    @MainActor
    func waitForContentToLoad(
        containerIdentifier: String,
        itemIdentifiers: [String] = [],
        timeout: TimeInterval = 10.0
    ) -> Bool {
        guard let app = self.value(forKey: "app") as? XCUIApplication else {
            XCTFail("Test class must have an 'app' property of type XCUIApplication")
            return false
        }
        
        // Use XCTestExpectation for event-driven content waiting
        let expectation = XCTestExpectation(description: "Content container '\(containerIdentifier)' appears")
        
        func checkForContent() {
            if let container = findContainerElement(in: app, identifier: containerIdentifier),
               container.exists && container.isHittable {
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    checkForContent()
                }
            }
        }
        
        checkForContent()
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Wait for loading completion using XCTestExpectation pattern
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        // Common containers to check for
        let commonContainers = [
            "Content Container",
            "Episode Cards Container",
            "Library Content",
            "Podcast List Container"
        ]
        
        // Use XCTestExpectation for event-driven waiting
        let expectation = XCTestExpectation(description: "App loading completes")
        
        func checkForLoading() {
            // Check if any common container appears
            for containerIdentifier in commonContainers {
                if let container = findContainerElement(in: app, identifier: containerIdentifier),
                   container.exists {
                    expectation.fulfill()
                    return
                }
            }
            
            // Fallback: check if main navigation elements are present
            let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
            let navigationBar = app.navigationBars.firstMatch
            
            if (libraryTab.exists && libraryTab.isHittable) ||
               (navigationBar.exists && navigationBar.isHittable) {
                expectation.fulfill()
                return
            }
            
            // Schedule next check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                checkForLoading()
            }
        }
        
        checkForLoading()
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
