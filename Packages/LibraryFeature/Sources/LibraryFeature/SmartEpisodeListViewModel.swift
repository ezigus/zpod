//
//  SmartEpisodeListViewModel.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Moved from EpisodeListViewModel.swift to improve file organization
//

import CoreModels
import Foundation
import Persistence
import SwiftUI

// MARK: - Smart List View Model

/// View model for smart episode lists
@MainActor
public final class SmartEpisodeListViewModel: ObservableObject {
  @Published public private(set) var episodes: [Episode] = []
  @Published public private(set) var smartList: SmartEpisodeList
  @Published public private(set) var isLoading = false
  @Published public private(set) var lastRefresh: Date?

  private let filterService: EpisodeFilterService
  private let filterManager: EpisodeFilterManager
  private var allEpisodes: [Episode] = []  // Would come from all podcasts

  public init(
    smartList: SmartEpisodeList,
    filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
    filterManager: EpisodeFilterManager
  ) {
    self.smartList = smartList
    self.filterService = filterService
    self.filterManager = filterManager

    updateEpisodes()

    // Set up auto-refresh if enabled
    if smartList.autoUpdate {
      scheduleAutoRefresh()
    }
  }

  // MARK: - Public Methods

  public func refreshNow() async {
    isLoading = true
    defer { isLoading = false }

    updateEpisodes()

    // Update the smart list's last updated time
    let updatedSmartList = smartList.withLastUpdated(Date())
    smartList = updatedSmartList
    await filterManager.updateSmartList(updatedSmartList)

    lastRefresh = Date()
  }

  public var needsRefresh: Bool {
    return filterService.smartListNeedsUpdate(smartList)
  }

  public var refreshIntervalText: String {
    let minutes = Int(smartList.refreshInterval / 60)
    return "\(minutes) min"
  }

  // MARK: - Private Methods

  @discardableResult
  private func launchMainActorTask(
    priority: TaskPriority? = nil,
    _ operation: @escaping (SmartEpisodeListViewModel) async -> Void
  ) -> Task<Void, Never> {
    Task(priority: priority) { @MainActor [weak self] in
      guard let self else { return }
      await operation(self)
    }
  }

  private func updateEpisodes() {
    launchMainActorTask { viewModel in
      let filteredEpisodes = viewModel.filterService.updateSmartList(
        viewModel.smartList,
        allEpisodes: viewModel.allEpisodes
      )
      viewModel.episodes = filteredEpisodes
    }
  }

  private func scheduleAutoRefresh() {
    // TODO: Implement background refresh scheduling
    // This would typically use a timer or background task
  }
}
