//
//  EpisodeSearch.swift
//  CoreModels
//
//  Enhanced episode search functionality with advanced query support,
//  result highlighting, and contextual snippets.
//

import Foundation

// MARK: - Search Models

/// Advanced search query with boolean operators
public struct EpisodeSearchQuery: Sendable, Codable, Equatable {
    public let text: String
    public let terms: [SearchTerm]
    public let operators: [BooleanOperator]
    
    public init(text: String) {
        self.text = text
        let parser = SearchQueryParser()
        let (terms, operators) = parser.parse(query: text)
        self.terms = terms
        self.operators = operators
    }
    
    public init(terms: [SearchTerm], operators: [BooleanOperator] = []) {
        self.terms = terms
        self.operators = operators
        self.text = SearchQueryFormatter.format(terms: terms, operators: operators)
    }
}

/// Individual search term with optional field targeting
public struct SearchTerm: Sendable, Codable, Equatable, Identifiable {
    public let id = UUID()
    public let text: String
    public let field: SearchField?
    public let isNegated: Bool
    public let isPhrase: Bool // true for quoted phrases
    
    public init(text: String, field: SearchField? = nil, isNegated: Bool = false, isPhrase: Bool = false) {
        self.text = text
        self.field = field
        self.isNegated = isNegated
        self.isPhrase = isPhrase
    }
}

/// Boolean operators for combining search terms
public enum BooleanOperator: String, Sendable, Codable, CaseIterable {
    case and = "AND"
    case or = "OR"
    case not = "NOT"
    
    public var displayName: String {
        switch self {
        case .and: return "and"
        case .or: return "or"
        case .not: return "not"
        }
    }
}

/// Specific fields that can be targeted in search
public enum SearchField: String, Sendable, Codable, CaseIterable {
    case title = "title"
    case description = "description"
    case podcast = "podcast"
    case duration = "duration"
    case date = "date"
    
    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .description: return "Description"
        case .podcast: return "Podcast"
        case .duration: return "Duration"
        case .date: return "Date"
        }
    }
}

/// Search result with highlighting and context information
public struct EpisodeSearchResult: Sendable, Identifiable {
    public let id: UUID
    public let episode: Episode
    public let relevanceScore: Double
    public let highlights: [SearchHighlight]
    public let contextSnippet: String?
    
    public init(episode: Episode, relevanceScore: Double, highlights: [SearchHighlight], contextSnippet: String? = nil) {
        self.id = UUID()
        self.episode = episode
        self.relevanceScore = relevanceScore
        self.highlights = highlights
        self.contextSnippet = contextSnippet
    }
}

/// Highlighted text match in search results
public struct SearchHighlight: Sendable, Identifiable {
    public let id = UUID()
    public let field: SearchField
    public let text: String
    public let range: NSRange
    public let matchedTerm: String
    
    public init(field: SearchField, text: String, range: NSRange, matchedTerm: String) {
        self.field = field
        self.text = text
        self.range = range
        self.matchedTerm = matchedTerm
    }
}

/// Search history entry
public struct SearchHistoryEntry: Sendable, Codable, Identifiable {
    public let id = UUID()
    public let query: String
    public let timestamp: Date
    public let resultCount: Int
    
    public init(query: String, resultCount: Int, timestamp: Date = Date()) {
        self.query = query
        self.timestamp = timestamp
        self.resultCount = resultCount
    }
}

/// Enhanced search suggestions based on history and common patterns
public struct EpisodeSearchSuggestion: Sendable, Identifiable {
    public let id = UUID()
    public let text: String
    public let type: SuggestionType
    public let frequency: Int // how often this suggestion has been used
    
    public init(text: String, type: SuggestionType, frequency: Int = 1) {
        self.text = text
        self.type = type
        self.frequency = frequency
    }
}

public enum SuggestionType: Sendable, CaseIterable {
    case history     // from search history
    case common      // common search patterns
    case fieldQuery  // field-specific queries like "title:news"
    case completion  // auto-completion of current input
}

// MARK: - Search Query Parser

/// Parses advanced search queries with boolean operators
public struct SearchQueryParser {
    
    public init() {}
    
    public func parse(query: String) -> ([SearchTerm], [BooleanOperator]) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return ([], []) }
        
        var terms: [SearchTerm] = []
        var operators: [BooleanOperator] = []
        
        // Simple implementation - can be enhanced with proper parsing
        let components = splitQueryComponents(normalizedQuery)
        
        for (index, component) in components.enumerated() {
            if let op = BooleanOperator(rawValue: component.uppercased()) {
                operators.append(op)
            } else {
                let term = parseSearchTerm(component)
                terms.append(term)
            }
        }
        
        return (terms, operators)
    }
    
    private func splitQueryComponents(_ query: String) -> [String] {
        // Handle quoted phrases and boolean operators
        var components: [String] = []
        var currentComponent = ""
        var inQuotes = false
        
        for char in query {
            if char == "\"" {
                inQuotes.toggle()
                currentComponent.append(char)
            } else if char == " " && !inQuotes {
                if !currentComponent.isEmpty {
                    components.append(currentComponent)
                    currentComponent = ""
                }
            } else {
                currentComponent.append(char)
            }
        }
        
        if !currentComponent.isEmpty {
            components.append(currentComponent)
        }
        
        return components
    }
    
    private func parseSearchTerm(_ component: String) -> SearchTerm {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = trimmed
        var field: SearchField? = nil
        var isNegated = false
        var isPhrase = false
        
        // Check for negation
        if text.hasPrefix("-") {
            isNegated = true
            text = String(text.dropFirst())
        }
        
        // Check for field targeting (e.g., "title:news")
        if let colonIndex = text.firstIndex(of: ":") {
            let fieldText = String(text[..<colonIndex])
            if let searchField = SearchField(rawValue: fieldText.lowercased()) {
                field = searchField
                text = String(text[text.index(after: colonIndex)...])
            }
        }
        
        // Check for quoted phrases
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count > 1 {
            isPhrase = true
            text = String(text.dropFirst().dropLast())
        }
        
        return SearchTerm(text: text, field: field, isNegated: isNegated, isPhrase: isPhrase)
    }
}

// MARK: - Search Query Formatter

/// Formats search terms and operators back into query string
public struct SearchQueryFormatter {
    
    public static func format(terms: [SearchTerm], operators: [BooleanOperator]) -> String {
        var components: [String] = []
        
        for (index, term) in terms.enumerated() {
            var termString = ""
            
            if term.isNegated {
                termString += "-"
            }
            
            if let field = term.field {
                termString += "\(field.rawValue):"
            }
            
            if term.isPhrase {
                termString += "\"\(term.text)\""
            } else {
                termString += term.text
            }
            
            components.append(termString)
            
            // Add operator if available
            if index < operators.count {
                components.append(operators[index].rawValue)
            }
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Built-in Search Suggestions

extension EpisodeSearchSuggestion {
    
    /// Common search patterns for podcast episodes
    public static let commonSuggestions: [EpisodeSearchSuggestion] = [
        EpisodeSearchSuggestion(text: "title:news", type: .fieldQuery, frequency: 10),
        EpisodeSearchSuggestion(text: "title:interview", type: .fieldQuery, frequency: 8),
        EpisodeSearchSuggestion(text: "title:review", type: .fieldQuery, frequency: 6),
        EpisodeSearchSuggestion(text: "description:tutorial", type: .fieldQuery, frequency: 5),
        EpisodeSearchSuggestion(text: "description:how to", type: .fieldQuery, frequency: 7),
        EpisodeSearchSuggestion(text: "podcast:\"The Daily\"", type: .fieldQuery, frequency: 4),
        EpisodeSearchSuggestion(text: "duration:\"30 minutes\"", type: .fieldQuery, frequency: 3),
        EpisodeSearchSuggestion(text: "unplayed episodes", type: .common, frequency: 15),
        EpisodeSearchSuggestion(text: "downloaded content", type: .common, frequency: 12),
        EpisodeSearchSuggestion(text: "recent episodes", type: .common, frequency: 9)
    ]
}