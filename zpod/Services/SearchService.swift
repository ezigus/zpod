import Foundation

/// Unified search service for podcasts, episodes, and notes
@MainActor
public final class SearchService: SearchServicing {
  
  /// Weight multipliers for different field types in relevance scoring
  private static let fieldWeights: [FieldType: Double] = [
    .title: 3.0,
    .author: 1.0,
    .description: 1.0,
    .showNotes: 1.0
  ]
  
  private let indexSources: [SearchIndexSource]
  private let index = SearchIndex()
  private let tokenizer = Tokenizer()
  
  public init(indexSources: [SearchIndexSource]) {
    self.indexSources = indexSources
  }
  
  /// Perform a search across all indexed content
  /// - Parameters:
  ///   - query: Search query string
  ///   - filter: Optional filter to restrict result types
  /// - Returns: Array of search results ordered by relevance
  public func search(query: String, filter: SearchFilter?) async -> [SearchResult] {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return []
    }
    
    let searchTerms = tokenizer.tokenize(query)
    guard !searchTerms.isEmpty else {
      return []
    }
    
    // Collect candidate documents for each search term
    var candidateDocuments: [String: IndexedDocument] = [:]
    
    for term in searchTerms {
      let documents = index.findDocuments(for: term)
      for doc in documents {
        candidateDocuments[doc.id] = doc
      }
    }
    
    // Score each candidate document
    var scoredResults: [(SearchResult, Double)] = []
    
    for (_, document) in candidateDocuments {
      let score = calculateRelevanceScore(document: document, searchTerms: searchTerms)
      
      if score > 0, let result = createSearchResult(document: document, score: score) {
        // Apply filter if specified
        if shouldIncludeResult(result, filter: filter) {
          scoredResults.append((result, score))
        }
      }
    }
    
    // Sort by relevance score (descending)
    scoredResults.sort { $0.1 > $1.1 }
    
    return scoredResults.map { $0.0 }
  }
  
  /// Rebuild the search index from all sources
  public func rebuildIndex() async {
    index.clear()
    
    for source in indexSources {
      let documents = source.documents()
      for document in documents {
        index.addDocument(document)
      }
    }
  }
  
  // MARK: - Private Methods
  
  /// Calculate relevance score for a document given search terms
  private func calculateRelevanceScore(document: IndexedDocument, searchTerms: [String]) -> Double {
    var totalScore: Double = 0
    var totalTerms = 0
    
    for (fieldType, termFrequencies) in document.termFrequencies {
      let fieldWeight = Self.fieldWeights[fieldType] ?? 1.0
      
      for searchTerm in searchTerms {
        if let frequency = termFrequencies[searchTerm] {
          // Basic TF score: term frequency * field weight
          totalScore += Double(frequency) * fieldWeight
          totalTerms += frequency
        }
      }
    }
    
    // Normalize by document length (total terms) to favor precision
    let documentLength = Double(max(totalTerms, 1))
    return totalScore / documentLength
  }
  
  /// Create a SearchResult from an IndexedDocument
  private func createSearchResult(document: IndexedDocument, score: Double) -> SearchResult? {
    switch document.type {
    case .podcast:
      if let podcast = document.sourceObject as? Podcast {
        return .podcast(podcast, relevanceScore: score)
      }
    case .episode:
      if let episode = document.sourceObject as? Episode {
        return .episode(episode, relevanceScore: score)
      }
    case .note:
      if let note = document.sourceObject as? Note {
        return .note(note, relevanceScore: score)
      }
    }
    return nil
  }
  
  /// Check if a result should be included based on the filter
  private func shouldIncludeResult(_ result: SearchResult, filter: SearchFilter?) -> Bool {
    guard let filter = filter else { return true }
    
    switch (result, filter) {
    case (.podcast(_, _), .podcastsOnly):
      return true
    case (.episode(_, _), .episodesOnly):
      return true
    case (.note(_, _), .notesOnly):
      return true
    case (_, .all):
      return true
    default:
      return false
    }
  }
}