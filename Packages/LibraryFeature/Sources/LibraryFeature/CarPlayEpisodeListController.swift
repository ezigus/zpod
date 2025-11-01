//
//  CarPlayEpisodeListController.swift
//  LibraryFeature
//
//  Created for Issue 02.1.8: CarPlay Integration for Episode Lists
//

#if canImport(CarPlay)
import CarPlay
import CoreModels
import Foundation
import OSLog
import Persistence
import PlaybackEngine

/// Controller that manages the episode list template for CarPlay
@available(iOS 14.0, *)
@MainActor
public final class CarPlayEpisodeListController {
  
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "CarPlayEpisodeListController")
  
  /// The podcast whose episodes are being displayed
  private let podcast: Podcast
  
  /// Episodes to display (fetched from repository)
  private var episodes: [Episode] = []
  
  /// Dependencies
  private let episodeRepository: EpisodeRepository
  private let playbackService: any PlaybackService
  
  /// Initialize with a podcast
  public init(
    podcast: Podcast,
    episodeRepository: EpisodeRepository = EpisodeListDependencyProvider.shared.episodeRepository,
    playbackService: any PlaybackService = EpisodeListDependencyProvider.shared.playbackService
  ) {
    self.podcast = podcast
    self.episodeRepository = episodeRepository
    self.playbackService = playbackService
    
    // Load episodes
    Task {
      await loadEpisodes()
    }
  }
  
  // MARK: - Episode Loading
  
  private func loadEpisodes() async {
    do {
      // Fetch episodes for this podcast
      // In a full implementation, this would use the episode repository
      // For now, using placeholder logic
      episodes = []
      Self.logger.info("Loaded \(self.episodes.count) episodes for podcast: \(self.podcast.title)")
    } catch {
      Self.logger.error("Failed to load episodes: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Template Creation
  
  /// Create the CarPlay list template for episode browsing
  func createEpisodeListTemplate() -> CPListTemplate {
    let section = createEpisodeSection()
    
    let template = CPListTemplate(
      title: podcast.title,
      sections: [section]
    )
    
    return template
  }
  
  private func createEpisodeSection() -> CPListSection {
    let items = episodes.prefix(100).map { episode in
      createEpisodeListItem(for: episode)
    }
    
    // CarPlay guidelines recommend limiting list length for safety
    // We limit to 100 items and show most recent episodes first
    let header = items.isEmpty ? "No Episodes" : "Recent Episodes"
    return CPListSection(items: Array(items), header: header, sectionIndexTitle: nil)
  }
  
  private func createEpisodeListItem(for episode: Episode) -> CPListItem {
    // Format episode metadata for CarPlay display
    let title = episode.title
    let duration = formatDuration(episode.duration)
    let detailText = duration
    
    // Create the list item
    let item = CPListItem(
      text: title,
      detailText: detailText,
      image: nil,  // Could add episode artwork if available
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    
    // Set up the handler for when the item is selected
    item.handler = { [weak self] _, completion in
      guard let self = self else {
        completion()
        return
      }
      
      Task { @MainActor in
        await self.handleEpisodeSelection(episode)
        completion()
      }
    }
    
    return item
  }
  
  // MARK: - Episode Selection Handling
  
  private func handleEpisodeSelection(_ episode: Episode) async {
    Self.logger.info("Episode selected in CarPlay: \(episode.title)")
    
    // Start playback of the selected episode
    do {
      try await playbackService.play(episode: episode)
      Self.logger.info("Started playback of episode: \(episode.title)")
    } catch {
      Self.logger.error("Failed to start playback: \(error.localizedDescription)")
      // In a full implementation, would show error to user via CarPlay alert
    }
  }
  
  // MARK: - Helper Methods
  
  private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }
}

#endif
