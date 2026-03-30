import Foundation
import CoreModels

/// Runs multiple `PodcastDirectorySearching` providers concurrently and merges results.
///
/// Each provider executes in its own child task. Individual provider failures are absorbed —
/// only if ALL providers fail does `search` throw (propagating the first error encountered).
/// Deduplication is by `feedURL.absoluteString`; the first provider's result wins on collision.
public struct AggregateSearchProvider: PodcastDirectorySearching {

    private let providers: [any PodcastDirectorySearching]

    public init(providers: [any PodcastDirectorySearching]) {
        self.providers = providers
    }

    public func search(query: String, limit: Int = 25) async throws -> [DirectorySearchResult] {
        guard !providers.isEmpty else { return [] }

        var allResults: [[DirectorySearchResult]] = []
        var firstError: (any Error)?

        await withTaskGroup(of: Result<[DirectorySearchResult], any Error>.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return .success(try await provider.search(query: query, limit: limit))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            for await result in group {
                switch result {
                case .success(let results):
                    allResults.append(results)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
            }
        }

        // If every provider failed, propagate the first error.
        if allResults.isEmpty, let error = firstError {
            throw error
        }

        // Deduplicate by feed URL; order of providers determines priority.
        var seen = Set<String>()
        var merged: [DirectorySearchResult] = []
        for results in allResults {
            for result in results {
                let key = result.feedURL.absoluteString
                if seen.insert(key).inserted {
                    merged.append(result)
                }
            }
        }
        return merged
    }
}
