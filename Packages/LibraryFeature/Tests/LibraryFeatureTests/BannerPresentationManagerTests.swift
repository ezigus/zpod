//
//  BannerPresentationManagerTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Tests for banner presentation management
//

import XCTest
@testable import LibraryFeature
import CoreModels

final class BannerPresentationManagerTests: XCTestCase {
  
  private var manager: BannerPresentationManager!
  private var retryCallbacks: [String] = []
  private var undoCallbacks: [String] = []
  
  @MainActor
  override func setUpWithError() throws {
    continueAfterFailure = false
    retryCallbacks = []
    undoCallbacks = []
    
    manager = BannerPresentationManager(
      autoDismissDelay: 0.5, // Short delay for testing
      retryHandler: { [weak self] operationID in
        self?.retryCallbacks.append(operationID)
      },
      undoHandler: { [weak self] operationID in
        self?.undoCallbacks.append(operationID)
      }
    )
  }
  
  @MainActor
  override func tearDownWithError() throws {
    manager.dismissBanner()
    manager = nil
    retryCallbacks = []
    undoCallbacks = []
  }
  
  // MARK: - Banner Presentation Tests
  
  @MainActor
  func testBannerStateInitiallyNil() {
    // Given: A new banner manager
    // When: Checking initial state
    // Then: Banner state should be nil
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testPresentBannerForSuccessfulOperation() {
    // Given: A completed batch operation
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1", "ep2", "ep3"]
    ).withStatus(.completed)
      .withCompletedCount(3)
    
    // When: Presenting a banner
    manager.presentBanner(for: operation)
    
    // Then: Banner should be displayed with success style
    XCTAssertNotNil(manager.bannerState)
    XCTAssertEqual(manager.bannerState?.title, "Mark as Played Complete")
    XCTAssertTrue(manager.bannerState?.subtitle.contains("3 succeeded") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .success)
  }
  
  @MainActor
  func testPresentBannerForFailedOperation() {
    // Given: A failed batch operation
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1", "ep2"]
    ).withStatus(.failed)
      .withCompletedCount(0)
      .withFailedCount(2)
    
    // When: Presenting a banner
    manager.presentBanner(for: operation)
    
    // Then: Banner should be displayed with failure style
    XCTAssertNotNil(manager.bannerState)
    XCTAssertEqual(manager.bannerState?.title, "Download Failed")
    XCTAssertTrue(manager.bannerState?.subtitle.contains("2 failed") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .failure)
  }
  
  @MainActor
  func testPresentBannerForPartiallySuccessfulOperation() {
    // Given: A batch operation with mixed results
    let operation = BatchOperation(
      operationType: .favorite,
      episodeIDs: ["ep1", "ep2", "ep3", "ep4"]
    ).withStatus(.completed)
      .withCompletedCount(3)
      .withFailedCount(1)
    
    // When: Presenting a banner
    manager.presentBanner(for: operation)
    
    // Then: Banner should show both succeeded and failed counts
    XCTAssertNotNil(manager.bannerState)
    XCTAssertTrue(manager.bannerState?.subtitle.contains("3 succeeded") ?? false)
    XCTAssertTrue(manager.bannerState?.subtitle.contains("1 failed") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .failure) // Failure if any failed
  }
  
  @MainActor
  func testPresentBannerWithRetryAction() {
    // Given: A failed batch operation
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1"]
    ).withStatus(.failed)
      .withFailedCount(1)
    
    // When: Presenting a banner and invoking retry
    manager.presentBanner(for: operation)
    
    guard let retryAction = manager.bannerState?.retry else {
      XCTFail("Retry action should be present for failed operations")
      return
    }
    
    retryAction()
    
    // Then: Retry callback should be invoked
    // Note: Callback is async, so we need to wait
    let expectation = expectation(description: "Retry callback")
    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertFalse(self.retryCallbacks.isEmpty)
      XCTAssertEqual(self.retryCallbacks.first, operation.id)
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  @MainActor
  func testPresentBannerWithUndoActionForReversibleOperation() {
    // Given: A completed reversible batch operation
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1", "ep2"]
    ).withStatus(.completed)
      .withCompletedCount(2)
    
    // When: Presenting a banner and invoking undo
    manager.presentBanner(for: operation)
    
    guard let undoAction = manager.bannerState?.undo else {
      XCTFail("Undo action should be present for reversible operations")
      return
    }
    
    undoAction()
    
    // Then: Undo callback should be invoked
    let expectation = expectation(description: "Undo callback")
    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertFalse(self.undoCallbacks.isEmpty)
      XCTAssertEqual(self.undoCallbacks.first, operation.id)
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  @MainActor
  func testPresentBannerWithNoActionsForNonReversibleOperation() {
    // Given: A completed non-reversible batch operation with all successes
    let operation = BatchOperation(
      operationType: .delete,
      episodeIDs: ["ep1"]
    ).withStatus(.completed)
      .withCompletedCount(1)
    
    // When: Presenting a banner
    manager.presentBanner(for: operation)
    
    // Then: No retry or undo actions should be present
    XCTAssertNil(manager.bannerState?.retry)
    XCTAssertNil(manager.bannerState?.undo)
  }
  
  @MainActor
  func testDismissBanner() {
    // Given: A displayed banner
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    ).withStatus(.completed)
      .withCompletedCount(1)
    
    manager.presentBanner(for: operation)
    XCTAssertNotNil(manager.bannerState)
    
    // When: Dismissing the banner
    manager.dismissBanner()
    
    // Then: Banner state should be nil
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testBannerAutoDismissesAfterDelay() async throws {
    // Given: A displayed banner with auto-dismiss
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    ).withStatus(.completed)
      .withCompletedCount(1)
    
    // When: Presenting a banner
    manager.presentBanner(for: operation)
    XCTAssertNotNil(manager.bannerState)
    
    // Then: Banner should still exist immediately
    XCTAssertNotNil(manager.bannerState)
    
    // When: Waiting for auto-dismiss delay
    try await Task.sleep(nanoseconds: 700_000_000) // 0.7s (delay is 0.5s)
    
    // Then: Banner should be dismissed
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testPresentingNewBannerCancelsPreviousAutoDismiss() async throws {
    // Given: A displayed banner
    let firstOperation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    ).withStatus(.completed)
      .withCompletedCount(1)
    
    manager.presentBanner(for: firstOperation)
    let firstBannerTitle = manager.bannerState?.title
    
    // When: Presenting a second banner before auto-dismiss
    try await Task.sleep(nanoseconds: 200_000_000) // 0.2s < 0.5s delay
    
    let secondOperation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep2"]
    ).withStatus(.completed)
      .withCompletedCount(1)
    
    manager.presentBanner(for: secondOperation)
    let secondBannerTitle = manager.bannerState?.title
    
    // Then: Second banner should be displayed
    XCTAssertNotEqual(firstBannerTitle, secondBannerTitle)
    XCTAssertNotNil(manager.bannerState)
    
    // And: Second banner should auto-dismiss on its own schedule
    try await Task.sleep(nanoseconds: 700_000_000) // 0.7s total
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testEmptyOperationDoesNotPresentBanner() {
    // Given: An empty batch operation
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: []
    ).withStatus(.completed)
    
    // When: Attempting to present a banner
    manager.presentBanner(for: operation)
    
    // Then: No banner should be displayed
    XCTAssertNil(manager.bannerState)
  }
}
