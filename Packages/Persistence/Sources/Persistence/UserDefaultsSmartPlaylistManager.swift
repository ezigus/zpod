//
//  UserDefaultsSmartPlaylistManager.swift
//  Persistence
//

import CoreModels
import Foundation

public final class UserDefaultsSmartPlaylistManager: SmartPlaylistManaging, @unchecked Sendable {

    private static let storageKey = "smart_episode_lists_v2"
    private let userDefaults: UserDefaults
    private let filterService: EpisodeFilterService
    private let lock = NSLock()
    private var customCache: [SmartEpisodeListV2]

    public init(
        userDefaults: UserDefaults = .standard,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService()
    ) {
        self.userDefaults = userDefaults
        self.filterService = filterService
        self.customCache = Self.loadCustom(from: userDefaults)
    }

    public func allSmartPlaylists() -> [SmartEpisodeListV2] {
        lock.withLock {
            (SmartEpisodeListV2.builtInSmartLists + customCache).sorted { lhs, rhs in
                if lhs.isSystemGenerated != rhs.isSystemGenerated { return lhs.isSystemGenerated }
                return lhs.name < rhs.name
            }
        }
    }

    public func builtInSmartPlaylists() -> [SmartEpisodeListV2] {
        SmartEpisodeListV2.builtInSmartLists.sorted { $0.name < $1.name }
    }

    public func customSmartPlaylists() -> [SmartEpisodeListV2] {
        lock.withLock { customCache.sorted { $0.name < $1.name } }
    }

    public func findSmartPlaylist(id: String) -> SmartEpisodeListV2? {
        lock.withLock {
            (SmartEpisodeListV2.builtInSmartLists + customCache).first { $0.id == id }
        }
    }

    public func createSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        lock.withLock {
            guard !smartPlaylist.isSystemGenerated,
                  !customCache.contains(where: { $0.id == smartPlaylist.id }) else { return }
            customCache.append(smartPlaylist)
            persist()
        }
    }

    public func updateSmartPlaylist(_ smartPlaylist: SmartEpisodeListV2) {
        lock.withLock {
            guard !smartPlaylist.isSystemGenerated,
                  let index = customCache.firstIndex(where: { $0.id == smartPlaylist.id }) else { return }
            customCache[index] = smartPlaylist
            persist()
        }
    }

    public func deleteSmartPlaylist(id: String) {
        lock.withLock {
            guard let item = customCache.first(where: { $0.id == id }),
                  !item.isSystemGenerated else { return }
            customCache.removeAll { $0.id == id }
            persist()
        }
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

    public func reloadFromStorage() {
        lock.withLock {
            customCache = Self.loadCustom(from: userDefaults)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customCache) {
            userDefaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func loadCustom(from userDefaults: UserDefaults) -> [SmartEpisodeListV2] {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SmartEpisodeListV2].self, from: data) else {
            return []
        }
        return decoded.filter { !$0.isSystemGenerated }
    }
}
