//
//  IsolatedUITestCase.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Mandatory base class for all UI tests - enforces isolation and cleanup
//
//  Architecture Pattern: https://alexilyenko.github.io/xcuitest-page-object/
//

import Foundation
import OSLog
import XCTest

/// Mandatory base class for all UI tests.
///
/// **Why this exists**: Ensures consistent test isolation, cleanup, and infrastructure
/// across all UI tests. Prevents state pollution between tests that causes flaky failures.
///
/// **Pattern**: BaseTest pattern from XCTest community best practices
/// - Single source of truth for test lifecycle
/// - Automatic cleanup in tearDown
/// - Consistent app launch configuration
/// - CI-aware termination handling
///
/// **Usage**:
/// ```swift
/// final class MyFeatureTests: IsolatedUITestCase {
///     // Override to specify custom UserDefaults suite if needed
///     override var userDefaultsSuite: String? { "com.app.custom-suite" }
///
///     @MainActor
///     func testFeature() {
///         app = launchConfiguredApp()  // From SmartUITesting protocol
///         // ... test logic
///     }
/// }
/// ```
///
/// **What you get for free**:
/// - Automatic UserDefaults cleanup (before and after each test)
/// - Automatic Keychain cleanup (before and after each test)
/// - App termination in CI to prevent resource exhaustion
/// - `SmartUITesting` protocol conformance (wait helpers, navigation, launch)
/// - `continueAfterFailure = false` for fast failure detection
///
/// **Issue**: #12.3 - Test Infrastructure Cleanup
open class IsolatedUITestCase: XCTestCase, SmartUITesting {

  // MARK: - Properties

  /// The application under test.
  ///
  /// **Important**: Must be `nonisolated(unsafe)` because XCUIApplication doesn't conform
  /// to Sendable, and tests run on MainActor while XCTest infrastructure is nonisolated.
  nonisolated(unsafe) public var app: XCUIApplication!

  /// Optional UserDefaults suite name for test isolation.
  ///
  /// Override in subclasses if your tests use a custom suite:
  /// ```swift
  /// override var userDefaultsSuite: String? { "us.zig.zpod.swipe-uitests" }
  /// ```
  ///
  /// When `nil`, cleans up standard UserDefaults.
  open var userDefaultsSuite: String? { nil }

  private static let logger = Logger(subsystem: "us.zig.zpod", category: "IsolatedUITestCase")

  // MARK: - XCTest Lifecycle

  /// Sets up test isolation before each test.
  ///
  /// **What happens here**:
  /// 1. Stop on first failure (`continueAfterFailure = false`)
  /// 2. Clear UserDefaults (prevents state pollution from previous tests)
  /// 3. Clear Keychain (prevents credential leaks between tests)
  /// 4. Terminate lingering app instances in CI (prevents resource exhaustion)
  ///
  /// **Override**: If you need custom setup, call `super.setUpWithError()` first:
  /// ```swift
  /// override func setUpWithError() throws {
  ///     try super.setUpWithError()
  ///     // Your custom setup here
  /// }
  /// ```
  open override func setUpWithError() throws {
    try super.setUpWithError()

    // Fail fast - stop immediately when a failure occurs
    continueAfterFailure = false

    // Pre-test cleanup: ensure clean slate
    performPreTestCleanup()
  }

  /// Cleans up test state after each test.
  ///
  /// **What happens here**:
  /// 1. Clear UserDefaults (prevent pollution to next test)
  /// 2. Clear Keychain (prevent credential leaks)
  /// 3. Terminate app in CI (prevent resource exhaustion in parallel runs)
  /// 4. Nil out app reference (prevent accidental reuse)
  ///
  /// **Override**: If you need custom teardown, call `super.tearDownWithError()` last:
  /// ```swift
  /// override func tearDownWithError() throws {
  ///     // Your custom cleanup here
  ///     try super.tearDownWithError()
  /// }
  /// ```
  open override func tearDownWithError() throws {
    // Post-test cleanup: ensure next test starts clean
    performPostTestCleanup()

    // Nil out app reference to catch accidental reuse
    app = nil

    try super.tearDownWithError()
  }

  // MARK: - Cleanup Helpers

  /// Performs pre-test cleanup to ensure clean slate.
  ///
  /// Called automatically in `setUpWithError()`.
  /// Can be called manually if you need to reset state mid-test.
  private func performPreTestCleanup() {
    // Clear UserDefaults to prevent state pollution
    clearUserDefaults(suiteName: userDefaultsSuite)

    // Clear Keychain to prevent credential leaks
    clearKeychain()

    // In CI: Force terminate any lingering app instance to prevent resource exhaustion
    // (Parallel test runs can exhaust simulator resources if apps aren't cleaned up)
    if ProcessInfo.processInfo.environment["CI"] != nil {
      MainActor.assumeIsolated {
        forceTerminateAppIfRunning()
      }
    }
  }

  /// Performs post-test cleanup to prepare for next test.
  ///
  /// Called automatically in `tearDownWithError()`.
  private func performPostTestCleanup() {
    // Clear UserDefaults to prevent pollution to next test
    clearUserDefaults(suiteName: userDefaultsSuite)

    // Clear Keychain to prevent credential leaks
    clearKeychain()

    // In CI: Terminate app between tests to prevent resource exhaustion
    if ProcessInfo.processInfo.environment["CI"] != nil {
      MainActor.assumeIsolated {
        if let application = app, application.state != .notRunning {
          application.terminate()

          // Wait for termination to complete (with timeout)
          let deadline = Date().addingTimeInterval(5.0)
          while application.state != .notRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
          }

          if application.state != .notRunning {
            Self.logger.warning("App did not terminate within 5s (state: \(application.state.rawValue))")
          }
        }
      }
    }
  }
}

// MARK: - SmartUITesting Protocol Conformance

extension IsolatedUITestCase {
  // SmartUITesting protocol methods are provided by default implementations in UITestHelpers.swift
  // This includes:
  // - waitForElement(_:timeout:description:)
  // - waitForAnyElement(_:timeout:description:failOnTimeout:)
  // - navigateAndVerify(action:expectedElement:description:)
  // - navigateAndWaitForResult(triggerAction:expectedElements:timeout:description:)
  // - launchConfiguredApp(environmentOverrides:)
  // - waitForContentToLoad(containerIdentifier:itemIdentifiers:timeout:)
  // - And many more helper methods
}
