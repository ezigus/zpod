//
//  CarPlaySceneDelegate.swift
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

  @available(iOS 14.0, *)
  @MainActor
  public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private static let logger = Logger(subsystem: "us.zig.zpod", category: "CarPlaySceneDelegate")

    private var interfaceController: CPInterfaceController?
    private var rootTemplate: CPTemplate?
    private var episodeListControllers: [String: CarPlayEpisodeListController] = [:]

    private var dependencies: CarPlayDependencies {
      CarPlayDependencyRegistry.resolve()
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    public func templateApplicationScene(
      _ templateApplicationScene: CPTemplateApplicationScene,
      didConnectInterfaceController interfaceController: CPInterfaceController
    ) {
      Self.logger.info("CarPlay interface connected")
      self.interfaceController = interfaceController

      // Set up the root template
      setupRootTemplate()
    }

    public func templateApplicationScene(
      _ templateApplicationScene: CPTemplateApplicationScene,
      didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
      Self.logger.info("CarPlay interface disconnected")
      self.interfaceController = nil
      self.episodeListControllers.removeAll()
    }

    // MARK: - Template Setup

    private func setupRootTemplate() {
      guard let interfaceController = interfaceController else {
        Self.logger.warning("Cannot setup root template: no interface controller")
        return
      }

      let podcasts = CarPlayDataAdapter.makePodcastItems(from: dependencies.podcastManager.all())
      let libraryTemplate = createPodcastLibraryTemplate(podcasts: podcasts)

      let tabBarTemplate = CPTabBarTemplate(templates: [libraryTemplate])

      self.rootTemplate = tabBarTemplate
      interfaceController.setRootTemplate(tabBarTemplate, animated: true) { success, error in
        if let error = error {
          Self.logger.error("Failed to set root template: \(error.localizedDescription)")
        } else {
          Self.logger.info("Successfully set root template")
        }
      }
    }

    private func createPodcastLibraryTemplate(podcasts: [CarPlayPodcastItem]) -> CPListTemplate {
      let section = createPodcastSection(from: podcasts)
      return CPListTemplate(title: "Podcasts", sections: [section])
    }

    private func createPodcastSection(from podcasts: [CarPlayPodcastItem]) -> CPListSection {
      let items = podcasts.map { podcast -> CPListItem in
        let item = CPListItem(text: podcast.title, detailText: podcast.detailText)
        item.userInfo = podcast

        // Enable voice control via accessibility
        item.isEnabled = true
        item.accessibilityLabel = podcast.title
        item.accessibilityHint = "Double tap to view episodes from \(podcast.title)"

        // Handler for both tap and voice selection
        item.handler = { [weak self] _, completion in
          guard let self else {
            completion()
            return
          }
          self.showEpisodeList(for: podcast.podcast)
          completion()
        }
        return item
      }

      let header = podcasts.isEmpty ? "No Podcasts" : "Your Podcasts"
      return CPListSection(items: items, header: header, sectionIndexTitle: nil)
    }

    // MARK: - Episode List Navigation

    /// Show the episode list for a given podcast
    func showEpisodeList(for podcast: Podcast) {
      guard let interfaceController = interfaceController else {
        Self.logger.warning("Cannot show episode list: no interface controller")
        return
      }

      let controller = episodeListController(for: podcast)
      let episodeListTemplate = controller.createEpisodeListTemplate()
      interfaceController.pushTemplate(episodeListTemplate, animated: true) { success, error in
        if let error = error {
          Self.logger.error("Failed to push episode list: \(error.localizedDescription)")
        } else {
          Self.logger.info("Successfully showed episode list for podcast: \(podcast.title)")
        }
      }
    }

    private func episodeListController(for podcast: Podcast) -> CarPlayEpisodeListController {
      if let existing = episodeListControllers[podcast.id] {
        existing.update(podcast: podcast)
        existing.setInterfaceController(interfaceController)
        return existing
      }

      let controller = CarPlayEpisodeListController(podcast: podcast, dependencies: dependencies)
      controller.setInterfaceController(interfaceController)
      episodeListControllers[podcast.id] = controller
      return controller
    }
  }

#endif
