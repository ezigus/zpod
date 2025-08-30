import Foundation
import CoreModels

/// Baseline implementation of recommendation service using simple heuristics
public final class BaselineRecommendationService: RecommendationService {
    
    /// Threshold for determining relevant categories based on user listening patterns
    private static let categoryRelevanceThreshold: Double = 0.1
    
    /// Default popularity score placeholder for episodes when popularity data is not available
    private static let defaultPopularityScore: Double = 0.5
    
    public init() {}
    
    public func generateRecommendations(
        criteria: RecommendationCriteria,
        podcasts: [Podcast],
        playHistory: [PlaybackHistoryEntry]
    ) async -> [Recommendation] {
        
        // Analyze category preferences from play history
        let categoryWeights = analyzeCategoryFrequency(podcasts: podcasts, playHistory: playHistory)
        
        // Get all episodes from subscribed podcasts
        let allEpisodes = podcasts.flatMap { podcast in
            podcast.episodes.map { episode in (podcast, episode) }
        }
        
        // Filter episodes based on criteria
        let candidateEpisodes = filterEpisodes(
            episodes: allEpisodes,
            playHistory: playHistory,
            criteria: criteria
        )
        
        // Generate scored recommendations
        var recommendations: [Recommendation] = []
        
        for (podcast, episode) in candidateEpisodes {
            let score = calculateRecommendationScore(
                podcast: podcast,
                episode: episode,
                categoryWeights: categoryWeights,
                criteria: criteria
            )
            
            if score >= criteria.minimumScore {
                let reason = generateRecommendationReason(
                    podcast: podcast,
                    episode: episode,
                    categoryWeights: categoryWeights,
                    score: score
                )
                
                let recommendation = Recommendation(
                    type: .episode,
                    targetId: episode.id,
                    score: score,
                    reason: reason
                )
                
                recommendations.append(recommendation)
            }
        }
        
        // Sort by score (descending) and apply limit
        recommendations.sort { $0.score > $1.score }
        return Array(recommendations.prefix(criteria.maxRecommendations))
    }
    
    // MARK: - Private Helper Methods
    
    /// Analyze category frequency from play history to determine user preferences
    private func analyzeCategoryFrequency(
        podcasts: [Podcast],
        playHistory: [PlaybackHistoryEntry]
    ) -> [String: Double] {
        
        var categoryPlayCounts: [String: Int] = [:]
        var totalPlays = 0
        
        // Count plays by category, weighing recent plays more heavily
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        for entry in playHistory {
            guard let podcast = podcasts.first(where: { $0.id == entry.podcastId }) else { continue }
            
            // Weight recent plays more heavily
            let weight = entry.playedAt > thirtyDaysAgo ? 2 : 1
            totalPlays += weight
            
            for category in podcast.categories {
                categoryPlayCounts[category, default: 0] += weight
            }
        }
        
        // Convert counts to normalized weights
        guard totalPlays > 0 else { return [:] }
        
        var categoryWeights: [String: Double] = [:]
        for (category, count) in categoryPlayCounts {
            categoryWeights[category] = Double(count) / Double(totalPlays)
        }
        
        return categoryWeights
    }
    
    /// Filter episodes based on recommendation criteria
    private func filterEpisodes(
        episodes: [(Podcast, Episode)],
        playHistory: [PlaybackHistoryEntry],
        criteria: RecommendationCriteria
    ) -> [(Podcast, Episode)] {
        
        let playedEpisodeIds = Set(playHistory.filter { $0.completed }.map { $0.episodeId })
        
        return episodes.filter { (podcast, episode) in
            // Exclude played episodes if configured
            if criteria.excludePlayedEpisodes && playedEpisodeIds.contains(episode.id) {
                return false
            }
            
            // Only include episodes with publication dates (for recency scoring)
            return episode.pubDate != nil
        }
    }
    
    /// Calculate recommendation score using weighted heuristics
    private func calculateRecommendationScore(
        podcast: Podcast,
        episode: Episode,
        categoryWeights: [String: Double],
        criteria: RecommendationCriteria
    ) -> Double {
        
        // Category frequency score
        let categoryScore = podcast.categories.compactMap { categoryWeights[$0] }.max() ?? 0.0
        
        // Recency score (prefer newer episodes)
        let recencyScore = calculateRecencyScore(episode: episode)
        
        // Popularity placeholder score (static for now)
        let popularityScore = Self.defaultPopularityScore
        
        // Weighted combination
        return (categoryScore * criteria.categoryFrequencyWeight) +
               (recencyScore * criteria.recencyWeight) +
               (popularityScore * criteria.popularityWeight)
    }
    
    /// Calculate recency score favoring newer episodes
    private func calculateRecencyScore(episode: Episode) -> Double {
        guard let pubDate = episode.pubDate else { return 0.0 }
        
        let daysSincePublication = Date().timeIntervalSince(pubDate) / (24 * 60 * 60)
        
        // Decay function: newer episodes get higher scores
        // Score = e^(-days/30) gives exponential decay with 30-day half-life
        return exp(-daysSincePublication / 30.0)
    }
    
    /// Generate human-readable reason for the recommendation
    private func generateRecommendationReason(
        podcast: Podcast,
        episode: Episode,
        categoryWeights: [String: Double],
        score: Double
    ) -> RecommendationReason {
        
        var details: [String] = []
        
        // Add category-based reasoning
        let relevantCategories = podcast.categories.filter { categoryWeights[$0] ?? 0 > Self.categoryRelevanceThreshold }
        if !relevantCategories.isEmpty {
            details.append("matches your interest in \(relevantCategories.joined(separator: ", "))")
        }
        
        // Add recency reasoning
        if let pubDate = episode.pubDate {
            let daysAgo = Int(Date().timeIntervalSince(pubDate) / (24 * 60 * 60))
            if daysAgo <= 7 {
                details.append("recent episode")
            }
        }
        
        let primary = "Recommended for you"
        let filteredCategoryWeights = categoryWeights.filter { podcast.categories.contains($0.key) }
        
        return RecommendationReason(
            primary: primary,
            details: details,
            categoryWeights: filteredCategoryWeights
        )
    }
}