import Foundation

/// Tokenizer for processing text into searchable terms
public final class Tokenizer {
  
  // Common English stop words to filter out
  private static let stopWords: Set<String> = [
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
    "has", "he", "in", "is", "it", "its", "of", "on", "that", "the",
    "to", "was", "were", "will", "with", "you", "your", "i", "me", "my",
    "we", "us", "our", "this", "these", "those", "they", "them", "their"
  ]
  
  public init() {}
  
  /// Tokenize text into normalized search terms
  /// - Parameter text: Input text to tokenize
  /// - Returns: Array of normalized, filtered tokens
  public func tokenize(_ text: String) -> [String] {
    guard !text.isEmpty else { return [] }
    
    // Normalize to lowercase
    let normalized = text.lowercased()
    
    // Split on word boundaries and remove punctuation
    let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    
    // Filter out stop words and very short words
    return words
      .filter { word in
        word.count >= 2 && !Self.stopWords.contains(word)
      }
  }
  
  /// Normalize a single term for consistent indexing/search
  /// - Parameter term: Input term to normalize
  /// - Returns: Normalized term
  public func normalize(_ term: String) -> String {
    return term.lowercased()
      .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  }
}