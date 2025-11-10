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
  nonisolated(unsafe) internal var lastSwipeExecutionTimestamp: TimeInterval = 0
  private let maxTestDuration: TimeInterval = 300  // 5 minutes per acceptance criteria

  // MARK: - Environment Configuration

  private var baseLaunchEnvironment: [String: String] {
    [
      "UITEST_SWIPE_DEBUG": "1",
      "UITEST_USER_DEFAULTS_SUITE": swipeDefaultsSuite,
      "UITEST_STUB_PLAYLIST_SHEET": "1",
      "UITEST_AUTO_SCROLL_PRESETS": "1",
      "UITEST_SWIPE_PRELOAD_SECTIONS": "1",
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
    lastSwipeExecutionTimestamp = 0
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

  func latestSwipeExecutionRecord() -> SwipeExecutionRecord? {
    let executionProbe = app.staticTexts["SwipeActions.Debug.LastExecution"]
    guard executionProbe.exists else { return nil }
    guard let rawValue = executionProbe.value as? String, !rawValue.isEmpty else {
      return nil
    }
    return parseSwipeExecutionRecord(from: rawValue)
  }

  @MainActor
  @discardableResult
  func waitForSwipeExecution(
    action expectedAction: String,
    timeout: TimeInterval = 5.0
  ) -> SwipeExecutionRecord? {
    let deadline = CFAbsoluteTimeGetCurrent() + timeout
    var lastObservedRecord: SwipeExecutionRecord?

    while CFAbsoluteTimeGetCurrent() < deadline {
      if let record = latestSwipeExecutionRecord() {
        lastObservedRecord = record
        if record.action == expectedAction, record.timestamp > lastSwipeExecutionTimestamp {
          lastSwipeExecutionTimestamp = record.timestamp
          return record
        }
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    if let record = lastObservedRecord {
      let attachment = XCTAttachment(
        string:
          "Last recorded swipe action: \(record.action) for episode \(record.episodeID) at \(record.timestamp)"
      )
      attachment.lifetime = .keepAlways
      add(attachment)
    } else {
      let attachment = XCTAttachment(string: "No swipe execution was recorded")
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    XCTFail("Expected swipe action \(expectedAction) to execute within \(timeout) seconds")
    return nil
  }
}

struct SwipeExecutionRecord {
  let action: String
  let episodeID: String
  let timestamp: TimeInterval
}

extension SwipeConfigurationTestCase {
  fileprivate func parseSwipeExecutionRecord(from rawValue: String) -> SwipeExecutionRecord? {
    var action: String?
    var episodeID: String?
    var timestamp: TimeInterval?

    for component in rawValue.split(separator: ";") {
      let pair = component.split(separator: "=", maxSplits: 1).map { String($0) }
      guard pair.count == 2 else { continue }
      switch pair[0] {
      case "action":
        action = pair[1]
      case "episode":
        episodeID = pair[1]
      case "timestamp":
        if let value = TimeInterval(pair[1]) {
          timestamp = value
        }
      default:
        continue
      }
    }

    guard let action, let episodeID, let timestamp else { return nil }
    return SwipeExecutionRecord(action: action, episodeID: episodeID, timestamp: timestamp)
  }
}
