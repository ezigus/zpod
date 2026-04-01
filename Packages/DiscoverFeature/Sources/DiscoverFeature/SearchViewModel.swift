import Foundation
import SwiftUI
import CombineSupport
import CoreModels
import SearchDomain
import FeedParsing
import SharedUtilities

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

    /// Whether an external directory search is in progress (shows "Searching online" indicator)
    @Published public var isSearchingDirectory: Bool = false

    /// Current search filter
    @Published public var currentFilter: SearchFilter = .all

    /// Search history for quick access
    @Published public var searchHistory: [String] = []

    /// Episode counts keyed by feed URL string, populated during directory search.
    /// Cleared on `clearSearch()`. Only holds current search session data.
    @Published public var episodeCountMap: [String: Int] = [:]

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
    private let directoryService: (any PodcastDirectorySearching)?
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.3
    private var subscribeTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        searchService: SearchServicing,
        podcastManager: PodcastManaging,
        rssParser: RSSFeedParsing = DefaultRSSFeedParser(),
        directoryService: (any PodcastDirectorySearching)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.searchService = searchService
        self.podcastManager = podcastManager
        self.rssParser = rssParser
        self.directoryService = directoryService
        self.userDefaults = userDefaults

        setupSearchDebouncing()
        loadSearchHistory()
    }
    
    // MARK: - Public Methods
    
    /// Perform search with current query and filter.
    ///
    /// Runs local and external directory searches concurrently. Local results are
    /// published immediately once the in-memory search completes; external directory
    /// results are merged in when the network fetch finishes. Directory search is
    /// skipped when the active filter excludes podcasts.
    public func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        // Directory search only makes sense when podcasts are included in the filter.
        let filterIncludesPodcasts = currentFilter == .all || currentFilter == .podcastsOnly
        isSearchingDirectory = directoryService != nil && filterIncludesPodcasts

        // Kick off the external directory fetch as a child task so the network request
        // starts concurrently with the local in-memory search. The ternary skips the
        // fetch (returning [] immediately) when the filter excludes podcasts.
        async let externalTask: [SearchResult] = filterIncludesPodcasts
            ? fetchDirectoryResults(query: query)
            : []

        // Yield so the child task can start its network request before we run the local
        // search. Because search() is @MainActor, the async let child task cannot begin
        // until this function suspends; Task.yield() provides that suspension point.
        await Task.yield()

        // Local search (in-memory, fast) runs while the directory call is in flight.
        let local = await searchService.search(query: query, filter: currentFilter)

        // Show local results immediately while the directory search continues.
        searchResults = local

        let external = await externalTask

        // Guard against stale searches overwriting results from a more recent query.
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
            isSearching = false
            isSearchingDirectory = false
            return
        }

        searchResults = mergeResults(local: local, external: external)
        isSearching = false
        isSearchingDirectory = false

        // Track search history.
        if !searchHistory.contains(query) {
            searchHistory.insert(query, at: 0)
            if searchHistory.count > 10 {
                searchHistory = Array(searchHistory.prefix(10))
            }
            saveSearchHistory()
        }
    }

    // MARK: - Private search helpers

    /// Fetches external directory results and converts them to `SearchResult`.
    /// Returns an empty array on any error (graceful degradation).
    private func fetchDirectoryResults(query: String) async -> [SearchResult] {
        guard let service = directoryService else { return [] }
        isSearchingDirectory = true
        do {
            let results = try await service.search(query: query, limit: 25)
            // Populate the episode count side-channel before converting to SearchResult.
            // Reset first so counts from a previous query don't leak into this one.
            episodeCountMap = [:]
            for result in results {
                if let count = result.episodeCount {
                    episodeCountMap[result.feedURL.absoluteString] = count
                }
            }
            return results.map { directoryResult in
                .podcast(directoryResult.toPodcast(), relevanceScore: 0.5)
            }
        } catch let err as DirectorySearchError {
            switch err {
            case .decodingError, .httpError:
                // Hard failure: schema break or auth/server rejection.
                // Surface to user so they know something is wrong.
                Logger.warning("fetchDirectoryResults: hard failure for '\(query)': \(err.localizedDescription)")
                errorMessage = "Directory search unavailable: \(err.localizedDescription)"
            case .networkError:
                // Transient connectivity issue — degrade silently.
                Logger.warning("fetchDirectoryResults: network failure for '\(query)': \(err.localizedDescription)")
            case .invalidQuery:
                break  // Caller already validated the query.
            }
            return []
        } catch {
            Logger.warning("fetchDirectoryResults: unexpected failure for '\(query)': \(error.localizedDescription)")
            return []
        }
    }

    /// Merges local and external results, deduplicating by feed URL.
    /// Local results take precedence (higher relevance scores) and appear first.
    private func mergeResults(local: [SearchResult], external: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var merged = [SearchResult]()

        for result in local {
            if case .podcast(let podcast, _) = result {
                seen.insert(podcast.feedURL.absoluteString)
            }
            merged.append(result)
        }

        for result in external {
            if case .podcast(let podcast, _) = result {
                let key = podcast.feedURL.absoluteString
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                merged.append(result)
            }
        }

        return merged
    }
    
    /// Subscribe to a podcast from search results.
    ///
    /// If the podcast has no episodes and a directory service is configured (meaning it
    /// came from an external directory result), the full feed is fetched via RSS before
    /// subscribing so that episodes are available immediately in the Library.
    public func subscribe(to podcast: Podcast) {
        if podcast.episodes.isEmpty && directoryService != nil {
            // Cancel any in-flight subscription fetch before starting a new one.
            // Multiple rapid taps would otherwise race on isAddingRSSFeed.
            subscribeTask?.cancel()
            subscribeTask = Task {
                await subscribeByFetchingFeed(podcast)
            }
        } else {
            persistSubscription(podcast)
        }
    }

    private func subscribeByFetchingFeed(_ podcast: Podcast) async {
        isAddingRSSFeed = true
        errorMessage = nil
        do {
            let fullPodcast = try await rssParser.parseFeed(from: podcast.feedURL)
            let merged = Podcast(
                id: fullPodcast.id,
                title: fullPodcast.title,
                author: fullPodcast.author ?? podcast.author,
                description: fullPodcast.description ?? podcast.description,
                artworkURL: fullPodcast.artworkURL ?? podcast.artworkURL,
                feedURL: fullPodcast.feedURL,
                categories: fullPodcast.categories.isEmpty ? podcast.categories : fullPodcast.categories,
                episodes: fullPodcast.episodes,
                isSubscribed: true,
                dateAdded: Date(),
                folderId: podcast.folderId,
                tagIds: podcast.tagIds
            )
            podcastManager.add(merged)
        } catch {
            // Feed fetch failed; subscribe with directory metadata only.
            // The podcast is added but won't show episodes until a feed refresh succeeds.
            Logger.warning("subscribeByFetchingFeed: feed parse failed for \(podcast.feedURL): \(error.localizedDescription)")
            errorMessage = "Subscribed, but couldn't load episodes yet. Pull to refresh later."
            persistSubscription(podcast)
        }
        isAddingRSSFeed = false
    }

    private func persistSubscription(_ podcast: Podcast) {
        let existingPodcast = podcastManager.find(id: podcast.id)
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
            dateAdded: existingPodcast?.dateAdded ?? Date(),
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
        if existingPodcast != nil {
            podcastManager.update(subscribedPodcast)
        } else {
            podcastManager.add(subscribedPodcast)
        }
    }
    
    /// Add podcast by RSS feed URL
    public func addPodcastByRSSURL() async {
        let trimmedURL = rssURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
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
        episodeCountMap = [:]
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
        // Debounce search text changes to avoid excessive API calls.
        // DispatchQueue.main (not RunLoop.main) allows quiescence gaps between
        // GCD blocks, preventing XCUITest "Wait for app to idle" hangs during typeText().
        $searchText
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                // MainActor.assumeIsolated executes synchronously without creating an
                // async task submission, keeping the run loop idle between debounce ticks.
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task {
                        await self.search()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSearchHistory() {
        guard let data = userDefaults.data(forKey: "SearchHistory") else { return }
        do {
            searchHistory = try JSONDecoder().decode([String].self, from: data)
        } catch {
            Logger.warning("SearchViewModel: failed to decode search history: \(error.localizedDescription)")
        }
    }

    private func saveSearchHistory() {
        do {
            let data = try JSONEncoder().encode(searchHistory)
            userDefaults.set(data, forKey: "SearchHistory")
        } catch {
            Logger.warning("SearchViewModel: failed to encode search history: \(error.localizedDescription)")
        }
    }
}
