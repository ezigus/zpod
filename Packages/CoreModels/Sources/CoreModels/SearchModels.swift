import Foundation

// MARK: - Search Result Types

/// Represents a search result with heterogeneous content types and relevance scoring
public enum SearchResult: Equatable, Sendable {
  case podcast(Podcast, relevanceScore: Double)
  case episode(Episode, relevanceScore: Double)
  case note(Note, relevanceScore: Double) // Future expansion
  
  public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
    switch (lhs, rhs) {
    case (.podcast(let lPodcast, let lScore), .podcast(let rPodcast, let rScore)):
      return lPodcast == rPodcast && abs(lScore - rScore) < 0.001
    case (.episode(let lEpisode, let lScore), .episode(let rEpisode, let rScore)):
      return lEpisode == rEpisode && abs(lScore - rScore) < 0.001
    case (.note(let lNote, let lScore), .note(let rNote, let rScore)):
      return lNote == rNote && abs(lScore - rScore) < 0.001
    default:
      return false
    }
  }
}

extension SearchResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, data, relevanceScore
    }
    
    private enum ResultType: String, Codable {
        case podcast, episode, note
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ResultType.self, forKey: .type)
        let score = try container.decode(Double.self, forKey: .relevanceScore)
        
        switch type {
        case .podcast:
            let podcast = try container.decode(Podcast.self, forKey: .data)
            self = .podcast(podcast, relevanceScore: score)
        case .episode:
            let episode = try container.decode(Episode.self, forKey: .data)
            self = .episode(episode, relevanceScore: score)
        case .note:
            let note = try container.decode(Note.self, forKey: .data)
            self = .note(note, relevanceScore: score)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .podcast(let podcast, let score):
            try container.encode(ResultType.podcast, forKey: .type)
            try container.encode(podcast, forKey: .data)
            try container.encode(score, forKey: .relevanceScore)
        case .episode(let episode, let score):
            try container.encode(ResultType.episode, forKey: .type)
            try container.encode(episode, forKey: .data)
            try container.encode(score, forKey: .relevanceScore)
        case .note(let note, let score):
            try container.encode(ResultType.note, forKey: .type)
            try container.encode(note, forKey: .data)
            try container.encode(score, forKey: .relevanceScore)
        }
    }
}

/// Filter options for search results
public enum SearchFilter: String, Codable, Sendable {
  case all
  case podcastsOnly
  case episodesOnly
  case notesOnly // Future
}

// MARK: - Search Index Types

/// Types of documents that can be indexed for search
public enum DocumentType {
  case podcast
  case episode
  case note // Future
}

/// Fields within documents that can be searched
public enum FieldType {
  case title
  case author
  case description
  case showNotes // Future
}

/// Represents a document in the search index
public struct SearchableDocument {
  public let id: String
  public let type: DocumentType
  public let fields: [FieldType: String]
  public let sourceObject: Any
  public init(id: String, type: DocumentType, fields: [FieldType: String], sourceObject: Any) {
    self.id = id
    self.type = type
    self.fields = fields
    self.sourceObject = sourceObject
  }
}

/// Internal representation of an indexed document with term frequency information
public struct IndexedDocument {
  public let id: String
  public let type: DocumentType
  public let termFrequencies: [FieldType: [String: Int]]
  public let sourceObject: Any
  public init(id: String, type: DocumentType, termFrequencies: [FieldType: [String: Int]], sourceObject: Any) {
    self.id = id
    self.type = type
    self.termFrequencies = termFrequencies
    self.sourceObject = sourceObject
  }
}

// MARK: - Search Query Types

/// Search query configuration
public struct SearchQuery: Codable, Equatable, Sendable {
    public let text: String
    public let filter: SearchFilter
    public let sortBy: SearchSortBy
    public let categoryFilters: [String]
    public let podcastId: String?
    public let dateRange: DateRange?
    
    public init(
        text: String,
        filter: SearchFilter,
        sortBy: SearchSortBy,
        categoryFilters: [String] = [],
        podcastId: String? = nil,
        dateRange: DateRange? = nil
    ) {
        self.text = text
        self.filter = filter
        self.sortBy = sortBy
        self.categoryFilters = categoryFilters
        self.podcastId = podcastId
        self.dateRange = dateRange
    }
}

/// Search result sorting options
public enum SearchSortBy: String, Codable, Sendable {
    case relevance
    case datePublished
    case dateAdded
    case duration
    case title
}

/// Date range for filtering search results
public struct DateRange: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// Search results container
public struct SearchResults: Codable, Equatable, Sendable {
    public let query: SearchQuery
    public let results: [SearchResult]
    public let totalCount: Int
    public let hasMore: Bool
    
    public init(
        query: SearchQuery,
        results: [SearchResult],
        totalCount: Int,
        hasMore: Bool
    ) {
        self.query = query
        self.results = results
        self.totalCount = totalCount
        self.hasMore = hasMore
    }
}

/// Search suggestions for auto-complete
public enum SearchSuggestion: Equatable, Sendable {
    case text(String)
    case podcast(Podcast)
    case category(String)
}

// MARK: - Note Model (Future Placeholder)

/// Placeholder for future note functionality
public struct Note: Codable, Equatable, Sendable {
    public let id: String
    public let content: String
    public let episodeId: String?
    public let timestamp: TimeInterval?
    public let createdAt: Date
    
    public init(
        id: String, 
        content: String, 
        timestamp: TimeInterval? = nil,
        episodeId: String? = nil, 
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.episodeId = episodeId
        self.createdAt = createdAt
    }
}

// MARK: - Search Protocols

/// Protocol for providing documents to the search index
public protocol SearchIndexSource {
  func documents() -> [SearchableDocument]
}

/// Protocol for search service functionality  
@MainActor
public protocol SearchServicing {
  func search(query: String, filter: SearchFilter?) async -> [SearchResult]
  func rebuildIndex() async
}
