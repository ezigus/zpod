//
//  SmartListBackgroundService.swift
//  Persistence
//
//  Implementation of background service for automatic smart list updates
//

import Foundation
import CoreModels

// MARK: - Background Refresh Manager Implementation

/// Manages background refresh of smart episode lists
public actor SmartListBackgroundRefreshManager: SmartListBackgroundService {
    
    // MARK: - Properties
    
    private let filterService: EpisodeFilterService
    private let smartListRepository: any SmartEpisodeListRepository
    private let episodeProvider: EpisodeProvider
    
    private var refreshTask: Task<Void, Never>?
    private var isActive: Bool = false
    private var globalRefreshInterval: TimeInterval = 300 // 5 minutes default
    
    // MARK: - Initialization
    
    public init(
        filterService: EpisodeFilterService,
        smartListRepository: any SmartEpisodeListRepository,
        episodeProvider: EpisodeProvider
    ) {
        self.filterService = filterService
        self.smartListRepository = smartListRepository
        self.episodeProvider = episodeProvider
    }
    
    // MARK: - Background Service Implementation
    
    public func startBackgroundRefresh() async {
        guard !isActive else { return }
        
        isActive = true
        refreshTask = Task { [weak self] in
            await self?.runBackgroundRefreshLoop()
        }
    }
    
    public func stopBackgroundRefresh() async {
        isActive = false
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    public func refreshAllSmartLists() async {
        do {
            let smartLists = try await smartListRepository.getAllSmartLists()
            let allEpisodes = await episodeProvider.getAllEpisodes()
            
            for smartList in smartLists {
                await refreshSmartList(smartList, allEpisodes: allEpisodes)
            }
        } catch {
            // Log error and continue - background refresh should be resilient
            print("Failed to refresh smart lists: \(error)")
        }
    }
    
    public var isRefreshActive: Bool {
        get async { isActive }
    }
    
    public func setGlobalRefreshInterval(_ interval: TimeInterval) async {
        globalRefreshInterval = max(60, interval) // Minimum 1 minute
    }
    
    // MARK: - Private Implementation
    
    private func runBackgroundRefreshLoop() async {
        while isActive && !Task.isCancelled {
            await refreshSmartListsIfNeeded()
            
            // Wait for the global refresh interval
            try? await Task.sleep(nanoseconds: UInt64(globalRefreshInterval * 1_000_000_000))
        }
    }
    
    private func refreshSmartListsIfNeeded() async {
        do {
            let smartLists = try await smartListRepository.getAllSmartLists()
            let allEpisodes = await episodeProvider.getAllEpisodes()
            
            for smartList in smartLists {
                // Only refresh if auto-update is enabled and enough time has passed
                if smartList.autoUpdate {
                    let shouldRefresh = await shouldRefreshSmartList(smartList)
                    if shouldRefresh {
                        await refreshSmartList(smartList, allEpisodes: allEpisodes)
                    }
                }
            }
        } catch {
            // Log error and continue - background refresh should be resilient
            print("Failed to refresh smart lists: \(error)")
        }
    }
    
    private func shouldRefreshSmartList(_ smartList: SmartEpisodeListV2) async -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(smartList.lastUpdated)
        let effectiveInterval = smartList.refreshInterval > 0 ? smartList.refreshInterval : globalRefreshInterval
        return timeSinceLastUpdate >= effectiveInterval
    }
    
    private func refreshSmartList(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) async {
        // Evaluate smart list rules to get updated episodes
        let updatedEpisodes = filterService.evaluateSmartListV2(smartList, allEpisodes: allEpisodes)
        
        // Update the last updated timestamp
        let updatedSmartList = SmartEpisodeListV2(
            id: smartList.id,
            name: smartList.name,
            description: smartList.description,
            rules: smartList.rules,
            sortBy: smartList.sortBy,
            maxEpisodes: smartList.maxEpisodes,
            autoUpdate: smartList.autoUpdate,
            refreshInterval: smartList.refreshInterval,
            createdAt: smartList.createdAt,
            lastUpdated: Date(),
            isSystemGenerated: smartList.isSystemGenerated
        )
        
        // Save the updated smart list
        do {
            try await smartListRepository.saveSmartList(updatedSmartList)
            
            // Optionally notify observers about the update
            await notifySmartListUpdated(updatedSmartList, episodes: updatedEpisodes)
        } catch {
            // Log error but continue - individual smart list refresh failure shouldn't stop the process
            print("Failed to save updated smart list '\(smartList.name)': \(error)")
        }
    }
    
    private func notifySmartListUpdated(_ smartList: SmartEpisodeListV2, episodes: [Episode]) async {
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: .smartListDidUpdate,
                object: smartList,
                userInfo: ["episodes": episodes]
            )
        }
    }
}