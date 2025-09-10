//
//  SmartListBackgroundService.swift
//  CoreModels
//
//  Background service for automatic smart list updates with configurable intervals
//

import Foundation

// MARK: - Background Service Protocol

/// Protocol for smart list background refresh service
public protocol SmartListBackgroundService: Sendable {
    /// Start background refresh for all auto-updating smart lists
    func startBackgroundRefresh() async
    
    /// Stop background refresh
    func stopBackgroundRefresh() async
    
    /// Force refresh all smart lists
    func refreshAllSmartLists() async
    
    /// Check if background refresh is active
    var isRefreshActive: Bool { get async }
    
    /// Set refresh interval for all smart lists
    func setGlobalRefreshInterval(_ interval: TimeInterval) async
}

// MARK: - Background Refresh Manager

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
        let smartLists = await smartListRepository.getAllSmartLists()
        let allEpisodes = await episodeProvider.getAllEpisodes()
        
        for smartList in smartLists {
            await refreshSmartList(smartList, allEpisodes: allEpisodes)
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
        let smartLists = await smartListRepository.getAllSmartLists()
        let allEpisodes = await episodeProvider.getAllEpisodes()
        
        for smartList in smartLists {
            // Only refresh if auto-update is enabled and enough time has passed
            if smartList.autoUpdate && await shouldRefreshSmartList(smartList) {
                await refreshSmartList(smartList, allEpisodes: allEpisodes)
            }
        }
    }
    
    private func shouldRefreshSmartList(_ smartList: SmartEpisodeListV2) async -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(smartList.lastUpdated)
        let effectiveInterval = smartList.refreshInterval > 0 ? smartList.refreshInterval : globalRefreshInterval
        return timeSinceLastUpdate >= effectiveInterval
    }
    
    private func refreshSmartList(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) async {
        // Evaluate smart list rules to get updated episodes
        let updatedEpisodes = await filterService.evaluateSmartListV2(smartList, allEpisodes: allEpisodes)
        
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
        await smartListRepository.saveSmartList(updatedSmartList)
        
        // Optionally notify observers about the update
        await notifySmartListUpdated(updatedSmartList, episodes: updatedEpisodes)
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

// MARK: - Episode Provider Protocol

/// Protocol for providing episodes to the background service
public protocol EpisodeProvider: Sendable {
    /// Get all episodes across all podcasts
    func getAllEpisodes() async -> [Episode]
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a smart list is updated in the background
    static let smartListDidUpdate = Notification.Name("smartListDidUpdate")
}

// MARK: - Background Refresh Configuration

/// Configuration for smart list background refresh
public struct SmartListRefreshConfiguration: Codable, Sendable {
    /// Whether background refresh is enabled globally
    public let isEnabled: Bool
    
    /// Global refresh interval (minimum override for all smart lists)
    public let globalInterval: TimeInterval
    
    /// Maximum number of smart lists to refresh per cycle
    public let maxRefreshPerCycle: Int
    
    /// Whether to refresh on app foreground
    public let refreshOnForeground: Bool
    
    /// Whether to refresh on network connectivity change
    public let refreshOnNetworkChange: Bool
    
    public init(
        isEnabled: Bool = true,
        globalInterval: TimeInterval = 300, // 5 minutes
        maxRefreshPerCycle: Int = 10,
        refreshOnForeground: Bool = true,
        refreshOnNetworkChange: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.globalInterval = max(60, globalInterval) // Minimum 1 minute
        self.maxRefreshPerCycle = max(1, maxRefreshPerCycle)
        self.refreshOnForeground = refreshOnForeground
        self.refreshOnNetworkChange = refreshOnNetworkChange
    }
}

// MARK: - Smart List Performance Monitor

/// Monitors performance of smart list evaluations for optimization
public actor SmartListPerformanceMonitor {
    
    private var evaluationTimes: [String: [TimeInterval]] = [:]
    private let maxStoredTimes = 10
    
    /// Record evaluation time for a smart list
    public func recordEvaluationTime(_ time: TimeInterval, for smartListId: String) {
        var times = evaluationTimes[smartListId] ?? []
        times.append(time)
        
        // Keep only the last maxStoredTimes entries
        if times.count > maxStoredTimes {
            times = Array(times.suffix(maxStoredTimes))
        }
        
        evaluationTimes[smartListId] = times
    }
    
    /// Get average evaluation time for a smart list
    public func getAverageEvaluationTime(for smartListId: String) -> TimeInterval? {
        guard let times = evaluationTimes[smartListId], !times.isEmpty else {
            return nil
        }
        return times.reduce(0, +) / Double(times.count)
    }
    
    /// Get all performance metrics
    public func getAllMetrics() -> [String: TimeInterval] {
        var metrics: [String: TimeInterval] = [:]
        for (smartListId, times) in evaluationTimes {
            if !times.isEmpty {
                metrics[smartListId] = times.reduce(0, +) / Double(times.count)
            }
        }
        return metrics
    }
    
    /// Reset all metrics
    public func resetMetrics() {
        evaluationTimes.removeAll()
    }
}