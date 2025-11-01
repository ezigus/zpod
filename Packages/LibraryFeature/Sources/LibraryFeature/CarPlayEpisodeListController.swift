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
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "CarPlayEpisodeListController")

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

    if item.isInProgress {
      listItem.playbackProgress = item.episode.playbackProgress
    }

    listItem.handler = { [weak self] _, completion in
      guard let self else {
        completion()
        return
      }
      self.presentOptions(for: item.episode)
      completion()
    }

    return listItem
  }

  // MARK: - Episode Selection Handling

  private func presentOptions(for episode: Episode) {
    guard let interfaceController else {
      playNow(episode)
      return
    }

    let playAction = CPAlertAction(title: "Play Now", style: .default) { [weak self] _ in
      self?.playNow(episode)
    }

    let queueAction = CPAlertAction(title: "Add to Queue", style: .default) { [weak self] _ in
      self?.enqueue(episode)
    }

    let alert = CPAlertTemplate(titleVariants: [episode.title], actions: [playAction, queueAction])
    interfaceController.presentTemplate(alert, animated: true, completion: nil)
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
