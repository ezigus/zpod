//
//  EpisodeListViewModel+BatchOperations.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts batch operation retry/undo logic from EpisodeListViewModel
//

import CoreModels
import Foundation
import OSLog

// MARK: - Batch Operation Helpers

@MainActor
extension EpisodeListViewModel {
  
  /// Retry a failed batch operation
  internal func retryBatchOperation(_ batchOperationId: String) async {
    // TODO: In a real implementation, this would retry the specific failed operations
    // For now, find the batch operation and restart failed operations
    if let batchIndex = activeBatchOperations.firstIndex(where: { $0.id == batchOperationId }) {
      let batchOperation = activeBatchOperations[batchIndex]
      let failedOperations = batchOperation.operations.filter { $0.status == .failed }

      if !failedOperations.isEmpty {
        // Restart the batch operation with only failed episodes
        let retryBatch = BatchOperation(
          operationType: batchOperation.operationType,
          episodeIDs: failedOperations.map { $0.episodeID },
          playlistID: batchOperation.playlistID
        )

        do {
          let _ = try await batchOperationManager.executeBatchOperation(retryBatch)
        } catch {
          Self.logger.error("Retry batch operation failed: \(error, privacy: .public)")
        }
      }
    }
  }

  /// Undo a completed batch operation if it's reversible
  internal func undoBatchOperation(_ batchOperationId: String) async {
    // TODO: In a real implementation, this would reverse the effects of the batch operation
    // For now, simulate the undo operation
    if let batchIndex = activeBatchOperations.firstIndex(where: { $0.id == batchOperationId }) {
      let batchOperation = activeBatchOperations[batchIndex]

      guard batchOperation.operationType.isReversible else { return }

      // Create reverse operation
      let reverseOperationType: BatchOperationType
      switch batchOperation.operationType {
      case .markAsPlayed:
        reverseOperationType = .markAsUnplayed
      case .markAsUnplayed:
        reverseOperationType = .markAsPlayed
      case .favorite:
        reverseOperationType = .unfavorite
      case .unfavorite:
        reverseOperationType = .favorite
      case .bookmark:
        reverseOperationType = .unbookmark
      case .unbookmark:
        reverseOperationType = .bookmark
      case .archive:
        // Unarchive episodes by updating them directly
        let episodeIDs = batchOperation.operations.map { $0.episodeID }
        for episodeID in episodeIDs {
          if let episode = allEpisodes.first(where: { $0.id == episodeID }) {
            let updatedEpisode = episode.withArchivedStatus(false)
            updateEpisode(updatedEpisode)
          }
        }
        return
      default:
        return  // Non-reversible operations
      }

      // Execute reverse batch operation
      let undoBatch = BatchOperation(
        operationType: reverseOperationType,
        episodeIDs: batchOperation.operations.map { $0.episodeID },
        playlistID: batchOperation.playlistID
      )

      do {
        let _ = try await batchOperationManager.executeBatchOperation(undoBatch)
      } catch {
        Self.logger.error("Undo batch operation failed: \(error, privacy: .public)")
      }
    }
  }
}
