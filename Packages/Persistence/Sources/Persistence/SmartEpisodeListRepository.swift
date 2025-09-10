//
//  SmartEpisodeListRepository.swift
//  Persistence
//
//  Repository for managing smart episode lists with enhanced rules
//

import Foundation
import CoreModels

// MARK: - Smart List Repository Protocol

public protocol SmartEpisodeListRepository: Sendable {
    /// Save smart episode list
    func saveSmartList(_ smartList: SmartEpisodeListV2) async throws
    
    /// Get all smart episode lists
    func getAllSmartLists() async throws -> [SmartEpisodeListV2]
    
    /// Get smart list by ID
    func getSmartList(id: String) async throws -> SmartEpisodeListV2?
    
    /// Delete smart episode list
    func deleteSmartList(id: String) async throws
    
    /// Update smart list last updated timestamp
    func updateSmartListTimestamp(id: String, timestamp: Date) async throws
    
    /// Get smart lists that need updating
    func getSmartListsNeedingUpdate() async throws -> [SmartEpisodeListV2]
}

// MARK: - UserDefaults Implementation

public actor UserDefaultsSmartEpisodeListRepository: SmartEpisodeListRepository {
    
    private let userDefaults: UserDefaults
    private let smartListsKey = "smart_episode_lists_v2"
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func saveSmartList(_ smartList: SmartEpisodeListV2) async throws {
        var smartLists = try await getAllSmartLists()
        
        // Remove existing smart list with same ID
        smartLists.removeAll { $0.id == smartList.id }
        
        // Add updated smart list
        smartLists.append(smartList)
        
        try await saveAllSmartLists(smartLists)
    }
    
    public func getAllSmartLists() async throws -> [SmartEpisodeListV2] {
        guard let data = userDefaults.data(forKey: smartListsKey) else {
            // Return built-in smart lists if none exist
            return SmartEpisodeListV2.builtInSmartLists
        }
        
        let smartLists = try JSONDecoder().decode([SmartEpisodeListV2].self, from: data)
        
        // Merge with built-in smart lists (only if they don't already exist)
        let existingIds = Set(smartLists.map(\.id))
        let builtInLists = SmartEpisodeListV2.builtInSmartLists.filter { !existingIds.contains($0.id) }
        
        return smartLists + builtInLists
    }
    
    public func getSmartList(id: String) async throws -> SmartEpisodeListV2? {
        let smartLists = try await getAllSmartLists()
        return smartLists.first { $0.id == id }
    }
    
    public func deleteSmartList(id: String) async throws {
        var smartLists = try await getAllSmartLists()
        
        // Don't allow deletion of system-generated smart lists
        guard let smartList = smartLists.first(where: { $0.id == id }),
              !smartList.isSystemGenerated else {
            throw SmartListRepositoryError.cannotDeleteSystemList
        }
        
        smartLists.removeAll { $0.id == id }
        try await saveAllSmartLists(smartLists)
    }
    
    public func updateSmartListTimestamp(id: String, timestamp: Date) async throws {
        var smartLists = try await getAllSmartLists()
        
        guard let index = smartLists.firstIndex(where: { $0.id == id }) else {
            throw SmartListRepositoryError.smartListNotFound
        }
        
        smartLists[index] = smartLists[index].withLastUpdated(timestamp)
        try await saveAllSmartLists(smartLists)
    }
    
    public func getSmartListsNeedingUpdate() async throws -> [SmartEpisodeListV2] {
        let smartLists = try await getAllSmartLists()
        return smartLists.filter { $0.needsUpdate() }
    }
    
    // MARK: - Private Methods
    
    private func saveAllSmartLists(_ smartLists: [SmartEpisodeListV2]) async throws {
        // Only save non-system smart lists
        let userSmartLists = smartLists.filter { !$0.isSystemGenerated }
        
        let encoded = try JSONEncoder().encode(userSmartLists)
        userDefaults.set(encoded, forKey: smartListsKey)
    }
}

// MARK: - Repository Errors

public enum SmartListRepositoryError: Error, LocalizedError {
    case smartListNotFound
    case cannotDeleteSystemList
    case encodingError
    case decodingError
    
    public var errorDescription: String? {
        switch self {
        case .smartListNotFound:
            return "Smart list not found"
        case .cannotDeleteSystemList:
            return "Cannot delete system-generated smart lists"
        case .encodingError:
            return "Failed to encode smart list data"
        case .decodingError:
            return "Failed to decode smart list data"
        }
    }
}

// MARK: - Smart List Manager

/// High-level manager for smart episode list functionality
@MainActor
public class SmartEpisodeListManager: ObservableObject {
    
    @Published public var smartLists: [SmartEpisodeListV2] = []
    @Published public var isLoading = false
    @Published public var isUpdating = false
    
    private let repository: SmartEpisodeListRepository
    private let filterService: EpisodeFilterService
    private var updateTimer: Timer?
    
    public init(
        repository: SmartEpisodeListRepository = UserDefaultsSmartEpisodeListRepository(),
        filterService: EpisodeFilterService
    ) {
        self.repository = repository
        self.filterService = filterService
        
        Task {
            await loadSmartLists()
            startPeriodicUpdates()
        }
    }
    
    deinit {
        // Timer must be invalidated on main actor since it's not Sendable
        Task { @MainActor in
            updateTimer?.invalidate()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all smart lists
    public func loadSmartLists() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let lists = try await repository.getAllSmartLists()
            await MainActor.run {
                self.smartLists = lists.sorted { list1, list2 in
                    // System lists first, then by name
                    if list1.isSystemGenerated != list2.isSystemGenerated {
                        return list1.isSystemGenerated
                    }
                    return list1.name < list2.name
                }
            }
        } catch {
            await MainActor.run {
                self.smartLists = SmartEpisodeListV2.builtInSmartLists
            }
        }
    }
    
    /// Create new smart list
    public func createSmartList(_ smartList: SmartEpisodeListV2) async throws {
        try await repository.saveSmartList(smartList)
        await loadSmartLists()
    }
    
    /// Update existing smart list
    public func updateSmartList(_ smartList: SmartEpisodeListV2) async throws {
        try await repository.saveSmartList(smartList)
        await loadSmartLists()
    }
    
    /// Delete smart list
    public func deleteSmartList(id: String) async throws {
        try await repository.deleteSmartList(id: id)
        await loadSmartLists()
    }
    
    /// Evaluate smart list and return matching episodes
    public func evaluateSmartList(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode] {
        return filterService.evaluateSmartListV2(smartList, allEpisodes: allEpisodes)
    }
    
    /// Update all smart lists that need updating
    public func updateSmartListsIfNeeded(allEpisodes: [Episode]) async {
        guard !isUpdating else { return }
        
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            let listsNeedingUpdate = try await repository.getSmartListsNeedingUpdate()
            
            for smartList in listsNeedingUpdate {
                // Update the timestamp to mark as refreshed
                try await repository.updateSmartListTimestamp(id: smartList.id, timestamp: Date())
            }
            
            if !listsNeedingUpdate.isEmpty {
                await loadSmartLists()
            }
        } catch {
            // Handle error silently for background updates
        }
    }
    
    /// Get smart lists by category
    public func smartListsByCategory() -> [SmartListDisplayCategory: [SmartEpisodeListV2]] {
        let grouped = Dictionary(grouping: smartLists) { smartList in
            if smartList.isSystemGenerated {
                return SmartListDisplayCategory.builtin
            } else {
                return SmartListDisplayCategory.custom
            }
        }
        
        return grouped
    }
    
    // MARK: - Private Methods
    
    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                // Note: This would need access to all episodes, which should be provided by the app
                // For now, we'll just mark this as where the periodic update would happen
            }
        }
    }
}

// MARK: - Display Categories

public enum SmartListDisplayCategory: String, CaseIterable {
    case builtin = "builtin"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .builtin: return "Built-in Smart Lists"
        case .custom: return "My Smart Lists"
        }
    }
}