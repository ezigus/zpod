//
//  SmartListBackgroundManager.swift
//  Persistence
//
//  Comprehensive background service manager for smart list automation
//

@preconcurrency import Foundation
import CoreModels

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Background Manager Protocol

/// Main interface for smart list background operations
public protocol SmartListBackgroundManager: ObservableObject, Sendable {
    /// Configuration for background refresh
    var configuration: SmartListRefreshConfiguration { get async }
    
    /// Start background services
    func startBackgroundServices() async
    
    /// Stop background services
    func stopBackgroundServices() async
    
    /// Configure background refresh settings
    func updateConfiguration(_ config: SmartListRefreshConfiguration) async
    
    /// Force refresh all smart lists
    func forceRefreshAll() async
    
    /// Get performance metrics
    func getPerformanceMetrics() async -> [String: TimeInterval]
}

// MARK: - Default Implementation

/// Manages all smart list background operations and coordination
@MainActor
public final class DefaultSmartListBackgroundManager: SmartListBackgroundManager {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var lastRefreshTime: Date?
    @Published public private(set) var activeRefreshCount: Int = 0
    
    // MARK: - Private Properties
    
    private let backgroundService: SmartListBackgroundService
    private let repository: any SmartEpisodeListRepository
    private let performanceMonitor: SmartListPerformanceMonitor
    private let configurationRepository: SmartListConfigurationRepository
    private let episodeProvider: EpisodeProvider
    
    private var _configuration: SmartListRefreshConfiguration
    nonisolated(unsafe) private var foregroundObserver: NSObjectProtocol?
    nonisolated(unsafe) private var backgroundObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    public init(
        backgroundService: SmartListBackgroundService,
        repository: any SmartEpisodeListRepository,
        performanceMonitor: SmartListPerformanceMonitor,
        configurationRepository: SmartListConfigurationRepository,
        episodeProvider: EpisodeProvider
    ) {
        self.backgroundService = backgroundService
        self.repository = repository
        self.performanceMonitor = performanceMonitor
        self.configurationRepository = configurationRepository
        self.episodeProvider = episodeProvider
        
        // Load configuration from storage
        self._configuration = configurationRepository.getConfiguration()
        
        setupAppLifecycleObservers()
    }
    
    deinit {
        if let foregroundObserver = foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        if let backgroundObserver = backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }
    
    // MARK: - Background Manager Implementation
    
    public var configuration: SmartListRefreshConfiguration {
        get async { _configuration }
    }
    
    public func startBackgroundServices() async {
        guard _configuration.isEnabled && !isActive else { return }
        
        await backgroundService.startBackgroundRefresh()
        await backgroundService.setGlobalRefreshInterval(_configuration.globalInterval)
        
        isActive = true
        lastRefreshTime = Date()
        
        // Listen for smart list updates
        setupSmartListNotifications()
    }
    
    public func stopBackgroundServices() async {
        await backgroundService.stopBackgroundRefresh()
        isActive = false
        
        // Remove notifications
        removeSmartListNotifications()
    }
    
    public func updateConfiguration(_ config: SmartListRefreshConfiguration) async {
        _configuration = config
        configurationRepository.saveConfiguration(config)
        
        // Update background service if running
        if isActive {
            await backgroundService.setGlobalRefreshInterval(config.globalInterval)
            
            // Restart if needed
            if !config.isEnabled {
                await stopBackgroundServices()
            }
        } else if config.isEnabled {
            await startBackgroundServices()
        }
    }
    
    public func forceRefreshAll() async {
        activeRefreshCount += 1
        
        let startTime = Date()
        await backgroundService.refreshAllSmartLists()
        
        lastRefreshTime = Date()
        activeRefreshCount = max(0, activeRefreshCount - 1)
        
        // Record performance metrics
        let totalTime = Date().timeIntervalSince(startTime)
        await performanceMonitor.recordEvaluationTime(totalTime, for: "all_smart_lists")
    }
    
    public func getPerformanceMetrics() async -> [String: TimeInterval] {
        return await performanceMonitor.getAllMetrics()
    }
    
    // MARK: - Private Implementation
    
    private func setupAppLifecycleObservers() {
        #if canImport(UIKit)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppForeground() }
        }
        
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppBackground() }
        }
        #endif
    }
    
    private func handleAppForeground() async {
        if _configuration.refreshOnForeground && _configuration.isEnabled {
            // Check if it's been long enough since last refresh
            if let lastRefresh = lastRefreshTime,
               Date().timeIntervalSince(lastRefresh) > _configuration.globalInterval {
                await forceRefreshAll()
            }
        }
        
        // Restart background services if they were stopped
        if _configuration.isEnabled && !isActive {
            await startBackgroundServices()
        }
    }
    
    private func handleAppBackground() async {
        // Background processing for smart lists could be added here
        // For now, we keep the background service running
    }
    
    private func setupSmartListNotifications() {
        NotificationCenter.default.addObserver(
            forName: .smartListDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleSmartListUpdate(notification)
            }
        }
    }
    
    private func removeSmartListNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: .smartListDidUpdate,
            object: nil
        )
    }
    
    private func handleSmartListUpdate(_ notification: Notification) async {
        // Update UI state based on smart list changes
        if notification.object is SmartEpisodeListV2 {
            lastRefreshTime = Date()
        }
    }
}

// MARK: - Configuration Repository

/// Repository for smart list background configuration
public protocol SmartListConfigurationRepository: Sendable {
    func getConfiguration() -> SmartListRefreshConfiguration
    func saveConfiguration(_ configuration: SmartListRefreshConfiguration)
}

/// UserDefaults implementation of configuration repository
public final class UserDefaultsSmartListConfigurationRepository: SmartListConfigurationRepository, @unchecked Sendable {
    
    private let userDefaults: UserDefaults
    private let key = "smart_list_background_configuration"
    private let lock = NSLock()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func getConfiguration() -> SmartListRefreshConfiguration {
        lock.lock()
        defer { lock.unlock() }
        
        guard let data = userDefaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(SmartListRefreshConfiguration.self, from: data) else {
            // Return default configuration
            return SmartListRefreshConfiguration()
        }
        
        return configuration
    }
    
    public func saveConfiguration(_ configuration: SmartListRefreshConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        
        if let data = try? JSONEncoder().encode(configuration) {
            userDefaults.set(data, forKey: key)
        }
    }
}

// MARK: - Episode Provider Implementation

/// Provides episodes from podcast manager for background operations
public actor PodcastManagerEpisodeProvider: EpisodeProvider {
    
    private let podcastManager: any PodcastManaging
    
    public init(podcastManager: any PodcastManaging) {
        self.podcastManager = podcastManager
    }
    
    public func getAllEpisodes() async -> [Episode] {
        let podcasts = podcastManager.all()
        var allEpisodes: [Episode] = []
        
        for podcast in podcasts {
            allEpisodes.append(contentsOf: podcast.episodes)
        }
        
        return allEpisodes
    }
}

// MARK: - Background Service Factory

/// Factory for creating background service components
public enum SmartListBackgroundServiceFactory {
    
    /// Create a complete background manager with all dependencies
    @MainActor
    public static func createBackgroundManager(
        filterService: EpisodeFilterService,
        smartListRepository: any SmartEpisodeListRepository,
        podcastManager: any PodcastManaging,
        userDefaults: UserDefaults = .standard
    ) -> DefaultSmartListBackgroundManager {
        
        let episodeProvider = PodcastManagerEpisodeProvider(podcastManager: podcastManager)
        let performanceMonitor = SmartListPerformanceMonitor()
        let configurationRepository = UserDefaultsSmartListConfigurationRepository(userDefaults: userDefaults)
        
        let backgroundService = SmartListBackgroundRefreshManager(
            filterService: filterService,
            smartListRepository: smartListRepository,
            episodeProvider: episodeProvider
        )
        
        return DefaultSmartListBackgroundManager(
            backgroundService: backgroundService,
            repository: smartListRepository,
            performanceMonitor: performanceMonitor,
            configurationRepository: configurationRepository,
            episodeProvider: episodeProvider
        )
    }
}

// MARK: - Background Service Extensions

public extension SmartListBackgroundManager {
    
    /// Convenience method to start with default configuration
    func startWithDefaultConfiguration() async {
        let defaultConfig = SmartListRefreshConfiguration()
        await updateConfiguration(defaultConfig)
        await startBackgroundServices()
    }
    
    /// Check if a specific smart list needs refresh
    func needsRefresh(smartList: SmartEpisodeListV2) async -> Bool {
        let config = await configuration
        guard config.isEnabled && smartList.autoUpdate else { return false }
        
        let timeSinceLastUpdate = Date().timeIntervalSince(smartList.lastUpdated)
        let effectiveInterval = smartList.refreshInterval > 0 ? smartList.refreshInterval : config.globalInterval
        
        return timeSinceLastUpdate >= effectiveInterval
    }
}