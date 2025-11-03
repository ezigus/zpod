#if os(iOS)
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
  
  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    retryCallbacks = []
    undoCallbacks = []
    
    manager = await BannerPresentationManager(
      autoDismissDelay: 0.5, // Short delay for testing
      retryHandler: { [weak self] operationID in
        self?.retryCallbacks.append(operationID)
      },
      undoHandler: { [weak self] operationID in
        self?.undoCallbacks.append(operationID)
      }
    )
  }
  
  override func tearDown() async throws {
    await manager.dismissBanner()
    manager = nil
    retryCallbacks = []
    undoCallbacks = []
    try await super.tearDown()
  }
  
  // MARK: - Banner Presentation Tests
  
  @MainActor
  func testBannerStateInitiallyNil() {
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testPresentBannerForSuccessfulOperation() {
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1", "ep2", "ep3"]
    )
    .withCompleted(3, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNotNil(manager.bannerState)
    XCTAssertEqual(manager.bannerState?.title, "Mark as Played Complete")
    XCTAssertTrue(manager.bannerState?.subtitle.contains("3 succeeded") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .success)
  }
  
  @MainActor
  func testPresentBannerForFailedOperation() {
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1", "ep2"]
    )
    .withCompleted(0, failed: 2)
    .withStatus(.failed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNotNil(manager.bannerState)
    XCTAssertEqual(manager.bannerState?.title, "Download Failed")
    XCTAssertTrue(manager.bannerState?.subtitle.contains("2 failed") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .failure)
  }
  
  @MainActor
  func testPresentBannerForPartiallySuccessfulOperation() {
    let operation = BatchOperation(
      operationType: .favorite,
      episodeIDs: ["ep1", "ep2", "ep3", "ep4"]
    )
    .withCompleted(3, failed: 1)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNotNil(manager.bannerState)
    XCTAssertTrue(manager.bannerState?.subtitle.contains("3 succeeded") ?? false)
    XCTAssertTrue(manager.bannerState?.subtitle.contains("1 failed") ?? false)
    XCTAssertEqual(manager.bannerState?.style, .failure)
  }
  
  @MainActor
  func testPresentBannerWithRetryAction() {
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1"]
    )
    .withCompleted(0, failed: 1)
    .withStatus(.failed)
    
    manager.presentBanner(for: operation)
    
    guard let retryAction = manager.bannerState?.retry else {
      XCTFail("Retry action should be present for failed operations")
      return
    }
    
    let expectation = expectation(description: "Retry callback invoked")
    retryAction()
    
    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertEqual(self.retryCallbacks.first, operation.id)
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  @MainActor
  func testPresentBannerWithUndoAction() {
    let operation = BatchOperation(
      operationType: .favorite,
      episodeIDs: ["ep1", "ep2"]
    )
    .withCompleted(2, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    guard let undoAction = manager.bannerState?.undo else {
      XCTFail("Undo action should be present for reversible operations")
      return
    }
    
    let expectation = expectation(description: "Undo callback invoked")
    undoAction()
    
    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertEqual(self.undoCallbacks.first, operation.id)
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  @MainActor
  func testPresentBannerWithNoActionsForNonReversibleOperation() {
    let operation = BatchOperation(
      operationType: .delete,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNil(manager.bannerState?.retry)
    XCTAssertNil(manager.bannerState?.undo)
  }
  
  @MainActor
  func testDismissBanner() {
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    XCTAssertNotNil(manager.bannerState)
    
    manager.dismissBanner()
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testBannerAutoDismissesAfterDelay() async throws {
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    XCTAssertNotNil(manager.bannerState)
    
    try await Task.sleep(nanoseconds: 700_000_000)
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testPresentingNewBannerCancelsPreviousAutoDismiss() async throws {
    let firstOperation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: firstOperation)
    let firstTitle = manager.bannerState?.title
    
    try await Task.sleep(nanoseconds: 200_000_000)
    
    let secondOperation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep2"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: secondOperation)
    let secondTitle = manager.bannerState?.title
    
    XCTAssertNotEqual(firstTitle, secondTitle)
    
    try await Task.sleep(nanoseconds: 700_000_000)
    XCTAssertNil(manager.bannerState)
  }
  
  @MainActor
  func testPartialSuccessBannerIncludesRetryAndUndo() {
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1", "ep2", "ep3", "ep4"]
    )
    .withCompleted(3, failed: 1)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNotNil(manager.bannerState?.retry)
    XCTAssertNotNil(manager.bannerState?.undo)
  }
  
  @MainActor
  func testFailureBannerOnlyHasRetry() {
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1"]
    )
    .withCompleted(0, failed: 1)
    .withStatus(.failed)
    
    manager.presentBanner(for: operation)
    
    XCTAssertNotNil(manager.bannerState?.retry)
    XCTAssertNil(manager.bannerState?.undo)
  }
  
  @MainActor
  func testUndoOnlyForReversibleOperations() {
    let reversible = BatchOperation(
      operationType: .favorite,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: reversible)
    XCTAssertNotNil(manager.bannerState?.undo)
    
    let irreversible = BatchOperation(
      operationType: .delete,
      episodeIDs: ["ep1"]
    )
    .withCompleted(1, failed: 0)
    .withStatus(.completed)
    
    manager.presentBanner(for: irreversible)
    XCTAssertNil(manager.bannerState?.undo)
  }
  
  @MainActor
  func testPresentBannerForMixedResultsIncludesBothCounts() {
    let operation = BatchOperation(
      operationType: .download,
      episodeIDs: ["ep1", "ep2", "ep3"]
    )
    .withCompleted(1, failed: 2)
    .withStatus(.completed)
    
    manager.presentBanner(for: operation)
    
    let subtitle = manager.bannerState?.subtitle ?? ""
    XCTAssertTrue(subtitle.contains("1 succeeded"))
    XCTAssertTrue(subtitle.contains("2 failed"))
  }
  
  @MainActor
  func testEmptyOperationDoesNotPresentBanner() {
    let operation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: []
    ).withStatus(.completed)
    
    manager.presentBanner(for: operation)
    XCTAssertNil(manager.bannerState)
  }
}

private extension BatchOperation {
  func withCompleted(_ completed: Int, failed: Int) -> BatchOperation {
    var copy = self
    for index in copy.operations.indices {
      if index < completed {
        copy.operations[index] = copy.operations[index].withStatus(.completed)
      } else if index < completed + failed {
        copy.operations[index] = copy.operations[index].withStatus(.failed)
      } else {
        copy.operations[index] = copy.operations[index].withStatus(.pending)
      }
    }
    return copy
  }
}

#endif
