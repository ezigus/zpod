//
//  DownloadTransitionTestHelper.swift
//  zpodUITests
//
//  Created for Issue 28.1.13: Download Transition Hooks
//  Provides notification-based hooks for testing download state transitions
//

import Foundation
import XCTest

/// Helper for capturing download transition events during UI tests
///
/// **Usage**:
/// 1. Set `UITEST_DOWNLOAD_TRANSITIONS=1` in launch environment
/// 2. Create helper: `let helper = DownloadTransitionTestHelper()`
/// 3. Wait for transitions: `helper.waitForDownloadStart(timeout: 5)`
///
/// **Pattern**: Follows the notification-based hook pattern from AGENTS.md
/// - Notifications are always posted by app code (zero cost when unlistened)
/// - Test helper conditionally listens when environment flag is set
/// - Enables deterministic testing of state transitions
final class DownloadTransitionTestHelper {
  private var startObserver: NSObjectProtocol?
  private var cancelObserver: NSObjectProtocol?
  private var resumeObserver: NSObjectProtocol?

  private var startExpectation: XCTestExpectation?
  private var cancelExpectation: XCTestExpectation?
  private var resumeExpectation: XCTestExpectation?

  private var capturedEpisodeIds: [String] = []

  init() {
    // Only listen if environment flag is set
    guard ProcessInfo.processInfo.environment["UITEST_DOWNLOAD_TRANSITIONS"] == "1" else {
      return
    }

    // Listen for download start
    startObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name("LibraryFeature.DownloadDidStart"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      if let episodeId = notification.userInfo?["episodeId"] as? String {
        self?.capturedEpisodeIds.append(episodeId)
      }
      self?.startExpectation?.fulfill()
    }

    // Listen for download cancel
    cancelObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name("LibraryFeature.DownloadDidCancel"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      if let episodeId = notification.userInfo?["episodeId"] as? String {
        self?.capturedEpisodeIds.append(episodeId)
      }
      self?.cancelExpectation?.fulfill()
    }

    // Listen for download resume
    resumeObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name("LibraryFeature.DownloadDidResume"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      if let episodeId = notification.userInfo?["episodeId"] as? String {
        self?.capturedEpisodeIds.append(episodeId)
      }
      self?.resumeExpectation?.fulfill()
    }
  }

  deinit {
    if let startObserver {
      NotificationCenter.default.removeObserver(startObserver)
    }
    if let cancelObserver {
      NotificationCenter.default.removeObserver(cancelObserver)
    }
    if let resumeObserver {
      NotificationCenter.default.removeObserver(resumeObserver)
    }
  }

  /// Wait for download to start
  @discardableResult
  func waitForDownloadStart(timeout: TimeInterval = 5.0) -> XCTWaiter.Result {
    startExpectation = XCTestExpectation(description: "Download started")
    return XCTWaiter().wait(for: [startExpectation!], timeout: timeout)
  }

  /// Wait for download to be cancelled
  @discardableResult
  func waitForDownloadCancel(timeout: TimeInterval = 5.0) -> XCTWaiter.Result {
    cancelExpectation = XCTestExpectation(description: "Download cancelled")
    return XCTWaiter().wait(for: [cancelExpectation!], timeout: timeout)
  }

  /// Wait for download to resume
  @discardableResult
  func waitForDownloadResume(timeout: TimeInterval = 5.0) -> XCTWaiter.Result {
    resumeExpectation = XCTestExpectation(description: "Download resumed")
    return XCTWaiter().wait(for: [resumeExpectation!], timeout: timeout)
  }

  /// Get captured episode IDs (for verification)
  var episodeIds: [String] {
    capturedEpisodeIds
  }

  /// Reset captured state
  func reset() {
    capturedEpisodeIds.removeAll()
  }
}
