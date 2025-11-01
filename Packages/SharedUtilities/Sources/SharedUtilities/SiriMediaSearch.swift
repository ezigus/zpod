//
//  SiriMediaSearch.swift
//  SharedUtilities
//
//  Created for Issue 02.1.8: CarPlay Siri Integration
//

import Foundation

/// Provides fuzzy matching and search capabilities for Siri media queries
@available(iOS 14.0, *)
public struct SiriMediaSearch {

  /// Search result with confidence score
  public struct SearchResult<T> {
    public let item: T
    public let score: Double

    public init(item: T, score: Double) {
      self.item = item
      self.score = score
    }
  }

  /// Performs fuzzy string matching and returns a confidence score (0.0 - 1.0)
  public static func fuzzyMatch(query: String, target: String) -> Double {
    let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty query returns zero
    if normalizedQuery.isEmpty {
      return 0.0
    }

    // Exact match
    if normalizedQuery == normalizedTarget {
      return 1.0
    }

    // Contains match
    if normalizedTarget.contains(normalizedQuery) {
      // Score based on how much of the target the query represents
      let ratio = Double(normalizedQuery.count) / Double(normalizedTarget.count)
      return 0.7 + (ratio * 0.3)  // 0.7 - 1.0 range
    }

    // Starts with match
    if normalizedTarget.hasPrefix(normalizedQuery) {
      return 0.8
    }

    // Levenshtein distance for typo tolerance
    let distance = levenshteinDistance(normalizedQuery, normalizedTarget)
    let maxLength = max(normalizedQuery.count, normalizedTarget.count)

    if distance <= 2 && maxLength > 3 {
      // Close match with 1-2 character difference
      return 0.6
    }

    // No match
    return 0.0
  }

  /// Calculates Levenshtein distance between two strings
  private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let s1 = Array(s1)
    let s2 = Array(s2)

    var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)

    for i in 0...s1.count {
      matrix[i][0] = i
    }

    for j in 0...s2.count {
      matrix[0][j] = j
    }

    for i in 1...s1.count {
      for j in 1...s2.count {
        if s1[i - 1] == s2[j - 1] {
          matrix[i][j] = matrix[i - 1][j - 1]
        } else {
          matrix[i][j] = min(
            matrix[i - 1][j] + 1,  // deletion
            matrix[i][j - 1] + 1,  // insertion
            matrix[i - 1][j - 1] + 1  // substitution
          )
        }
      }
    }

    return matrix[s1.count][s2.count]
  }

  /// Parses temporal references from search query
  public static func parseTemporalReference(_ query: String) -> TemporalReference? {
    let normalized = query.lowercased()

    if normalized.contains("latest") || normalized.contains("newest")
      || normalized.contains("recent")
    {
      return .latest
    }

    if normalized.contains("first") || normalized.contains("oldest") {
      return .oldest
    }

    return nil
  }

  /// Temporal reference types
  public enum TemporalReference {
    case latest
    case oldest
  }
}
