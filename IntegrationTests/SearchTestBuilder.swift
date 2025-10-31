import Foundation
import XCTest
import CoreModels
import SearchDomain

/// Builder for setting up search test scenarios
///
/// This builder simplifies the creation and configuration of search services for testing.
/// It provides helpers for common search operations used in workflow tests.
///
/// Example usage:
/// ```swift
/// let builder = await SearchTestBuilder()
///     .withSearchService(searchService)
///     .rebuildIndex()
///     .searchPodcasts("Swift")
/// ```
@MainActor
final class SearchTestBuilder {
    private var searchService: SearchService?
    
    init() {}
    
    // MARK: - Service Configuration
    
    /// Sets the search service for this builder
    @discardableResult
    func withSearchService(_ service: SearchService) -> Self {
        self.searchService = service
        return self
    }
    
    // MARK: - Search Operations
    
    /// Rebuilds the search index
    @discardableResult
    func rebuildIndex() async -> Self {
        guard let searchService = searchService else {
            XCTFail("Search service not configured")
            return self
        }
        
        await searchService.rebuildIndex()
        return self
    }
    
    /// Searches for podcasts with a query
    ///
    /// - Parameter query: The search query
    /// - Returns: Array of matching podcasts
    func searchPodcasts(_ query: String) async -> [Podcast] {
        guard let searchService = searchService else {
            XCTFail("Search service not configured")
            return []
        }
        
        let results = await searchService.search(query: query, filter: .podcastsOnly)
        return results.compactMap { result in
            if case .podcast(let podcast, _) = result {
                return podcast
            }
            return nil
        }
    }
    
    /// Searches for episodes with a query
    ///
    /// - Parameter query: The search query
    /// - Returns: Array of matching episodes
    func searchEpisodes(_ query: String) async -> [Episode] {
        guard let searchService = searchService else {
            XCTFail("Search service not configured")
            return []
        }
        
        let results = await searchService.search(query: query, filter: .episodesOnly)
        return results.compactMap { result in
            if case .episode(let episode, _) = result {
                return episode
            }
            return nil
        }
    }
    
    /// Searches for both podcasts and episodes with a query
    ///
    /// - Parameter query: The search query
    /// - Returns: Array of all matching search results
    func search(_ query: String) async -> [SearchResult] {
        guard let searchService = searchService else {
            XCTFail("Search service not configured")
            return []
        }
        
        return await searchService.search(query: query, filter: .all)
    }
}
