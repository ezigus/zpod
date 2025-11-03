//
//  AdvancedSearchBuilderView.swift
//  LibraryFeature
//
//  Advanced search query builder interface for complex episode searches
//

import SwiftUI
import CoreModels
import SharedUtilities

// MARK: - Advanced Search Builder

struct AdvancedSearchBuilderView: View {
    @ObservedObject var viewModel: EpisodeSearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchTerms: [SearchTermBuilder] = [SearchTermBuilder()]
    @State private var operators: [BooleanOperator] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    termsSection
                    previewSection
                }
                .padding()
            }
            .navigationTitle("Advanced Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Search") {
                        executeSearch()
                        dismiss()
                    }
                    .disabled(!isValidQuery)
                }
            }
        }
        .onAppear {
            loadCurrentQuery()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build Advanced Query")
                .font(.headline)
            
            Text("Combine multiple search terms with boolean operators. Use quotes for exact phrases and specify fields to search in.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Terms Section
    
    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Terms")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Term") {
                    addSearchTerm()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            ForEach(Array(zip(searchTerms.indices, searchTerms)), id: \.0) { index, termBuilder in
                VStack(spacing: 12) {
                    SearchTermBuilderRow(
                        termBuilder: termBuilder,
                        onDelete: searchTerms.count > 1 ? { removeSearchTerm(at: index) } : nil
                    )
                    
                    // Boolean operator selector (except for last term)
                    if index < searchTerms.count - 1 {
                        BooleanOperatorSelector(
                            selectedOperator: operators.indices.contains(index) ? operators[index] : .and,
                            onSelect: { boolOp in
                                updateOperator(at: index, to: boolOp)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Preview")
                .font(.headline)
            
            Text(queryPreview)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.platformSystemGray6)
                .cornerRadius(8)
            
            if !isValidQuery {
                Label("Query is incomplete or invalid", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentQuery() {
        if let currentQuery = viewModel.currentAdvancedQuery {
            searchTerms = currentQuery.terms.map { SearchTermBuilder(from: $0) }
            operators = currentQuery.operators
        }
    }
    
    private func addSearchTerm() {
        searchTerms.append(SearchTermBuilder())
        
        // Add default AND operator if this isn't the first term
        if searchTerms.count > 1 && operators.count < searchTerms.count - 1 {
            operators.append(.and)
        }
    }
    
    private func removeSearchTerm(at index: Int) {
        searchTerms.remove(at: index)
        
        // Adjust operators array
        if index < operators.count {
            operators.remove(at: index)
        } else if !operators.isEmpty && index == searchTerms.count {
            operators.removeLast()
        }
    }
    
    private func updateOperator(at index: Int, to boolOperator: BooleanOperator) {
        // Ensure operators array is large enough
        while operators.count <= index {
            operators.append(.and)
        }
        operators[index] = boolOperator
    }
    
    private var queryPreview: String {
        let terms = searchTerms.compactMap { $0.buildSearchTerm() }
        let validOperators = Array(operators.prefix(terms.count - 1))
        
        return SearchQueryFormatter.format(terms: terms, operators: validOperators)
    }
    
    private var isValidQuery: Bool {
        return searchTerms.contains { !$0.text.isEmpty }
    }
    
    private func executeSearch() {
        let terms = searchTerms.compactMap { $0.buildSearchTerm() }
        let validOperators = Array(operators.prefix(terms.count - 1))
        
        guard !terms.isEmpty else { return }
        
        let query = EpisodeSearchQuery(terms: terms, operators: validOperators)
        viewModel.performAdvancedSearch(with: query)
    }
}

// MARK: - Search Term Builder Model

class SearchTermBuilder: ObservableObject {
    @Published var text: String = ""
    @Published var field: SearchField? = nil
    @Published var isNegated: Bool = false
    @Published var isPhrase: Bool = false
    
    init() {}
    
    init(from searchTerm: SearchTerm) {
        self.text = searchTerm.text
        self.field = searchTerm.field
        self.isNegated = searchTerm.isNegated
        self.isPhrase = searchTerm.isPhrase
    }
    
    func buildSearchTerm() -> SearchTerm? {
        guard !text.isEmpty else { return nil }
        
        return SearchTerm(
            text: text,
            field: field,
            isNegated: isNegated,
            isPhrase: isPhrase
        )
    }
}

// MARK: - Search Term Builder Row

struct SearchTermBuilderRow: View {
    @ObservedObject var termBuilder: SearchTermBuilder
    let onDelete: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main text input
            HStack {
                TextField("Search term...", text: $termBuilder.text)
                    .textFieldStyle(.roundedBorder)
                
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Options
            VStack(alignment: .leading, spacing: 8) {
                // Field selector
                HStack {
                    Text("Search in:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Field", selection: $termBuilder.field) {
                        Text("All Fields").tag(nil as SearchField?)
                        ForEach(SearchField.allCases, id: \.self) { field in
                            Text(field.displayName).tag(field as SearchField?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Toggles
                HStack(spacing: 20) {
                    Toggle("Exact phrase", isOn: $termBuilder.isPhrase)
                    Toggle("Exclude (NOT)", isOn: $termBuilder.isNegated)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)
    }
}

// MARK: - Boolean Operator Selector

struct BooleanOperatorSelector: View {
    let selectedOperator: BooleanOperator
    let onSelect: (BooleanOperator) -> Void
    
    @State private var currentSelection: BooleanOperator
    
    init(selectedOperator: BooleanOperator, onSelect: @escaping (BooleanOperator) -> Void) {
        self.selectedOperator = selectedOperator
        self.onSelect = onSelect
        self._currentSelection = State(initialValue: selectedOperator)
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Picker("Operator", selection: $currentSelection) {
                ForEach(BooleanOperator.allCases, id: \.self) { op in
                    Text(op.displayName.uppercased())
                        .tag(op)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .onChange(of: currentSelection) { _, newValue in
                onSelect(newValue)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Search Templates

struct QuickSearchTemplatesView: View {
    let onSelectTemplate: (EpisodeSearchQuery) -> Void
    
    private let templates: [(String, EpisodeSearchQuery)] = [
        ("Unplayed episodes from this week", EpisodeSearchQuery(terms: [
            SearchTerm(text: "unplayed", field: nil),
            SearchTerm(text: "this week", field: .date)
        ], operators: [.and])),
        
        ("Downloaded interviews", EpisodeSearchQuery(terms: [
            SearchTerm(text: "downloaded", field: nil),
            SearchTerm(text: "interview", field: .title)
        ], operators: [.and])),
        
        ("News episodes under 30 minutes", EpisodeSearchQuery(terms: [
            SearchTerm(text: "news", field: .title),
            SearchTerm(text: "30 minutes", field: .duration, isNegated: true)
        ], operators: [.and]))
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Templates")
                .font(.headline)
            
            ForEach(Array(zip(templates.indices, templates)), id: \.0) { index, template in
                Button(action: { onSelectTemplate(template.1) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.0)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(SearchQueryFormatter.format(terms: template.1.terms, operators: template.1.operators))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.platformSystemGray6)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
