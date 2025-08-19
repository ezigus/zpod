import Foundation

/// In-memory search index for fast term lookup
public final class SearchIndex {
  
  /// Mapping from terms to documents containing them
  private var termIndex: [String: [IndexedDocument]] = [:]
  
  /// Tokenizer for processing text
  private let tokenizer = Tokenizer()
  
  public init() {}
  
  /// Add a document to the search index
  /// - Parameter document: Document to index
  public func addDocument(_ document: SearchableDocument) {
    // Build term frequencies for each field
    var fieldTermFrequencies: [FieldType: [String: Int]] = [:]
    
    for (fieldType, fieldText) in document.fields {
      let terms = tokenizer.tokenize(fieldText)
      var termFreq: [String: Int] = [:]
      
      for term in terms {
        termFreq[term, default: 0] += 1
      }
      
      fieldTermFrequencies[fieldType] = termFreq
    }
    
    let indexedDoc = IndexedDocument(
      id: document.id,
      type: document.type,
      termFrequencies: fieldTermFrequencies,
      sourceObject: document.sourceObject
    )
    
    // Add document to term index for each unique term
    for (_, termFreq) in fieldTermFrequencies {
      for term in termFreq.keys {
        termIndex[term, default: []].append(indexedDoc)
      }
    }
  }
  
  /// Find documents containing the specified term
  /// - Parameter term: Search term to look up
  /// - Returns: Array of indexed documents containing the term
  public func findDocuments(for term: String) -> [IndexedDocument] {
    let normalizedTerm = tokenizer.normalize(term)
    return termIndex[normalizedTerm] ?? []
  }
  
  /// Clear all documents from the index
  public func clear() {
    termIndex.removeAll()
  }
  
  /// Get all indexed terms (primarily for debugging/testing)
  public func getAllTerms() -> [String] {
    return Array(termIndex.keys)
  }
}