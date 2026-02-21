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
    public var errorMessage: String? = nil

    // MARK: - Dependencies

    private let manager: any SmartPlaylistManaging
    private let allEpisodesProvider: () -> [Episode]

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

    // MARK: - Private

    private func reload() {
        smartPlaylists = manager.allSmartPlaylists()
        builtInPlaylists = manager.builtInSmartPlaylists()
        customPlaylists = manager.customSmartPlaylists()
    }
}
