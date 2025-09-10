//
//  EpisodeSearchViews.swift
//  LibraryFeature
//
//  Enhanced episode search interface with advanced query support,
//  search history, suggestions, and result highlighting.
//

import SwiftUI
import CoreModels
import Persistence

// MARK: - Enhanced Episode Search View

public struct EpisodeSearchView: View {
    @StateObject private var viewModel: EpisodeSearchViewModel
    @State private var showingAdvancedSearch = false
    @State private var showingSearchHistory = false
    
    public init(episodes: [Episode], filterService: EpisodeFilterService) {
        self._viewModel = StateObject(wrappedValue: EpisodeSearchViewModel(episodes: episodes, filterService: filterService))
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Search Results or Suggestions
                if viewModel.searchText.isEmpty {
                    if showingSearchHistory {
                        searchHistoryView
                    } else {
                        searchSuggestionsView
                    }
                } else {
                    searchResultsView
                }
            }
            .navigationTitle("Search Episodes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Advanced Search") {
                            showingAdvancedSearch = true
                        }
                        
                        Button("Search History") {
                            showingSearchHistory.toggle()
                        }
                        
                        Button("Clear History") {
                            viewModel.clearSearchHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAdvancedSearch) {
                AdvancedSearchBuilderView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Main Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search episodes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.performSearch()
                    }
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.updateSuggestions(for: newValue)
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.clearSearch()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Active Query Display (for advanced searches)
            if let advancedQuery = viewModel.currentAdvancedQuery {
                AdvancedQueryDisplayView(query: advancedQuery) {
                    viewModel.clearAdvancedQuery()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Search Suggestions
    
    private var searchSuggestionsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if !viewModel.searchSuggestions.isEmpty {
                    Text("Suggestions")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ForEach(viewModel.searchSuggestions) { suggestion in
                        SearchSuggestionRow(suggestion: suggestion) {
                            viewModel.selectSuggestion(suggestion)
                        }
                    }
                }
                
                // Common search patterns
                Text("Common Searches")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                ForEach(SearchSuggestion.commonSuggestions.prefix(8), id: \.text) { suggestion in
                    SearchSuggestionRow(suggestion: suggestion) {
                        viewModel.selectSuggestion(suggestion)
                    }
                }
            }
        }
    }
    
    // MARK: - Search History
    
    private var searchHistoryView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Searches")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        viewModel.clearSearchHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if viewModel.searchHistory.isEmpty {
                    Text("No search history")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.searchHistory) { entry in
                        SearchHistoryRow(entry: entry,
                                       onSelect: { viewModel.selectHistoryEntry(entry) },
                                       onDelete: { viewModel.removeHistoryEntry(entry) })
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Results header
                HStack {
                    Text("\(viewModel.searchResults.count) results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Results list
                if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search terms or filters")
                    )
                    .padding(.top, 100)
                } else {
                    ForEach(viewModel.searchResults) { result in
                        SearchResultCard(result: result)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Search Suggestion Row

struct SearchSuggestionRow: View {
    let suggestion: SearchSuggestion
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: suggestionIcon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.text)
                        .foregroundColor(.primary)
                    
                    Text(suggestion.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if suggestion.frequency > 1 {
                    Text("\(suggestion.frequency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var suggestionIcon: String {
        switch suggestion.type {
        case .history: return "clock"
        case .common: return "star"
        case .fieldQuery: return "scope"
        case .completion: return "text.cursor"
        }
    }
}

// MARK: - Search History Row

struct SearchHistoryRow: View {
    let entry: SearchHistoryEntry
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.query)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("\(entry.resultCount) results")
                            Text("•")
                            Text(entry.timestamp, style: .relative)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: EpisodeSearchResult
    @State private var showingHighlights = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Episode Info
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: result.episode.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title with relevance score
                    HStack {
                        Text(result.episode.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", result.relevanceScore))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    Text(result.episode.podcastTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(result.episode.pubDate, style: .date)
                        Text("•")
                        Text(formatDuration(result.episode.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Context snippet
            if let snippet = result.contextSnippet {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Highlights toggle
            if !result.highlights.isEmpty {
                Button("Show Highlights (\(result.highlights.count))") {
                    showingHighlights.toggle()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                
                if showingHighlights {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.highlights) { highlight in
                            HighlightView(highlight: highlight)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - Highlight View

struct HighlightView: View {
    let highlight: SearchHighlight
    
    var body: some View {
        HStack {
            Text(highlight.field.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(highlight.matchedTerm)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            
            Spacer()
        }
    }
}

// MARK: - Advanced Query Display

struct AdvancedQueryDisplayView: View {
    let query: EpisodeSearchQuery
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Text("Advanced Query:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(zip(query.terms.indices, query.terms)), id: \.0) { index, term in
                        AdvancedTermChip(term: term)
                        
                        if index < query.operators.count {
                            Text(query.operators[index].displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AdvancedTermChip: View {
    let term: SearchTerm
    
    var body: some View {
        HStack(spacing: 4) {
            if term.isNegated {
                Image(systemName: "minus")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if let field = term.field {
                Text(field.displayName)
                    .foregroundColor(.accentColor)
                Text(":")
                    .foregroundColor(.secondary)
            }
            
            Text(term.text)
                .fontWeight(term.isPhrase ? .medium : .regular)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

// MARK: - SuggestionType Extension

extension SuggestionType {
    var displayName: String {
        switch self {
        case .history: return "Recent"
        case .common: return "Popular"
        case .fieldQuery: return "Field Search"
        case .completion: return "Suggestion"
        }
    }
}