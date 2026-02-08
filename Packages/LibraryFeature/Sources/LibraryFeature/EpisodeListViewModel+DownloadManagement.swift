//
//  EpisodeListViewModel+DownloadManagement.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts download management logic from EpisodeListViewModel
//

import CoreModels
import Foundation

// MARK: - Download Management

@MainActor
extension EpisodeListViewModel {

  /// Delete the local download for an episode, reverting it to streaming-only
  public func deleteDownloadForEpisode(_ episode: Episode) async {
    guard isEffectivelyDownloadedForDeletion(episode) else { return }
    do {
      try await downloadManager?.deleteDownloadedEpisode(episodeId: episode.id)
      let updated = episode.withDownloadStatus(.notDownloaded)
      updateEpisode(updated)
      deletedDownloadEpisodeIDs.insert(episode.id)
    } catch {
      Self.logger.error(
        "Failed to delete download for episode \(episode.id): \(error, privacy: .public)")
    }
  }

  /// Retry failed download for an episode
  public func retryEpisodeDownload(_ episode: Episode) {
    guard episode.downloadStatus == .failed else { return }

    // Update status to downloading
    let updatedEpisode = episode.withDownloadStatus(.downloading)
    updateEpisode(updatedEpisode)

    if let enqueuer = downloadManager as? EpisodeDownloadEnqueuing {
      enqueuer.enqueueEpisode(updatedEpisode)
      return
    }

    // Fallback simulation when no download manager is provided
    launchTask { viewModel in
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      await MainActor.run {
        let completedEpisode = updatedEpisode.withDownloadStatus(.downloaded)
        viewModel.updateEpisode(completedEpisode)
      }
    }
  }

  internal func startEpisodeDownload(_ episode: Episode) {
    let downloadingEpisode = episode.withDownloadStatus(.downloading)
    updateEpisode(downloadingEpisode)

    if let enqueuer = downloadManager as? EpisodeDownloadEnqueuing {
      enqueuer.enqueueEpisode(downloadingEpisode)
      return
    }

    guard let manager = downloadManager else {
      launchTask { viewModel in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
          viewModel.updateEpisode(downloadingEpisode.withDownloadStatus(.downloaded))
        }
      }
      return
    }

    Task { @MainActor in
      do {
        try await manager.downloadEpisode(downloadingEpisode.id)
      } catch {
        updateEpisode(downloadingEpisode.withDownloadStatus(.failed))
      }
    }
  }

  /// Pause episode download
  public func pauseEpisodeDownload(_ episode: Episode) async {
    guard let downloadManager else { return }
    await downloadManager.pauseDownload(episode.id)
    if var storedEpisode = episodeForID(episode.id) {
      storedEpisode = storedEpisode.withDownloadStatus(.paused)
      updateEpisode(storedEpisode)
    }
    // Progress update will be handled by downloadProgressCoordinator
  }

  /// Resume episode download
  public func resumeEpisodeDownload(_ episode: Episode) async {
    guard let downloadManager else { return }
    await downloadManager.resumeDownload(episode.id)
    if var storedEpisode = episodeForID(episode.id) {
      storedEpisode = storedEpisode.withDownloadStatus(.downloading)
      updateEpisode(storedEpisode)
    }
    // Progress update will be handled by downloadProgressCoordinator
  }

  private func isEffectivelyDownloadedForDeletion(_ episode: Episode) -> Bool {
    if deletedDownloadEpisodeIDs.contains(episode.id) {
      return false
    }
    if episode.isDownloaded || episode.downloadStatus == .downloaded {
      return true
    }
    guard
      let envValue = ProcessInfo.processInfo.environment["UITEST_DOWNLOADED_EPISODES"],
      !envValue.isEmpty
    else {
      return false
    }
    let seededEpisodes = envValue
      .split(separator: ",")
      .map { normalizeEpisodeIDForDeletion(String($0)) }
    return seededEpisodes.contains(normalizeEpisodeIDForDeletion(episode.id))
  }

  private func normalizeEpisodeIDForDeletion(_ id: String) -> String {
    let trimmed = id
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let tokenParts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let episodePortion = tokenParts.count == 2 ? String(tokenParts[1]) : trimmed
    if episodePortion.hasPrefix("episode-") {
      return String(episodePortion.dropFirst("episode-".count))
    }
    return episodePortion
  }
}
