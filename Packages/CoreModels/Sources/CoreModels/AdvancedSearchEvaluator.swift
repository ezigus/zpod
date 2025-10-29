import Foundation
import SharedUtilities

// MARK: - Advanced Search Evaluator

/// Helper for advanced episode search with scoring and highlighting.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct AdvancedSearchEvaluator: Sendable {
    
    public init() {}
    
    /// Advanced search with result highlighting and context
    public func searchEpisodesAdvanced(
        _ episodes: [Episode],
        query: EpisodeSearchQuery,
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false,
        filterEvaluator: EpisodeFilterEvaluator,
        sortService: EpisodeSortService
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
                let filtered = filterEvaluator.applyFilter([result.episode], filter: filter)
                let sorted = sortService.sortEpisodes(filtered, by: filter.sortBy)
                return !sorted.isEmpty
            }
            return filteredEpisodes
        } else {
            return sortedResults
        }
    }
    
    // MARK: - Private Helpers
    
    /// Evaluate advanced search query against episode with scoring and highlighting
    private func evaluateAdvancedSearch(episode: Episode, query: EpisodeSearchQuery) -> EpisodeSearchResult? {
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
    private func evaluateSearchTerm(
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
    private func getFieldText(episode: Episode, field: SearchField) -> String {
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
    private func evaluateFieldMatch(
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
    private func generateContextSnippet(
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
    private func fieldWeight(_ field: SearchField) -> Double {
        switch field {
        case .title: return 3.0      // Title matches are most important
        case .podcast: return 2.0    // Podcast name is quite important
        case .description: return 1.0 // Description matches are baseline
        case .duration: return 0.5   // Duration matches are less important
        case .date: return 0.5       // Date matches are less important
        }
    }
    
    /// Base score for exact matches in a field
    private func exactMatchScore(field: SearchField) -> Double {
        switch field {
        case .title: return 10.0
        case .podcast: return 7.0
        case .description: return 5.0
        case .duration: return 3.0
        case .date: return 3.0
        }
    }
    
    /// Format duration for search
    private func formatDuration(_ duration: TimeInterval) -> String {
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
