//
//  EpisodeDownloadProgressCoordinator.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts download progress monitoring and state management
//

import CombineSupport
import CoreModels
import Foundation
import OSLog

// MARK: - Protocol

/// Coordinates download progress updates and episode status synchronization
@MainActor
public protocol EpisodeDownloadProgressCoordinating: AnyObject {
  /// Current download progress by episode ID
  var downloadProgressByEpisodeID: [String: EpisodeDownloadProgressUpdate] { get }
  
  /// Returns download progress for a specific episode
  func downloadProgress(for episodeID: String) -> EpisodeDownloadProgressUpdate?

  /// Clears cached progress for an episode (used when a download is cancelled).
  func clearProgress(for episodeID: String)
  
  /// Starts monitoring download progress updates
  func startMonitoring()
  
  /// Stops monitoring download progress updates
  func stopMonitoring()
}

// MARK: - Implementation

/// Default implementation of download progress coordination
@MainActor
public final class EpisodeDownloadProgressCoordinator: ObservableObject, EpisodeDownloadProgressCoordinating {
  @Published public private(set) var downloadProgressByEpisodeID: [String: EpisodeDownloadProgressUpdate] = [:]
  
  private let downloadProgressProvider: DownloadProgressProviding?
  private let episodeUpdateHandler: (Episode) -> Void
  private let episodeLookup: (String) -> Episode?
  private var cancellables = Set<AnyCancellable>()
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "DownloadProgressCoordinator")
  
  public init(
    downloadProgressProvider: DownloadProgressProviding?,
    episodeLookup: @escaping (String) -> Episode?,
    episodeUpdateHandler: @escaping (Episode) -> Void
  ) {
    self.downloadProgressProvider = downloadProgressProvider
    self.episodeLookup = episodeLookup
    self.episodeUpdateHandler = episodeUpdateHandler
  }
  
  public func downloadProgress(for episodeID: String) -> EpisodeDownloadProgressUpdate? {
    downloadProgressByEpisodeID[episodeID]
  }

  public func clearProgress(for episodeID: String) {
    downloadProgressByEpisodeID.removeValue(forKey: episodeID)
  }
  
  public func startMonitoring() {
    guard let downloadProgressProvider else { return }
    
    downloadProgressProvider.progressPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] update in
        self?.applyDownloadProgressUpdate(update)
      }
      .store(in: &cancellables)
  }
  
  public func stopMonitoring() {
    cancellables.removeAll()
  }
  
  // MARK: - Private Methods
  
  private func applyDownloadProgressUpdate(_ update: EpisodeDownloadProgressUpdate) {
    downloadProgressByEpisodeID[update.episodeID] = update
    
    guard var episode = episodeLookup(update.episodeID) else { return }
    
    switch update.status {
    case .queued, .downloading:
      episode = episode.withDownloadStatus(.downloading)
    case .paused:
      episode = episode.withDownloadStatus(.paused)
    case .completed:
      episode = episode.withDownloadStatus(.downloaded)
    case .failed:
      episode = episode.withDownloadStatus(.failed)
    }
    
    episodeUpdateHandler(episode)
    
    if update.status == .completed || update.status == .failed {
      scheduleProgressClear(for: update.episodeID)
    }
  }
  
  private func scheduleProgressClear(for episodeID: String) {
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      await MainActor.run {
        guard let self else { return }
        guard let progress = self.downloadProgressByEpisodeID[episodeID] else { return }
        switch progress.status {
        case .completed, .failed:
          self.downloadProgressByEpisodeID.removeValue(forKey: episodeID)
        default:
          break
        }
      }
    }
  }
}
