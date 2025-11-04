import SwiftUI
import CoreModels
import SharedUtilities

// MARK: - Filter Button

/// Button that triggers the episode filter interface
public struct EpisodeFilterButton: View {
    let hasActiveFilters: Bool
    let action: () -> Void
    
    public init(hasActiveFilters: Bool, action: @escaping () -> Void) {
        self.hasActiveFilters = hasActiveFilters
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(hasActiveFilters ? .blue : .primary)
                Text("Filter")
                    .font(.caption)
                    .foregroundStyle(hasActiveFilters ? .blue : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(hasActiveFilters ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(hasActiveFilters ? Color.blue : Color.secondary, lineWidth: 1)
                    )
            )
        }
        .accessibilityIdentifier("Episode Filter Button")
        .accessibilityLabel(hasActiveFilters ? "Filter Episodes (Active)" : "Filter Episodes")
    }
}

// MARK: - Sort Picker

/// Picker for selecting episode sort order
public struct EpisodeSortPicker: View {
    @Binding var selectedSort: EpisodeSortBy
    
    public init(selectedSort: Binding<EpisodeSortBy>) {
        self._selectedSort = selectedSort
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort By")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Picker("Sort By", selection: $selectedSort) {
                ForEach(EpisodeSortBy.allCases, id: \.self) { sortOption in
                    HStack {
                        Image(systemName: sortOption.systemImage)
                        Text(sortOption.displayName)
                    }
                    .tag(sortOption)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("Episode Sort Picker")
        }
    }
}

// MARK: - Filter Criteria Grid

/// Grid of filter criteria chips
public struct EpisodeFilterCriteriaGrid: View {
    @Binding var selectedCriteria: [EpisodeFilterCriteria]
    
    public init(selectedCriteria: Binding<[EpisodeFilterCriteria]>) {
        self._selectedCriteria = selectedCriteria
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter By")
                .font(.headline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: adaptiveColumns, spacing: 8) {
                ForEach(EpisodeFilterCriteria.allCases, id: \.self) { criteria in
                    FilterCriteriaChip(
                        criteria: criteria,
                        isSelected: selectedCriteria.contains(criteria),
                        onToggle: { toggleCriteria(criteria) }
                    )
                }
            }
        }
        .accessibilityIdentifier("Filter Criteria Grid")
    }
    
    private var adaptiveColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: 8)]
    }
    
    private func toggleCriteria(_ criteria: EpisodeFilterCriteria) {
        if selectedCriteria.contains(criteria) {
            selectedCriteria.removeAll { $0 == criteria }
        } else {
            selectedCriteria.append(criteria)
        }
    }
}

// MARK: - Filter Criteria Chip

/// Individual filter criteria chip
public struct FilterCriteriaChip: View {
    let criteria: EpisodeFilterCriteria
    let isSelected: Bool
    let onToggle: () -> Void
    
    public init(
        criteria: EpisodeFilterCriteria,
        isSelected: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.criteria = criteria
        self.isSelected = isSelected
        self.onToggle = onToggle
    }
    
    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: criteria.systemImage)
                    .font(.caption)
                Text(criteria.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.platformSystemGray6)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .accessibilityIdentifier("Filter Chip-\(criteria.rawValue)")
        .accessibilityLabel("\(criteria.displayName) filter")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Active Filters Display

/// Displays currently active filters as removable chips
public struct ActiveFiltersDisplay: View {
    let filter: EpisodeFilter
    let onRemoveCriteria: (EpisodeFilterCriteria) -> Void
    let onClearAll: () -> Void
    
    public init(
        filter: EpisodeFilter,
        onRemoveCriteria: @escaping (EpisodeFilterCriteria) -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self.filter = filter
        self.onRemoveCriteria = onRemoveCriteria
        self.onClearAll = onClearAll
    }
    
    public var body: some View {
        if !filter.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Filters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Clear All", action: onClearAll)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("Clear All Filters")
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filter.conditions, id: \.criteria) { condition in
                            ActiveFilterChip(
                                condition: condition,
                                onRemove: { onRemoveCriteria(condition.criteria) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .accessibilityIdentifier("Active Filters Display")
        }
    }
}

// MARK: - Active Filter Chip

/// Individual active filter chip with remove button
public struct ActiveFilterChip: View {
    let condition: EpisodeFilterCondition
    let onRemove: () -> Void
    
    public init(condition: EpisodeFilterCondition, onRemove: @escaping () -> Void) {
        self.condition = condition
        self.onRemove = onRemove
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: condition.criteria.systemImage)
                .font(.caption2)
            Text(condition.displayName)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Remove \(condition.displayName) filter")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(.blue)
        .accessibilityIdentifier("Active Filter Chip-\(condition.criteria.rawValue)")
    }
}

// MARK: - Episode Filter Sheet

/// Complete filter interface in a sheet
public struct EpisodeFilterSheet: View {
    @State private var selectedCriteria: [EpisodeFilterCriteria]
    @State private var selectedSort: EpisodeSortBy
    @State private var filterLogic: FilterLogic
    
    let initialFilter: EpisodeFilter
    let onApply: (EpisodeFilter) -> Void
    let onDismiss: () -> Void
    
    public init(
        initialFilter: EpisodeFilter,
        onApply: @escaping (EpisodeFilter) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialFilter = initialFilter
        self.onApply = onApply
        self.onDismiss = onDismiss
        
        self._selectedCriteria = State(initialValue: initialFilter.conditions.map { $0.criteria })
        self._selectedSort = State(initialValue: initialFilter.sortBy)
        self._filterLogic = State(initialValue: initialFilter.logic)
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    EpisodeSortPicker(selectedSort: $selectedSort)
                    
                    Divider()
                    
                    EpisodeFilterCriteriaGrid(selectedCriteria: $selectedCriteria)
                    
                    if selectedCriteria.count > 1 {
                        Divider()
                        filterLogicPicker
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Filter Episodes")
            .platformNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: PlatformToolbarPlacement.cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .accessibilityIdentifier("Cancel Filter")
                }
                
                ToolbarItem(placement: PlatformToolbarPlacement.primaryAction) {
                    Button("Apply") {
                        let conditions = selectedCriteria.map { EpisodeFilterCondition(criteria: $0) }
                        let filter = EpisodeFilter(
                            conditions: conditions,
                            logic: filterLogic,
                            sortBy: selectedSort
                        )
                        onApply(filter)
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("Apply Filter")
                }
            }
        }
        .accessibilityIdentifier("Episode Filter Sheet")
    }
    
    @ViewBuilder
    private var filterLogicPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter Logic")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Picker("Filter Logic", selection: $filterLogic) {
                Text("Match ALL filters").tag(FilterLogic.and)
                Text("Match ANY filter").tag(FilterLogic.or)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("Filter Logic Picker")
        }
    }
}

// MARK: - Sort By Extensions

private extension EpisodeSortBy {
    var systemImage: String {
        switch self {
        case .pubDateNewest: return "calendar.badge.minus"
        case .pubDateOldest: return "calendar.badge.plus"
        case .duration: return "clock"
        case .title: return "textformat.abc"
        case .playStatus: return "play.circle"
        case .downloadStatus: return "arrow.down.circle"
        case .rating: return "star"
        case .dateAdded: return "plus.circle"
        }
    }
}
