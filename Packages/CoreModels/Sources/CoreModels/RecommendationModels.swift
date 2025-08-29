import Foundation

// MARK: - Recommendation Models

/// Represents a single recommendation for a podcast or episode
public struct Recommendation: Codable, Equatable, Sendable {
    public let id: String
    public let type: RecommendationType
    public let targetId: String // podcast or episode ID
    public let score: Double
    public let reason: RecommendationReason
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        type: RecommendationType,
        targetId: String,
        score: Double,
        reason: RecommendationReason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.targetId = targetId
        self.score = score
        self.reason = reason
        self.createdAt = createdAt
    }
}

/// Type of recommendation
public enum RecommendationType: String, Codable, Sendable {
    case podcast
    case episode
}

/// Reason for the recommendation with user-friendly explanation
public struct RecommendationReason: Codable, Equatable, Sendable {
    public let primary: String
    public let details: [String]
    public let categoryWeights: [String: Double]
    
    public init(
        primary: String,
        details: [String] = [],
        categoryWeights: [String: Double] = [:]
    ) {
        self.primary = primary
        self.details = details
        self.categoryWeights = categoryWeights
    }
    
    /// Formatted string for UI display
    public var displayText: String {
        if details.isEmpty {
            return primary
        }
        return "\(primary) (\(details.joined(separator: ", ")))"
    }
}

/// Criteria for generating recommendations
public struct RecommendationCriteria: Codable, Equatable, Sendable {
    public let maxRecommendations: Int
    public let categoryFrequencyWeight: Double
    public let recencyWeight: Double
    public let popularityWeight: Double
    public let excludePlayedEpisodes: Bool
    public let minimumScore: Double
    
    public init(
        maxRecommendations: Int = 20,
        categoryFrequencyWeight: Double = 0.5,
        recencyWeight: Double = 0.3,
        popularityWeight: Double = 0.2,
        excludePlayedEpisodes: Bool = true,
        minimumScore: Double = 0.1
    ) {
        self.maxRecommendations = maxRecommendations
        self.categoryFrequencyWeight = categoryFrequencyWeight
        self.recencyWeight = recencyWeight
        self.popularityWeight = popularityWeight
        self.excludePlayedEpisodes = excludePlayedEpisodes
        self.minimumScore = minimumScore
    }
}

// MARK: - Recommendation Service Protocol

/// Protocol for generating podcast and episode recommendations
public protocol RecommendationService: Sendable {
    /// Generate recommendations based on user's listening history and subscriptions
    /// - Parameters:
    ///   - criteria: Criteria for recommendation generation
    ///   - podcasts: User's subscribed podcasts
    ///   - playHistory: User's play history data
    /// - Returns: Array of recommendations sorted by score (descending)
    func generateRecommendations(
        criteria: RecommendationCriteria,
        podcasts: [Podcast],
        playHistory: [PlaybackHistoryEntry]
    ) async -> [Recommendation]
}

// MARK: - Play History Model

/// Represents a single playback event in the user's history
public struct PlaybackHistoryEntry: Codable, Equatable, Sendable {
    public let id: String
    public let episodeId: String
    public let podcastId: String
    public let playedAt: Date
    public let duration: TimeInterval
    public let completed: Bool
    
    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        podcastId: String,
        playedAt: Date = Date(),
        duration: TimeInterval,
        completed: Bool
    ) {
        self.id = id
        self.episodeId = episodeId
        self.podcastId = podcastId
        self.playedAt = playedAt
        self.duration = duration
        self.completed = completed
    }
}