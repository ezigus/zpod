#if os(iOS)
//
//  BatchOperationTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.1.3: Batch Operations and Episode Status Management
//

import XCTest
import CombineSupport
@testable import LibraryFeature
@testable import CoreModels
@testable import PlaybackEngine

final class BatchOperationTests: XCTestCase {
    var batchOperationManager: BatchOperationManager!
    var mockEpisodeStateManager: MockEpisodeStateManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockEpisodeStateManager = MockEpisodeStateManager()
        batchOperationManager = BatchOperationManager(episodeStateManager: mockEpisodeStateManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        batchOperationManager = nil
        mockEpisodeStateManager = nil
    }
    
    // MARK: - Batch Operation Creation Tests
    
    func testBatchOperationCreation() throws {
        // Given
        let episodeIDs = ["ep1", "ep2", "ep3"]
        let operationType = BatchOperationType.markAsPlayed
        
        // When
        let batchOperation = BatchOperation(
            operationType: operationType,
            episodeIDs: episodeIDs
        )
        
        // Then
        XCTAssertEqual(batchOperation.operationType, operationType)
        XCTAssertEqual(batchOperation.operations.count, 3)
        XCTAssertEqual(batchOperation.status, .pending)
        XCTAssertEqual(batchOperation.totalCount, 3)
        XCTAssertEqual(batchOperation.completedCount, 0)
        XCTAssertEqual(batchOperation.progress, 0.0)
        
        // Verify all episode operations are created correctly
        for (index, operation) in batchOperation.operations.enumerated() {
            XCTAssertEqual(operation.episodeID, episodeIDs[index])
            XCTAssertEqual(operation.operationType, operationType)
            XCTAssertEqual(operation.status, .pending)
        }
    }
    
    // MARK: - Batch Operation Execution Tests
    
    @MainActor
    func testSuccessfulBatchOperationExecution() async throws {
        // Given
        let episodeIDs = ["ep1", "ep2"]
        let batchOperation = BatchOperation(
            operationType: .markAsPlayed,
            episodeIDs: episodeIDs
        )
        
        var receivedUpdates: [BatchOperation] = []
        let expectation = expectation(description: "Batch operation updates")
        expectation.expectedFulfillmentCount = 3 // Running + 2 progress updates + completed
        
        batchOperationManager.batchOperationUpdates
            .sink { update in
                receivedUpdates.append(update)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        let result = try await batchOperationManager.executeBatchOperation(batchOperation)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.completedCount, 2)
        XCTAssertEqual(result.progress, 1.0)
        XCTAssertTrue(receivedUpdates.count >= 3)
        
        // Verify the final state
        let activeBatchOperations = await batchOperationManager.getActiveBatchOperations()
        XCTAssertTrue(activeBatchOperations.isEmpty)
    }
    
    @MainActor
    func testBatchOperationCancellation() async throws {
        // Given
        let episodeIDs = ["ep1", "ep2", "ep3"]
        let batchOperation = BatchOperation(
            operationType: .download,
            episodeIDs: episodeIDs
        )
        
        let expectation = expectation(description: "Batch operation cancelled")
        
        batchOperationManager.batchOperationUpdates
            .sink { update in
                if update.status == .cancelled {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        Task {
            do {
                let _ = try await batchOperationManager.executeBatchOperation(batchOperation)
            } catch {
                // Expected to be cancelled
            }
        }
        
        // Cancel immediately
        await batchOperationManager.cancelBatchOperation(id: batchOperation.id)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        
        let activeBatchOperations = await batchOperationManager.getActiveBatchOperations()
        XCTAssertTrue(activeBatchOperations.isEmpty)
    }
    
    // MARK: - Episode Selection Tests
    
    func testEpisodeSelectionState() throws {
        // Given
        var selectionState = EpisodeSelectionState()
        
        // When entering multi-select mode
        selectionState.enterMultiSelectMode()
        
        // Then
        XCTAssertTrue(selectionState.isMultiSelectMode)
        XCTAssertFalse(selectionState.hasSelection)
        XCTAssertEqual(selectionState.selectedCount, 0)
        
        // When selecting episodes
        selectionState.toggleSelection(for: "ep1")
        selectionState.toggleSelection(for: "ep2")
        
        // Then
        XCTAssertTrue(selectionState.hasSelection)
        XCTAssertEqual(selectionState.selectedCount, 2)
        XCTAssertTrue(selectionState.isSelected("ep1"))
        XCTAssertTrue(selectionState.isSelected("ep2"))
        XCTAssertFalse(selectionState.isSelected("ep3"))
        
        // When deselecting an episode
        selectionState.toggleSelection(for: "ep1")
        
        // Then
        XCTAssertEqual(selectionState.selectedCount, 1)
        XCTAssertFalse(selectionState.isSelected("ep1"))
        XCTAssertTrue(selectionState.isSelected("ep2"))
        
        // When exiting multi-select mode
        selectionState.exitMultiSelectMode()
        
        // Then
        XCTAssertFalse(selectionState.isMultiSelectMode)
        XCTAssertFalse(selectionState.hasSelection)
        XCTAssertEqual(selectionState.selectedCount, 0)
    }
    
    func testSelectAllAndSelectNone() throws {
        // Given
        var selectionState = EpisodeSelectionState()
        selectionState.enterMultiSelectMode()
        let episodeIDs = ["ep1", "ep2", "ep3", "ep4"]
        
        // When selecting all
        selectionState.selectAll(episodeIDs: episodeIDs)
        
        // Then
        XCTAssertEqual(selectionState.selectedCount, 4)
        for episodeID in episodeIDs {
            XCTAssertTrue(selectionState.isSelected(episodeID))
        }
        
        // When selecting none
        selectionState.selectNone()
        
        // Then
        XCTAssertEqual(selectionState.selectedCount, 0)
        for episodeID in episodeIDs {
            XCTAssertFalse(selectionState.isSelected(episodeID))
        }
    }
    
    func testInvertSelection() throws {
        // Given
        var selectionState = EpisodeSelectionState()
        selectionState.enterMultiSelectMode()
        let episodeIDs = ["ep1", "ep2", "ep3", "ep4"]
        
        // Select some episodes
        selectionState.toggleSelection(for: "ep1")
        selectionState.toggleSelection(for: "ep3")
        
        // When inverting selection
        selectionState.invertSelection(allEpisodeIDs: episodeIDs)
        
        // Then
        XCTAssertEqual(selectionState.selectedCount, 2)
        XCTAssertFalse(selectionState.isSelected("ep1"))
        XCTAssertTrue(selectionState.isSelected("ep2"))
        XCTAssertFalse(selectionState.isSelected("ep3"))
        XCTAssertTrue(selectionState.isSelected("ep4"))
    }
    
    // MARK: - Episode Selection Criteria Tests
    
    func testEpisodeSelectionCriteriaMatching() throws {
        // Given
        let playedEpisode = Episode(
            id: "played",
            title: "Played Episode",
            isPlayed: true,
            pubDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()),
            duration: 1800, // 30 minutes
            downloadStatus: .downloaded,
            isFavorited: true
        )
        
        let unplayedEpisode = Episode(
            id: "unplayed",
            title: "Unplayed Episode",
            pubDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            duration: 3600, // 60 minutes
            downloadStatus: .notDownloaded,
            isFavorited: false
        )
        
        let inProgressEpisode = Episode(
            id: "progress",
            title: "In Progress Episode",
            playbackPosition: 900, // 15 minutes
            pubDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            duration: 1800, // 30 minutes
            downloadStatus: .downloading
        )
        
        // Test play status criteria
        var criteria = EpisodeSelectionCriteria()
        criteria.playStatus = .played
        XCTAssertTrue(criteria.matches(episode: playedEpisode))
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode))
        XCTAssertFalse(criteria.matches(episode: inProgressEpisode))
        
        criteria.playStatus = .unplayed
        XCTAssertFalse(criteria.matches(episode: playedEpisode))
        XCTAssertTrue(criteria.matches(episode: unplayedEpisode))
        XCTAssertFalse(criteria.matches(episode: inProgressEpisode))
        
        criteria.playStatus = .inProgress
        XCTAssertFalse(criteria.matches(episode: playedEpisode))
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode))
        XCTAssertTrue(criteria.matches(episode: inProgressEpisode))
        
        // Test download status criteria
        criteria = EpisodeSelectionCriteria()
        criteria.downloadStatus = .downloaded
        XCTAssertTrue(criteria.matches(episode: playedEpisode))
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode))
        XCTAssertFalse(criteria.matches(episode: inProgressEpisode))
        
        // Test date criteria
        criteria = EpisodeSelectionCriteria()
        criteria.olderThanDays = 7
        XCTAssertTrue(criteria.matches(episode: playedEpisode)) // 10 days old
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode)) // 5 days old
        XCTAssertFalse(criteria.matches(episode: inProgressEpisode)) // 2 days old
        
        criteria = EpisodeSelectionCriteria()
        criteria.newerThanDays = 3
        XCTAssertFalse(criteria.matches(episode: playedEpisode)) // 10 days old
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode)) // 5 days old
        XCTAssertTrue(criteria.matches(episode: inProgressEpisode)) // 2 days old
        
        // Test duration criteria
        criteria = EpisodeSelectionCriteria()
        criteria.minimumDuration = 3000 // 50 minutes
        XCTAssertFalse(criteria.matches(episode: playedEpisode)) // 30 minutes
        XCTAssertTrue(criteria.matches(episode: unplayedEpisode)) // 60 minutes
        XCTAssertFalse(criteria.matches(episode: inProgressEpisode)) // 30 minutes
        
        // Test favorite status criteria
        criteria = EpisodeSelectionCriteria()
        criteria.favoriteStatus = true
        XCTAssertTrue(criteria.matches(episode: playedEpisode))
        XCTAssertFalse(criteria.matches(episode: unplayedEpisode))
    }
    
    // MARK: - Batch Operation Types Tests
    
    func testBatchOperationTypeProperties() {
        // Test display names
        XCTAssertEqual(BatchOperationType.download.displayName, "Download")
        XCTAssertEqual(BatchOperationType.markAsPlayed.displayName, "Mark as Played")
        XCTAssertEqual(BatchOperationType.delete.displayName, "Delete")
        
        // Test reversibility
        XCTAssertTrue(BatchOperationType.markAsPlayed.isReversible)
        XCTAssertTrue(BatchOperationType.archive.isReversible)
        XCTAssertFalse(BatchOperationType.delete.isReversible)
        XCTAssertFalse(BatchOperationType.share.isReversible)
        
        // Test system icons
        XCTAssertEqual(BatchOperationType.download.systemIcon, "arrow.down.circle")
        XCTAssertEqual(BatchOperationType.favorite.systemIcon, "heart")
        XCTAssertEqual(BatchOperationType.delete.systemIcon, "trash")
    }
    
    // MARK: - Progress and Status Tests
    
    func testBatchOperationProgress() {
        // Given
        let episodeIDs = ["ep1", "ep2", "ep3", "ep4"]
        var batchOperation = BatchOperation(
            operationType: .markAsPlayed,
            episodeIDs: episodeIDs
        )
        
        // Initially no progress
        XCTAssertEqual(batchOperation.progress, 0.0)
        XCTAssertEqual(batchOperation.completedCount, 0)
        XCTAssertEqual(batchOperation.failedCount, 0)
        
        // Complete first operation
        let completedOperation1 = batchOperation.operations[0].withStatus(.completed)
        batchOperation = batchOperation.withUpdatedOperation(completedOperation1)
        
        XCTAssertEqual(batchOperation.progress, 0.25)
        XCTAssertEqual(batchOperation.completedCount, 1)
        
        // Fail second operation
        let failedOperation2 = batchOperation.operations[1].withError("Network error")
        batchOperation = batchOperation.withUpdatedOperation(failedOperation2)
        
        XCTAssertEqual(batchOperation.progress, 0.5)
        XCTAssertEqual(batchOperation.completedCount, 1)
        XCTAssertEqual(batchOperation.failedCount, 1)
        
        // Complete remaining operations
        let completedOperation3 = batchOperation.operations[2].withStatus(.completed)
        let completedOperation4 = batchOperation.operations[3].withStatus(.completed)
        batchOperation = batchOperation.withUpdatedOperation(completedOperation3)
        batchOperation = batchOperation.withUpdatedOperation(completedOperation4)
        
        XCTAssertEqual(batchOperation.progress, 1.0)
        XCTAssertEqual(batchOperation.completedCount, 3)
        XCTAssertEqual(batchOperation.failedCount, 1)
        XCTAssertEqual(batchOperation.status, .completed)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testBatchOperationPerformance() async throws {
        // Given - Large batch operation
        let episodeIDs = (1...100).map { "episode-\($0)" }
        let batchOperation = BatchOperation(
            operationType: .markAsPlayed,
            episodeIDs: episodeIDs
        )
        
        // When - Measure execution time
        let startTime = Date()
        let result = try await batchOperationManager.executeBatchOperation(batchOperation)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then - Should complete within reasonable time
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.completedCount, 100)
        XCTAssertLessThan(executionTime, 30.0, "Batch operation should complete within 30 seconds")
    }
    
    // MARK: - Enhanced Batch Operation Features Tests
    
    @MainActor
    func testBatchOperationRetryFunctionality() async throws {
        // Given
        let episodeIDs = ["ep1", "ep2"]
        var batchOperation = BatchOperation(
            operationType: .download,
            episodeIDs: episodeIDs
        )
        
        // Simulate a failed operation
        batchOperation = batchOperation.withStatus(.failed)
        let failedOperation = batchOperation.operations[0].withStatus(.failed)
        batchOperation = batchOperation.withUpdatedOperation(failedOperation)
        
        // When
        let retryExpectation = expectation(description: "Retry operation")
        var retryUpdates: [BatchOperation] = []
        
        batchOperationManager.batchOperationUpdates
            .sink { update in
                retryUpdates.append(update)
                if update.status == .running {
                    retryExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Execute retry (simplified for test)
        let retryBatch = BatchOperation(
            operationType: batchOperation.operationType,
            episodeIDs: [failedOperation.episodeID]
        )
        let _ = try await batchOperationManager.executeBatchOperation(retryBatch)
        
        // Then
        await fulfillment(of: [retryExpectation], timeout: 5.0)
        XCTAssertTrue(retryUpdates.contains { $0.status == .running })
    }
    
    @MainActor
    func testReversibleBatchOperationProperties() throws {
        // Given
        let reversibleOperations: [BatchOperationType] = [
            .markAsPlayed, .markAsUnplayed, .favorite, .unfavorite, 
            .bookmark, .unbookmark, .archive
        ]
        let nonReversibleOperations: [BatchOperationType] = [
            .delete, .share, .download
        ]
        
        // When & Then
        for operation in reversibleOperations {
            XCTAssertTrue(operation.isReversible, "\(operation) should be reversible")
        }
        
        for operation in nonReversibleOperations {
            XCTAssertFalse(operation.isReversible, "\(operation) should not be reversible")
        }
    }
    
    @MainActor  
    func testBatchOperationUndoFunctionality() async throws {
        // Given
        let episodeIDs = ["ep1", "ep2"]
        let batchOperation = BatchOperation(
            operationType: .markAsPlayed,
            episodeIDs: episodeIDs
        )
        
        // When - Complete the original operation
        let completedBatch = try await batchOperationManager.executeBatchOperation(batchOperation)
        
        // Then - Verify it's marked as reversible
        XCTAssertTrue(completedBatch.operationType.isReversible)
        XCTAssertEqual(completedBatch.status, .completed)
        
        // When - Create undo operation
        let undoBatch = BatchOperation(
            operationType: .markAsUnplayed, // Reverse of markAsPlayed
            episodeIDs: episodeIDs
        )
        
        let undoResult = try await batchOperationManager.executeBatchOperation(undoBatch)
        
        // Then
        XCTAssertEqual(undoResult.status, .completed)
        XCTAssertEqual(undoResult.operationType, .markAsUnplayed)
    }
}

// MARK: - Mock Episode State Manager

class MockEpisodeStateManager: EpisodeStateManager, @unchecked Sendable {
    private let lock = NSLock()
    private var episodes: [String: Episode] = [:]
    
    func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
        lock.lock()
        defer { lock.unlock() }
        episodes[episode.id] = episode.withPlayedStatus(isPlayed)
    }
    
    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
        lock.lock()
        defer { lock.unlock() }
        episodes[episode.id] = episode.withPlaybackPosition(Int(position))
    }
    
    func getEpisodeState(_ episode: Episode) async -> Episode {
        lock.lock()
        defer { lock.unlock() }
        return episodes[episode.id] ?? episode
    }
}

#endif
