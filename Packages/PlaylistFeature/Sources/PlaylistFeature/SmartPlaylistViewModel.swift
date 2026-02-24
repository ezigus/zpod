import CoreModels
import Foundation

/// ViewModel for smart playlist management.
///
/// Owns the list state and delegates persistence to an injected `SmartPlaylistManaging`.
/// Episode evaluation uses the manager's built-in filter service so PlaylistFeature
/// remains decoupled from Persistence.
@MainActor
@Observable
public final class SmartPlaylistViewModel {

    // MARK: - Observable State

    public private(set) var smartPlaylists: [SmartEpisodeListV2] = []
    public private(set) var builtInPlaylists: [SmartEpisodeListV2] = []
    public private(set) var customPlaylists: [SmartEpisodeListV2] = []
    public var isShowingCreateSheet = false
    public var editingSmartPlaylist: SmartEpisodeListV2? = nil
    public var isShowingTemplatePicker = false
    public var isShowingAnalyticsDashboard = false
    public var errorMessage: String? = nil

    // MARK: - Episode Count Cache

    /// Cached episode counts keyed by smart playlist ID.
    /// Populated during `reload()` so rows can read counts without triggering
    /// a full evaluation pass on every SwiftUI render cycle.
    private var cachedEpisodeCounts: [String: Int] = [:]
    private var cachedEpisodeSignature: Int? = nil

    // MARK: - Dependencies

    private let manager: any SmartPlaylistManaging
    private let allEpisodesProvider: () -> [Episode]

    // MARK: - Analytics

    /// Injected repository for recording and querying play events.
    /// Set this from the app layer (LibraryFeature) after construction so PlaylistFeature
    /// stays free of a Persistence dependency.
    public var analyticsRepository: (any SmartPlaylistAnalyticsRepository)?

    // MARK: - Initialization

    public init(
        manager: any SmartPlaylistManaging,
        allEpisodesProvider: @escaping () -> [Episode] = { [] }
    ) {
        self.manager = manager
        self.allEpisodesProvider = allEpisodesProvider
        reload()
    }

    // MARK: - Playback Actions

    /// Called when the user requests "Play All" on a smart playlist's evaluated episodes.
    public var onPlayAll: (([Episode]) -> Void)? = nil

    /// Called when the user requests "Shuffle" on a smart playlist's evaluated episodes.
    public var onShuffle: (([Episode]) -> Void)? = nil

    // MARK: - Analytics Methods

    /// Record a play event when a user starts playing an episode from a smart playlist.
    public func recordPlay(of episode: Episode, from smartPlaylist: SmartEpisodeListV2) {
        analyticsRepository?.record(SmartPlaylistPlayEvent(
            playlistID: smartPlaylist.id,
            episodeID: episode.id,
            episodeDuration: episode.duration
        ))
    }

    /// Stats for a smart playlist based on stored play events.
    public func stats(for smartPlaylist: SmartEpisodeListV2) -> SmartPlaylistStats {
        analyticsRepository?.stats(for: smartPlaylist.id)
            ?? SmartPlaylistStats.empty(for: smartPlaylist.id)
    }

    /// Human-readable insights derived from play-event patterns.
    public func insights(for smartPlaylist: SmartEpisodeListV2) -> [SmartPlaylistInsight] {
        analyticsRepository?.insights(for: smartPlaylist.id) ?? []
    }

    /// JSON export of all play events for a smart playlist.
    public func exportJSON(for smartPlaylist: SmartEpisodeListV2) throws -> Data {
        if let repo = analyticsRepository {
            return try repo.exportJSON(for: smartPlaylist.id)
        }
        return try JSONEncoder().encode([SmartPlaylistPlayEvent]())
    }

    // MARK: - Episode Evaluation

    /// Evaluate a smart playlist and return matching episodes.
    public func episodes(for smartPlaylist: SmartEpisodeListV2) -> [Episode] {
        manager.evaluateSmartPlaylist(smartPlaylist, allEpisodes: allEpisodesProvider())
    }

    /// Total playback duration across evaluated episodes.
    public func totalDuration(for smartPlaylist: SmartEpisodeListV2) -> TimeInterval? {
        let eps = episodes(for: smartPlaylist)
        guard !eps.isEmpty else { return nil }
        let total = eps.compactMap(\.duration).reduce(0, +)
        return total > 0 ? total : nil
    }

    /// Preview episodes for a set of rules (used during creation/editing).
    public func previewEpisodes(for rules: SmartListRuleSet, sortBy: EpisodeSortBy = .pubDateNewest, maxEpisodes: Int? = nil) -> [Episode] {
        let preview = SmartEpisodeListV2(
            name: "Preview",
            rules: rules,
            sortBy: sortBy,
            maxEpisodes: maxEpisodes
        )
        return manager.evaluateSmartPlaylist(preview, allEpisodes: allEpisodesProvider())
    }

    // MARK: - Smart Playlist CRUD

    public func createSmartPlaylist(
        name: String,
        description: String? = nil,
        rules: SmartListRuleSet,
        sortBy: EpisodeSortBy = .pubDateNewest,
        maxEpisodes: Int? = nil,
        autoUpdate: Bool = true,
        refreshInterval: TimeInterval = 300
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let smartPlaylist = SmartEpisodeListV2(
            name: trimmedName,
            description: description,
            rules: rules,
            sortBy: sortBy,
            maxEpisodes: maxEpisodes,
            autoUpdate: autoUpdate,
            refreshInterval: refreshInterval
        )
        manager.createSmartPlaylist(smartPlaylist)
        reload()
    }

    public func createFromTemplate(_ template: SmartListRuleTemplate) {
        let smartPlaylist = SmartEpisodeListV2(
            name: template.name,
            description: template.description,
            rules: template.rules,
            sortBy: .pubDateNewest,
            autoUpdate: true
        )
        manager.createSmartPlaylist(smartPlaylist)
        reload()
    }

    public func updateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        manager.updateSmartPlaylist(smartPlaylist)
        reload()
    }

    public func deleteSmartPlaylist(id: String) {
        manager.deleteSmartPlaylist(id: id)
        reload()
    }

    public func deleteSmartPlaylist(at offsets: IndexSet) {
        let deletable = customPlaylists
        for index in offsets {
            guard index < deletable.count else { continue }
            manager.deleteSmartPlaylist(id: deletable[index].id)
        }
        reload()
    }

    /// Duplicate a custom smart playlist with a new ID and "(Copy)" suffix.
    public func duplicateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        guard !smartPlaylist.isSystemGenerated else { return }
        let copy = SmartEpisodeListV2(
            name: "\(smartPlaylist.name) Copy",
            description: smartPlaylist.description,
            rules: smartPlaylist.rules,
            sortBy: smartPlaylist.sortBy,
            maxEpisodes: smartPlaylist.maxEpisodes,
            autoUpdate: smartPlaylist.autoUpdate,
            refreshInterval: smartPlaylist.refreshInterval
        )
        manager.createSmartPlaylist(copy)
        reload()
    }

    // MARK: - Templates

    public func availableTemplates() -> [SmartListRuleTemplate] {
        manager.availableTemplates()
    }

    public func templatesByCategory() -> [SmartListTemplateCategory: [SmartListRuleTemplate]] {
        Dictionary(grouping: manager.availableTemplates(), by: \.category)
    }

    /// Cached episode count for a smart playlist, computed during the last `reload()`.
    /// Use this in list rows to avoid triggering a full evaluation per SwiftUI render cycle.
    public func cachedEpisodeCount(for smartPlaylist: SmartEpisodeListV2) -> Int {
        cachedEpisodeCountsSnapshot()[smartPlaylist.id] ?? 0
    }

    /// Snapshot of cached episode counts keyed by smart playlist ID.
    /// Refreshes the cache when the underlying episode input set changes.
    public func cachedEpisodeCountsSnapshot() -> [String: Int] {
        refreshCachedEpisodeCountsIfNeeded()
        return cachedEpisodeCounts
    }

    // MARK: - Private

    private func reload() {
        smartPlaylists = manager.allSmartPlaylists()
        builtInPlaylists = manager.builtInSmartPlaylists()
        customPlaylists = manager.customSmartPlaylists()
        refreshCachedEpisodeCountsIfNeeded(force: true)
    }

    private func refreshCachedEpisodeCountsIfNeeded(force: Bool = false) {
        let allEpisodes = allEpisodesProvider()
        let signature = Self.episodeSignature(for: allEpisodes)
        guard force || signature != cachedEpisodeSignature else { return }
        cachedEpisodeSignature = signature
        cachedEpisodeCounts = Dictionary(uniqueKeysWithValues: smartPlaylists.map { smartPlaylist in
            (smartPlaylist.id, manager.evaluateSmartPlaylist(smartPlaylist, allEpisodes: allEpisodes).count)
        })
    }

    private static func episodeSignature(for episodes: [Episode]) -> Int {
        var hasher = Hasher()
        hasher.combine(episodes.count)
        for episode in episodes.sorted(by: { $0.id < $1.id }) {
            hasher.combine(episode.id)
            hasher.combine(episode.title)
            hasher.combine(episode.podcastID)
            hasher.combine(episode.podcastTitle)
            hasher.combine(episode.playbackPosition)
            hasher.combine(episode.isPlayed)
            hasher.combine(episode.pubDate?.timeIntervalSinceReferenceDate)
            hasher.combine(episode.duration)
            hasher.combine(episode.description)
            hasher.combine(episode.downloadStatus.rawValue)
            hasher.combine(episode.isFavorited)
            hasher.combine(episode.isBookmarked)
            hasher.combine(episode.isArchived)
            hasher.combine(episode.rating)
            hasher.combine(episode.dateAdded.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }
}
