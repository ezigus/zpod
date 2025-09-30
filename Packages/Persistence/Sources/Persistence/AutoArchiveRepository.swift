@preconcurrency import Foundation
import CoreModels
import SharedUtilities

// MARK: - Auto Archive Repository

/// Repository for persisting automatic archiving configuration
public protocol AutoArchiveRepository: Sendable {
    /// Load global auto-archive configuration
    func loadGlobalConfig() async throws -> GlobalAutoArchiveConfig?
    
    /// Save global auto-archive configuration
    func saveGlobalConfig(_ config: GlobalAutoArchiveConfig) async throws
    
    /// Load per-podcast auto-archive configuration
    func loadPodcastConfig(podcastId: String) async throws -> PodcastAutoArchiveConfig?
    
    /// Save per-podcast auto-archive configuration
    func savePodcastConfig(_ config: PodcastAutoArchiveConfig) async throws
    
    /// Delete per-podcast configuration
    func deletePodcastConfig(podcastId: String) async throws
}

// MARK: - UserDefaults Implementation

public actor UserDefaultsAutoArchiveRepository: AutoArchiveRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let globalConfigKey = "auto_archive:global_config"
    private let podcastConfigKeyPrefix = "auto_archive:podcast:"
    
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
    
    public func loadGlobalConfig() async throws -> GlobalAutoArchiveConfig? {
        guard let data = userDefaults.data(forKey: globalConfigKey) else {
            return nil
        }
        
        do {
            return try decoder.decode(GlobalAutoArchiveConfig.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode global auto-archive config: \(error)")
        }
    }
    
    public func saveGlobalConfig(_ config: GlobalAutoArchiveConfig) async throws {
        do {
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: globalConfigKey)
        } catch {
            throw SharedError.persistenceError("Failed to encode global auto-archive config: \(error)")
        }
    }
    
    public func loadPodcastConfig(podcastId: String) async throws -> PodcastAutoArchiveConfig? {
        let key = podcastConfigKeyPrefix + podcastId
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(PodcastAutoArchiveConfig.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode podcast auto-archive config: \(error)")
        }
    }
    
    public func savePodcastConfig(_ config: PodcastAutoArchiveConfig) async throws {
        let key = podcastConfigKeyPrefix + config.podcastId
        do {
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: key)
        } catch {
            throw SharedError.persistenceError("Failed to encode podcast auto-archive config: \(error)")
        }
    }
    
    public func deletePodcastConfig(podcastId: String) async throws {
        let key = podcastConfigKeyPrefix + podcastId
        userDefaults.removeObject(forKey: key)
    }
}
