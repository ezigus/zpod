import Foundation
import CoreModels

// MARK: - Protocol

/// A provider that can search an external podcast directory by name or keyword.
public protocol PodcastDirectorySearching: Sendable {
    /// Search the external directory for podcasts matching `query`.
    /// - Parameters:
    ///   - query: User-supplied search term.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching directory results, ordered by relevance.
    func search(query: String, limit: Int) async throws -> [DirectorySearchResult]
}

// MARK: - Error

/// Errors that can occur during an external directory search.
public enum DirectorySearchError: Error, Sendable {
    /// The query was empty or contained only whitespace.
    case invalidQuery
    /// A network-level error occurred (transient; degrade gracefully).
    case networkError(URLError)
    /// The response could not be decoded (hard failure; schema may have changed).
    case decodingError(DecodingError)
    /// The server returned a non-200 HTTP status (or an application-level auth failure).
    case httpError(Int)
}

extension DirectorySearchError: Equatable {
    public static func == (lhs: DirectorySearchError, rhs: DirectorySearchError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidQuery, .invalidQuery):
            return true
        case (.httpError(let l), .httpError(let r)):
            return l == r
        case (.networkError(let l), .networkError(let r)):
            return l.code == r.code
        case (.decodingError, .decodingError):
            // Compare by case only; DecodingError is not Equatable.
            return true
        default:
            return false
        }
    }
}

extension DirectorySearchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Search query is empty."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let code):
            return "Server returned HTTP \(code)."
        }
    }
}
