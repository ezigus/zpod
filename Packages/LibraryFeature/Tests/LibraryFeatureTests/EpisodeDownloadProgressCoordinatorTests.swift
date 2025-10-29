//
//  EpisodeDownloadProgressCoordinatorTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Tests for download progress coordination
//

import XCTest
import Combine
@testable import LibraryFeature
import CoreModels

final class EpisodeDownloadProgressCoordinatorTests: XCTestCase {
  
  private var coordinator: EpisodeDownloadProgressCoordinator!
  private var mockProgressProvider: MockDownloadProgressProvider!
  private var updatedEpisodes: [Episode] = []
  private var testEpisode: Episode!
  
  @MainActor
  override func setUpWithError() throws {
    continueAfterFailure = false
    
    testEpisode = Episode(
      id: "test-episode-1",
      title: "Test Episode",
      podcastID: "test-podcast",
      pubDate: Date(),
      duration: 1800,
      description: "Test description"
    )
    
    updatedEpisodes = []
    mockProgressProvider = MockDownloadProgressProvider()
    
    coordinator = EpisodeDownloadProgressCoordinator(
      downloadProgressProvider: mockProgressProvider,
      episodeLookup: { [weak self] id in
        guard let self = self else { return nil }
        return id == self.testEpisode.id ? self.testEpisode : nil
      },
      episodeUpdateHandler: { [weak self] episode in
        self?.updatedEpisodes.append(episode)
      }
    )
  }
  
  @MainActor
  override func tearDownWithError() throws {
    coordinator.stopMonitoring()
    coordinator = nil
    mockProgressProvider = nil
    updatedEpisodes = []
    testEpisode = nil
  }
  
  // MARK: - Download Progress Tests
  
  @MainActor
  func testDownloadProgressInitiallyEmpty() {
    // Given: A new coordinator
    // When: Checking initial state
    // Then: Progress dictionary should be empty
    XCTAssertTrue(coordinator.downloadProgressByEpisodeID.isEmpty)
    XCTAssertNil(coordinator.downloadProgress(for: testEpisode.id))
  }
  
  @MainActor
  func testStartMonitoringReceivesProgressUpdates() async throws {
    // Given: A coordinator ready to monitor
    let expectation = expectation(description: "Progress update received")
    
    // When: Starting monitoring and sending a progress update
    coordinator.startMonitoring()
    
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 0.5,
      status: .downloading,
      message: "Downloading"
    )
    
    mockProgressProvider.sendProgress(update)
    
    // Then: Progress should be tracked
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    let progress = coordinator.downloadProgress(for: testEpisode.id)
    XCTAssertNotNil(progress)
    XCTAssertEqual(progress?.fractionCompleted, 0.5)
    XCTAssertEqual(progress?.status, .downloading)
    
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 1.0)
  }
  
  @MainActor
  func testDownloadProgressUpdatesEpisodeStatus() async throws {
    // Given: A coordinator monitoring progress
    coordinator.startMonitoring()
    
    // When: Sending a downloading progress update
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 0.3,
      status: .downloading,
      message: "Downloading"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Episode should be updated with downloading status
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertEqual(updatedEpisodes.last?.downloadStatus, .downloading)
  }
  
  @MainActor
  func testDownloadCompletedUpdatesEpisodeStatus() async throws {
    // Given: A coordinator monitoring progress
    coordinator.startMonitoring()
    
    // When: Sending a completed progress update
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 1.0,
      status: .completed,
      message: "Complete"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Episode should be updated with downloaded status
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertEqual(updatedEpisodes.last?.downloadStatus, .downloaded)
  }
  
  @MainActor
  func testDownloadFailedUpdatesEpisodeStatus() async throws {
    // Given: A coordinator monitoring progress
    coordinator.startMonitoring()
    
    // When: Sending a failed progress update
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 0.7,
      status: .failed,
      message: "Failed"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Episode should be updated with failed status
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertEqual(updatedEpisodes.last?.downloadStatus, .failed)
  }
  
  @MainActor
  func testDownloadPausedUpdatesEpisodeStatus() async throws {
    // Given: A coordinator monitoring progress
    coordinator.startMonitoring()
    
    // When: Sending a paused progress update
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 0.6,
      status: .paused,
      message: "Paused"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Episode should be updated with paused status
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertEqual(updatedEpisodes.last?.downloadStatus, .paused)
  }
  
  @MainActor
  func testProgressClearedAfterCompletion() async throws {
    // Given: A coordinator monitoring progress with a completed download
    coordinator.startMonitoring()
    
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 1.0,
      status: .completed,
      message: "Complete"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Progress should exist initially
    XCTAssertNotNil(coordinator.downloadProgress(for: testEpisode.id))
    
    // When: Waiting for auto-clear delay (1.5 seconds)
    try await Task.sleep(nanoseconds: 2_000_000_000)
    
    // Then: Progress should be cleared
    XCTAssertNil(coordinator.downloadProgress(for: testEpisode.id))
  }
  
  @MainActor
  func testStopMonitoringStopsReceivingUpdates() async throws {
    // Given: A coordinator that was monitoring
    coordinator.startMonitoring()
    
    // When: Stopping monitoring
    coordinator.stopMonitoring()
    
    // And: Sending a progress update
    let update = EpisodeDownloadProgressUpdate(
      episodeID: testEpisode.id,
      fractionCompleted: 0.5,
      status: .downloading,
      message: "Downloading"
    )
    
    mockProgressProvider.sendProgress(update)
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Progress should not be tracked
    XCTAssertNil(coordinator.downloadProgress(for: testEpisode.id))
    XCTAssertTrue(updatedEpisodes.isEmpty)
  }
  
  @MainActor
  func testNilProviderDoesNotCrash() {
    // Given: A coordinator with no progress provider
    let nilCoordinator = EpisodeDownloadProgressCoordinator(
      downloadProgressProvider: nil,
      episodeLookup: { _ in nil },
      episodeUpdateHandler: { _ in }
    )
    
    // When: Starting monitoring
    nilCoordinator.startMonitoring()
    
    // Then: Should not crash and progress should be empty
    XCTAssertTrue(nilCoordinator.downloadProgressByEpisodeID.isEmpty)
    XCTAssertNil(nilCoordinator.downloadProgress(for: testEpisode.id))
  }
}

// MARK: - Mock Download Progress Provider

private class MockDownloadProgressProvider: DownloadProgressProviding {
  private let progressSubject = PassthroughSubject<EpisodeDownloadProgressUpdate, Never>()
  
  var progressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> {
    progressSubject.eraseToAnyPublisher()
  }
  
  func sendProgress(_ update: EpisodeDownloadProgressUpdate) {
    progressSubject.send(update)
  }
}
