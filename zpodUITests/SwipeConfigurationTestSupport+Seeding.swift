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

    guard
      waitForDebugState(timeout: timeout, validator: { state in
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
