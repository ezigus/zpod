import Foundation

/// Manual playlist with ordered episode references
public struct Playlist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let episodeIds: [String]  // Ordered episode references
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    // ...full initializers, methods, and static properties from PlaylistModels.swift...
}

/// Smart playlist with rule-based dynamic content
public struct SmartPlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rules: [PlaylistRuleData]  // Serializable rule configurations
    public let sortCriteria: PlaylistSortCriteria
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let maxEpisodes: Int
    public static let minMaxEpisodes = 1
    public static let maxMaxEpisodes = 500
    // ...full initializers, methods, and static properties from PlaylistModels.swift...
}

public enum PlaylistSortCriteria: String, Codable, CaseIterable, Sendable {
    // ...full code from PlaylistModels.swift...
}

public struct PlaylistRuleData: Codable, Equatable, Sendable {
    // ...full code from PlaylistModels.swift...
}

public protocol PlaylistRule {
    // ...full code from PlaylistModels.swift...
}

public struct IsNewRule: PlaylistRule, Sendable {
    // ...full code from PlaylistModels.swift...
}

public struct IsDownloadedRule: PlaylistRule, Sendable {
    // ...full code from PlaylistModels.swift...
}

public struct IsUnplayedRule: PlaylistRule, Sendable {
    // ...full code from PlaylistModels.swift...
}

public struct PodcastIdRule: PlaylistRule {
    // ...full code from PlaylistModels.swift...
}

public struct DurationRangeRule: PlaylistRule, Sendable {
    // ...full code from PlaylistModels.swift...
}

public struct PlaylistRuleFactory: Sendable {
    // ...full code from PlaylistModels.swift...
}
