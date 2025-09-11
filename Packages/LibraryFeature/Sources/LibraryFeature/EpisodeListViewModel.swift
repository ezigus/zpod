import Foundation
import SwiftUI
import CoreModels
import Persistence

// MARK: - Episode List View Model

/// View model for episode list with filtering and sorting
@MainActor
public final class EpisodeListViewModel: ObservableObject {
    @Published public private(set) var filteredEpisodes: [Episode] = []
    @Published public private(set) var currentFilter: EpisodeFilter = EpisodeFilter()
    @Published public private(set) var isLoading = false
    @Published public private(set) var searchText = ""
    @Published public var showingFilterSheet = false
    
    private let podcast: Podcast
    private let filterService: EpisodeFilterService
    private let filterManager: EpisodeFilterManager?
    private var allEpisodes: [Episode] = []
    
    public init(
        podcast: Podcast,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
        filterManager: EpisodeFilterManager? = nil
    ) {
        self.podcast = podcast
        self.filterService = filterService
        self.filterManager = filterManager
        self.allEpisodes = podcast.episodes
        
        // Load saved filter for this podcast
        loadInitialFilter()
        applyCurrentFilter()
    }
    
    // MARK: - Public Methods
    
    public func setFilter(_ filter: EpisodeFilter) {
        currentFilter = filter
        applyCurrentFilter()
        
        // Save filter preference for this podcast
        Task {
            await filterManager?.setCurrentFilter(filter, forPodcast: podcast.id)
        }
    }
    
    public func clearFilter() {
        setFilter(EpisodeFilter())
    }
    
    public func updateSearchText(_ text: String) {
        searchText = text
        applyCurrentFilter()
    }
    
    public func refreshEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: In a real implementation, this would fetch fresh episodes
        // For now, simulate a refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        applyCurrentFilter()
    }
    
    public func toggleEpisodeFavorite(_ episode: Episode) {
        updateEpisode(episode.withFavoriteStatus(!episode.isFavorited))
    }
    
    public func toggleEpisodeBookmark(_ episode: Episode) {
        updateEpisode(episode.withBookmarkStatus(!episode.isBookmarked))
    }
    
    public func markEpisodeAsPlayed(_ episode: Episode) {
        updateEpisode(episode.withPlayedStatus(true))
    }
    
    public func setEpisodeRating(_ episode: Episode, rating: Int?) {
        updateEpisode(episode.withRating(rating))
    }
    
    // MARK: - Episode Status Helpers
    
    public var hasActiveFilters: Bool {
        return !currentFilter.isEmpty || !searchText.isEmpty
    }
    
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
    
    // MARK: - Private Methods
    
    private func loadInitialFilter() {
        if let filterManager = filterManager {
            currentFilter = filterManager.filterForPodcast(podcast.id)
        }
    }
    
    private func applyCurrentFilter() {
        Task {
            var episodes = allEpisodes
            
            // Apply search if present
            if !searchText.isEmpty {
                episodes = filterService.searchEpisodes(episodes, query: searchText, filter: nil)
            }
            
            // Apply filter and sort
            episodes = filterService.filterAndSort(episodes: episodes, using: currentFilter)
            
            await MainActor.run {
                filteredEpisodes = episodes
            }
        }
    }
    
    private func updateEpisode(_ updatedEpisode: Episode) {
        // Update in all episodes
        if let index = allEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
            allEpisodes[index] = updatedEpisode
        }
        
        // Update in filtered episodes
        if let index = filteredEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
            filteredEpisodes[index] = updatedEpisode
        }
        
        // TODO: In a real implementation, this would save to persistence
    }
}

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
    private var allEpisodes: [Episode] = [] // Would come from all podcasts
    
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
    
    private func updateEpisodes() {
        Task {
            let filteredEpisodes = filterService.updateSmartList(smartList, allEpisodes: allEpisodes)
            
            await MainActor.run {
                episodes = filteredEpisodes
            }
        }
    }
    
    private func scheduleAutoRefresh() {
        // TODO: Implement background refresh scheduling
        // This would typically use a timer or background task
    }
}

