import Foundation
import CoreModels
import CryptoKit

/// Searches the PodcastIndex directory for podcasts. Requires API key and secret.
///
/// API reference: https://podcastindex-org.github.io/docs-api/
///
/// Authentication uses HMAC-style SHA-1: `SHA1(apiKey + apiSecret + epochSeconds)`.
/// Keys are read from the caller at init time (typically from `Bundle.main.infoDictionary`
/// populated via a `.xcconfig` file excluded from version control).
public struct PodcastIndexSearchProvider: PodcastDirectorySearching {

    private let apiKey: String
    private let apiSecret: String
    private let urlSession: URLSession
    private static let baseURL = "https://api.podcastindex.org/api/1.0/search/byterm"

    /// Returns `nil` when `apiKey` or `apiSecret` is `nil` or empty.
    /// This makes PodcastIndex opt-in: callers use `compactMap` to naturally exclude it.
    public init?(apiKey: String?, apiSecret: String?, urlSession: URLSession = .shared) {
        guard let key = apiKey, !key.isEmpty,
              let secret = apiSecret, !secret.isEmpty else {
            return nil
        }
        self.apiKey = key
        self.apiSecret = secret
        self.urlSession = urlSession
    }

    public func search(query: String, limit: Int = 25) async throws -> [DirectorySearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DirectorySearchError.invalidQuery
        }

        let url = try buildURL(query: trimmed, limit: limit)
        var request = URLRequest(url: url)
        for (field, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw DirectorySearchError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DirectorySearchError.httpError(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(PodcastIndexResponse.self, from: data)
            return decoded.feeds.compactMap { DirectorySearchResult(from: $0) }
        } catch {
            throw DirectorySearchError.decodingError(error)
        }
    }

    // MARK: - Private helpers

    private func buildURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "max", value: String(min(limit, 200))),
        ]
        guard let url = components.url else {
            throw DirectorySearchError.invalidQuery
        }
        return url
    }

    /// Builds the three authentication headers required by PodcastIndex.
    private func authHeaders() -> [String: String] {
        let epoch = String(Int(Date().timeIntervalSince1970))
        let hashInput = apiKey + apiSecret + epoch
        let digest = Insecure.SHA1.hash(data: Data(hashInput.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return [
            "X-Auth-Key": apiKey,
            "X-Auth-Date": epoch,
            "Authorization": hex,
            "User-Agent": "zpod/1.0",
        ]
    }
}

// MARK: - Internal response models (PodcastIndex JSON shape)

private struct PodcastIndexResponse: Decodable {
    let status: String
    let feeds: [PodcastIndexFeed]
    let count: Int
}

private struct PodcastIndexFeed: Decodable {
    let id: Int?
    let title: String?
    let author: String?
    let description: String?
    let artwork: String?
    let url: String?          // feed URL
    let episodeCount: Int?

    // PodcastIndex returns categories as {"1": "Technology", "2": "Music"}
    // We only need the values; decode as a flexible type and extract strings.
    let categories: [String: String]?
}

private extension DirectorySearchResult {
    init?(from feed: PodcastIndexFeed) {
        // Must have a feed URL — without it we can't subscribe.
        guard let feedURLString = feed.url,
              let feedURL = URL(string: feedURLString) else {
            return nil
        }
        let title = feed.title ?? ""
        guard !title.isEmpty else { return nil }

        let artworkURL = feed.artwork.flatMap { URL(string: $0) }
        let id = feed.id.map { String($0) } ?? feedURLString
        let genres = feed.categories.map { Array($0.values) } ?? []

        self.init(
            id: id,
            title: title,
            author: feed.author,
            description: feed.description,
            artworkURL: artworkURL,
            feedURL: feedURL,
            genres: genres,
            episodeCount: feed.episodeCount,
            provider: "podcastindex"
        )
    }
}
