//
//  EpisodeListViewModel+FilterHelpers.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts filter helper logic
//

import CoreModels
import Foundation

// MARK: - Filter Helpers

@MainActor
extension EpisodeListViewModel {
  
  /// Check if there are active filters
  public var hasActiveFilters: Bool {
    return !currentFilter.isEmpty || !searchText.isEmpty
  }

  /// Get a summary of the current filter state
  public var filterSummary: String {
    if currentFilter.isEmpty && searchText.isEmpty {
      return "All Episodes (\(allEpisodes.count))"
    }

    var parts: [String] = []

    if !currentFilter.isEmpty {
      parts.append(currentFilter.displayName)
    }

    if !searchText.isEmpty {
      parts.append("Search: \"\(searchText)\"")
    }

    let summary = parts.joined(separator: " • ")
    return "\(summary) (\(filteredEpisodes.count))"
  }
}
