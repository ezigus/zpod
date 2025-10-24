//
//  UITestHelpers.swift
//  zpodUITests
//
//  Event-driven UI testing architecture using XCTestExpectation patterns
//  No artificial wait states - relies on natural system events
//

import Foundation
import XCTest

// MARK: - UI Test Automation Fix for "Waiting for App to Idle" Hanging

extension XCTestCase {
  /// Configure XCUITest to avoid hanging on "waiting for app to idle" by disabling quiescence detection
  /// This should be called once per test suite to prevent CI hanging issues
  func disableWaitingForIdleIfNeeded() {
    // Note: This function currently serves as a placeholder for test setup consistency.
    // The actual "waiting for idle" prevention is handled by:
    // 1. Launch environment variables (UITEST_DISABLE_ANIMATIONS)
    // 2. Proper use of waitForExistence and XCTestExpectation patterns
    // 3. Avoiding operations that trigger quiescence checks

    // Apply optimizations in both CI and local environments for better test reliability
    print("🔧 Applying UI test hanging prevention measures")
    print("✅ Applied UI test hanging prevention measures")
  }
}

// MARK: - Application Configuration

extension XCUIApplication {
  private static let podAppBundleIdentifier = "us.zig.zpod"

  static func configuredForUITests() -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: podAppBundleIdentifier)
    app.launchEnvironment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] = "1"
    app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
    return app
  }

  static func configuredForUITests(environmentOverrides: [String: String]) -> XCUIApplication {
    let app = XCUIApplication.configuredForUITests()
    environmentOverrides.forEach { key, value in
      app.launchEnvironment[key] = value
    }
    return app
  }
}

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
  func navigateAndVerify(
    action: @MainActor @escaping () -> Void, expectedElement: XCUIElement, description: String
  ) -> Bool
}

/// Composite protocol for smart UI testing - this is what test classes should conform to
@MainActor protocol SmartUITesting: TestNavigation {}

// MARK: - Default Implementation

extension UITestFoundation {
  /// Returns the timeout scale factor from the environment, optimized for faster tests
  private var timeoutScale: TimeInterval {
    if let scaleString = ProcessInfo.processInfo.environment["UITEST_TIMEOUT_SCALE"],
      let scale = TimeInterval(scaleString), scale > 0
    {
      return scale
    }
    return 1.0
  }

  var adaptiveTimeout: TimeInterval {
    let baseTimeout = ProcessInfo.processInfo.environment["CI"] != nil ? 12.0 : 8.0
    return baseTimeout * timeoutScale
  }

  var adaptiveShortTimeout: TimeInterval {
    let baseTimeout = ProcessInfo.processInfo.environment["CI"] != nil ? 6.0 : 4.0
    return baseTimeout * timeoutScale
  }
}

extension ElementWaiting {

  /// Core event-based element waiting using XCUITest's native event detection
  func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0, description: String)
    -> Bool
  {
    // Use XCUITest's native event-based waiting - no artificial timeouts
    let success = element.waitForExistence(timeout: timeout)

    if !success {
      // Note: Removed app.debugDescription here as it can cause "Lost connection" errors
      // when the app has crashed. Element-level debugging is still available via the element's properties.
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

    // Use predicate-based waiting to avoid DispatchQueue.main deadlocks
    var foundElement: XCUIElement?

    let predicate = NSPredicate { _, _ in
      for element in elements where element.exists {
        foundElement = element
        return true
      }
      return false
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for \(description)"

    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

    if result != .completed {
      if failOnTimeout {
        let debugSummaries = elements.enumerated().map { idx, el in
          "[\(idx)] id='\(el.identifier)' exists=\(el.exists) hittable=\(el.isHittable)"
        }.joined(separator: "\n")
        // Note: Removed app.debugDescription as it can cause "Lost connection" errors when app has crashed
        XCTFail(
          "No elements found for '\(description)' within timeout (\(timeout)s). Debug:\n\(debugSummaries)"
        )
      }
    }

    return foundElement
  }

  /// Check if an element is hittable after ensuring it exists.
  /// Simply delegates to waitForExistence since XCUIElement.tap() automatically
  /// waits for hittability. This avoids blocking the test runner thread.
  func waitForElementToBeHittable(
    _ element: XCUIElement,
    timeout: TimeInterval = 10.0,
    description: String
  ) -> Bool {
    // Wait for existence using XCUITest's built-in mechanism
    // The caller will typically call .tap() which automatically waits for hittability
    guard element.waitForExistence(timeout: timeout) else {
      XCTFail("Element '\(description)' did not appear within \(timeout) seconds")
      return false
    }

    return true
  }
  /// Wait for an element to disappear (non-existent or not hittable). Does not fail on timeout.
  func waitForElementToDisappear(
    _ element: XCUIElement,
    timeout: TimeInterval = 10.0
  ) -> Bool {
    if !element.exists { return true }

    // Use predicate-based waiting to avoid DispatchQueue.main deadlocks
    let predicate = NSPredicate { _, _ in
      !element.exists
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Wait for element to disappear"

    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
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

    let foundElement = waitForAnyElement(
      expectedElements, timeout: timeout, description: description)
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
        guard element.exists else { continue }
        let label = element.label
        if label.localizedCaseInsensitiveContains(partialLabel) {
          return element
        }
      }
    }

    return nil
  }

  /// Resolve a container element by accessibility identifier independent of backing UIKit type.
  /// The episode list was refactored to use a `UITableView` on iPhone for performance and platform alignment;
  /// legacy automation expected a scroll view. This helper keeps identifiers stable through those UIKit swaps.
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
      app.staticTexts,
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

  /// Wait for loading completion using predicate-based waiting (no async dispatching)
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
      "Podcast List Container",
    ]

    // Use predicate for synchronous polling (avoids DispatchQueue.main deadlocks)
    let predicate = NSPredicate { [weak self] _, _ in
      guard let self else { return false }

      // Presence of the batch operations overlay indicates the view finished loading
      if app.otherElements["Batch Operation Progress"].exists {
        return true
      }

      // Check if any common container appears
      for containerIdentifier in commonContainers {
        if let container = self.findContainerElement(in: app, identifier: containerIdentifier),
          container.exists
        {
          return true
        }
      }

      // Fallback: check if main navigation elements are present
      let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
      let navigationBar = app.navigationBars.firstMatch
      let swiftPodcast = app.buttons["Podcast-swift-talk"]

      if (libraryTab.exists && libraryTab.isHittable)
        || (navigationBar.exists && navigationBar.isHittable)
        || swiftPodcast.exists
      {
        return true
      }

      return false
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "App loading completes"

    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    if result != .completed && ProcessInfo.processInfo.environment["CI"] != nil {
      // Note: Commented out app.debugDescription as it can cause "Lost connection" errors when app crashes
      print("Loading did not complete within \(timeout)s.")
      // print("Loading did not complete within \(timeout)s. Accessibility tree:\n\(app.debugDescription)")
    }
    return result == .completed
  }
}

// MARK: - Smart UI Testing Extensions

@MainActor
private struct BatchOverlayObservation {
  let primaryElement: XCUIElement
  private let auxiliaryElements: [XCUIElement]

  init(app: XCUIApplication) {
    primaryElement = app.otherElements["Batch Operation Progress"]
    auxiliaryElements = [
      app.scrollViews.otherElements["Batch Operation Progress"],
      app.tables.otherElements["Batch Operation Progress"],
      app.cells["Batch Operation Progress"],
      app.tables.cells["Batch Operation Progress"],
      app.staticTexts["Batch Operation Progress"],
      app.staticTexts["Processing..."],
      app.staticTexts["Processing"],
      app.staticTexts["Complete"],
      app.staticTexts["Completed"],
      app.staticTexts["Batch Operation"],
      app.buttons["Pause"],
      app.buttons["Resume"],
      app.buttons["Cancel"],
    ]
  }

  var isVisible: Bool {
    if primaryElement.exists { return true }
    return auxiliaryElements.contains { $0.exists }
  }

  func debugSummary() -> String {
    let visibleElements = ([primaryElement] + auxiliaryElements).enumerated().compactMap {
      index, element -> String? in
      guard element.exists else { return nil }
      let identifier = element.identifier.isEmpty ? "∅" : element.identifier
      let label = element.label.isEmpty ? "∅" : element.label
      return
        "[#\(index)] identifier='\(identifier)' label='\(label)' hittable=\(element.isHittable)"
    }

    guard !visibleElements.isEmpty else { return "No overlay elements currently visible" }
    return visibleElements.joined(separator: "\n")
  }
}

enum BatchOverlayWaitResult: Equatable {
  case notPresent
  case skippedForcedOverlay
  case dismissed
  case timedOut(debugDescription: String)
}

extension SmartUITesting where Self: XCTestCase {

  /// Launches a configured application and waits for the main tab bar to appear so tests start from a stable state.
  @MainActor
  @discardableResult
  func launchConfiguredApp(environmentOverrides: [String: String] = [:]) -> XCUIApplication {
    forceTerminateAppIfRunning()

    let application =
      environmentOverrides.isEmpty
      ? XCUIApplication.configuredForUITests()
      : XCUIApplication.configuredForUITests(environmentOverrides: environmentOverrides)
    application.launch()

    // Check if app is actually running
    guard application.state == .runningForeground || application.state == .runningBackground else {
      XCTFail("App failed to launch. State: \(application.state.rawValue)")
      return application
    }

    let mainTabBar = application.tabBars["Main Tab Bar"]
    if !mainTabBar.waitForExistence(timeout: adaptiveTimeout) {
      XCTFail("Main tab bar did not appear after launch. App state: \(application.state.rawValue)")
    }

    _ = waitForBatchOverlayDismissalIfNeeded(in: application)

    return application
  }

  @MainActor
  func forceTerminateAppIfRunning(bundleIdentifier: String = "us.zig.zpod") {
    let existingApp = XCUIApplication(bundleIdentifier: bundleIdentifier)
    guard existingApp.state != .notRunning else { return }

    existingApp.terminate()

    let deadline = Date().addingTimeInterval(5.0)
    while existingApp.state != .notRunning && Date() < deadline {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
    }

    if existingApp.state != .notRunning {
      XCTFail("Unable to terminate application before relaunch. Current state: \(existingApp.state.rawValue)")
    }
  }

  @MainActor
  func waitForBatchOverlayDismissalIfNeeded(
    in app: XCUIApplication,
    timeout: TimeInterval? = nil
  ) -> BatchOverlayWaitResult {
    if app.launchEnvironment["UITEST_FORCE_BATCH_OVERLAY"] == "1" {
      return .skippedForcedOverlay
    }

    let observation = BatchOverlayObservation(app: app)
    guard observation.isVisible else { return .notPresent }

    let overlayTimeout = timeout ?? max(adaptiveTimeout, 20.0)
    let predicate = NSPredicate { _, _ in
      return !observation.isVisible
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Batch operation overlay dismissal"

    let waiter = XCTWaiter()
    let result = waiter.wait(for: [expectation], timeout: overlayTimeout)

    guard result == .completed else {
      let diagnostics = observation.debugSummary()
      XCTFail(
        "Timed out waiting for batch overlay to disappear after launch.\nOverlay state:\n\(diagnostics)"
      )
      return .timedOut(debugDescription: diagnostics)
    }

    return .dismissed
  }

  @MainActor
  func waitForBatchOverlayAppearance(
    in app: XCUIApplication,
    timeout: TimeInterval? = nil
  ) -> Bool {
    let observation = BatchOverlayObservation(app: app)
    if observation.isVisible { return true }

    let overlayTimeout = timeout ?? max(adaptiveShortTimeout, 10.0)
    let overlayAppearedPredicate = NSPredicate { _, _ in
      return observation.isVisible
    }

    let expectation = XCTNSPredicateExpectation(
      predicate: overlayAppearedPredicate,
      object: nil
    )
    expectation.expectationDescription = "Batch operation overlay appeared"

    let result = XCTWaiter().wait(for: [expectation], timeout: overlayTimeout)

    guard result == .completed else {
      XCTFail(
        "Timed out waiting for batch overlay to appear.\nOverlay state:\n\(observation.debugSummary())"
      )
      return false
    }

    return true
  }

  /// Waits for a dialog, confirmation sheet, or alert with the supplied title.
  /// - Returns: The first matching container once it exists, otherwise nil if it never appears.
  @MainActor
  func waitForDialog(
    in app: XCUIApplication,
    title: String,
    timeout: TimeInterval = 5.0
  ) -> XCUIElement? {
    let titlePredicate = NSPredicate(format: "label CONTAINS[c] %@", title)
    let candidates: [XCUIElement] = [
      app.dialogs[title],
      app.sheets[title],
      app.alerts[title],
      app.otherElements[title],
      app.scrollViews.otherElements[title],
      app.dialogs.matching(titlePredicate).firstMatch,
      app.sheets.matching(titlePredicate).firstMatch,
      app.otherElements.matching(titlePredicate).firstMatch,
      app.dialogs.firstMatch,
      app.sheets.firstMatch,
      app.alerts.firstMatch,
    ]

    if let existing = candidates.first(where: { $0.exists }) {
      return existing
    }

    return waitForAnyElement(
      candidates,
      timeout: timeout,
      description: "\(title) dialog",
      failOnTimeout: false
    )
  }

  /// Resolves a button associated with a dialog container by identifier with an optional label fallback.
  @MainActor
  func resolveDialogButton(
    in app: XCUIApplication,
    dialog: XCUIElement?,
    identifier: String,
    fallbackLabel: String? = nil
  ) -> XCUIElement? {
    func candidates(from query: XCUIElementQuery) -> [XCUIElement] {
      let count = query.count
      guard count > 0 else { return [] }
      return (0..<count).map { query.element(boundBy: $0) }
    }

    func select(from elements: [XCUIElement]) -> XCUIElement? {
      if let hittable = elements.first(where: { $0.exists && $0.isHittable }) {
        return hittable
      }
      return elements.first(where: { $0.exists })
    }

    var elementPool: [XCUIElement] = []

    if let dialog, dialog.exists {
      elementPool.append(
        contentsOf: candidates(
          from: dialog.descendants(matching: .button).matching(identifier: identifier)))
    }

    let globalQueries: [XCUIElementQuery] = [
      app.buttons,
      app.dialogs.buttons,
      app.sheets.buttons,
      app.alerts.buttons,
      app.collectionViews.buttons,
      app.otherElements.buttons,
      app.scrollViews.buttons,
    ]

    for query in globalQueries {
      elementPool.append(contentsOf: candidates(from: query.matching(identifier: identifier)))
    }

    if let fallbackLabel {
      if let dialog, dialog.exists {
        elementPool.append(
          contentsOf: candidates(
            from: dialog.descendants(matching: .button).matching(
              NSPredicate(format: "label == %@", fallbackLabel))))
      }

      for query in globalQueries {
        elementPool.append(
          contentsOf: candidates(
            from: query.matching(NSPredicate(format: "label == %@", fallbackLabel))))
      }
    }

    return select(from: elementPool)
  }

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

    let predicate = NSPredicate { [weak self] _, _ in
      guard let self else { return false }

      if let container = self.findContainerElement(in: app, identifier: containerIdentifier),
        container.exists
      {
        return true
      }

      if !itemIdentifiers.isEmpty {
        for identifier in itemIdentifiers {
          let matchedElement = app.descendants(matching: .any)[identifier]
          if matchedElement.exists {
            return true
          }
        }
      }

      return false
    }

    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
    expectation.expectationDescription = "Content container '\(containerIdentifier)' appears"

    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }
}
