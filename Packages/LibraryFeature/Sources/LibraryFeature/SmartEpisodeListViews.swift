//
//  SmartEpisodeListViews.swift
//  LibraryFeature
//
//  Smart episode list management and rule builder interface
//

import SwiftUI
import CoreModels
import Persistence

// MARK: - Smart Episode Lists Main View

public struct SmartEpisodeListsView: View {
    @StateObject private var manager: SmartEpisodeListManager
    @State private var showingCreateSheet = false
    @State private var selectedSmartList: SmartEpisodeListV2?
    @State private var showingEditSheet = false
    
    private let allEpisodes: [Episode]
    
    public init(allEpisodes: [Episode], filterService: EpisodeFilterService) {
        self.allEpisodes = allEpisodes
        self._manager = StateObject(wrappedValue: SmartEpisodeListManager(filterService: filterService))
    }
    
    public var body: some View {
        NavigationView {
            Group {
                if manager.isLoading {
                    ProgressView("Loading Smart Lists...")
                } else {
                    smartListsContent
                }
            }
            .navigationTitle("Smart Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create", systemImage: "plus") {
                        showingCreateSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                SmartListBuilderView(
                    manager: manager,
                    allEpisodes: allEpisodes
                )
            }
            .sheet(item: $selectedSmartList) { smartList in
                SmartListBuilderView(
                    smartList: smartList,
                    manager: manager,
                    allEpisodes: allEpisodes
                )
            }
        }
        .task {
            await manager.updateSmartListsIfNeeded(allEpisodes: allEpisodes)
        }
    }
    
    // MARK: - Smart Lists Content
    
    private var smartListsContent: some View {
        List {
            let categorizedLists = manager.smartListsByCategory()
            
            ForEach(SmartListDisplayCategory.allCases, id: \.self) { category in
                if let lists = categorizedLists[category], !lists.isEmpty {
                    Section(category.displayName) {
                        ForEach(lists) { smartList in
                            SmartListRow(
                                smartList: smartList,
                                episodeCount: getEpisodeCount(for: smartList),
                                onEdit: { selectedSmartList = smartList },
                                onDelete: category == .custom ? { deleteSmartList(smartList) } : nil
                            )
                        }
                    }
                }
            }
            
            if manager.smartLists.isEmpty {
                ContentUnavailableView(
                    "No Smart Lists",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create smart lists to automatically organize your episodes")
                )
            }
        }
        .refreshable {
            await manager.loadSmartLists()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getEpisodeCount(for smartList: SmartEpisodeListV2) -> Int {
        // This would ideally be cached or computed asynchronously
        let _ = manager.evaluateSmartList(smartList, allEpisodes: allEpisodes)
        return 0 // Placeholder - would need to handle async properly
    }
    
    private func deleteSmartList(_ smartList: SmartEpisodeListV2) {
        Task {
            try? await manager.deleteSmartList(id: smartList.id)
        }
    }
}

// MARK: - Smart List Row

struct SmartListRow: View {
    let smartList: SmartEpisodeListV2
    let episodeCount: Int
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(smartList.name)
                            .font(.headline)
                        
                        if smartList.isSystemGenerated {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    if let description = smartList.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Label("\(smartList.rules.rules.count) rules", systemImage: "slider.horizontal.3")
                        Text("•")
                        Label(smartList.sortBy.displayName, systemImage: "arrow.up.arrow.down")
                        
                        if let maxEpisodes = smartList.maxEpisodes {
                            Text("•")
                            Label("Max \(maxEpisodes)", systemImage: "number")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(episodeCount)")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("episodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if smartList.autoUpdate {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Auto")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Rule preview
            SmartListRulePreview(rules: smartList.rules)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                onEdit()
            }
            
            if let onDelete = onDelete {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}

// MARK: - Smart List Rule Preview

struct SmartListRulePreview: View {
    let rules: SmartListRuleSet
    
    var body: some View {
        HStack {
            Text("Rules:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(zip(rules.rules.indices, rules.rules)), id: \.0) { index, rule in
                        RuleChip(rule: rule)
                        
                        if index < rules.rules.count - 1 {
                            Text(rules.logic.displayName.lowercased())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct RuleChip: View {
    let rule: SmartListRule
    
    var body: some View {
        HStack(spacing: 4) {
            if rule.isNegated {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red)
                    .font(.caption2)
            }
            
            Text(rule.type.displayName)
                .fontWeight(.medium)
            
            Text(rule.comparison.displayName)
                .foregroundColor(.secondary)
            
            Text(rule.value.displayValue)
                .foregroundColor(.accentColor)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Smart List Builder View

public struct SmartListBuilderView: View {
    @ObservedObject var manager: SmartEpisodeListManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var rules: [SmartListRuleBuilder]
    @State private var logic: SmartListLogic
    @State private var sortBy: EpisodeSortBy
    @State private var maxEpisodes: Int?
    @State private var autoUpdate: Bool
    @State private var refreshInterval: TimeInterval
    @State private var showingRuleSheet = false
    @State private var editingRuleIndex: Int?
    @State private var previewEpisodes: [Episode] = []
    @State private var isLoadingPreview = false
    
    private let allEpisodes: [Episode]
    private let smartList: SmartEpisodeListV2?
    private let isEditing: Bool
    
    public init(
        smartList: SmartEpisodeListV2? = nil,
        manager: SmartEpisodeListManager,
        allEpisodes: [Episode]
    ) {
        self.smartList = smartList
        self.manager = manager
        self.allEpisodes = allEpisodes
        self.isEditing = smartList != nil
        
        // Initialize state from smart list or defaults
        self._name = State(initialValue: smartList?.name ?? "")
        self._description = State(initialValue: smartList?.description ?? "")
        self._rules = State(initialValue: smartList?.rules.rules.map(SmartListRuleBuilder.init) ?? [])
        self._logic = State(initialValue: smartList?.rules.logic ?? .and)
        self._sortBy = State(initialValue: smartList?.sortBy ?? .pubDateNewest)
        self._maxEpisodes = State(initialValue: smartList?.maxEpisodes)
        self._autoUpdate = State(initialValue: smartList?.autoUpdate ?? true)
        self._refreshInterval = State(initialValue: smartList?.refreshInterval ?? 300)
    }
    
    public var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                rulesSection
                sortingSection
                autoUpdateSection
                previewSection
            }
            .navigationTitle(isEditing ? "Edit Smart List" : "Create Smart List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSmartList()
                    }
                    .disabled(!isValidConfiguration)
                }
            }
            .sheet(isPresented: $showingRuleSheet) {
                SmartListRuleBuilderView(
                    rule: editingRuleIndex.map { rules[$0] },
                    onSave: { rule in
                        if let index = editingRuleIndex {
                            rules[index] = rule
                        } else {
                            rules.append(rule)
                        }
                        updatePreview()
                    }
                )
            }
        }
        .onAppear {
            updatePreview()
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Name", text: $name)
            TextField("Description (Optional)", text: $description, axis: .vertical)
                .lineLimit(2...4)
        }
    }
    
    private var rulesSection: some View {
        Section {
            ForEach(Array(zip(rules.indices, rules)), id: \.0) { index, rule in
                SmartListRuleBuilderRow(rule: rule) {
                    editingRuleIndex = index
                    showingRuleSheet = true
                } onDelete: {
                    rules.remove(at: index)
                    updatePreview()
                }
            }
            .onDelete { indexSet in
                rules.remove(atOffsets: indexSet)
                updatePreview()
            }
            
            Button("Add Rule") {
                editingRuleIndex = nil
                showingRuleSheet = true
            }
            .foregroundColor(.accentColor)
            
            if rules.count > 1 {
                Picker("Logic", selection: $logic) {
                    ForEach(SmartListLogic.allCases, id: \.self) { logic in
                        Text(logic.displayName).tag(logic)
                    }
                }
                .onChange(of: logic) { _, _ in
                    updatePreview()
                }
            }
        } header: {
            Text("Rules (\(rules.count))")
        }
    }
    
    private var sortingSection: some View {
        Section("Sorting & Limits") {
            Picker("Sort By", selection: $sortBy) {
                ForEach(EpisodeSortBy.allCases, id: \.self) { sort in
                    Text(sort.displayName).tag(sort)
                }
            }
            .onChange(of: sortBy) { _, _ in
                updatePreview()
            }
            
            HStack {
                Text("Max Episodes")
                Spacer()
                
                if let maxEpisodes = maxEpisodes {
                    TextField("Max", value: .constant(maxEpisodes), format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                } else {
                    Text("No limit")
                        .foregroundColor(.secondary)
                }
                
                Button(maxEpisodes == nil ? "Set Limit" : "Remove Limit") {
                    maxEpisodes = maxEpisodes == nil ? 50 : nil
                    updatePreview()
                }
                .font(.caption)
            }
        }
    }
    
    private var autoUpdateSection: some View {
        Section("Auto Update") {
            Toggle("Auto Update", isOn: $autoUpdate)
                .onChange(of: autoUpdate) { _, _ in
                    updatePreview()
                }
            
            if autoUpdate {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Text(formatInterval(refreshInterval))
                        .foregroundColor(.secondary)
                }
                
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                    Text("1 hour").tag(TimeInterval(3600))
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var previewSection: some View {
        Section {
            if isLoadingPreview {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating preview...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        Text("\(previewEpisodes.count) episodes")
                            .foregroundColor(.secondary)
                    }
                    
                    if previewEpisodes.isEmpty {
                        Text("No episodes match these rules")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(previewEpisodes.prefix(5)) { episode in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(episode.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(episode.podcastTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if previewEpisodes.count > 5 {
                            Text("... and \(previewEpisodes.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var isValidConfiguration: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !rules.isEmpty
    }
    
    private func updatePreview() {
        guard !rules.isEmpty else {
            previewEpisodes = []
            return
        }
        
        isLoadingPreview = true
        
        Task {
            let smartListRules = SmartListRuleSet(
                rules: rules.compactMap { $0.buildRule() },
                logic: logic
            )
            
            let testSmartList = SmartEpisodeListV2(
                name: name,
                description: description.isEmpty ? nil : description,
                rules: smartListRules,
                sortBy: sortBy,
                maxEpisodes: maxEpisodes,
                autoUpdate: autoUpdate,
                refreshInterval: refreshInterval
            )
            
            let episodes = manager.evaluateSmartList(testSmartList, allEpisodes: allEpisodes)
            
            await MainActor.run {
                previewEpisodes = episodes
                isLoadingPreview = false
            }
        }
    }
    
    private func saveSmartList() {
        let smartListRules = SmartListRuleSet(
            rules: rules.compactMap { $0.buildRule() },
            logic: logic
        )
        
        let newSmartList = SmartEpisodeListV2(
            id: smartList?.id ?? UUID().uuidString,
            name: name,
            description: description.isEmpty ? nil : description,
            rules: smartListRules,
            sortBy: sortBy,
            maxEpisodes: maxEpisodes,
            autoUpdate: autoUpdate,
            refreshInterval: refreshInterval,
            createdAt: smartList?.createdAt ?? Date()
        )
        
        Task {
            try? await manager.updateSmartList(newSmartList)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval)) seconds"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) minutes"
        } else {
            return "\(Int(interval / 3600)) hours"
        }
    }
}

// MARK: - Smart List Rule Builder Row

struct SmartListRuleBuilderRow: View {
    let rule: SmartListRuleBuilder
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if rule.isNegated {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    
                    Text(rule.type.displayName)
                        .fontWeight(.medium)
                    
                    Text(rule.comparison.displayName)
                        .foregroundColor(.secondary)
                    
                    if let valueText = rule.valueDisplayText {
                        Text(valueText)
                            .foregroundColor(.accentColor)
                    }
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            Button("Edit") {
                onEdit()
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}