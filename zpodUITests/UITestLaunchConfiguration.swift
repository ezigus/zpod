//
//  UITestLaunchConfiguration.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//  Central registry for all launch environment variables
//
//  Eliminates scattered configuration across multiple files
//

import Foundation

/// Central registry for all UI test launch configurations.
///
/// **Why this exists**: Scattered environment variables across multiple files made it hard
/// to understand what configuration applied to which tests. This centralizes all launch
/// configurations in one place.
///
/// **Before**:
/// ```swift
/// // UITestHelpers.swift
/// app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
///
/// // SwipeConfigurationTestSupport.swift
/// environment["UITEST_SWIPE_DEBUG"] = "1"
///
/// // Individual test files
/// app.launchEnvironment["CUSTOM_FLAG"] = "1"
/// ```
///
/// **After**:
/// ```swift
/// // All configurations in one place
/// let env = UITestLaunchConfiguration.base
/// let env = UITestLaunchConfiguration.tickerPlayback
/// let env = UITestLaunchConfiguration.swipeConfiguration(suite: "...", reset: true)
/// ```
///
/// **Usage**:
/// ```swift
/// // Use base configuration
/// app = XCUIApplication.configuredForUITests(
///     environmentOverrides: UITestLaunchConfiguration.base
/// )
///
/// // Use swipe configuration with customization
/// var env = UITestLaunchConfiguration.swipeConfiguration(
///     suite: "us.zig.zpod.swipe-uitests",
///     reset: true
/// )
/// env["CUSTOM_FLAG"] = "1"
/// app = XCUIApplication.configuredForUITests(environmentOverrides: env)
/// ```
///
/// **Issue**: #12.3 - Test Infrastructure Cleanup
public enum UITestLaunchConfiguration {

  // MARK: - Base Configurations

  /// Base configuration used by all UI tests.
  ///
  /// **What's enabled**:
  /// - Download coordinator disabled (prevents background downloads during tests)
  /// - Animations disabled (faster tests, more deterministic)
  /// - Slider opacity reduced (makes slider values readable in tests)
  ///
  /// **Usage**: Starting point for all test configurations. Merge with specific configs.
  public static let base: [String: String] = [
    "UITEST_DISABLE_DOWNLOAD_COORDINATOR": "1",
    "UITEST_DISABLE_ANIMATIONS": "1",
    "UITEST_SLIDER_OPACITY": "0.1",
  ]

  // MARK: - Playback Configurations

  /// Ticker-based playback (fast, deterministic, no audio).
  ///
  /// **What's enabled**:
  /// - Base configuration
  /// - Audio engine disabled (uses TimerTicker instead of AVPlayer)
  ///
  /// **When to use**: Default for most tests. Faster and more deterministic than real audio.
  ///
  /// **Example**:
  /// ```swift
  /// app = XCUIApplication.configuredForUITests(
  ///     environmentOverrides: UITestLaunchConfiguration.tickerPlayback
  /// )
  /// ```
  public static let tickerPlayback: [String: String] = base.merging([
    "UITEST_DISABLE_AUDIO_ENGINE": "1"
  ]) { _, new in new }

  /// AVPlayer-based playback (real audio streaming).
  ///
  /// **What's enabled**:
  /// - Base configuration
  /// - Audio engine enabled (uses AVPlayerPlaybackEngine for real audio)
  ///
  /// **When to use**: Tests that need real audio playback (e.g., testing audio session handling).
  ///
  /// **Example**:
  /// ```swift
  /// app = XCUIApplication.configuredForUITests(
  ///     environmentOverrides: UITestLaunchConfiguration.avplayerPlayback
  /// )
  /// ```
  public static let avplayerPlayback: [String: String] = base.merging([
    "UITEST_DISABLE_AUDIO_ENGINE": "0"
  ]) { _, new in new }

  // MARK: - Feature-Specific Configurations

  /// Swipe configuration tests (used by SwipeConfigurationTestCase).
  ///
  /// **What's enabled**:
  /// - Base configuration
  /// - Ticker playback (deterministic timing)
  /// - Swipe debug mode (exposes debug UI for test verification)
  /// - Custom UserDefaults suite (isolation from other tests)
  /// - Stubbed playlist sheet (bypass multi-step playlist selection)
  /// - Auto-scroll presets (pre-materialize SwiftUI lazy sections)
  /// - Preload sections (avoid SwiftUI lazy unmaterialization issues)
  /// - Optional settings reset
  ///
  /// **When to use**: All swipe configuration tests.
  ///
  /// **Example**:
  /// ```swift
  /// let env = UITestLaunchConfiguration.swipeConfiguration(
  ///     suite: "us.zig.zpod.swipe-uitests",
  ///     reset: true  // Reset settings before test
  /// )
  /// app = XCUIApplication.configuredForUITests(environmentOverrides: env)
  /// ```
  ///
  /// - Parameters:
  ///   - suite: UserDefaults suite name for test isolation
  ///   - reset: Whether to reset swipe settings before launch
  ///   - seededConfiguration: Optional base64-encoded configuration to seed
  /// - Returns: Complete launch environment
  public static func swipeConfiguration(
    suite: String,
    reset: Bool,
    seededConfiguration: String? = nil
  ) -> [String: String] {
    var environment = tickerPlayback  // Start with ticker-based playback

    environment["UITEST_SWIPE_DEBUG"] = "1"
    environment["UITEST_USER_DEFAULTS_SUITE"] = suite
    environment["UITEST_STUB_PLAYLIST_SHEET"] = "1"
    environment["UITEST_AUTO_SCROLL_PRESETS"] = "1"
    environment["UITEST_SWIPE_PRELOAD_SECTIONS"] = "1"
    environment["UITEST_RESET_SWIPE_SETTINGS"] = reset ? "1" : "0"

    if let payload = seededConfiguration {
      environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] = payload
    }

    return environment
  }

  /// Batch operation tests (for testing batch download/delete/archive).
  ///
  /// **What's enabled**:
  /// - Base configuration
  /// - Ticker playback
  /// - Optional batch overlay forcing (for testing overlay behavior)
  ///
  /// **Example**:
  /// ```swift
  /// let env = UITestLaunchConfiguration.batchOperations(forceOverlay: true)
  /// app = XCUIApplication.configuredForUITests(environmentOverrides: env)
  /// ```
  ///
  /// - Parameter forceOverlay: Whether to force batch overlay to appear (for testing)
  /// - Returns: Complete launch environment
  public static func batchOperations(forceOverlay: Bool = false) -> [String: String] {
    var environment = tickerPlayback

    if forceOverlay {
      environment["UITEST_FORCE_BATCH_OVERLAY"] = "1"
    }

    return environment
  }

  // MARK: - Debugging Configurations

  /// Debug configuration with extended timeouts and logging.
  ///
  /// **What's enabled**:
  /// - Base configuration
  /// - Extended timeouts (3x normal)
  /// - Verbose logging
  ///
  /// **When to use**: When debugging flaky tests locally.
  ///
  /// **Example**:
  /// ```swift
  /// let env = UITestLaunchConfiguration.debug
  /// app = XCUIApplication.configuredForUITests(environmentOverrides: env)
  /// ```
  public static var debug: [String: String] {
    var environment = base
    environment["UITEST_TIMEOUT_SCALE"] = "3.0"  // 3x normal timeouts
    return environment
  }

  // MARK: - Custom Configuration Builders

  /// Creates custom configuration by merging base with overrides.
  ///
  /// **Usage**: For one-off test configurations that don't fit predefined patterns.
  ///
  /// **Example**:
  /// ```swift
  /// let env = UITestLaunchConfiguration.custom(
  ///     base: .tickerPlayback,
  ///     overrides: [
  ///         "UITEST_CUSTOM_FLAG": "1",
  ///         "UITEST_FEATURE_FLAG": "enabled"
  ///     ]
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - base: Base configuration to start from (default: `.base`)
  ///   - overrides: Environment variables to merge
  /// - Returns: Merged environment
  public static func custom(
    base: [String: String] = base,
    overrides: [String: String]
  ) -> [String: String] {
    return base.merging(overrides) { _, new in new }
  }
}

// MARK: - Backward Compatibility

extension UITestLaunchConfiguration {

  /// **DEPRECATED**: Use `UITestLaunchConfiguration.tickerPlayback` instead.
  ///
  /// Migration:
  /// ```swift
  /// // Old
  /// XCUIApplication.configuredForUITests()
  ///
  /// // New
  /// XCUIApplication.configuredForUITests(
  ///     environmentOverrides: UITestLaunchConfiguration.tickerPlayback
  /// )
  /// ```
  @available(*, deprecated, message: "Use UITestLaunchConfiguration.tickerPlayback instead")
  public static var defaultConfiguration: [String: String] {
    return tickerPlayback
  }
}
