import Foundation

/// Protocol abstracting smart playlist (SmartEpisodeListV2) CRUD operations.
///
/// Mirrors the `PlaylistManaging` pattern: synchronous and @MainActor-friendly.
/// PlaylistFeature depends on this protocol; the concrete implementation lives in
/// Persistence and bridges the async `SmartEpisodeListRepository` behind a cached
/// synchronous facade.
public protocol SmartPlaylistManaging {
    // MARK: - Smart Playlists (V2)

    func allSmartPlaylists() -> [SmartEpisodeListV2]
    func builtInSmartPlaylists() -> [SmartEpisodeListV2]
    func customSmartPlaylists() -> [SmartEpisodeListV2]
    func findSmartPlaylist(id: String) -> SmartEpisodeListV2?
    func createSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2)
    func updateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2)
    func deleteSmartPlaylist(id: String)

    // MARK: - Templates

    func availableTemplates() -> [SmartListRuleTemplate]

    // MARK: - Evaluation

    /// Evaluate a smart playlist against episodes, returning matching episodes.
    /// The conforming type should use `EpisodeFilterService.evaluateSmartListV2`
    /// or equivalent logic.
    func evaluateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode]
}

// MARK: - In-Memory Implementation (Testing)

/// In-memory smart playlist manager for testing and previews.
///
/// Stores smart playlists in memory with built-in lists pre-populated.
/// Evaluation delegates to `DefaultEpisodeFilterService.evaluateSmartListV2`.
public final class InMemorySmartPlaylistManager: SmartPlaylistManaging, @unchecked Sendable {

    private var smartPlaylists: [SmartEpisodeListV2]
    private let filterService: EpisodeFilterService

    public init(
        initialSmartPlaylists: [SmartEpisodeListV2] = SmartEpisodeListV2.builtInSmartLists,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService()
    ) {
        self.smartPlaylists = initialSmartPlaylists
        self.filterService = filterService
    }

    public func allSmartPlaylists() -> [SmartEpisodeListV2] {
        smartPlaylists.sorted { lhs, rhs in
            if lhs.isSystemGenerated != rhs.isSystemGenerated {
                return lhs.isSystemGenerated
            }
            return lhs.name < rhs.name
        }
    }

    public func builtInSmartPlaylists() -> [SmartEpisodeListV2] {
        smartPlaylists.filter(\.isSystemGenerated).sorted { $0.name < $1.name }
    }

    public func customSmartPlaylists() -> [SmartEpisodeListV2] {
        smartPlaylists.filter { !$0.isSystemGenerated }.sorted { $0.name < $1.name }
    }

    public func findSmartPlaylist(id: String) -> SmartEpisodeListV2? {
        smartPlaylists.first { $0.id == id }
    }

    public func createSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        guard !smartPlaylists.contains(where: { $0.id == smartPlaylist.id }) else { return }
        smartPlaylists.append(smartPlaylist)
    }

    public func updateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        guard let index = smartPlaylists.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
        smartPlaylists[index] = smartPlaylist
    }

    public func deleteSmartPlaylist(id: String) {
        guard let list = smartPlaylists.first(where: { $0.id == id }),
              !list.isSystemGenerated else { return }
        smartPlaylists.removeAll { $0.id == id }
    }

    public func availableTemplates() -> [SmartListRuleTemplate] {
        SmartListRuleTemplate.builtInTemplates
    }

    public func evaluateSmartPlaylist(
        _ smartPlaylist: SmartEpisodeListV2,
        allEpisodes: [Episode]
    ) -> [Episode] {
        filterService.evaluateSmartListV2(smartPlaylist, allEpisodes: allEpisodes)
    }
}
