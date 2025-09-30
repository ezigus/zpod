//
//  EpisodeSearchViewModel.swift
//  LibraryFeature
//
//  View model for advanced episode search functionality
//

import Foundation
import SwiftUI
import Combine
import CoreModels
import Persistence

@MainActor
public class EpisodeSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var searchText: String = ""
    @Published public var searchResults: [EpisodeSearchResult] = []
    @Published public var searchSuggestions: [EpisodeSearchSuggestion] = []
    @Published public var searchHistory: [SearchHistoryEntry] = []
    @Published public var isSearching: Bool = false
    @Published public var currentAdvancedQuery: EpisodeSearchQuery?
    
    // MARK: - Private Properties
    
    private let episodes: [Episode]
    private let filterService: EpisodeFilterService
    private let searchManager: EpisodeSearchManager
    private var searchTask: Task<Void, Never>?
    private var suggestionsTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init(
        episodes: [Episode],
        filterService: EpisodeFilterService,
        searchManager: EpisodeSearchManager = EpisodeSearchManager()
    ) {
        self.episodes = episodes
        self.filterService = filterService
        self.searchManager = searchManager
        
        // Observe search manager changes
        setupSearchManagerObservation()
    }
    
    // MARK: - Public Methods
    
    /// Perform basic text search
    public func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }
            
            // Use basic search for simple text
            let results = filterService.searchEpisodes(episodes, query: searchText, filter: nil, includeArchived: false)
            
            // Convert to search results format
            let searchResults = results.map { episode in
                EpisodeSearchResult(
                    episode: episode,
                    relevanceScore: 1.0, // Basic relevance for simple search
                    highlights: []
                )
            }
            
            guard !Task.isCancelled else { return }
            
            self.searchResults = searchResults
            
            // Save to search history
            searchManager.saveSearch(query: searchText, resultCount: searchResults.count)
        }
    }
    
    /// Perform advanced search with query object
    public func performAdvancedSearch(with query: EpisodeSearchQuery) {
        searchTask?.cancel()
        currentAdvancedQuery = query
        searchText = query.text
        
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }
            
            let results = filterService.searchEpisodesAdvanced(episodes, query: query, filter: nil, includeArchived: false)
            
            guard !Task.isCancelled else { return }
            
            self.searchResults = results
            
            // Save to search history
            searchManager.saveSearch(query: query.text, resultCount: results.count)
        }
    }
    
    /// Clear current search
    public func clearSearch() {
        searchText = ""
        searchResults = []
        currentAdvancedQuery = nil
        searchTask?.cancel()
    }
    
    /// Clear advanced query but keep search text
    public func clearAdvancedQuery() {
        currentAdvancedQuery = nil
        if !searchText.isEmpty {
            performSearch() // Fall back to basic search
        }
    }
    
    /// Update search suggestions based on input
    public func updateSuggestions(for input: String) {
        suggestionsTask?.cancel()
        
        guard !input.isEmpty else {
            searchSuggestions = []
            return
        }
        
        suggestionsTask = Task {
            searchManager.getSuggestions(for: input)
            
            // The searchManager will update its @Published properties,
            // which we observe and mirror
        }
    }
    
    /// Select a search suggestion
    public func selectSuggestion(_ suggestion: EpisodeSearchSuggestion) {
        switch suggestion.type {
        case .fieldQuery:
            // Parse as advanced query if it contains field syntax
            if suggestion.text.contains(":") {
                let query = EpisodeSearchQuery(text: suggestion.text)
                performAdvancedSearch(with: query)
            } else {
                searchText = suggestion.text
                performSearch()
            }
        case .completion:
            // Add to current search text
            searchText = suggestion.text
        default:
            // Use as-is for history and common suggestions
            searchText = suggestion.text
            performSearch()
        }
        
        // Increment suggestion frequency
        searchManager.incrementSuggestionFrequency(for: suggestion.text)
    }
    
    /// Select a search history entry
    public func selectHistoryEntry(_ entry: SearchHistoryEntry) {
        searchText = entry.query
        
        // Try to parse as advanced query
        let query = EpisodeSearchQuery(text: entry.query)
        if query.terms.count > 1 || query.operators.count > 0 {
            performAdvancedSearch(with: query)
        } else {
            performSearch()
        }
    }
    
    /// Remove a search history entry
    public func removeHistoryEntry(_ entry: SearchHistoryEntry) {
        searchManager.removeHistoryEntry(entry)
    }
    
    /// Clear all search history
    public func clearSearchHistory() {
        searchManager.clearHistory()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchManagerObservation() {
        // Mirror search manager's published properties
        searchManager.$searchHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$searchHistory)
        
        searchManager.$searchSuggestions
            .receive(on: DispatchQueue.main)
            .assign(to: &$searchSuggestions)
    }
}

// MARK: - Advanced Search Support

extension EpisodeSearchViewModel {
    
    /// Quick search patterns for common use cases
    public static let quickSearchPatterns: [(String, String)] = [
        ("Recent unplayed", "unplayed AND date:\"this week\""),
        ("Downloaded interviews", "downloaded AND title:interview"),
        ("Short episodes", "duration:\"under 30 minutes\""),
        ("News episodes", "title:news OR description:news"),
        ("Favorited content", "favorited:true"),
        ("Long episodes", "duration:\"over 60 minutes\""),
        ("Recent downloads", "downloaded AND date:recent"),
        ("Bookmarked episodes", "bookmarked:true")
    ]
    
    /// Create quick search query
    public func performQuickSearch(_ pattern: String) {
        let query = EpisodeSearchQuery(text: pattern)
        performAdvancedSearch(with: query)
    }
}

// MARK: - Search Analytics Support

extension EpisodeSearchViewModel {
    
    /// Get search analytics for the current session
    public var searchAnalytics: SearchAnalytics {
        SearchAnalytics(
            totalSearches: searchHistory.count,
            averageResultCount: searchHistory.isEmpty ? 0 : searchHistory.map(\.resultCount).reduce(0, +) / searchHistory.count,
            mostCommonTerms: getMostCommonSearchTerms(),
            searchSuccessRate: getSearchSuccessRate()
        )
    }
    
    private func getMostCommonSearchTerms() -> [String] {
        let allTerms = searchHistory.flatMap { entry in
            entry.query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        }
        
        let termCounts = Dictionary(grouping: allTerms, by: { $0 })
            .mapValues { $0.count }
        
        return termCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func getSearchSuccessRate() -> Double {
        guard !searchHistory.isEmpty else { return 0.0 }
        
        let successfulSearches = searchHistory.filter { $0.resultCount > 0 }.count
        return Double(successfulSearches) / Double(searchHistory.count)
    }
}

// MARK: - Search Analytics Model

public struct SearchAnalytics {
    public let totalSearches: Int
    public let averageResultCount: Int
    public let mostCommonTerms: [String]
    public let searchSuccessRate: Double
}