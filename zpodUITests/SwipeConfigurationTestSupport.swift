//
//  SwipeConfigurationTestSupport.swift
//  zpodUITests
//
//  Created for Issue 02.6.3: SwipeConfiguration UI Test Decomposition
//  Base class that wires together shared swipe-configuration helpers.
//

import Foundation
import OSLog
import XCTest

class SwipeConfigurationTestCase: XCTestCase, SmartUITesting {
  // MARK: - Shared State

  internal let logger = Logger(subsystem: "us.zig.zpod", category: "SwipeConfigurationUITests")
  nonisolated(unsafe) var app: XCUIApplication!
  internal let swipeDefaultsSuite = "us.zig.zpod.swipe-uitests"
  internal var seededConfigurationPayload: String?
  internal var pendingSeedExpectation: SeedExpectation?
  @MainActor internal static var reportedToggleValueSignatures = Set<String>()
  nonisolated(unsafe) private var testStartTime: CFAbsoluteTime?
  private let maxTestDuration: TimeInterval = 300  // 5 minutes per acceptance criteria

  // MARK: - Environment Configuration

  private var baseLaunchEnvironment: [String: String] {
    [
      "UITEST_SWIPE_DEBUG": "1",
      "UITEST_USER_DEFAULTS_SUITE": swipeDefaultsSuite,
    ]
  }

  func launchEnvironment(reset: Bool) -> [String: String] {
    var environment = baseLaunchEnvironment
    let shouldReset = reset || seededConfigurationPayload != nil
    environment["UITEST_RESET_SWIPE_SETTINGS"] = shouldReset ? "1" : "0"
    if let payload = seededConfigurationPayload {
      environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] = payload
    }
    return environment
  }

  // MARK: - XCTest Hooks

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
    testStartTime = CFAbsoluteTimeGetCurrent()
  }

  override func tearDownWithError() throws {
    if let start = testStartTime {
      let elapsed = CFAbsoluteTimeGetCurrent() - start
      if elapsed > maxTestDuration {
        XCTFail(
          String(
            format: "Swipe test exceeded %0.1f seconds (actual %0.1f)",
            maxTestDuration,
            elapsed
          )
        )
      }
    }
    app = nil
    try super.tearDownWithError()
  }
}
