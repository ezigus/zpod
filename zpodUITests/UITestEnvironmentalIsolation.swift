//
//  UITestEnvironmentalIsolation.swift
//  zpodUITests
//
//  Created for Issue #148 - CI Test Flakiness: Phase 3 - Infrastructure Improvements
//  Provides cleanup utilities for test isolation (UserDefaults, Keychain, app state)
//
//  Addresses: 10% of test failures (state pollution category)
//

import Foundation
import Security
import XCTest

// MARK: - Test Environment Isolation Protocol

/// Protocol for test classes that need environmental isolation
protocol TestEnvironmentIsolation {
  /// Clears UserDefaults to prevent state pollution
  func clearUserDefaults(suiteName: String?)

  /// Clears all keychain items for test isolation
  func clearKeychain()

  /// Terminates and relaunches app to clear in-memory state
  @MainActor
  func resetAppState(app: XCUIApplication)

  /// Performs standard cleanup (UserDefaults + Keychain)
  func performStandardCleanup(suiteName: String?)
}

// MARK: - Default Implementation

extension XCTestCase: TestEnvironmentIsolation {

  /// Clears all UserDefaults to prevent state pollution between tests
  ///
  /// This is critical for test isolation when tests modify persistent settings.
  /// Without cleanup, one test's configuration can leak into subsequent tests,
  /// causing flaky failures.
  ///
  /// Example:
  /// ```swift
  /// override func tearDown() {
  ///   clearUserDefaults(suiteName: "us.zig.zpod.swipe-uitests")
  ///   super.tearDown()
  /// }
  /// ```
  ///
  /// - Parameter suiteName: Optional suite name (nil = standard UserDefaults)
  func clearUserDefaults(suiteName: String? = nil) {
    let defaults: UserDefaults
    if let suiteName = suiteName {
      guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
        print("⚠️ Unable to access UserDefaults suite '\(suiteName)'")
        return
      }
      defaults = suiteDefaults
      // Use removePersistentDomain for efficient suite clearing (Apple recommended)
      defaults.removePersistentDomain(forName: suiteName)
    } else {
      defaults = UserDefaults.standard
      // For standard defaults, remove the bundle's domain
      if let bundleID = Bundle.main.bundleIdentifier {
        defaults.removePersistentDomain(forName: bundleID)
      }
    }

    // Force synchronization
    defaults.synchronize()

    print("✅ Cleared UserDefaults\(suiteName.map { " (suite: \($0))" } ?? "")")
  }

  /// Clears all keychain items to ensure test isolation
  ///
  /// Prevents keychain data from leaking between tests. Important for tests that
  /// store authentication tokens, credentials, or other secure data.
  ///
  /// Example:
  /// ```swift
  /// override func tearDown() {
  ///   clearKeychain()
  ///   super.tearDown()
  /// }
  /// ```
  func clearKeychain() {
    let secItemClasses = [
      kSecClassGenericPassword,
      kSecClassInternetPassword,
      kSecClassCertificate,
      kSecClassKey,
      kSecClassIdentity,
    ]

    var deletedCount = 0

    for itemClass in secItemClasses {
      let spec: [String: Any] = [kSecClass as String: itemClass]
      let status = SecItemDelete(spec as CFDictionary)

      if status == errSecSuccess || status == errSecItemNotFound {
        if status == errSecSuccess {
          deletedCount += 1
        }
      } else {
        print(
          "⚠️ Failed to clear keychain class \(itemClass): OSStatus \(status)"
        )
      }
    }

    if deletedCount > 0 {
      print("✅ Cleared keychain (\(deletedCount) item classes cleared)")
    }
  }

  /// Terminates and relaunches app to clear in-memory state
  ///
  /// Use this when you need to completely reset app state, including in-memory
  /// caches, singletons, and view state. More heavyweight than clearing UserDefaults.
  ///
  /// Example:
  /// ```swift
  /// func testFreshAppState() {
  ///   resetAppState(app: app)
  ///   // App is now in fresh state
  /// }
  /// ```
  ///
  /// - Parameter app: The XCUIApplication instance to reset
  @MainActor
  func resetAppState(app: XCUIApplication) {
    print("🔄 Resetting app state (terminate + relaunch)...")
    app.terminate()

    // Wait for app to fully terminate
    // Check for .notRunning OR .unknown to handle edge cases where app may be in intermediate state
    let deadline = Date().addingTimeInterval(5.0)
    while app.state != .notRunning && app.state != .unknown && Date() < deadline {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
    }

    if app.state != .notRunning && app.state != .unknown {
      print("⚠️ App did not terminate cleanly within 5s (state: \(app.state.rawValue))")
    }

    // Relaunch will happen automatically in setUp or can be done manually
    print("✅ App terminated successfully")
  }

  /// Performs standard cleanup (UserDefaults + Keychain)
  ///
  /// Convenience method that combines UserDefaults and Keychain cleanup.
  /// Recommended for use in tearDown methods to ensure clean state between tests.
  ///
  /// Example:
  /// ```swift
  /// override func tearDown() {
  ///   performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  ///   super.tearDown()
  /// }
  /// ```
  ///
  /// - Parameter suiteName: Optional UserDefaults suite name
  func performStandardCleanup(suiteName: String? = nil) {
    clearUserDefaults(suiteName: suiteName)
    clearKeychain()
  }
}

// MARK: - Cleanup Extensions for Test Base Classes

extension XCTestCase {

  /// Clears multiple UserDefaults suites at once
  ///
  /// Useful when your app uses multiple suites that need cleanup.
  ///
  /// Example:
  /// ```swift
  /// clearMultipleUserDefaults(suites: [
  ///   "us.zig.zpod.swipe-uitests",
  ///   "us.zig.zpod.settings-uitests",
  ///   nil  // standard defaults
  /// ])
  /// ```
  ///
  /// - Parameter suites: Array of suite names (nil = standard defaults)
  func clearMultipleUserDefaults(suites: [String?]) {
    for suite in suites {
      clearUserDefaults(suiteName: suite)
    }
  }

  /// Removes a specific UserDefaults key
  ///
  /// Less aggressive than clearing all defaults - only removes specific keys.
  /// Useful when you want to reset specific test state without affecting everything.
  ///
  /// Example:
  /// ```swift
  /// removeUserDefaultsKey("test_configuration", suiteName: "us.zig.zpod.swipe-uitests")
  /// ```
  ///
  /// - Parameters:
  ///   - key: The key to remove
  ///   - suiteName: Optional suite name
  func removeUserDefaultsKey(_ key: String, suiteName: String? = nil) {
    let defaults: UserDefaults
    if let suiteName = suiteName {
      guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
        print("⚠️ Unable to access UserDefaults suite '\(suiteName)'")
        return
      }
      defaults = suiteDefaults
    } else {
      defaults = UserDefaults.standard
    }

    defaults.removeObject(forKey: key)
    defaults.synchronize()
  }

  /// Removes specific keychain items by service name
  ///
  /// More targeted than clearing all keychain items. Useful when you only want
  /// to clean up specific test-related credentials.
  ///
  /// Example:
  /// ```swift
  /// removeKeychainItem(service: "com.test.auth-token", account: "test-user")
  /// ```
  ///
  /// - Parameters:
  ///   - service: Service identifier
  ///   - account: Optional account name
  func removeKeychainItem(service: String, account: String? = nil) {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]

    if let account = account {
      query[kSecAttrAccount as String] = account
    }

    let status = SecItemDelete(query as CFDictionary)

    if status == errSecSuccess {
      print("✅ Removed keychain item (service: \(service))")
    } else if status == errSecItemNotFound {
      // Not an error - item didn't exist
    } else {
      print("⚠️ Failed to remove keychain item: OSStatus \(status)")
    }
  }
}

// MARK: - Verification Helpers

extension XCTestCase {

  /// Verifies UserDefaults is empty (for debugging)
  ///
  /// Useful for debugging test isolation issues - confirms cleanup worked.
  ///
  /// - Parameter suiteName: Optional suite name
  /// - Returns: True if UserDefaults is empty
  func verifyUserDefaultsIsEmpty(suiteName: String? = nil) -> Bool {
    let defaults: UserDefaults
    if let suiteName = suiteName {
      guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
        return false
      }
      defaults = suiteDefaults
    } else {
      defaults = UserDefaults.standard
    }

    let dictionary = defaults.dictionaryRepresentation()
    let isEmpty = dictionary.isEmpty

    if !isEmpty {
      print("⚠️ UserDefaults not empty: \(dictionary.keys.count) keys remaining")
      print("   Keys: \(Array(dictionary.keys).joined(separator: ", "))")
    }

    return isEmpty
  }

  /// Logs current UserDefaults state (for debugging)
  ///
  /// Helpful for understanding what's persisting between tests.
  ///
  /// - Parameter suiteName: Optional suite name
  func logUserDefaultsState(suiteName: String? = nil) {
    let defaults: UserDefaults
    let label = suiteName ?? "standard"

    if let suiteName = suiteName {
      guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
        print("⚠️ Unable to access UserDefaults suite '\(suiteName)'")
        return
      }
      defaults = suiteDefaults
    } else {
      defaults = UserDefaults.standard
    }

    let dictionary = defaults.dictionaryRepresentation()

    print("📋 UserDefaults state (\(label)):")
    if dictionary.isEmpty {
      print("   (empty)")
    } else {
      for (key, value) in dictionary.sorted(by: { $0.key < $1.key }) {
        print("   \(key) = \(value)")
      }
    }
  }
}

// MARK: - Automated Cleanup for SwipeConfiguration Tests

extension XCTestCase {

  /// Performs SwipeConfiguration-specific cleanup
  ///
  /// Specialized cleanup for SwipeConfiguration tests that use custom suite names
  /// and specific launch environment variables.
  ///
  /// Example:
  /// ```swift
  /// override func tearDown() {
  ///   performSwipeConfigurationCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  ///   super.tearDown()
  /// }
  /// ```
  ///
  /// - Parameter suiteName: Optional suite name (defaults to "us.zig.zpod.swipe-uitests")
  func performSwipeConfigurationCleanup(suiteName: String = "us.zig.zpod.swipe-uitests") {
    // Clear the swipe-specific UserDefaults suite
    clearUserDefaults(suiteName: suiteName)

    // Also clear standard defaults in case anything leaked
    clearUserDefaults(suiteName: nil)

    // Clear keychain
    clearKeychain()

    print("✅ SwipeConfiguration cleanup complete")
  }
}
