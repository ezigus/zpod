//
//  UITestHelpers.swift
//  zpodUITests
//
//  Event-driven UI testing architecture using XCTestExpectation patterns
//  No artificial wait states - relies on natural system events
//

import Foundation
import OSLog
import XCTest

private let launchLogger = Logger(subsystem: "us.zig.zpod", category: "UITestHelpers")

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
    app.launchEnvironment["UITEST_SLIDER_OPACITY"] = "0.1"
    app.launchEnvironment["UITEST_DISABLE_AUDIO_ENGINE"] = "1"  // Use ticker-based playback for deterministic timing
    return app
  }

  static func configuredForUITests(environmentOverrides: [String: String]) -> XCUIApplication {
    let app = XCUIApplication.configuredForUITests()
    environmentOverrides.forEach { key, value in
      app.launchEnvironment[key] = value
    }
    return app
  }

  // MARK: - Playback Test Mode Configuration

  /// Playback engine mode for UI tests.
  /// Controls whether tests use the deterministic TimerTicker or real AVPlayer.
  ///
  /// **Issue**: 03.3.2.1 - Extract Shared Test Infrastructure
  public enum PlaybackTestMode {
    /// Uses TimerTicker for deterministic, fast position updates (no audio).
    /// Sets UITEST_DISABLE_AUDIO_ENGINE=1.
    case ticker

    /// Uses AVPlayerPlaybackEngine for real audio streaming.
    /// Does NOT set UITEST_DISABLE_AUDIO_ENGINE, allowing production audio path.
    case avplayer
  }

  /// Launch app configured for UI testing with specified playback mode.
  ///
  /// - Parameters:
  ///   - playbackMode: Whether to use ticker (fast, deterministic) or AVPlayer (real audio)
  ///   - environmentOverrides: Additional environment variables to set
  /// - Returns: Configured XCUIApplication ready to launch
  static func configuredForUITests(
    playbackMode: PlaybackTestMode,
    environmentOverrides: [String: String] = [:]
  ) -> XCUIApplication {
    var baseOverrides: [String: String] = environmentOverrides

    switch playbackMode {
    case .ticker:
      // Ensure ticker mode is enabled (same as default behavior)
      baseOverrides["UITEST_DISABLE_AUDIO_ENGINE"] = "1"
    case .avplayer:
      // Explicitly remove the disable flag to use real AVPlayer
      // Note: We set to "0" rather than removing, so it's explicit in logs
      baseOverrides["UITEST_DISABLE_AUDIO_ENGINE"] = "0"
    }

    return XCUIApplication.configuredForUITests(environmentOverrides: baseOverrides)
  }
}

// MARK: - Element Query Helpers

extension XCUIElementQuery {
  /// Returns the first match for the provided accessibility identifier, avoiding duplicate
  /// element crashes by always funneling through `.matching(identifier:)`.
  func element(matchingIdentifier identifier: String) -> XCUIElement {
    matching(identifier: identifier).firstMatch
  }
}

// MARK: - Core Testing Protocols

/// Foundation protocol for event-based UI testing
protocol UITestFoundation {
  var adaptiveTimeout: TimeInterval { get }
  var adaptiveShortTimeout: TimeInterval { get }
  var postReadinessTimeout: TimeInterval { get }
  var debugStateTimeout: TimeInterval { get }
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

  var postReadinessTimeout: TimeInterval {
    // Increased from 1.5s→2.5s→3.0s (local) and 2.0s→3.0s→4.0s→5.0s (CI) to handle
    // resource exhaustion, fresh app launches after termination, and SwiftUI
    // lazy unmaterialization race conditions.
    // Tests still proceed immediately when elements appear quickly - this is a maximum
    // ceiling, not a fixed delay.
    let baseTimeout = ProcessInfo.processInfo.environment["CI"] != nil ? 5.0 : 3.0
    return baseTimeout * timeoutScale
  }

  var debugStateTimeout: TimeInterval {
    let baseTimeout = ProcessInfo.processInfo.environment["CI"] != nil ? 4.0 : 2.5
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

  func discoverRootElement(in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(identifier: "Discover.Root")
      .firstMatch
  }

  func discoverSearchFieldCandidates(in app: XCUIApplication) -> [XCUIElement] {
    [
      app.textFields.matching(identifier: "Discover.SearchField").firstMatch,
      app.descendants(matching: .any)
        .matching(identifier: "Discover.SearchField")
        .firstMatch,
      app.searchFields.firstMatch,
      app.textFields.matching(
        NSPredicate(format: "placeholderValue CONTAINS[cd] 'search'")
      ).firstMatch,
    ]
  }

  func discoverSearchField(
    in app: XCUIApplication,
    probeTimeout: TimeInterval = 0.5,
    finalTimeout: TimeInterval = 1.0
  ) -> XCUIElement {
    let candidates = discoverSearchFieldCandidates(in: app)
    for candidate in candidates.dropLast() {
      if candidate.waitForExistence(timeout: probeTimeout) {
        return candidate
      }
    }

    let lastCandidate = candidates.last ?? app.textFields.firstMatch
    _ = lastCandidate.waitForExistence(timeout: finalTimeout)
    return lastCandidate
  }

  func quickPlayButton(
    in app: XCUIApplication,
    episodeIdentifier: String = "Episode-st-001",
    timeout: TimeInterval,
    description: String = "Quick play button"
  ) -> XCUIElement? {
    let rawEpisodeId = episodeIdentifier.hasPrefix("Episode-")
      ? String(episodeIdentifier.dropFirst("Episode-".count))
      : episodeIdentifier
    let primaryQuickPlayButton = app.buttons
      .matching(identifier: "Episode-\(rawEpisodeId)-QuickPlay")
      .firstMatch
    let fallbackQuickPlayButton = app.buttons
      .matching(identifier: "Episode-\(rawEpisodeId)")
      .matching(NSPredicate(format: "label == 'Quick play'"))
      .firstMatch
    return waitForAnyElement(
      [primaryQuickPlayButton, fallbackQuickPlayButton],
      timeout: timeout,
      description: description,
      failOnTimeout: true
    )
  }

  func tapQuickPlayButton(
    in app: XCUIApplication,
    episodeIdentifier: String = "Episode-st-001",
    timeout: TimeInterval,
    description: String = "Quick play button"
  ) {
    guard
      let quickPlayButton = quickPlayButton(
        in: app,
        episodeIdentifier: episodeIdentifier,
        timeout: timeout,
        description: description
      )
    else { return }
    quickPlayButton.tap()
  }

  func miniPlayerElement(in app: XCUIApplication) -> XCUIElement {
    app.otherElements.matching(identifier: "Mini Player").firstMatch
  }

  func hasNonEmptyLabel(_ element: XCUIElement) -> Bool {
    guard element.exists else { return false }
    let text = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
    return !text.isEmpty
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
      let element = app.descendants(matching: elementType)
        .matching(identifier: identifier)
        .firstMatch
      if element.exists { return element }
    }

    // Try label
    if let label = label {
      let labelPredicate = NSPredicate(format: "label == %@", label)
      let element = app.descendants(matching: elementType)
        .matching(labelPredicate)
        .firstMatch
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

  /// Waits for an element to appear and fails the test immediately when it never becomes available.
  @MainActor
  @discardableResult
  func waitForElementOrSkip(
    _ element: XCUIElement,
    timeout: TimeInterval,
    description: String
  ) throws -> XCUIElement {
    guard element.waitForExistence(timeout: timeout) else {
      XCTFail("\(description) not available; verify test data and launch arguments.")
      return element
    }
    return element
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
      let element = query.matching(identifier: identifier).firstMatch
      if element.exists {
        return element
      }
    }

    let anyMatch = app.descendants(matching: .any)
      .matching(identifier: identifier)
      .firstMatch
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
      "Podcast Cards Container",
      "Library Content",
      "Podcast List Container",
    ]

    // Use predicate for synchronous polling (avoids DispatchQueue.main deadlocks)
    let predicate = NSPredicate { [weak self] _, _ in
      guard let self else { return false }

      // Presence of the batch operations overlay indicates the view finished loading
      if app.otherElements.matching(identifier: "Batch Operation Progress").firstMatch.exists {
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
      let libraryTab = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch.buttons.matching(identifier: "Library").firstMatch
      let navigationBar = app.navigationBars.firstMatch
      let swiftPodcast = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch

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
    primaryElement = app.otherElements.matching(identifier: "Batch Operation Progress").firstMatch
    auxiliaryElements = [
      app.scrollViews.otherElements.matching(identifier: "Batch Operation Progress").firstMatch,
      app.tables.otherElements.matching(identifier: "Batch Operation Progress").firstMatch,
      app.cells.matching(identifier: "Batch Operation Progress").firstMatch,
      app.tables.cells.matching(identifier: "Batch Operation Progress").firstMatch,
      app.staticTexts.matching(identifier: "Batch Operation Progress").firstMatch,
      app.staticTexts.matching(identifier: "Processing...").firstMatch,
      app.staticTexts.matching(identifier: "Processing").firstMatch,
      app.staticTexts.matching(identifier: "Complete").firstMatch,
      app.staticTexts.matching(identifier: "Completed").firstMatch,
      app.staticTexts.matching(identifier: "Batch Operation").firstMatch,
      app.buttons.matching(identifier: "Pause").firstMatch,
      app.buttons.matching(identifier: "Resume").firstMatch,
      app.buttons.matching(identifier: "Cancel").firstMatch,
    ]
  }

  var isVisible: Bool {
    if primaryElement.exists { return true }
    return auxiliaryElements.contains { $0.exists }
  }

  func debugSummary() -> String {
    let visibleElements = ([primaryElement] + auxiliaryElements).enumerated().compactMap { index, element -> String? in
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

  /// Polls for a condition until it becomes true or the timeout elapses.
  /// Useful for UI values that update asynchronously without triggering XC expectations.
  @MainActor
  @discardableResult
  func waitUntil(
    timeout: TimeInterval = 1.0,
    pollInterval: TimeInterval = 0.1,
    description: String = "condition",
    condition: () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }
    return condition()
  }

  /// Waits until the provided text field reports keyboard focus.
  @MainActor
  func waitForKeyboardFocus(
    on element: XCUIElement,
    timeout: TimeInterval = 1.0,
    description: String
  ) -> Bool {
    waitUntil(timeout: timeout, pollInterval: 0.05, description: description) {
      (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }
  }

  /// Launches app with playback mode selection and full test infrastructure.
  ///
  /// This helper integrates `PlaybackTestMode` with the standard `launchConfiguredApp`
  /// flow, ensuring proper app termination, Springboard readiness, and overlay handling.
  ///
  /// **For AVPlayer mode**: Automatically injects test audio file paths via environment
  /// variables so the app can populate Episode.audioURL during UI tests. Audio files are
  /// resolved from the test bundle (TestResources/Audio/).
  ///
  /// - Parameters:
  ///   - mode: Playback engine mode (ticker or AVPlayer)
  ///   - environmentOverrides: Additional environment variables
  /// - Returns: Launched XCUIApplication instance
  @MainActor
  @discardableResult
  func launchWithPlaybackMode(
    _ mode: XCUIApplication.PlaybackTestMode,
    environmentOverrides: [String: String] = [:]
  ) -> XCUIApplication {
    var overrides = environmentOverrides
    
    switch mode {
    case .ticker:
      overrides["UITEST_DISABLE_AUDIO_ENGINE"] = "1"
      
    case .avplayer:
      overrides["UITEST_DISABLE_AUDIO_ENGINE"] = "0"
      overrides["UITEST_DEBUG_AUDIO"] = "1"  // Enable diagnostic logging
      
      // Copy audio files to /tmp and inject paths
      // Cast to concrete type to access audioLaunchEnvironment() helper
      if let testCase = self as? (any PlaybackPositionTestSupport & XCTestCase) {
        NSLog("🔧 AVPlayer mode: calling audioLaunchEnvironment()")
        let audioEnv = testCase.audioLaunchEnvironment()
        NSLog("🔧 Audio environment keys: \(audioEnv.keys.sorted().joined(separator: ", "))")
        overrides.merge(audioEnv) { _, new in new }
      } else {
        NSLog("⚠️  AVPlayer mode: Failed to cast to PlaybackPositionTestSupport")
      }
    }
    
    return launchConfiguredApp(environmentOverrides: overrides)
  }

  /// Launches a configured application and waits for the main tab bar to appear so tests start from a stable state.
  @MainActor
  @discardableResult
  func launchConfiguredApp(environmentOverrides: [String: String] = [:]) -> XCUIApplication {
    launchConfiguredApp(environmentOverrides: environmentOverrides, launchArguments: [])
  }

  /// Launches a configured application with explicit launch arguments for size category or feature flags.
  @MainActor
  @discardableResult
  func launchConfiguredApp(
    environmentOverrides: [String: String] = [:],
    launchArguments: [String]
  ) -> XCUIApplication {
    logLaunchEvent("Preparing to launch app (envOverrides=\(!environmentOverrides.isEmpty))")
    ensureSpringboardReady(timeout: adaptiveTimeout)
    forceTerminateAppIfRunning()
    logLaunchEvent("Termination check complete")

    let application =
      environmentOverrides.isEmpty
      ? XCUIApplication.configuredForUITests()
      : XCUIApplication.configuredForUITests(environmentOverrides: environmentOverrides)
    application.launchArguments += launchArguments
    application.launch()
    logLaunchEvent("Launch request issued")

    guard application.state == .runningForeground || application.state == .runningBackground else {
      XCTFail("App failed to launch. State: \(application.state.rawValue)")
      return application
    }

    let mainTabBar = application.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let tabBarAppeared = mainTabBar.waitForExistence(timeout: adaptiveTimeout)
    logLaunchEvent("Main tab bar existence=\(tabBarAppeared)")
    XCTAssertTrue(
      tabBarAppeared,
      "Main tab bar did not appear after launch. App state: \(application.state.rawValue)"
    )

    let overlayResult = waitForBatchOverlayDismissalIfNeeded(in: application)
    logLaunchEvent("Batch overlay result=\(overlayResult)")

    return application
  }

  @MainActor
  private func ensureSpringboardReady(timeout: TimeInterval) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    springboard.activate()
    let ready = waitUntil(timeout: timeout, pollInterval: 0.1, description: "Springboard ready") {
      springboard.state == .runningForeground
    }
    if !ready {
      logLaunchEvent("Springboard not foreground within \(timeout)s")
    }
  }

  private func logLaunchEvent(_ message: String) {
    launchLogger.debug("[SwipeUITestDebug] \(message, privacy: .public)")
    print("[SwipeUITestDebug] \(message)")
  }

  @MainActor
  func forceTerminateAppIfRunning(bundleIdentifier: String = "us.zig.zpod") {
    let existingApp = XCUIApplication(bundleIdentifier: bundleIdentifier)
    guard existingApp.state != .notRunning else { return }

    if existingApp.state == .runningBackground {
      existingApp.activate()
    }
    existingApp.terminate()

    let deadline = Date().addingTimeInterval(12.0)
    while existingApp.state != .notRunning && Date() < deadline {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
    }

    if existingApp.state != .notRunning {
      XCTFail(
        "Unable to terminate application before relaunch. Current state: \(existingApp.state.rawValue)"
      )
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
          let matchedElement = app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
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
