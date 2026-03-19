import Foundation
import CoreModels

/// Searches the iTunes Search API for podcasts. No API key required.
///
/// API reference: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/
public struct ITunesSearchProvider: PodcastDirectorySearching {

    private let urlSession: URLSession
    private static let baseURL = "https://itunes.apple.com/search"

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func search(query: String, limit: Int = 25) async throws -> [DirectorySearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DirectorySearchError.invalidQuery
        }

        let url = try buildURL(query: trimmed, limit: limit)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(from: url)
        } catch {
            throw DirectorySearchError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DirectorySearchError.httpError(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            return decoded.results.compactMap { DirectorySearchResult(from: $0) }
        } catch {
            throw DirectorySearchError.decodingError(error)
        }
    }

    // MARK: - Private helpers

    private func buildURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: ITunesSearchProvider.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]
        guard let url = components.url else {
            throw DirectorySearchError.invalidQuery
        }
        return url
    }
}

// MARK: - Internal response models (iTunes JSON shape)

private struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesPodcastResult]
}

private struct ITunesPodcastResult: Decodable {
    let collectionId: Int?
    let collectionName: String?
    let artistName: String?
    let artworkUrl600: String?
    let artworkUrl100: String?
    let feedUrl: String?
    let primaryGenreName: String?
    let genres: [String]?
    let trackCount: Int?
    let description: String?

    // iTunes uses `kind` but for podcasts, `wrapperType` is "track" and `kind` is "podcast"
    let kind: String?
}

private extension DirectorySearchResult {
    init?(from result: ITunesPodcastResult) {
        // Must have a feed URL — without it we can't subscribe.
        guard let feedURLString = result.feedUrl,
              let feedURL = URL(string: feedURLString) else {
            return nil
        }
        let title = result.collectionName ?? ""
        guard !title.isEmpty else { return nil }

        let artworkURL = (result.artworkUrl600 ?? result.artworkUrl100).flatMap { URL(string: $0) }
        let id = result.collectionId.map { String($0) } ?? feedURLString

        self.init(
            id: id,
            title: title,
            author: result.artistName,
            description: result.description,
            artworkURL: artworkURL,
            feedURL: feedURL,
            genres: result.genres ?? [result.primaryGenreName].compactMap { $0 },
            episodeCount: result.trackCount,
            provider: "itunes"
        )
    }
}
