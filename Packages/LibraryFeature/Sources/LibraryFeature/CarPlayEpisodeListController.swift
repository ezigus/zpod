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

  @available(iOS 14.0, *)
  @MainActor
  public final class CarPlayEpisodeListController {
    private static let logger = Logger(
      subsystem: "us.zig.zpod", category: "CarPlayEpisodeListController")

    private var podcast: Podcast
    private var episodeItems: [CarPlayEpisodeItem]
    private let dependencies: CarPlayDependencies
    weak var interfaceController: CPInterfaceController?

    public init(podcast: Podcast, dependencies: CarPlayDependencies) {
      self.podcast = podcast
      self.dependencies = dependencies
      self.episodeItems = CarPlayDataAdapter.makeEpisodeItems(for: podcast)
    }

    public func update(podcast: Podcast) {
      guard podcast.id == self.podcast.id else { return }
      self.podcast = podcast
      self.episodeItems = CarPlayDataAdapter.makeEpisodeItems(for: podcast)
    }

    public func setInterfaceController(_ interfaceController: CPInterfaceController?) {
      self.interfaceController = interfaceController
    }

    // MARK: - Episode Loading

    func createEpisodeListTemplate() -> CPListTemplate {
      let section = createEpisodeSection()
      let template = CPListTemplate(title: podcast.title, sections: [section])
      return template
    }

    private func createEpisodeSection() -> CPListSection {
      let items = episodeItems.map { createEpisodeListItem(for: $0) }
      let header = items.isEmpty ? "No Episodes" : "Recent Episodes"
      return CPListSection(items: items, header: header, sectionIndexTitle: nil)
    }

    private func createEpisodeListItem(for item: CarPlayEpisodeItem) -> CPListItem {
      let listItem = CPListItem(text: item.title, detailText: item.detailText)
      listItem.userInfo = item

      // Enable voice control by setting accessibility label and hint
      listItem.isEnabled = true
      listItem.accessibilityLabel = item.title
      listItem.accessibilityHint = "Double tap to play \(item.title)"

      // Show playback progress for in-progress episodes (HIG compliance)
      if item.isInProgress {
        listItem.playbackProgress = item.episode.playbackProgress
      }

      // Note: Cannot reliably detect currently playing episode without exposing currentEpisode in protocol
      // Future enhancement: Add currentEpisode to EpisodePlaybackService protocol

      // Handler for tap selection (also triggered by voice commands)
      listItem.handler = { [weak self] _, completion in
        guard let self else {
          completion()
          return
        }
        self.presentOptions(for: item.episode)
        completion()
      }

      // Enable explicit action button for immediate playback (HIG: reduce driver distraction)
      listItem.playingIndicatorLocation = .trailing

      return listItem
    }

    // MARK: - Episode Selection Handling

    private func presentOptions(for episode: Episode) {
      guard let interfaceController else {
        // Fallback: directly play if no interface controller
        playNow(episode)
        return
      }

      // HIG Compliance: Provide simple, safe options while driving
      // Primary action should be "Play Now" for minimal distraction
      let playAction = CPAlertAction(title: "Play Now", style: .default) { [weak self] _ in
        self?.playNow(episode)
      }

      let queueAction = CPAlertAction(title: "Add to Queue", style: .default) { [weak self] _ in
        self?.enqueue(episode)
      }

      // Cancel action for safety (driver can dismiss if needed)
      let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { _ in
        // No-op: just dismiss the alert
      }  // Use title variants for different screen sizes (HIG compliance)
      let titleVariants = [
        episode.title,
        truncateTitle(episode.title, maxLength: 40),
      ]

      let alert = CPAlertTemplate(
        titleVariants: titleVariants,
        actions: [playAction, queueAction, cancelAction]
      )

      interfaceController.presentTemplate(alert, animated: true) { success, error in
        if let error = error {
          Self.logger.error("Failed to present episode options: \(error.localizedDescription)")
        }
      }
    }

    /// Truncate title for smaller CarPlay screens (HIG: ensure readability)
    private func truncateTitle(_ title: String, maxLength: Int) -> String {
      if title.count <= maxLength {
        return title
      }
      let index = title.index(title.startIndex, offsetBy: maxLength - 3)
      return String(title[..<index]) + "..."
    }

    private func playNow(_ episode: Episode) {
      Self.logger.info("Playing episode via CarPlay: \(episode.title)")
      dependencies.queueManager.playNow(episode)
    }

    private func enqueue(_ episode: Episode) {
      Self.logger.info("Enqueued episode via CarPlay: \(episode.title)")
      dependencies.queueManager.enqueue(episode)
    }
  }
#endif
