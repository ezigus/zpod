//
//  SwipeConfigurationTestSupport+Seeding.swift
//  zpodUITests
//
//  Persistence + seeding helpers for Issue 02.6.3.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  @MainActor
  func seedSwipeConfiguration(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) {
    let payload: [String: Any] = [
      "swipeActions": [
        "leadingActions": leading,
        "trailingActions": trailing,
        "allowFullSwipeLeading": allowFullSwipeLeading,
        "allowFullSwipeTrailing": allowFullSwipeTrailing,
        "hapticFeedbackEnabled": hapticsEnabled,
      ],
      "hapticStyle": hapticStyle,
    ]

    guard JSONSerialization.isValidJSONObject(payload) else {
      XCTFail("Swipe configuration payload is not valid JSON")
      return
    }

    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
      XCTFail("Failed to encode seeded swipe configuration")
      return
    }

    seededConfigurationPayload = data.base64EncodedString()
    pendingSeedExpectation = SeedExpectation(
      leading: leading,
      trailing: trailing,
      hapticsEnabled: hapticsEnabled
    )
  }

  func clearSeededConfigurationPayload() {
    seededConfigurationPayload = nil
    pendingSeedExpectation = nil
  }

  @MainActor
  func completeSeedIfNeeded(timeout: TimeInterval = 10.0) {
    guard let expectation = pendingSeedExpectation else { return }

    // OPTIMIZATION: Verify seed was persisted directly via UserDefaults before polling UI
    // This reduces typical wait from 10s to ~100ms for successful seeds
    let verificationDeadline = Date().addingTimeInterval(min(timeout, 2.0))
    var configurationPersisted = false

    while Date() < verificationDeadline && !configurationPersisted {
      if verifySeedPersistedToDefaults(expected: expectation) {
        configurationPersisted = true
        break
      }
      Thread.sleep(forTimeInterval: 0.1)  // Brief wait between checks
    }

    // If persisted to defaults, wait briefly for UI to reflect the state
    // Otherwise fall through to full UI polling with original timeout
    let uiTimeout: TimeInterval = configurationPersisted ? 2.0 : timeout

    guard
      waitForDebugState(timeout: uiTimeout, validator: { state in
        guard state.baselineLoaded else { return false }
        let leadingMatches = state.leading == expectation.leading
        let trailingMatches = state.trailing == expectation.trailing
        let hapticsMatches = state.hapticsEnabled == expectation.hapticsEnabled
        return leadingMatches && trailingMatches && hapticsMatches
      }) != nil
    else {
      let stateDescription: String
      if let state = currentDebugState() {
        stateDescription =
          "leading=\(state.leading) trailing=\(state.trailing) haptics=\(state.hapticsEnabled)"
      } else {
        stateDescription = "<unavailable>"
      }
      let summary = """
      expectedLeading=\(expectation.leading)
      expectedTrailing=\(expectation.trailing)
      expectedHaptics=\(expectation.hapticsEnabled)
      observed=\(stateDescription)
      """
      let attachment = XCTAttachment(string: summary)
      attachment.name = "Seeded Swipe Configuration Diagnostics"
      attachment.lifetime = .keepAlways
      add(attachment)
      XCTFail("Seeded swipe configuration did not materialize within \(timeout) seconds")
      clearSeededConfigurationPayload()
      return
    }

    clearSeededConfigurationPayload()
  }

  /// Verifies that seeded configuration was persisted to UserDefaults
  /// Returns true if configuration in defaults matches expected seed values
  private func verifySeedPersistedToDefaults(expected: SwipeSeedExpectation) -> Bool {
    guard let defaults = UserDefaults(suiteName: swipeDefaultsSuite) else {
      return false
    }

    // Read UISettings JSON from defaults (same key used by SettingsRepository)
    guard let data = defaults.data(forKey: "UISettings"),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let swipeActionsJSON = json["swipeActions"] as? [String: Any]
    else {
      return false
    }

    // Verify leading actions
    if let leadingArray = swipeActionsJSON["leading"] as? [String],
       leadingArray != expected.leading {
      return false
    }

    // Verify trailing actions
    if let trailingArray = swipeActionsJSON["trailing"] as? [String],
       trailingArray != expected.trailing {
      return false
    }

    // Verify haptics enabled
    if let haptics = swipeActionsJSON["hapticFeedbackEnabled"] as? Bool,
       haptics != expected.hapticsEnabled {
      return false
    }

    return true
  }

  @MainActor
  func restoreDefaultConfiguration() {
    resetSwipeSettingsToDefault()
    relaunchApp(resetDefaults: true)
  }

  @MainActor
  func launchAppWithSeed(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) {
    seedSwipeConfiguration(
      leading: leading,
      trailing: trailing,
      allowFullSwipeLeading: allowFullSwipeLeading,
      allowFullSwipeTrailing: allowFullSwipeTrailing,
      hapticsEnabled: hapticsEnabled,
      hapticStyle: hapticStyle
    )
    app = launchConfiguredApp(environmentOverrides: launchEnvironment(reset: false))
  }
}

struct SeedExpectation {
  let leading: [String]
  let trailing: [String]
  let hapticsEnabled: Bool
}
