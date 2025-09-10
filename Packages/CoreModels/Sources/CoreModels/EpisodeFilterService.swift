import Foundation

// MARK: - Episode Filtering Protocol

/// Protocol for episode filtering services
public protocol EpisodeFilterService: Sendable {
    /// Apply filter and sort to episodes
    func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode]
    
    /// Check if episode matches filter condition
    func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool
    
    /// Sort episodes by criteria
    func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode]
    
    /// Search episodes by text query
    func searchEpisodes(_ episodes: [Episode], query: String, filter: EpisodeFilter?) -> [Episode]
    
    /// Advanced search with result highlighting and context
    func searchEpisodesAdvanced(_ episodes: [Episode], query: EpisodeSearchQuery, filter: EpisodeFilter?) -> [EpisodeSearchResult]
    
    /// Update smart list with new episodes
    func updateSmartList(_ smartList: SmartEpisodeList, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool
}

// MARK: - Default Implementation

public actor DefaultEpisodeFilterService: EpisodeFilterService {
    
    public init() {}
    
    nonisolated public func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode] {
        let filteredEpisodes = applyFilter(episodes, filter: filter)
        return sortEpisodes(filteredEpisodes, by: filter.sortBy)
    }
    
    nonisolated public func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool {
        let matches = evaluateCondition(episode, condition.criteria)
        return condition.isNegated ? !matches : matches
    }
    
    nonisolated public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
        switch sortBy {
        case .pubDateNewest:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.pubDate else { return false }
                guard let rhsDate = rhs.pubDate else { return true }
                return lhsDate > rhsDate
            }
            
        case .pubDateOldest:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.pubDate else { return true }
                guard let rhsDate = rhs.pubDate else { return false }
                return lhsDate < rhsDate
            }
            
        case .duration:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDuration = lhs.duration else { return false }
                guard let rhsDuration = rhs.duration else { return true }
                return lhsDuration < rhsDuration
            }
            
        case .title:
            return episodes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
        case .playStatus:
            return episodes.sorted { (lhs, rhs) in
                // Order: unplayed, in-progress, played
                let lhsStatus = playStatusValue(lhs)
                let rhsStatus = playStatusValue(rhs)
                return lhsStatus < rhsStatus
            }
            
        case .downloadStatus:
            return episodes.sorted { (lhs, rhs) in
                let lhsValue = downloadStatusValue(lhs.downloadStatus)
                let rhsValue = downloadStatusValue(rhs.downloadStatus)
                return lhsValue < rhsValue
            }
            
        case .rating:
            return episodes.sorted { (lhs, rhs) in
                let lhsRating = lhs.rating ?? 0
                let rhsRating = rhs.rating ?? 0
                return lhsRating > rhsRating // Higher ratings first
            }
            
        case .dateAdded:
            return episodes.sorted { $0.dateAdded > $1.dateAdded }
        }
    }
    
    /// Search episodes by text query
    nonisolated public func searchEpisodes(
        _ episodes: [Episode],
        query: String,
        filter: EpisodeFilter? = nil
    ) -> [Episode] {
        let searchResults = episodes.filter { episode in
            searchMatches(episode: episode, query: query)
        }
        
        if let filter = filter {
            return filterAndSort(episodes: searchResults, using: filter)
        } else {
            // Default sort by relevance (we could implement scoring here)
            return searchResults
        }
    }
    
    /// Advanced search with result highlighting and context
    nonisolated public func searchEpisodesAdvanced(
        _ episodes: [Episode],
        query: EpisodeSearchQuery,
        filter: EpisodeFilter? = nil
    ) -> [EpisodeSearchResult] {
        let searchResults: [EpisodeSearchResult] = episodes.compactMap { episode in
            if let result = evaluateAdvancedSearch(episode: episode, query: query) {
                return result
            }
            return nil
        }
        
        // Sort by relevance score (highest first)
        let sortedResults = searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
        
        if let filter = filter {
            // Apply additional filtering if specified
            let filteredEpisodes = sortedResults.filter { result in
                filterAndSort(episodes: [result.episode], using: filter).count > 0
            }
            return filteredEpisodes
        } else {
            return sortedResults
        }
    }
    
    /// Update smart list with new episodes
    nonisolated public func updateSmartList(
        _ smartList: SmartEpisodeList,
        allEpisodes: [Episode]
    ) -> [Episode] {
        var filteredEpisodes = filterAndSort(episodes: allEpisodes, using: smartList.filter)
        
        // Apply max episode limit if specified
        if let maxEpisodes = smartList.maxEpisodes, filteredEpisodes.count > maxEpisodes {
            filteredEpisodes = Array(filteredEpisodes.prefix(maxEpisodes))
        }
        
        return filteredEpisodes
    }
    
    /// Check if smart list needs updating based on refresh interval
    nonisolated public func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool {
        guard smartList.autoUpdate else { return false }
        
        let timeSinceUpdate = Date().timeIntervalSince(smartList.lastUpdated)
        return timeSinceUpdate >= smartList.refreshInterval
    }
    
    // MARK: - Private Methods
    
    nonisolated private func applyFilter(_ episodes: [Episode], filter: EpisodeFilter) -> [Episode] {
        guard !filter.isEmpty else { return episodes }
        
        return episodes.filter { episode in
            switch filter.logic {
            case .and:
                return filter.conditions.allSatisfy { condition in
                    episodeMatches(episode, condition: condition)
                }
            case .or:
                return filter.conditions.contains { condition in
                    episodeMatches(episode, condition: condition)
                }
            }
        }
    }
    
    nonisolated private func evaluateCondition(_ episode: Episode, _ criteria: EpisodeFilterCriteria) -> Bool {
        switch criteria {
        case .unplayed:
            return !episode.isPlayed
        case .downloaded:
            return episode.isDownloaded
        case .favorited:
            return episode.isFavorited
        case .inProgress:
            return episode.isInProgress
        case .bookmarked:
            return episode.isBookmarked
        case .archived:
            return episode.isArchived
        case .rated:
            return episode.rating != nil
        case .unrated:
            return episode.rating == nil
        }
    }
    
    nonisolated private func playStatusValue(_ episode: Episode) -> Int {
        if !episode.isPlayed && episode.playbackPosition == 0 {
            return 0 // unplayed
        } else if episode.isInProgress {
            return 1 // in-progress
        } else {
            return 2 // played
        }
    }
    
    nonisolated private func downloadStatusValue(_ status: EpisodeDownloadStatus) -> Int {
        switch status {
        case .downloaded: return 0
        case .downloading: return 1
        case .notDownloaded: return 2
        case .failed: return 3
        }
    }
    
    nonisolated private func searchMatches(episode: Episode, query: String) -> Bool {
        let searchText = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return true }
        
        // Search in title
        if episode.title.lowercased().contains(searchText) {
            return true
        }
        
        // Search in description
        if let description = episode.description,
           description.lowercased().contains(searchText) {
            return true
        }
        
        return false
    }
    
    // MARK: - Advanced Search Implementation
    
    /// Evaluate advanced search query against episode with scoring and highlighting
    nonisolated private func evaluateAdvancedSearch(episode: Episode, query: EpisodeSearchQuery) -> EpisodeSearchResult? {
        var totalScore = 0.0
        var highlights: [SearchHighlight] = []
        
        // Evaluate each search term
        for (index, term) in query.terms.enumerated() {
            let termScore = evaluateSearchTerm(episode: episode, term: term, highlights: &highlights)
            
            // Apply boolean logic
            if index < query.operators.count {
                let boolOperator = query.operators[index]
                switch boolOperator {
                case .and:
                    if termScore == 0 { return nil } // AND requires all terms to match
                    totalScore += termScore
                case .or:
                    totalScore = max(totalScore, termScore) // OR takes the best match
                case .not:
                    if termScore > 0 { return nil } // NOT excludes matches
                }
            } else {
                // Default is AND behavior for the first term
                if termScore == 0 && index == 0 { return nil }
                totalScore += termScore
            }
        }
        
        guard totalScore > 0 else { return nil }
        
        // Generate context snippet
        let contextSnippet = generateContextSnippet(episode: episode, query: query, highlights: highlights)
        
        return EpisodeSearchResult(
            episode: episode,
            relevanceScore: totalScore,
            highlights: highlights,
            contextSnippet: contextSnippet
        )
    }
    
    /// Evaluate a single search term against episode
    nonisolated private func evaluateSearchTerm(
        episode: Episode,
        term: SearchTerm,
        highlights: inout [SearchHighlight]
    ) -> Double {
        let searchText = term.text.lowercased()
        var score = 0.0
        
        // Determine which fields to search
        let fieldsToSearch: [SearchField] = term.field != nil ? [term.field!] : [.title, .description, .podcast]
        
        for field in fieldsToSearch {
            let fieldText = getFieldText(episode: episode, field: field)
            let fieldScore = evaluateFieldMatch(
                fieldText: fieldText,
                searchText: searchText,
                term: term,
                field: field,
                highlights: &highlights
            )
            
            // Weight different fields differently
            let weightedScore = fieldScore * fieldWeight(field)
            score += weightedScore
        }
        
        return term.isNegated ? -score : score
    }
    
    /// Get text content for a specific field
    nonisolated private func getFieldText(episode: Episode, field: SearchField) -> String {
        switch field {
        case .title:
            return episode.title
        case .description:
            return episode.description ?? ""
        case .podcast:
            return episode.podcastTitle
        case .duration:
            return formatDuration(episode.duration)
        case .date:
            return DateFormatter.localizedString(from: episode.pubDate, dateStyle: .medium, timeStyle: .none)
        }
    }
    
    /// Evaluate match in a specific field
    nonisolated private func evaluateFieldMatch(
        fieldText: String,
        searchText: String,
        term: SearchTerm,
        field: SearchField,
        highlights: inout [SearchHighlight]
    ) -> Double {
        let lowercaseField = fieldText.lowercased()
        
        if term.isPhrase {
            // Exact phrase matching
            if let range = lowercaseField.range(of: searchText) {
                let nsRange = NSRange(range, in: fieldText)
                highlights.append(SearchHighlight(
                    field: field,
                    text: fieldText,
                    range: nsRange,
                    matchedTerm: term.text
                ))
                return exactMatchScore(field: field)
            }
        } else {
            // Fuzzy matching - split into words
            let words = searchText.components(separatedBy: .whitespacesAndNewlines)
            var matchedWords = 0
            
            for word in words {
                if let range = lowercaseField.range(of: word) {
                    let nsRange = NSRange(range, in: fieldText)
                    highlights.append(SearchHighlight(
                        field: field,
                        text: fieldText,
                        range: nsRange,
                        matchedTerm: word
                    ))
                    matchedWords += 1
                }
            }
            
            if matchedWords > 0 {
                let partialScore = (Double(matchedWords) / Double(words.count)) * exactMatchScore(field: field)
                return partialScore
            }
        }
        
        return 0.0
    }
    
    /// Generate context snippet around search matches
    nonisolated private func generateContextSnippet(
        episode: Episode,
        query: EpisodeSearchQuery,
        highlights: [SearchHighlight]
    ) -> String? {
        // Find the best highlight (highest score field)
        guard let bestHighlight = highlights.max(by: { fieldWeight($0.field) < fieldWeight($1.field) }) else {
            return nil
        }
        
        let text = bestHighlight.text
        let range = bestHighlight.range
        
        // Create context window around the match
        let contextLength = 150 // characters
        let startIndex = max(0, range.location - contextLength / 2)
        let endIndex = min(text.count, range.location + range.length + contextLength / 2)
        
        let contextRange = NSRange(location: startIndex, length: endIndex - startIndex)
        
        if let substring = text.substring(with: contextRange) {
            var snippet = substring
            
            // Add ellipsis if truncated
            if startIndex > 0 {
                snippet = "..." + snippet
            }
            if endIndex < text.count {
                snippet = snippet + "..."
            }
            
            return snippet
        }
        
        return nil
    }
    
    /// Weight factors for different fields in search scoring
    nonisolated private func fieldWeight(_ field: SearchField) -> Double {
        switch field {
        case .title: return 3.0      // Title matches are most important
        case .podcast: return 2.0    // Podcast name is quite important
        case .description: return 1.0 // Description matches are baseline
        case .duration: return 0.5   // Duration matches are less important
        case .date: return 0.5       // Date matches are less important
        }
    }
    
    /// Base score for exact matches in a field
    nonisolated private func exactMatchScore(field: SearchField) -> Double {
        switch field {
        case .title: return 10.0
        case .podcast: return 7.0
        case .description: return 5.0
        case .duration: return 3.0
        case .date: return 3.0
        }
    }
    
    /// Format duration for search
    nonisolated private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - String Extension for Substring

extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}