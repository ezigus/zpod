import Foundation
import SwiftUI
import Combine
import CoreModels
import SearchDomain
import FeedParsing

/// Protocol for RSS feed parsing to support dependency injection
public protocol RSSFeedParsing: Sendable {
    func parseFeed(from url: URL) async throws -> Podcast
}

/// Default implementation using RSSFeedParser
public struct DefaultRSSFeedParser: RSSFeedParsing {
    public init() {}
    
    public func parseFeed(from url: URL) async throws -> Podcast {
        #if !os(Linux)
        return try await RSSFeedParser.parseFeed(from: url)
        #else
        // For non-macOS platforms, create a basic podcast from URL
        return Podcast(
            id: url.absoluteString.hash.description,
            title: "Podcast from \(url.host ?? "RSS Feed")",
            author: "Unknown",
            description: "Added via RSS feed URL",
            feedURL: url
        )
        #endif
    }
}

/// ViewModel for search functionality in the Discover tab
@MainActor
public final class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current search query text
    @Published public var searchText: String = ""
    
    /// Current search results
    @Published public var searchResults: [SearchResult] = []
    
    /// Whether a search is currently in progress
    @Published public var isSearching: Bool = false
    
    /// Current search filter
    @Published public var currentFilter: SearchFilter = .all
    
    /// Search history for quick access
    @Published public var searchHistory: [String] = []
    
    /// Error message for display to user
    @Published public var errorMessage: String?
    
    /// RSS feed URL for direct addition
    @Published public var rssURL: String = ""
    
    /// Whether RSS feed addition is in progress
    @Published public var isAddingRSSFeed: Bool = false
    
    // MARK: - Private Properties
    
    private let searchService: SearchServicing
    private let podcastManager: PodcastManaging
    private let rssParser: RSSFeedParsing
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Initialization
    
    public init(
        searchService: SearchServicing,
        podcastManager: PodcastManaging,
        rssParser: RSSFeedParsing = DefaultRSSFeedParser()
    ) {
        self.searchService = searchService
        self.podcastManager = podcastManager
        self.rssParser = rssParser
        
        setupSearchDebouncing()
        loadSearchHistory()
    }
    
    // MARK: - Public Methods
    
    /// Perform search with current query and filter
    public func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
            errorMessage = nil
        }
        
        let results = await searchService.search(query: searchText, filter: currentFilter)
        
        await MainActor.run {
            searchResults = results
            isSearching = false
            
            // Add to search history if not already present
            if !searchHistory.contains(searchText) {
                searchHistory.insert(searchText, at: 0)
                // Keep only last 10 searches
                if searchHistory.count > 10 {
                    searchHistory = Array(searchHistory.prefix(10))
                }
                saveSearchHistory()
            }
        }
    }
    
    /// Subscribe to a podcast from search results
    public func subscribe(to podcast: Podcast) {
        let subscribedPodcast = Podcast(
            id: podcast.id,
            title: podcast.title,
            author: podcast.author,
            description: podcast.description,
            artworkURL: podcast.artworkURL,
            feedURL: podcast.feedURL,
            categories: podcast.categories,
            episodes: podcast.episodes,
            isSubscribed: true,
            dateAdded: Date(),
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
        
        podcastManager.add(subscribedPodcast)
    }
    
    /// Add podcast by RSS feed URL
    public func addPodcastByRSSURL() async {
        guard !rssURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: rssURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            await MainActor.run {
                errorMessage = "Invalid RSS feed URL"
            }
            return
        }
        
        await MainActor.run {
            isAddingRSSFeed = true
            errorMessage = nil
        }
        
        do {
            let podcast = try await rssParser.parseFeed(from: url)
            
            await MainActor.run {
                let subscribedPodcast = Podcast(
                    id: podcast.id,
                    title: podcast.title,
                    author: podcast.author,
                    description: podcast.description,
                    artworkURL: podcast.artworkURL,
                    feedURL: podcast.feedURL,
                    categories: podcast.categories,
                    episodes: podcast.episodes,
                    isSubscribed: true,
                    dateAdded: Date(),
                    folderId: podcast.folderId,
                    tagIds: podcast.tagIds
                )
                
                podcastManager.add(subscribedPodcast)
                isAddingRSSFeed = false
                rssURL = ""
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                isAddingRSSFeed = false
                errorMessage = "Failed to add RSS feed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Clear current search results
    public func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
    
    /// Use a search from history
    public func useSearchFromHistory(_ query: String) {
        searchText = query
    }
    
    /// Clear search history
    public func clearSearchHistory() {
        searchHistory = []
        saveSearchHistory()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchDebouncing() {
        // Debounce search text changes to avoid excessive API calls
        $searchText
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.search()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "SearchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "SearchHistory")
        }
    }
}