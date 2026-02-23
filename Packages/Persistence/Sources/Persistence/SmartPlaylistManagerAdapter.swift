//
//  SmartPlaylistManagerAdapter.swift
//  Persistence
//
//  Bridges the async SmartEpisodeListManager to the synchronous
//  SmartPlaylistManaging protocol expected by PlaylistFeature.
//
//  Reads from a locally cached snapshot for instant sync access.
//  Writes apply optimistic updates to the local cache then persist
//  asynchronously via the underlying manager.
//

import CoreModels
import Foundation

/// Adapter that conforms the Persistence layer's async ``SmartEpisodeListManager``
/// to the synchronous ``SmartPlaylistManaging`` protocol used by PlaylistFeature.
///
/// Designed to be created from `@MainActor` context (alongside the
/// ``SmartPlaylistViewModel``), matching the pattern used by
/// ``InMemorySmartPlaylistManager``.
///
/// Usage at the app composition root:
/// ```swift
/// let manager = SmartEpisodeListManager(filterService: filterService)
/// let adapter = await SmartPlaylistManagerAdapter(manager: manager)
/// let viewModel = SmartPlaylistViewModel(manager: adapter, allEpisodesProvider: { ... })
/// ```
public final class SmartPlaylistManagerAdapter: SmartPlaylistManaging, @unchecked Sendable {

    /// The underlying async manager. Marked `nonisolated(unsafe)` because
    /// both this adapter and the manager are always used from `@MainActor`
    /// context (the ViewModel), following the same pattern as
    /// ``InMemorySmartPlaylistManager``.
    private nonisolated(unsafe) var manager: SmartEpisodeListManager
    private let filterService: EpisodeFilterService

    /// Local cache providing synchronous reads.
    /// Initialized from the manager's published state at init time.
    /// Optimistic writes update this cache immediately; async persistence
    /// round-trips keep the underlying repository in sync.
    private var cachedLists: [SmartEpisodeListV2]

    /// Create an adapter. Must be called from `@MainActor` context since
    /// ``SmartEpisodeListManager`` is `@MainActor`-isolated.
    @MainActor
    public init(
        manager: SmartEpisodeListManager,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService()
    ) {
        self.manager = manager
        self.filterService = filterService
        // Snapshot the manager's current cached state for sync reads.
        // The manager has already loaded its lists at this point.
        let initial = manager.smartLists
        self.cachedLists = initial.isEmpty ? SmartEpisodeListV2.builtInSmartLists : initial
    }

    // MARK: - SmartPlaylistManaging — Reads

    public func allSmartPlaylists() -> [SmartEpisodeListV2] {
        cachedLists.sorted { lhs, rhs in
            if lhs.isSystemGenerated != rhs.isSystemGenerated {
                return lhs.isSystemGenerated
            }
            return lhs.name < rhs.name
        }
    }

    public func builtInSmartPlaylists() -> [SmartEpisodeListV2] {
        cachedLists.filter(\.isSystemGenerated).sorted { $0.name < $1.name }
    }

    public func customSmartPlaylists() -> [SmartEpisodeListV2] {
        cachedLists.filter { !$0.isSystemGenerated }.sorted { $0.name < $1.name }
    }

    public func findSmartPlaylist(id: String) -> SmartEpisodeListV2? {
        cachedLists.first { $0.id == id }
    }

    // MARK: - SmartPlaylistManaging — Writes (Optimistic)

    public func createSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        guard !cachedLists.contains(where: { $0.id == smartPlaylist.id }) else { return }
        cachedLists.append(smartPlaylist)
        let mgr = manager
        Task { @MainActor in
            try? await mgr.createSmartList(smartPlaylist)
        }
    }

    public func updateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        guard let index = cachedLists.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
        cachedLists[index] = smartPlaylist
        let mgr = manager
        Task { @MainActor in
            try? await mgr.updateSmartList(smartPlaylist)
        }
    }

    public func deleteSmartPlaylist(id: String) {
        guard let list = cachedLists.first(where: { $0.id == id }),
              !list.isSystemGenerated else { return }
        cachedLists.removeAll { $0.id == id }
        let mgr = manager
        Task { @MainActor in
            try? await mgr.deleteSmartList(id: id)
        }
    }

    // MARK: - Templates

    public func availableTemplates() -> [SmartListRuleTemplate] {
        SmartListRuleTemplate.builtInTemplates
    }

    // MARK: - Evaluation

    public func evaluateSmartPlaylist(
        _ smartPlaylist: SmartEpisodeListV2,
        allEpisodes: [Episode]
    ) -> [Episode] {
        filterService.evaluateSmartListV2(smartPlaylist, allEpisodes: allEpisodes)
    }
}
