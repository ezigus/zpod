import Foundation

// MARK: - Protocols
public protocol FeedDataLoading {
  func load(url: URL) async throws -> Data
}

public protocol FeedParsing {
  func parse(data: Data, sourceURL: URL) throws -> ParsedFeed
}

// MARK: - Models
public struct ParsedFeed {
  public let podcast: Podcast
  public init(podcast: Podcast) { self.podcast = podcast }
}

// MARK: - Service
public final class SubscriptionService {
  public enum Error: Swift.Error, Equatable {
    case invalidURL
    case dataLoadFailed
    case parseFailed
    case duplicateSubscription
  }

  private let dataLoader: FeedDataLoading
  private let parser: FeedParsing
  private let podcastManager: PodcastManaging

  public init(dataLoader: FeedDataLoading, parser: FeedParsing, podcastManager: PodcastManaging) {
    self.dataLoader = dataLoader
    self.parser = parser
    self.podcastManager = podcastManager
  }

  @discardableResult
  public func subscribe(urlString: String) async throws -> Podcast {
    guard let url = URL(string: urlString),
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme)
    else {
      throw Error.invalidURL
    }
    return try await subscribe(feedURL: url)
  }

  @discardableResult
  public func subscribe(feedURL: URL) async throws -> Podcast {
    if podcastManager.find(id: feedURL.absoluteString) != nil { throw Error.duplicateSubscription }
    let data: Data
    do { 
      data = try await dataLoader.load(url: feedURL) 
    } catch {
      throw Error.dataLoadFailed
    }
    let parsed: ParsedFeed
    do { 
      parsed = try parser.parse(data: data, sourceURL: feedURL) 
    } catch {
      throw Error.parseFailed
    }
    var p = parsed.podcast
    // Ensure subscription flags
    p = Podcast(
      id: p.id,
      title: p.title,
      author: p.author,
      description: p.description,
      artworkURL: p.artworkURL,
      feedURL: p.feedURL,
      categories: p.categories,
      episodes: p.episodes,
      isSubscribed: true,
      dateAdded: Date()
    )
    podcastManager.add(p)
    return p
  }
}

// MARK: - Simple Data Loader (Placeholder)
public final class PassthroughFeedDataLoader: FeedDataLoading {
  private let provider: (URL) async throws -> Data
  public init(provider: @escaping (URL) async throws -> Data) { self.provider = provider }
  public func load(url: URL) async throws -> Data { try await provider(url) }
}
