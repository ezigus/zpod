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

/// Filter options for search results
public enum SearchFilter: Sendable {
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

// MARK: - Note Model (Future Placeholder)

/// Placeholder for future note functionality
public struct Note: Codable, Equatable, Sendable {
  public let id: String
  public let content: String
  public let episodeId: String?
  public let timestamp: TimeInterval?
  
  public init(id: String, content: String, episodeId: String? = nil, timestamp: TimeInterval? = nil) {
    self.id = id
    self.content = content
    self.episodeId = episodeId
    self.timestamp = timestamp
  }
}

// MARK: - Search Protocols

/// Protocol for providing documents to the search index
public protocol SearchIndexSource {
  func documents() -> [SearchableDocument]
}

/// Protocol for search service functionality  
public protocol SearchServicing {
  func search(query: String, filter: SearchFilter?) async -> [SearchResult]
  func rebuildIndex() async
}