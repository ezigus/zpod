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

// MARK: - Default Implementation
// Implementation is in Persistence package to access SmartEpisodeListRepository

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
    
    public init() {}
    
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