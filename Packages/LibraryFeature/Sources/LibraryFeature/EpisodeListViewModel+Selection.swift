//
//  EpisodeListViewModel+Selection.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts multi-select and batch operation selection logic
//

import CoreModels
import Foundation
import OSLog

// MARK: - Selection Management

@MainActor
extension EpisodeListViewModel {
  
  /// Enter multi-select mode
  public func enterMultiSelectMode() {
    selectionState.enterMultiSelectMode()
  }

  /// Exit multi-select mode
  public func exitMultiSelectMode() {
    selectionState.exitMultiSelectMode()
  }

  /// Toggle selection for a specific episode
  public func toggleEpisodeSelection(_ episode: Episode) {
    selectionState.toggleSelection(for: episode.id)
  }

  /// Select all filtered episodes
  public func selectAllEpisodes() {
    let episodeIDs = filteredEpisodes.map { $0.id }
    selectionState.selectAll(episodeIDs: episodeIDs)
  }

  /// Deselect all episodes
  public func selectNone() {
    selectionState.selectNone()
  }

  /// Invert the current selection
  public func invertSelection() {
    let allEpisodeIDs = filteredEpisodes.map { $0.id }
    selectionState.invertSelection(allEpisodeIDs: allEpisodeIDs)
  }

  /// Select episodes matching specific criteria
  public func selectEpisodesByCriteria(_ criteria: EpisodeSelectionCriteria) {
    let matchingEpisodes = filteredEpisodes.filter { criteria.matches(episode: $0) }
    let episodeIDs = matchingEpisodes.map { $0.id }
    selectionState.selectAll(episodeIDs: episodeIDs)
  }

  /// Execute a batch operation on selected episodes
  public func executeBatchOperation(_ operationType: BatchOperationType, playlistID: String? = nil)
    async
  {
    guard selectionState.hasSelection else { return }

    let selectedEpisodeIDs = Array(selectionState.selectedEpisodeIDs)
    let batchOperation = BatchOperation(
      operationType: operationType,
      episodeIDs: selectedEpisodeIDs,
      playlistID: playlistID
    )

    do {
      let _ = try await batchOperationManager.executeBatchOperation(batchOperation)
      // Operation completed successfully
      exitMultiSelectMode()
    } catch {
      // Handle error - in a real implementation, this would show an error message
      Self.selectionLogger.error("Batch operation failed: \(error, privacy: .public)")
    }
  }

  /// Cancel a running batch operation
  public func cancelBatchOperation(_ operationID: String) async {
    await batchOperationManager.cancelBatchOperation(id: operationID)
  }

  /// Get currently selected episodes
  public var selectedEpisodes: [Episode] {
    return filteredEpisodes.filter { selectionState.isSelected($0.id) }
  }

  /// Check if an episode is selected
  public var isEpisodeSelected: (String) -> Bool {
    return { [weak self] episodeID in
      self?.selectionState.isSelected(episodeID) ?? false
    }
  }

  /// Check if there are any selected episodes
  public var hasActiveSelection: Bool {
    return selectionState.hasSelection
  }

  /// Get the count of selected episodes
  public var selectedCount: Int {
    return selectionState.selectedCount
  }

  /// Check if in multi-select mode
  public var isInMultiSelectMode: Bool {
    return selectionState.isMultiSelectMode
  }

  /// Get available batch operations
  public var availableBatchOperations: [BatchOperationType] {
    return [
      .download,
      .markAsPlayed,
      .markAsUnplayed,
      .addToPlaylist,
      .favorite,
      .unfavorite,
      .bookmark,
      .unbookmark,
      .archive,
      .share,
      .delete,
    ]
  }
  
  private static let selectionLogger = Logger(
    subsystem: "us.zig.zpod",
    category: "EpisodeListViewModel.Selection"
  )
}
