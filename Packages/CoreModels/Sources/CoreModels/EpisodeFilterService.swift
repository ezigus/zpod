import Foundation
import SharedUtilities

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
    func searchEpisodes(_ episodes: [Episode], query: String, filter: EpisodeFilter?, includeArchived: Bool) -> [Episode]
    
    /// Advanced search with result highlighting and context
    func searchEpisodesAdvanced(_ episodes: [Episode], query: EpisodeSearchQuery, filter: EpisodeFilter?, includeArchived: Bool) -> [EpisodeSearchResult]
    
    /// Evaluate smart list with enhanced rules
    func evaluateSmartListV2(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdateV2(_ smartList: SmartEpisodeListV2) -> Bool
    
    /// Update smart list with new episodes
    func updateSmartList(_ smartList: SmartEpisodeList, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool
}

// MARK: - Default Implementation

// Comprehensive filtering logic scheduled for modularization.
public actor DefaultEpisodeFilterService: EpisodeFilterService { // swiftlint:disable:this type_body_length
    
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
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false
    ) -> [Episode] {
        // Exclude archived episodes by default unless explicitly requested
        let episodesToSearch = includeArchived ? episodes : episodes.filter { !$0.isArchived }
        
        let searchResults = episodesToSearch.filter { episode in
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
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false
    ) -> [EpisodeSearchResult] {
        // Exclude archived episodes by default unless explicitly requested
        let episodesToSearch = includeArchived ? episodes : episodes.filter { !$0.isArchived }
        
        let searchResults: [EpisodeSearchResult] = episodesToSearch.compactMap { episode in
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
        // Exclude archived episodes by default unless filter explicitly includes archived criteria
        let includesArchivedFilter = filter.conditions.contains { condition in
            condition.criteria == .archived && !condition.isNegated
        }
        
        let episodesToFilter = includesArchivedFilter ? episodes : episodes.filter { !$0.isArchived }
        
        guard !filter.isEmpty else { return episodesToFilter }
        
        return episodesToFilter.filter { episode in
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
        case .paused: return 2
        case .notDownloaded: return 3
        case .failed: return 4
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
    
    // MARK: - Enhanced Smart List Support
    
    /// Evaluate smart list with enhanced rules
    nonisolated public func evaluateSmartListV2(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode] {
        let filteredEpisodes = allEpisodes.filter { episode in
            evaluateSmartListRules(episode: episode, rules: smartList.rules)
        }
        
        let sortedEpisodes = sortEpisodes(filteredEpisodes, by: smartList.sortBy)
        
        if let maxEpisodes = smartList.maxEpisodes {
            return Array(sortedEpisodes.prefix(maxEpisodes))
        } else {
            return sortedEpisodes
        }
    }
    
    /// Check if smart list needs updating based on refresh interval
    nonisolated public func smartListNeedsUpdateV2(_ smartList: SmartEpisodeListV2) -> Bool {
        return smartList.needsUpdate()
    }
    
    // MARK: - Smart List Rule Evaluation
    
    /// Evaluate all rules in a smart list rule set
    nonisolated private func evaluateSmartListRules(episode: Episode, rules: SmartListRuleSet) -> Bool {
        guard !rules.rules.isEmpty else { return true }
        
        switch rules.logic {
        case .and:
            return rules.rules.allSatisfy { rule in
                let result = evaluateSmartListRule(episode: episode, rule: rule)
                return rule.isNegated ? !result : result
            }
        case .or:
            return rules.rules.contains { rule in
                let result = evaluateSmartListRule(episode: episode, rule: rule)
                return rule.isNegated ? !result : result
            }
        }
    }
    
    /// Evaluate a single smart list rule
    nonisolated private func evaluateSmartListRule(episode: Episode, rule: SmartListRule) -> Bool {
        switch rule.type {
        case .playStatus:
            return evaluatePlayStatusRule(episode: episode, comparison: rule.comparison, value: rule.value)
        case .downloadStatus:
            return evaluateDownloadStatusRule(episode: episode, comparison: rule.comparison, value: rule.value)
        case .dateAdded:
            return evaluateDateRule(date: episode.dateAdded, comparison: rule.comparison, value: rule.value)
        case .pubDate:
            guard let pubDate = episode.pubDate else { return false }
            return evaluateDateRule(date: pubDate, comparison: rule.comparison, value: rule.value)
        case .duration:
            guard let duration = episode.duration else { return false }
            return evaluateNumberRule(number: duration, comparison: rule.comparison, value: rule.value)
        case .rating:
            let rating = episode.rating.map(Double.init) ?? 0.0
            return evaluateNumberRule(number: rating, comparison: rule.comparison, value: rule.value)
        case .podcast:
            return evaluateStringRule(text: episode.podcastTitle, comparison: rule.comparison, value: rule.value)
        case .title:
            return evaluateStringRule(text: episode.title, comparison: rule.comparison, value: rule.value)
        case .description:
            return evaluateStringRule(text: episode.description ?? "", comparison: rule.comparison, value: rule.value)
        case .isFavorited:
            return evaluateBooleanRule(value: episode.isFavorited, comparison: rule.comparison, ruleValue: rule.value)
        case .isBookmarked:
            return evaluateBooleanRule(value: episode.isBookmarked, comparison: rule.comparison, ruleValue: rule.value)
        case .isArchived:
            return evaluateBooleanRule(value: episode.isArchived, comparison: rule.comparison, ruleValue: rule.value)
        case .playbackPosition:
            return evaluateNumberRule(number: Double(episode.playbackPosition), comparison: rule.comparison, value: rule.value)
        }
    }
    
    // MARK: - Rule Type Evaluators
    
    nonisolated private func evaluatePlayStatusRule(episode: Episode, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .episodeStatus(let expectedStatus) = value else { return false }
        
        let actualStatus: EpisodePlayStatus
        if !episode.isPlayed && episode.playbackPosition == 0 {
            actualStatus = .unplayed
        } else if episode.isInProgress {
            actualStatus = .inProgress
        } else {
            actualStatus = .played
        }
        
        switch comparison {
        case .equals:
            return actualStatus == expectedStatus
        case .notEquals:
            return actualStatus != expectedStatus
        default:
            return false
        }
    }
    
    nonisolated private func evaluateDownloadStatusRule(episode: Episode, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .downloadStatus(let expectedStatus) = value else { return false }
        
        switch comparison {
        case .equals:
            return episode.downloadStatus == expectedStatus
        case .notEquals:
            return episode.downloadStatus != expectedStatus
        default:
            return false
        }
    }
    
    nonisolated private func evaluateDateRule(date: Date, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        switch value {
        case .date(let targetDate):
            return evaluateDateComparison(date: date, comparison: comparison, targetDate: targetDate)
        case .dateRange(let start, let end):
            switch comparison {
            case .between:
                return date >= start && date <= end
            default:
                return false
            }
        case .relativeDate(let period):
            let range = period.dateRange()
            switch comparison {
            case .within, .between:
                return date >= range.start && date <= range.end
            case .after:
                return date > range.start
            case .before:
                return date < range.end
            default:
                return false
            }
        default:
            return false
        }
    }
    
    nonisolated private func evaluateDateComparison(date: Date, comparison: SmartListComparison, targetDate: Date) -> Bool {
        switch comparison {
        case .equals:
            return Calendar.current.isDate(date, inSameDayAs: targetDate)
        case .notEquals:
            return !Calendar.current.isDate(date, inSameDayAs: targetDate)
        case .before:
            return date < targetDate
        case .after:
            return date > targetDate
        default:
            return false
        }
    }
    
    nonisolated private func evaluateNumberRule(number: Double, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        let targetValue: Double
        
        switch value {
        case .integer(let intValue):
            targetValue = Double(intValue)
        case .double(let doubleValue):
            targetValue = doubleValue
        case .timeInterval(let interval):
            targetValue = interval
        default:
            return false
        }
        
        switch comparison {
        case .equals:
            return abs(number - targetValue) < 0.01 // Allow small floating point differences
        case .notEquals:
            return abs(number - targetValue) >= 0.01
        case .lessThan:
            return number < targetValue
        case .greaterThan:
            return number > targetValue
        default:
            return false
        }
    }
    
    nonisolated private func evaluateStringRule(text: String, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .string(let targetText) = value else { return false }
        
        let lowercaseText = text.lowercased()
        let lowercaseTarget = targetText.lowercased()
        
        switch comparison {
        case .equals:
            return lowercaseText == lowercaseTarget
        case .notEquals:
            return lowercaseText != lowercaseTarget
        case .contains:
            return lowercaseText.contains(lowercaseTarget)
        case .notContains:
            return !lowercaseText.contains(lowercaseTarget)
        case .startsWith:
            return lowercaseText.hasPrefix(lowercaseTarget)
        case .endsWith:
            return lowercaseText.hasSuffix(lowercaseTarget)
        default:
            return false
        }
    }
    
    nonisolated private func evaluateBooleanRule(value: Bool, comparison: SmartListComparison, ruleValue: SmartListRuleValue) -> Bool {
        guard case .boolean(let expectedValue) = ruleValue else { return false }
        
        switch comparison {
        case .equals:
            return value == expectedValue
        case .notEquals:
            return value != expectedValue
        default:
            return false
        }
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
            return episode.duration.map { formatDuration($0) } ?? "Unknown"
        case .date:
            return episode.pubDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "Unknown"
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
                snippet += "..."
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
        duration.abbreviatedDescription(includeSeconds: true)
    }
}

// MARK: - String Extension for Substring

extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}
