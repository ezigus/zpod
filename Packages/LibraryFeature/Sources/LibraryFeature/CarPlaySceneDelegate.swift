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

/// CarPlay scene delegate that manages the CarPlay interface lifecycle and templates
@available(iOS 14.0, *)
@MainActor
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "CarPlaySceneDelegate")
  
  /// The CarPlay interface controller
  private var interfaceController: CPInterfaceController?
  
  /// The root template (tab bar with podcasts and now playing)
  private var rootTemplate: CPTemplate?
  
  /// Episode list controllers by podcast ID for caching
  private var episodeListControllers: [String: CarPlayEpisodeListController] = [:]
  
  // MARK: - CPTemplateApplicationSceneDelegate
  
  public func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    Self.logger.info("CarPlay interface connected")
    self.interfaceController = interfaceController
    
    // Set up the root template
    setupRootTemplate()
  }
  
  public func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
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
    
    // Create the podcast library list
    let libraryTemplate = createPodcastLibraryTemplate()
    
    // Create a tab bar template with library and now playing
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
  
  private func createPodcastLibraryTemplate() -> CPListTemplate {
    let listTemplate = CPListTemplate(
      title: "Podcasts",
      sections: [createPodcastSection()]
    )
    
    return listTemplate
  }
  
  private func createPodcastSection() -> CPListSection {
    // In a full implementation, this would fetch actual podcasts from the repository
    // For now, create a placeholder that shows the structure
    let items: [CPListItem] = []
    
    // TODO: Fetch podcasts from PodcastRepository
    // For each podcast, create a CPListItem with handler that shows episode list
    
    let section = CPListSection(items: items, header: "Your Podcasts", sectionIndexTitle: nil)
    return section
  }
  
  // MARK: - Episode List Navigation
  
  /// Show the episode list for a given podcast
  func showEpisodeList(for podcast: Podcast) {
    guard let interfaceController = interfaceController else {
      Self.logger.warning("Cannot show episode list: no interface controller")
      return
    }
    
    // Get or create the episode list controller for this podcast
    let controller: CarPlayEpisodeListController
    if let existing = episodeListControllers[podcast.id] {
      controller = existing
    } else {
      controller = CarPlayEpisodeListController(podcast: podcast)
      episodeListControllers[podcast.id] = controller
    }
    
    // Create and push the episode list template
    let episodeListTemplate = controller.createEpisodeListTemplate()
    interfaceController.pushTemplate(episodeListTemplate, animated: true) { success, error in
      if let error = error {
        Self.logger.error("Failed to push episode list: \(error.localizedDescription)")
      } else {
        Self.logger.info("Successfully showed episode list for podcast: \(podcast.title)")
      }
    }
  }
}

#endif
