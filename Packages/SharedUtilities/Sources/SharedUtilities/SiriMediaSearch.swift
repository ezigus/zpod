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
  private static func levenshteinDistance(_ first: String, _ second: String) -> Int {
    let lhsCharacters = Array(first)
    let rhsCharacters = Array(second)

    var matrix = [[Int]](
      repeating: [Int](repeating: 0, count: rhsCharacters.count + 1),
      count: lhsCharacters.count + 1
    )

    for rowIndex in 0...lhsCharacters.count {
      matrix[rowIndex][0] = rowIndex
    }

    for columnIndex in 0...rhsCharacters.count {
      matrix[0][columnIndex] = columnIndex
    }

    for rowIndex in 1...lhsCharacters.count {
      for columnIndex in 1...rhsCharacters.count {
        if lhsCharacters[rowIndex - 1] == rhsCharacters[columnIndex - 1] {
          matrix[rowIndex][columnIndex] = matrix[rowIndex - 1][columnIndex - 1]
        } else {
          matrix[rowIndex][columnIndex] = min(
            matrix[rowIndex - 1][columnIndex] + 1,  // deletion
            matrix[rowIndex][columnIndex - 1] + 1,  // insertion
            matrix[rowIndex - 1][columnIndex - 1] + 1  // substitution
          )
        }
      }
    }

    return matrix[lhsCharacters.count][rhsCharacters.count]
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
