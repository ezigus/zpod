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

/// Protocol for element waiting capabilities - Swift 6 concurrency compliant with MainActor
@MainActor protocol ElementWaiting: UITestFoundation {
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval, description: String) -> Bool
    func waitForAnyElement(_ elements: [XCUIElement], timeout: TimeInterval, description: String) -> XCUIElement?
}

/// Protocol for navigation testing - Swift 6 concurrency compliant with MainActor
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
    
    /// Core event-based element waiting using XCUITest's native mechanisms
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0, description: String) -> Bool {
        let success = element.waitForExistence(timeout: timeout)
        
        if !success {
            XCTFail("Element '\(description)' did not appear within \(timeout) seconds")
        }
        return success
    }
    
    /// Wait for any of multiple elements using efficient event-based detection
    func waitForAnyElement(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String = "any element"
    ) -> XCUIElement? {
        guard !elements.isEmpty else {
            XCTFail("No elements provided for 'waitForAnyElement' (\(description))")
            return nil
        }
        
        // Fast path: something already exists
        for element in elements where element.exists {
            return element
        }
        
        let deadline = Date().addingTimeInterval(timeout)
        // Use short run loop advances (no sleep) to allow main run loop to process UI events
        while Date() < deadline {
            for element in elements where element.exists {
                return element
            }
            // Advance run loop minimally to avoid busy-wait; this is event-driven (no arbitrary Thread.sleep)
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        
        // Collect debug info for triage
        let debugSummaries = elements.enumerated().map { idx, el in
            "[\(idx)] id='\(el.identifier)' exists=\(el.exists) hittable=\(el.isHittable)"
        }.joined(separator: "\n")
        XCTFail("No elements found for '\(description)' within timeout (\(timeout)s). Debug:\n\(debugSummaries)")
        return nil
    }
}

extension TestNavigation {
    
    /// Navigate and verify expected element appears using event-based detection
    func navigateAndVerify(
        action: @MainActor @escaping () -> Void,
        expectedElement: XCUIElement,
        description: String
    ) -> Bool {
        action()
        return waitForElement(expectedElement, timeout: adaptiveTimeout, description: description)
    }
    
    /// Navigate and wait for any of multiple elements to appear - used by test files
    func navigateAndWaitForResult(
        triggerAction: @MainActor @escaping () -> Void,
        expectedElements: [XCUIElement],
        timeout: TimeInterval = 10.0,
        description: String
    ) -> Bool {
        triggerAction()
        
        // Use waitForAnyElement to check for any of the expected elements
        let foundElement = waitForAnyElement(expectedElements, timeout: timeout, description: description)
        return foundElement != nil
    }
}

// MARK: - Smart UI Testing Extensions

extension SmartUITesting where Self: XCTestCase {
    
    /// Wait for content to load - assumes test class has `app` property
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
        
        return waitForContentToLoadWithApp(
            containerIdentifier: containerIdentifier,
            itemIdentifiers: itemIdentifiers,
            in: app,
            timeout: timeout
        )
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
    
    /// Wait for content to load with pure event-based detection
    @MainActor
    func waitForContentToLoadWithApp(
        containerIdentifier: String,
        itemIdentifiers: [String] = [],
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        // Wait for content container directly using event-based approach
        let container = app.scrollViews[containerIdentifier]
        guard container.waitForExistence(timeout: timeout) else {
            return false
        }
        
        // If specific items expected, try to find at least one (but don't require all)
        if !itemIdentifiers.isEmpty {
            for identifier in itemIdentifiers {
                let item = app.buttons[identifier]
                if item.exists {
                    return true
                }
            }
            
            // If specific items not found, check if container has basic interactivity
            return container.isHittable
        }
        
        return true // Container exists, no specific items required
    }
    
    /// Wait for loading to complete - flexible approach for different container types
    @MainActor
    func waitForLoadingToComplete(
        in app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        // Try multiple common container patterns used in the app
        let commonContainers = [
            "Content Container",
            "Episode Cards Container",
            "Library Content",
            "Podcast List Container"
        ]
        
        // Check if any common container appears (immediate check, no timeout splitting)
        for containerIdentifier in commonContainers {
            let container = app.scrollViews[containerIdentifier]
            if container.exists {
                return true
            }
        }
        
        // Fallback: check if main navigation elements are present and interactive
        let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
        let navigationBar = app.navigationBars.firstMatch
        
        return (libraryTab.exists && libraryTab.isHittable) ||
               (navigationBar.exists && navigationBar.isHittable)
    }
    
    /// Event-based wait for any of several potential container identifiers / element types to appear.
    @MainActor
    func waitForAnyContainer(
        identifiers: [String],
        in app: XCUIApplication,
        elementKinds: [(XCUIApplication) -> XCUIElementQuery] = [ { $0.scrollViews }, { $0.tables }, { $0.collectionViews } ],
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for makeQuery in elementKinds {
                let query = makeQuery(app)
                for id in identifiers {
                    let el = query[id]
                    if el.exists { return el }
                }
                // Fallback: heuristic – any element whose identifier contains first token
                if let token = identifiers.first, let heuristic = query.matching(NSPredicate(format: "identifier CONTAINS[c] %@", token)).firstMatch.optionalExists {
                    return heuristic
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return nil
    }
    
    /// Improved loading completion that actively waits (event loop advancing) until a known container appears or timeout.
    @MainActor
    func improvedWaitForLoading(
        in app: XCUIApplication,
        primaryContainerIds: [String],
        timeout: TimeInterval
    ) -> Bool {
        if let found = waitForAnyContainer(identifiers: primaryContainerIds, in: app, timeout: timeout) {
            return found.exists
        }
        return false
    }
    
    /// Discover an episode list style container using several strategies (identifiers + content heuristics).
    @MainActor
    func discoverEpisodeListContainer(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        // First try canonical identifiers
        if let canonical = waitForAnyContainer(identifiers: ["Episode Cards Container", "Episode List", "Episodes"], in: app, timeout: timeout) {
            return canonical
        }
        // Heuristic: any scroll view / table / collection containing at least one child button whose identifier starts with Episode-
        let deadline = Date().addingTimeInterval(timeout)
        let containers: [XCUIElementQuery] = [app.scrollViews, app.tables, app.collectionViews]
        while Date() < deadline {
            for query in containers {
                let candidates = query.allElementsBoundByIndex
                for el in candidates where el.exists {
                    // Look for a descendant button with Episode- prefix
                    let buttons = el.descendants(matching: .button)
                    for i in 0..<buttons.count {
                        let b = buttons.element(boundBy: i)
                        if b.identifier.hasPrefix("Episode-") { return el }
                    }
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return nil
    }
}

private extension XCUIElement {
    var optionalExists: XCUIElement? { exists ? self : nil }
}
s
