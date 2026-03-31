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

        // Keyed by provider index so deduplication respects the original providers order,
        // not task-group completion order (which is nondeterministic).
        var resultsByIndex: [Int: [DirectorySearchResult]] = [:]
        var firstError: (any Error)?

        await withTaskGroup(of: (Int, Result<[DirectorySearchResult], any Error>).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    do {
                        return (index, .success(try await provider.search(query: query, limit: limit)))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            for await (index, result) in group {
                switch result {
                case .success(let results):
                    resultsByIndex[index] = results
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
            }
        }

        // If every provider failed, propagate the first error.
        if resultsByIndex.isEmpty, let error = firstError {
            throw error
        }

        // Merge in provider order; first provider wins on duplicate feed URL.
        var seen = Set<String>()
        var merged: [DirectorySearchResult] = []
        for index in providers.indices {
            for result in resultsByIndex[index] ?? [] {
                let key = result.feedURL.absoluteString
                if seen.insert(key).inserted {
                    merged.append(result)
                }
            }
        }
        return merged
    }
}
