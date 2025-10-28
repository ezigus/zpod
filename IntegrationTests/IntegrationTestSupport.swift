import XCTest
@testable import CoreModels
@testable import TestSupport
@testable import SearchDomain
@testable import DiscoverFeature
@testable import PlaybackEngine

// MARK: - Mock Episode State Manager

final class MockEpisodeStateManager: EpisodeStateManager, @unchecked Sendable {
    private actor Storage {
        private var episodes: [String: Episode] = [:]

        func update(_ episode: Episode) {
            episodes[episode.id] = episode
        }

        func episode(for id: String) -> Episode? {
            episodes[id]
        }
    }

    private let storage = Storage()

    func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
        let updatedEpisode = episode.withPlayedStatus(isPlayed)
        await storage.update(updatedEpisode)
    }

    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
        let updatedEpisode = episode.withPlaybackPosition(Int(position))
        await storage.update(updatedEpisode)
    }

    func updateEpisodeState(_ episode: Episode) async {
        await storage.update(episode)
    }

    func getEpisodeState(_ episode: Episode) async -> Episode {
        await storage.episode(for: episode.id) ?? episode
    }
}

// MARK: - Mock RSS Parser

final class MockRSSParser: RSSFeedParsing, @unchecked Sendable {
    var mockPodcast: Podcast?
    var shouldThrowError = false
    
    func parseFeed(from url: URL) async throws -> Podcast {
        if shouldThrowError {
            throw NSError(domain: "MockRSSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock RSS parsing error"])
        }
        
        return mockPodcast ?? Podcast(
            id: "mock-podcast",
            title: "Mock Podcast",
            feedURL: url
        )
    }
}

// MARK: - Podcast Index Source

final class PodcastIndexSource: SearchIndexSource {
    private let podcastManager: PodcastManaging
    
    init(podcastManager: PodcastManaging) {
        self.podcastManager = podcastManager
    }
    
    func documents() -> [SearchableDocument] {
        return podcastManager.all().map { podcast in
            SearchableDocument(
                id: podcast.id,
                type: .podcast,
                fields: [
                    .title: podcast.title,
                    .author: podcast.author ?? "",
                    .description: podcast.description ?? ""
                ],
                sourceObject: podcast
            )
        }
    }
}

// MARK: - Episode Index Source

final class EpisodeIndexSource: SearchIndexSource {
    private let podcastManager: PodcastManaging
    
    init(podcastManager: PodcastManaging) {
        self.podcastManager = podcastManager
    }
    
    func documents() -> [SearchableDocument] {
        return podcastManager.all().flatMap { podcast in
            podcast.episodes.map { episode in
                SearchableDocument(
                    id: episode.id,
                    type: .episode,
                    fields: [
                        .title: episode.title,
                        .description: episode.description ?? ""
                    ],
                    sourceObject: episode
                )
            }
        }
    }
}

// MARK: - Playlist Manager

@MainActor
final class PlaylistManager: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var smartPlaylists: [SmartPlaylist] = []
    
    func createPlaylist(_ playlist: Playlist) async {
        playlists.append(playlist)
    }
    
    func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) async {
        smartPlaylists.append(smartPlaylist)
    }
}

// MARK: - Playlist Engine

final class PlaylistEngine: @unchecked Sendable {
    func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) async -> [Episode] {
        var matchingEpisodes = episodes
        
        for filterRule in smartPlaylist.criteria.filterRules {
            matchingEpisodes = matchingEpisodes.filter { episode in
                matchesFilterRule(filterRule, episode: episode, downloadStatus: downloadStatuses[episode.id])
            }
        }
        
        if matchingEpisodes.count > smartPlaylist.criteria.maxEpisodes {
            matchingEpisodes = Array(matchingEpisodes.prefix(smartPlaylist.criteria.maxEpisodes))
        }
        
        return matchingEpisodes
    }
    
    func generatePlaybackQueue(
        from playlist: Playlist,
        episodes: [Episode],
        shuffle: Bool = false
    ) async -> [Episode] {
        let matchingEpisodes = episodes.filter { episode in
            playlist.episodeIds.contains(episode.id)
        }
        
        if !shuffle || !playlist.shuffleAllowed {
            return playlist.episodeIds.compactMap { episodeId in
                matchingEpisodes.first { $0.id == episodeId }
            }
        } else {
            return matchingEpisodes.shuffled()
        }
    }
    
    private func matchesFilterRule(_ rule: SmartPlaylistFilterRule, episode: Episode, downloadStatus: DownloadState?) -> Bool {
        switch rule {
        case .isPlayed(let isPlayed):
            return episode.isPlayed == isPlayed
        case .isDownloaded:
            return downloadStatus == .completed
        case .podcastCategory(_):
            return true // For testing purposes
        case .dateRange(let start, let end):
            guard let pubDate = episode.pubDate else { return false }
            return pubDate >= start && pubDate <= end
        case .durationRange(let min, let max):
            guard let duration = episode.duration else { return false }
            return duration >= min && duration <= max
        }
    }
}

// MARK: - Extensions for Testing

extension InMemoryPodcastManager {
    func findByFolderRecursive(folderId: String, folderManager: InMemoryFolderManager) -> [Podcast] {
        let directPodcasts = findByFolder(folderId: folderId)
        let childFolders = folderManager.getDescendants(of: folderId)
        let childPodcasts = childFolders.flatMap { folder in
            findByFolder(folderId: folder.id)
        }
        return directPodcasts + childPodcasts
    }
    
    func getSubscribedPodcasts() -> [Podcast] {
        return all().filter { $0.isSubscribed }
    }
}

extension Podcast {
    func withSubscriptionStatus(_ isSubscribed: Bool) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            description: self.description,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: self.episodes,
            isSubscribed: isSubscribed,
            dateAdded: self.dateAdded,
            folderId: self.folderId,
            tagIds: self.tagIds
        )
    }
}
