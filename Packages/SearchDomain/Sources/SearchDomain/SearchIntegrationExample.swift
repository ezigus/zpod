import Foundation
import CoreModels
import TestSupport

/// Example integration showing how to set up and use the SearchService with existing data
@MainActor
public final class SearchIntegrationExample {
  
  private let searchService: SearchService
  private let podcastManager: PodcastManaging
  
  public init(podcastManager: PodcastManaging) {
    self.podcastManager = podcastManager
    
    // Create index sources for podcasts and episodes
    let podcastSource = PodcastIndexSource(podcastManager: podcastManager)
    let episodeSource = EpisodeIndexSource(podcastManager: podcastManager)
    
    // Initialize search service with both sources
    self.searchService = SearchService(indexSources: [podcastSource, episodeSource])
  }
  
  /// Initialize the search index
  public func initializeSearch() async {
    await searchService.rebuildIndex()
  }
  
  /// Perform a unified search across podcasts and episodes
  public func search(query: String) async -> [SearchResult] {
    return await searchService.search(query: query, filter: nil)
  }
  
  /// Search only podcasts
  public func searchPodcasts(query: String) async -> [SearchResult] {
    return await searchService.search(query: query, filter: .podcastsOnly)
  }
  
  /// Search only episodes
  public func searchEpisodes(query: String) async -> [SearchResult] {
    return await searchService.search(query: query, filter: .episodesOnly)
  }
  
  /// Refresh the search index (call after adding new podcasts/episodes)
  public func refreshIndex() async {
    await searchService.rebuildIndex()
  }
}

// MARK: - Usage Example

extension SearchIntegrationExample {
  
  /// Example usage showing the complete search workflow
  public static func demonstrateUsage() async {
    // 1. Set up the podcast manager with some sample data
    let samplePodcast = Podcast(
      id: "swift-weekly",
      title: "Swift Weekly Podcast",
      author: "iOS Developer",
      description: "Weekly discussions about Swift programming and iOS development",
      feedURL: URL(string: "https://example.com/swift-weekly.xml")!,
      episodes: [
        Episode(
          id: "ep-001",
          title: "Getting Started with Swift 6",
          podcastID: "swift-weekly",
          description: "Introduction to the new features in Swift 6 including strict concurrency"
        ),
        Episode(
          id: "ep-002", 
          title: "Building iOS Apps with SwiftUI",
          podcastID: "swift-weekly",
          description: "Best practices for creating beautiful iOS applications using SwiftUI"
        )
      ]
    )
    
    let podcastManager = InMemoryPodcastManager(initial: [samplePodcast])
    
    // 2. Initialize search integration
    let searchIntegration = SearchIntegrationExample(podcastManager: podcastManager)
    await searchIntegration.initializeSearch()
    
    // 3. Perform searches
    print("=== Search Integration Demo ===")
    
    // Search for Swift content
    let swiftResults = await searchIntegration.search(query: "swift")
    print("Search for 'swift' returned \(swiftResults.count) results")
    
    for result in swiftResults {
      switch result {
      case .podcast(let podcast, let score):
        print("  📻 Podcast: \(podcast.title) (score: \(String(format: "%.2f", score)))")
      case .episode(let episode, let score):
        print("  🎧 Episode: \(episode.title) (score: \(String(format: "%.2f", score)))")
      case .note(_, let score):
        print("  📝 Note (score: \(String(format: "%.2f", score)))")
      }
    }
    
    // Search only episodes
    let episodeResults = await searchIntegration.searchEpisodes(query: "iOS")
    print("\nSearch episodes for 'iOS' returned \(episodeResults.count) results")
    
    // Search only podcasts  
    let podcastResults = await searchIntegration.searchPodcasts(query: "weekly")
    print("Search podcasts for 'weekly' returned \(podcastResults.count) results")
  }
}