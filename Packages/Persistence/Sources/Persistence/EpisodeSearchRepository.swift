//
//  EpisodeSearchRepository.swift
//  Persistence
//
//  Repository for managing episode search history and suggestions
//

import Foundation
import CoreModels

// MARK: - Search Repository Protocol

public protocol EpisodeSearchRepository: Sendable {
    /// Save search history entry
    func saveSearchHistory(_ entry: SearchHistoryEntry) async throws
    
    /// Get recent search history (most recent first)
    func getSearchHistory(limit: Int) async throws -> [SearchHistoryEntry]
    
    /// Clear all search history
    func clearSearchHistory() async throws
    
    /// Remove specific search history entry
    func removeSearchHistory(_ entryId: UUID) async throws
    
    /// Get search suggestions based on input and history
    func getSearchSuggestions(for input: String, limit: Int) async throws -> [SearchSuggestion]
    
    /// Update suggestion frequency
    func incrementSuggestionFrequency(for text: String) async throws
}

// MARK: - UserDefaults Implementation

public actor UserDefaultsEpisodeSearchRepository: EpisodeSearchRepository {
    
    private let userDefaults: UserDefaults
    private let historyKey = "episode_search_history"
    private let suggestionsKey = "episode_search_suggestions"
    private let maxHistoryCount = 100
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func saveSearchHistory(_ entry: SearchHistoryEntry) async throws {
        var history = try await getSearchHistory(limit: maxHistoryCount)
        
        // Remove duplicate queries
        history.removeAll { $0.query.lowercased() == entry.query.lowercased() }
        
        // Add new entry at the beginning
        history.insert(entry, at: 0)
        
        // Limit history size
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        let encoded = try JSONEncoder().encode(history)
        userDefaults.set(encoded, forKey: historyKey)
    }
    
    public func getSearchHistory(limit: Int = 50) async throws -> [SearchHistoryEntry] {
        guard let data = userDefaults.data(forKey: historyKey) else {
            return []
        }
        
        let history = try JSONDecoder().decode([SearchHistoryEntry].self, from: data)
        return Array(history.prefix(limit))
    }
    
    public func clearSearchHistory() async throws {
        userDefaults.removeObject(forKey: historyKey)
    }
    
    public func removeSearchHistory(_ entryId: UUID) async throws {
        var history = try await getSearchHistory(limit: maxHistoryCount)
        history.removeAll { $0.id == entryId }
        
        let encoded = try JSONEncoder().encode(history)
        userDefaults.set(encoded, forKey: historyKey)
    }
    
    public func getSearchSuggestions(for input: String, limit: Int = 10) async throws -> [SearchSuggestion] {
        let lowercaseInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowercaseInput.isEmpty else {
            return Array(SearchSuggestion.commonSuggestions.prefix(limit))
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // Add history-based suggestions
        let history = try await getSearchHistory(limit: 50)
        let historySuggestions = history
            .filter { $0.query.lowercased().contains(lowercaseInput) }
            .map { SearchSuggestion(text: $0.query, type: .history, frequency: 1) }
        suggestions.append(contentsOf: historySuggestions)
        
        // Add completion suggestions
        let completionSuggestions = generateCompletionSuggestions(for: lowercaseInput)
        suggestions.append(contentsOf: completionSuggestions)
        
        // Add common suggestions that match
        let matchingCommon = SearchSuggestion.commonSuggestions
            .filter { $0.text.lowercased().contains(lowercaseInput) }
        suggestions.append(contentsOf: matchingCommon)
        
        // Add custom stored suggestions
        let customSuggestions = try await getCustomSuggestions(for: lowercaseInput)
        suggestions.append(contentsOf: customSuggestions)
        
        // Remove duplicates and sort by relevance
        let uniqueSuggestions = Dictionary(grouping: suggestions, by: { $0.text })
            .compactMapValues { $0.first }
            .values
            .sorted { suggestion1, suggestion2 in
                // Sort by frequency and relevance
                if suggestion1.frequency != suggestion2.frequency {
                    return suggestion1.frequency > suggestion2.frequency
                }
                
                // Prefer exact matches
                let input = lowercaseInput
                let text1 = suggestion1.text.lowercased()
                let text2 = suggestion2.text.lowercased()
                
                if text1.hasPrefix(input) && !text2.hasPrefix(input) {
                    return true
                } else if !text1.hasPrefix(input) && text2.hasPrefix(input) {
                    return false
                }
                
                return text1.count < text2.count // Prefer shorter suggestions
            }
        
        return Array(uniqueSuggestions.prefix(limit))
    }
    
    public func incrementSuggestionFrequency(for text: String) async throws {
        var customSuggestions = try await loadCustomSuggestions()
        
        if let index = customSuggestions.firstIndex(where: { $0.text.lowercased() == text.lowercased() }) {
            let existingSuggestion = customSuggestions[index]
            customSuggestions[index] = SearchSuggestion(
                text: existingSuggestion.text,
                type: existingSuggestion.type,
                frequency: existingSuggestion.frequency + 1
            )
        } else {
            customSuggestions.append(SearchSuggestion(
                text: text,
                type: .common,
                frequency: 1
            ))
        }
        
        try await saveCustomSuggestions(customSuggestions)
    }
    
    // MARK: - Private Methods
    
    private func generateCompletionSuggestions(for input: String) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // Generate field-specific completions
        for field in SearchField.allCases {
            if field.rawValue.hasPrefix(input) {
                suggestions.append(SearchSuggestion(
                    text: "\(field.rawValue):",
                    type: .fieldQuery,
                    frequency: 5
                ))
            }
        }
        
        // Generate boolean operator completions
        for op in BooleanOperator.allCases {
            if op.displayName.lowercased().hasPrefix(input) {
                suggestions.append(SearchSuggestion(
                    text: op.rawValue,
                    type: .completion,
                    frequency: 3
                ))
            }
        }
        
        return suggestions
    }
    
    private func getCustomSuggestions(for input: String) async throws -> [SearchSuggestion] {
        let customSuggestions = try await loadCustomSuggestions()
        return customSuggestions.filter { $0.text.lowercased().contains(input) }
    }
    
    private func loadCustomSuggestions() async throws -> [SearchSuggestion] {
        guard let data = userDefaults.data(forKey: suggestionsKey) else {
            return []
        }
        
        return try JSONDecoder().decode([SearchSuggestion].self, from: data)
    }
    
    private func saveCustomSuggestions(_ suggestions: [SearchSuggestion]) async throws {
        let encoded = try JSONEncoder().encode(suggestions)
        userDefaults.set(encoded, forKey: suggestionsKey)
    }
}

// MARK: - Search Manager

/// High-level manager for episode search functionality
@MainActor
public class EpisodeSearchManager: ObservableObject {
    
    @Published public var searchHistory: [SearchHistoryEntry] = []
    @Published public var searchSuggestions: [SearchSuggestion] = []
    @Published public var isLoadingSuggestions = false
    
    private let repository: EpisodeSearchRepository
    private var suggestionsTask: Task<Void, Never>?
    
    public init(repository: EpisodeSearchRepository = UserDefaultsEpisodeSearchRepository()) {
        self.repository = repository
        Task {
            await loadSearchHistory()
        }
    }
    
    /// Save a search query to history
    public func saveSearch(query: String, resultCount: Int) {
        let entry = SearchHistoryEntry(query: query, resultCount: resultCount)
        
        Task {
            try? await repository.saveSearchHistory(entry)
            await loadSearchHistory()
            
            // Also increment suggestion frequency
            try? await repository.incrementSuggestionFrequency(for: query)
        }
    }
    
    /// Get suggestions for current input
    public func getSuggestions(for input: String) {
        suggestionsTask?.cancel()
        
        suggestionsTask = Task {
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoadingSuggestions = true
            }
            
            do {
                let suggestions = try await repository.getSearchSuggestions(for: input, limit: 10)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchSuggestions = suggestions
                    self.isLoadingSuggestions = false
                }
            } catch {
                await MainActor.run {
                    self.searchSuggestions = []
                    self.isLoadingSuggestions = false
                }
            }
        }
    }
    
    /// Clear all search history
    public func clearHistory() {
        Task {
            try? await repository.clearSearchHistory()
            await loadSearchHistory()
        }
    }
    
    /// Remove specific search history entry
    public func removeHistoryEntry(_ entry: SearchHistoryEntry) {
        Task {
            try? await repository.removeSearchHistory(entry.id)
            await loadSearchHistory()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSearchHistory() async {
        do {
            let history = try await repository.getSearchHistory(limit: 50)
            await MainActor.run {
                self.searchHistory = history
            }
        } catch {
            await MainActor.run {
                self.searchHistory = []
            }
        }
    }
}