import Foundation
import CoreModels
import SharedUtilities

// MARK: - Episode Filter Persistence Protocol

/// Protocol for persisting episode filter preferences
public protocol EpisodeFilterRepository: Sendable {
    /// Save global filter preferences
    func saveGlobalPreferences(_ preferences: GlobalFilterPreferences) async throws
    
    /// Load global filter preferences
    func loadGlobalPreferences() async throws -> GlobalFilterPreferences?
    
    /// Save filter preference for specific podcast
    func savePodcastFilter(podcastId: String, filter: EpisodeFilter) async throws
    
    /// Load filter preference for specific podcast
    func loadPodcastFilter(podcastId: String) async throws -> EpisodeFilter?
    
    /// Save smart episode list
    func saveSmartList(_ smartList: SmartEpisodeList) async throws
    
    /// Load all smart episode lists
    func loadSmartLists() async throws -> [SmartEpisodeList]
    
    /// Delete smart episode list
    func deleteSmartList(id: String) async throws
}

// MARK: - UserDefaults Implementation

public actor UserDefaultsEpisodeFilterRepository: EpisodeFilterRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let globalPreferencesKey = "episode_filter_global_preferences"
    private let podcastFilterPrefix = "episode_filter_podcast:"
    private let smartListPrefix = "episode_smart_list:"
    private let smartListIdsKey = "episode_smart_list_ids"
    
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public init(suiteName: String) {
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suiteDefaults
        } else {
            self.userDefaults = .standard
        }
    }
    
    // MARK: - Global Preferences
    
    public func saveGlobalPreferences(_ preferences: GlobalFilterPreferences) async throws {
        do {
            let data = try encoder.encode(preferences)
            userDefaults.set(data, forKey: globalPreferencesKey)
        } catch {
            throw SharedError.persistenceError("Failed to encode global filter preferences: \(error)")
        }
    }
    
    public func loadGlobalPreferences() async throws -> GlobalFilterPreferences? {
        guard let data = userDefaults.data(forKey: globalPreferencesKey) else { 
            return nil 
        }
        
        do {
            return try decoder.decode(GlobalFilterPreferences.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode global filter preferences: \(error)")
        }
    }
    
    // MARK: - Podcast Filter Preferences
    
    public func savePodcastFilter(podcastId: String, filter: EpisodeFilter) async throws {
        do {
            let data = try encoder.encode(filter)
            userDefaults.set(data, forKey: podcastFilterPrefix + podcastId)
        } catch {
            throw SharedError.persistenceError("Failed to encode podcast filter: \(error)")
        }
    }
    
    public func loadPodcastFilter(podcastId: String) async throws -> EpisodeFilter? {
        guard let data = userDefaults.data(forKey: podcastFilterPrefix + podcastId) else {
            return nil
        }
        
        do {
            return try decoder.decode(EpisodeFilter.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode podcast filter: \(error)")
        }
    }
    
    // MARK: - Smart Lists
    
    public func saveSmartList(_ smartList: SmartEpisodeList) async throws {
        // Save the smart list data
        do {
            let data = try encoder.encode(smartList)
            userDefaults.set(data, forKey: smartListPrefix + smartList.id)
        } catch {
            throw SharedError.persistenceError("Failed to encode smart list: \(error)")
        }
        
        // Update the list of smart list IDs
        var smartListIds = loadSmartListIds()
        if !smartListIds.contains(smartList.id) {
            smartListIds.append(smartList.id)
            userDefaults.set(smartListIds, forKey: smartListIdsKey)
        }
    }
    
    public func loadSmartLists() async throws -> [SmartEpisodeList] {
        let smartListIds = loadSmartListIds()
        var smartLists: [SmartEpisodeList] = []
        
        for id in smartListIds {
            if let smartList = try await loadSmartList(id: id) {
                smartLists.append(smartList)
            }
        }
        
        return smartLists.sorted { $0.createdAt < $1.createdAt }
    }
    
    public func deleteSmartList(id: String) async throws {
        // Remove the smart list data
        userDefaults.removeObject(forKey: smartListPrefix + id)
        
        // Update the list of smart list IDs
        var smartListIds = loadSmartListIds()
        smartListIds.removeAll { $0 == id }
        userDefaults.set(smartListIds, forKey: smartListIdsKey)
    }
    
    // MARK: - Private Methods
    
    private func loadSmartList(id: String) async throws -> SmartEpisodeList? {
        guard let data = userDefaults.data(forKey: smartListPrefix + id) else {
            return nil
        }
        
        do {
            return try decoder.decode(SmartEpisodeList.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode smart list \(id): \(error)")
        }
    }
    
    private func loadSmartListIds() -> [String] {
        return userDefaults.array(forKey: smartListIdsKey) as? [String] ?? []
    }
}

// MARK: - Episode Filter Manager

/// High-level manager for episode filtering functionality
@MainActor
public final class EpisodeFilterManager: ObservableObject {
    @Published public private(set) var globalPreferences: GlobalFilterPreferences
    @Published public private(set) var currentFilter: EpisodeFilter
    @Published public private(set) var smartLists: [SmartEpisodeList] = []
    
    private let repository: EpisodeFilterRepository
    private let filterService: EpisodeFilterService
    
    public init(
        repository: EpisodeFilterRepository,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService()
    ) {
        self.repository = repository
        self.filterService = filterService
        self.globalPreferences = GlobalFilterPreferences()
        self.currentFilter = GlobalFilterPreferences().defaultFilter
        
        Task {
            await loadPreferences()
        }
    }
    
    // MARK: - Public Methods
    
    public func setCurrentFilter(_ filter: EpisodeFilter, forPodcast podcastId: String? = nil) async {
        currentFilter = filter
        
        if let podcastId = podcastId {
            // Save podcast-specific preference
            globalPreferences = globalPreferences.withPodcastPreference(
                podcastId: podcastId, 
                filter: filter
            )
            
            do {
                try await repository.savePodcastFilter(podcastId: podcastId, filter: filter)
                try await repository.saveGlobalPreferences(globalPreferences)
            } catch {
                // Log error but continue - filter is applied locally
                print("Failed to save podcast filter preference: \(error)")
            }
        }
    }
    
    public func filterForPodcast(_ podcastId: String) -> EpisodeFilter {
        return globalPreferences.filterForPodcast(podcastId)
    }
    
    public func createSmartList(_ smartList: SmartEpisodeList) async {
        globalPreferences = globalPreferences.withSmartList(smartList)
        smartLists.append(smartList)
        
        do {
            try await repository.saveSmartList(smartList)
            try await repository.saveGlobalPreferences(globalPreferences)
        } catch {
            print("Failed to save smart list: \(error)")
        }
    }
    
    public func updateSmartList(_ smartList: SmartEpisodeList) async {
        let updatedList = smartList.withLastUpdated(Date())
        globalPreferences = globalPreferences.withSmartList(updatedList)
        
        if let index = smartLists.firstIndex(where: { $0.id == smartList.id }) {
            smartLists[index] = updatedList
        }
        
        do {
            try await repository.saveSmartList(updatedList)
            try await repository.saveGlobalPreferences(globalPreferences)
        } catch {
            print("Failed to update smart list: \(error)")
        }
    }
    
    public func deleteSmartList(id: String) async {
        smartLists.removeAll { $0.id == id }
        
        var newSmartLists = globalPreferences.smartLists
        newSmartLists.removeAll { $0.id == id }
        
        globalPreferences = GlobalFilterPreferences(
            defaultFilter: globalPreferences.defaultFilter,
            defaultSortBy: globalPreferences.defaultSortBy,
            savedPresets: globalPreferences.savedPresets,
            smartLists: newSmartLists,
            perPodcastPreferences: globalPreferences.perPodcastPreferences
        )
        
        do {
            try await repository.deleteSmartList(id: id)
            try await repository.saveGlobalPreferences(globalPreferences)
        } catch {
            print("Failed to delete smart list: \(error)")
        }
    }
    
    public func clearAllFilters() async {
        currentFilter = EpisodeFilter()
    }
    
    // MARK: - Private Methods
    
    private func loadPreferences() async {
        do {
            if let preferences = try await repository.loadGlobalPreferences() {
                globalPreferences = preferences
                currentFilter = preferences.defaultFilter
            }
            
            smartLists = try await repository.loadSmartLists()
        } catch {
            print("Failed to load filter preferences: \(error)")
        }
    }
}
