//
//  EpisodeListViewModel+UITestSupport.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts UI test overlay support from EpisodeListViewModel
//

import CoreModels
import Foundation
import OSLog

// MARK: - UI Test Support

@MainActor
extension EpisodeListViewModel {
  
  public func ensureUITestBatchOverlayIfNeeded(after delay: TimeInterval = 0.0) async {
    await ensureUITestBatchOverlayIfNeeded(after: delay, remainingRetries: 5)
  }

  private func ensureUITestBatchOverlayIfNeeded(
    after delay: TimeInterval,
    remainingRetries: Int
  ) async {
    let forcingOverlay = ProcessInfo.processInfo.environment["UITEST_FORCE_BATCH_OVERLAY"] == "1"
    guard forcingOverlay else { return }
    guard !hasSeededUITestOverlay else { return }
    guard activeBatchOperations.isEmpty else {
      overlayLogger.debug("Forced overlay already active; skipping reseed")
      return
    }

    overlayLogger.debug(
      "Requesting forced overlay (delay: \(delay, format: .fixed(precision: 2), privacy: .public)s, retries: \(remainingRetries, privacy: .public))"
    )

    if delay > 0 {
      try? await Task.sleep(nanoseconds: nanoseconds(from: delay))
    }

    let seedEpisodeIDs = makeSeedEpisodeIDs()
    overlayLogger.debug(
      "[UITEST_OVERLAY] candidate episode IDs: \(seedEpisodeIDs, privacy: .public)")

    if seedEpisodeIDs.isEmpty {
      overlayLogger.debug(
        "No episodes available for forced overlay; retries remaining: \(remainingRetries, privacy: .public)"
      )
      guard remainingRetries > 0 else { return }
      try? await Task.sleep(nanoseconds: 200_000_000)
      await ensureUITestBatchOverlayIfNeeded(after: 0.0, remainingRetries: remainingRetries - 1)
      return
    }

    hasSeededUITestOverlay = true

    overlayLogger.debug(
      "Seeding forced overlay with \(seedEpisodeIDs.count, privacy: .public) episodes")
    overlayLogger.debug(
      "[UITEST_OVERLAY] seeding overlay with \(seedEpisodeIDs.count, privacy: .public) IDs")

    var seededOperation = BatchOperation(
      operationType: .markAsPlayed,
      episodeIDs: seedEpisodeIDs
    ).withStatus(.running)

    activeBatchOperations = [seededOperation]

    if forcingOverlay {
      overlayLogger.debug("Forced overlay seeded; leaving batch operation in running state for UI tests")
      return
    }

    launchTask { viewModel in
      try? await Task.sleep(nanoseconds: 12_000_000_000)
      await MainActor.run {
        viewModel.activeBatchOperations.removeAll { $0.id == seededOperation.id }
        seededOperation = seededOperation.withStatus(.completed)
        viewModel.bannerManager.presentBanner(for: seededOperation)
        viewModel.overlayLogger.debug("Forced overlay transitioned to completion banner")
      }
    }
  }

  private func makeSeedEpisodeIDs() -> [String] {
    let sourceEpisodes = filteredEpisodes.isEmpty ? allEpisodes : filteredEpisodes
    let ids = Array(sourceEpisodes.prefix(5)).map { $0.id }
    return ids.isEmpty ? ["ui-test-episode"] : ids
  }

  private func nanoseconds(from seconds: TimeInterval) -> UInt64 {
    guard seconds > 0 else { return 0 }
    return UInt64((seconds * 1_000_000_000).rounded())
  }
}
