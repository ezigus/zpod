import CoreModels
import SwiftUI

// MARK: - SmartPlaylistSectionView

/// Section that displays smart playlists in the main PlaylistFeatureView.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistSectionView: View {
    var viewModel: SmartPlaylistViewModel

    public init(viewModel: SmartPlaylistViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let episodeCounts = viewModel.cachedEpisodeCountsSnapshot()

        if !viewModel.builtInPlaylists.isEmpty {
            Section("Smart Playlists") {
                ForEach(viewModel.builtInPlaylists) { smartPlaylist in
                    NavigationLink(value: SmartPlaylistNavigation(id: smartPlaylist.id)) {
                        SmartPlaylistRow(
                            smartPlaylist: smartPlaylist,
                            episodeCount: episodeCounts[smartPlaylist.id] ?? 0
                        )
                    }
                    .accessibilityIdentifier("SmartPlaylist.\(smartPlaylist.id).Row")
                }
            }
        }

        if !viewModel.customPlaylists.isEmpty {
            Section("My Smart Playlists") {
                ForEach(viewModel.customPlaylists) { smartPlaylist in
                    NavigationLink(value: SmartPlaylistNavigation(id: smartPlaylist.id)) {
                        SmartPlaylistRow(
                            smartPlaylist: smartPlaylist,
                            episodeCount: episodeCounts[smartPlaylist.id] ?? 0
                        )
                    }
                    .accessibilityIdentifier("SmartPlaylist.\(smartPlaylist.id).Row")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteSmartPlaylist(id: smartPlaylist.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            viewModel.editingSmartPlaylist = smartPlaylist
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            viewModel.duplicateSmartPlaylist(smartPlaylist)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.deleteSmartPlaylist(id: smartPlaylist.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Navigation Value

/// Hashable wrapper to distinguish smart playlist navigation from manual playlist navigation.
public struct SmartPlaylistNavigation: Hashable, Sendable {
    public let id: String
    public init(id: String) { self.id = id }
}

// MARK: - SmartPlaylistRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistRow: View {
    let smartPlaylist: SmartEpisodeListV2
    let episodeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: smartPlaylist.isSystemGenerated ? "wand.and.stars" : "sparkles")
                    .foregroundStyle(smartPlaylist.isSystemGenerated ? .blue : .purple)
                    .font(.subheadline)
                Text(smartPlaylist.name)
                    .font(.headline)
            }
            if let desc = smartPlaylist.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text("\(episodeCount) episode\(episodeCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if smartPlaylist.autoUpdate {
                    Label("Auto-update", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - SmartPlaylistDetailView

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistDetailView: View {
    let smartPlaylist: SmartEpisodeListV2
    var viewModel: SmartPlaylistViewModel

    @State private var showingAnalytics = false

    /// Always reads the latest version of the playlist from the ViewModel so that
    /// edited rules/name/description are reflected immediately after sheet dismissal.
    private var currentPlaylist: SmartEpisodeListV2 {
        viewModel.smartPlaylists.first(where: { $0.id == smartPlaylist.id }) ?? smartPlaylist
    }

    public init(smartPlaylist: SmartEpisodeListV2, viewModel: SmartPlaylistViewModel) {
        self.smartPlaylist = smartPlaylist
        self.viewModel = viewModel
    }

    public var body: some View {
        let episodes = viewModel.episodes(for: currentPlaylist)

        List {
            if episodes.isEmpty {
                Section {
                    SmartPlaylistEmptyView(name: currentPlaylist.name)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(.init(top: 24, leading: 16, bottom: 24, trailing: 16))
                }
            } else {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            if let firstEpisode = episodes.first {
                                viewModel.recordPlay(of: firstEpisode, from: currentPlaylist)
                            }
                            viewModel.onPlayAll?(episodes)
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("SmartPlaylist.\(currentPlaylist.id).PlayAll")

                        Button {
                            viewModel.onShuffle?(episodes)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("SmartPlaylist.\(currentPlaylist.id).Shuffle")
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("\(episodes.count) episodes")) {
                    ForEach(episodes) { episode in
                        SmartPlaylistEpisodeRow(episode: episode)
                            .accessibilityIdentifier("SmartPlaylistEpisode.\(episode.id).Row")
                    }
                }
            }

            Section("Rules") {
                SmartPlaylistRuleSummary(smartPlaylist: currentPlaylist)
            }
        }
        .navigationTitle(currentPlaylist.name)
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingAnalytics = true
                } label: {
                    Label("Analytics", systemImage: "chart.bar")
                }
                .accessibilityIdentifier("SmartPlaylist.\(currentPlaylist.id).AnalyticsButton")

                if !currentPlaylist.isSystemGenerated {
                    Button {
                        viewModel.editingSmartPlaylist = currentPlaylist
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("SmartPlaylist.\(currentPlaylist.id).EditButton")
                }
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            SmartPlaylistAnalyticsView(smartPlaylist: currentPlaylist, viewModel: viewModel)
        }
        #endif
    }
}

// MARK: - SmartPlaylistCreationView

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistCreationView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: SmartPlaylistViewModel
    let existingSmartPlaylist: SmartEpisodeListV2?

    @State private var name: String
    @State private var description: String
    @State private var rules: [SmartListRule]
    @State private var logic: SmartListLogic
    @State private var sortBy: EpisodeSortBy
    @State private var maxEpisodes: Int?
    @State private var autoUpdate: Bool
    @State private var refreshInterval: TimeInterval
    @State private var showingTemplatePicker = false
    @State private var previewEpisodes: [Episode] = []
    @State private var isReordering = false
    @State private var showingDiscardConfirmation = false

    public init(viewModel: SmartPlaylistViewModel, existingSmartPlaylist: SmartEpisodeListV2?) {
        self.viewModel = viewModel
        self.existingSmartPlaylist = existingSmartPlaylist
        _name = State(initialValue: existingSmartPlaylist?.name ?? "")
        _description = State(initialValue: existingSmartPlaylist?.description ?? "")
        _rules = State(initialValue: existingSmartPlaylist?.rules.rules ?? [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        ])
        _logic = State(initialValue: existingSmartPlaylist?.rules.logic ?? .and)
        _sortBy = State(initialValue: existingSmartPlaylist?.sortBy ?? .pubDateNewest)
        _maxEpisodes = State(initialValue: existingSmartPlaylist?.maxEpisodes)
        _autoUpdate = State(initialValue: existingSmartPlaylist?.autoUpdate ?? true)
        _refreshInterval = State(initialValue: existingSmartPlaylist?.refreshInterval ?? 300)
    }

    private var isEditing: Bool { existingSmartPlaylist != nil }
    private var isNameValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var currentRuleSet: SmartListRuleSet { SmartListRuleSet(rules: rules, logic: logic) }

    private var hasUnsavedChanges: Bool {
        if let existing = existingSmartPlaylist {
            return name != existing.name
                || description != (existing.description ?? "")
                || rules != existing.rules.rules
                || logic != existing.rules.logic
                || sortBy != existing.sortBy
                || maxEpisodes != existing.maxEpisodes
                || autoUpdate != existing.autoUpdate
                || refreshInterval != existing.refreshInterval
        }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !description.isEmpty
            || rules.count > 1
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Smart Playlist Info") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("SmartPlaylistCreation.NameField")
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                        .accessibilityIdentifier("SmartPlaylistCreation.DescriptionField")
                    if !isEditing {
                        Button {
                            showingTemplatePicker = true
                        } label: {
                            Label("From Template", systemImage: "doc.on.doc")
                        }
                        .accessibilityIdentifier("SmartPlaylistCreation.TemplateButton")
                    }
                }

                Section("Matching Logic") {
                    Picker("Match", selection: $logic) {
                        ForEach(SmartListLogic.allCases, id: \.self) { logicType in
                            Text(logicType.displayName).tag(logicType)
                        }
                    }
                    .accessibilityIdentifier("SmartPlaylistCreation.LogicPicker")
                }

                #if os(iOS)
                Section {
                    rulesForEach
                    if !isReordering {
                        Button {
                            rules.append(
                                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
                            )
                        } label: {
                            Label("Add Rule", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("SmartPlaylistCreation.AddRule")
                    }
                } header: {
                    HStack {
                        Text("Rules")
                        Spacer()
                        if rules.count > 1 {
                            Button(isReordering ? "Done" : "Reorder") {
                                withAnimation { isReordering.toggle() }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .accessibilityIdentifier("SmartPlaylistCreation.ReorderButton")
                        }
                    }
                }
                .environment(\.editMode, .constant(isReordering ? .active : .inactive))
                #else
                Section("Rules") {
                    rulesForEach
                    Button {
                        rules.append(
                            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
                        )
                    } label: {
                        Label("Add Rule", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("SmartPlaylistCreation.AddRule")
                }
                #endif

                Section("Sort & Limits") {
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(EpisodeSortBy.allCases, id: \.self) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    .accessibilityIdentifier("SmartPlaylistCreation.SortPicker")

                    Toggle("Limit Episodes", isOn: Binding(
                        get: { maxEpisodes != nil },
                        set: { maxEpisodes = $0 ? 50 : nil }
                    ))
                    .accessibilityIdentifier("SmartPlaylistCreation.LimitToggle")

                    if maxEpisodes != nil {
                        Stepper(
                            "Max: \(maxEpisodes ?? 50)",
                            value: Binding(
                                get: { maxEpisodes ?? 50 },
                                set: { maxEpisodes = $0 }
                            ),
                            in: 5...500,
                            step: 5
                        )
                        .accessibilityIdentifier("SmartPlaylistCreation.MaxEpisodesStepper")
                    }
                }

                Section("Automation") {
                    Toggle("Auto-update", isOn: $autoUpdate)
                        .accessibilityIdentifier("SmartPlaylistCreation.AutoUpdateToggle")

                    if autoUpdate {
                        Picker("Refresh Interval", selection: $refreshInterval) {
                            Text("1 minute").tag(TimeInterval(60))
                            Text("5 minutes").tag(TimeInterval(300))
                            Text("15 minutes").tag(TimeInterval(900))
                            Text("30 minutes").tag(TimeInterval(1800))
                            Text("1 hour").tag(TimeInterval(3600))
                        }
                        .accessibilityIdentifier("SmartPlaylistCreation.RefreshPicker")
                    }
                }

                Section {
                    if previewEpisodes.isEmpty {
                        Text("No episodes match these rules")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(previewEpisodes.prefix(5)) { episode in
                            SmartPlaylistEpisodeRow(episode: episode)
                        }
                        if previewEpisodes.count > 5 {
                            Text("and \(previewEpisodes.count - 5) more...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Text("Preview")
                        Spacer()
                        if !previewEpisodes.isEmpty {
                            Text("\(previewEpisodes.count) match\(previewEpisodes.count == 1 ? "" : "es")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Smart Playlist" : "New Smart Playlist")
            .onAppear { refreshPreview() }
            .onChange(of: rules) { refreshPreview() }
            .onChange(of: logic) { refreshPreview() }
            .onChange(of: sortBy) { refreshPreview() }
            .onChange(of: maxEpisodes) { refreshPreview() }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("SmartPlaylistCreation.CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        save()
                        dismiss()
                    }
                    .disabled(!isNameValid || rules.isEmpty)
                    .accessibilityIdentifier("SmartPlaylistCreation.SaveButton")
                }
            }
            .sheet(isPresented: $showingTemplatePicker) {
                SmartPlaylistTemplatePicker(viewModel: viewModel) { template in
                    name = template.name
                    description = template.description
                    rules = template.rules.rules
                    logic = template.rules.logic
                    showingTemplatePicker = false
                }
            }
            .confirmationDialog("Discard Changes?", isPresented: $showingDiscardConfirmation) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }

    private func refreshPreview() {
        previewEpisodes = viewModel.previewEpisodes(
            for: currentRuleSet,
            sortBy: sortBy,
            maxEpisodes: maxEpisodes
        )
    }

    /// ForEach of rule rows with delete and (on iOS) move support.
    /// Extracted so platform-conditional modifiers can be applied without duplicating row content.
    @ViewBuilder private var rulesForEach: some View {
        #if os(iOS)
        ForEach(rules, id: \.id) { rule in ruleRow(for: rule) }
            .onDelete { offsets in rules.remove(atOffsets: offsets) }
            .onMove { source, destination in rules.move(fromOffsets: source, toOffset: destination) }
        #else
        ForEach(rules, id: \.id) { rule in ruleRow(for: rule) }
            .onDelete { offsets in rules.remove(atOffsets: offsets) }
        #endif
    }

    @ViewBuilder private func ruleRow(for rule: SmartListRule) -> some View {
        SmartPlaylistRuleRow(
            rule: rule,
            onUpdate: { updatedRule in
                // Look up by ID to avoid stale indices after deletes/reorders.
                if let idx = rules.firstIndex(where: { $0.id == updatedRule.id }) {
                    rules[idx] = updatedRule
                }
            }
        )
        .contextMenu {
            Button {
                let copy = SmartListRule(
                    type: rule.type,
                    comparison: rule.comparison,
                    value: rule.value,
                    isNegated: rule.isNegated
                )
                if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules.insert(copy, at: idx + 1)
                }
            } label: {
                Label("Duplicate Rule", systemImage: "plus.square.on.square")
            }
        }
    }

    private func save() {
        let ruleSet = SmartListRuleSet(rules: rules, logic: logic)

        if let existing = existingSmartPlaylist {
            let updated = existing
                .withName(name.trimmingCharacters(in: .whitespacesAndNewlines))
                .withDescription(description.isEmpty ? nil : description)
                .withRules(ruleSet)
                .withSortBy(sortBy)
                .withMaxEpisodes(maxEpisodes)
                .withAutoUpdate(autoUpdate)
                .withRefreshInterval(refreshInterval)
            viewModel.updateSmartPlaylist(updated)
        } else {
            viewModel.createSmartPlaylist(
                name: name,
                description: description.isEmpty ? nil : description,
                rules: ruleSet,
                sortBy: sortBy,
                maxEpisodes: maxEpisodes,
                autoUpdate: autoUpdate,
                refreshInterval: refreshInterval
            )
        }
    }
}

// MARK: - SmartPlaylistRuleRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistRuleRow: View {
    let rule: SmartListRule
    let onUpdate: (SmartListRule) -> Void

    @State private var selectedType: SmartListRuleType
    @State private var selectedComparison: SmartListComparison
    @State private var ruleValue: SmartListRuleValue
    @State private var isNegated: Bool

    init(rule: SmartListRule, onUpdate: @escaping (SmartListRule) -> Void) {
        self.rule = rule
        self.onUpdate = onUpdate
        _selectedType = State(initialValue: rule.type)
        _selectedComparison = State(initialValue: rule.comparison)
        _ruleValue = State(initialValue: rule.value)
        _isNegated = State(initialValue: rule.isNegated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Type", selection: $selectedType) {
                    ForEach(SmartListRuleType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("SmartPlaylistRule.\(rule.id).TypePicker")
                .onChange(of: selectedType) { _, newType in
                    // Always reset to the semantic default for the new type.
                    // Preserving the previous comparison risks invalid pairings
                    // (e.g. .equals + .relativeDate for date rules), which the
                    // evaluator cannot handle and silently returns false.
                    selectedComparison = newType.defaultComparison
                    ruleValue = defaultValue(for: newType)
                    notifyUpdate()
                }

                Picker("Comparison", selection: $selectedComparison) {
                    ForEach(selectedType.availableComparisons, id: \.self) { comparison in
                        Text(comparison.displayName).tag(comparison)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("SmartPlaylistRule.\(rule.id).ComparisonPicker")
                .onChange(of: selectedComparison) { _, _ in notifyUpdate() }
            }

            SmartPlaylistRuleValueEditor(
                ruleType: selectedType,
                value: $ruleValue,
                onChange: { notifyUpdate() }
            )
            .accessibilityIdentifier("SmartPlaylistRule.\(rule.id).ValueEditor")

            Toggle("Negate", isOn: $isNegated)
                .font(.caption)
                .accessibilityIdentifier("SmartPlaylistRule.\(rule.id).NegateToggle")
                .onChange(of: isNegated) { _, _ in notifyUpdate() }
        }
        .padding(.vertical, 4)
    }

    private func notifyUpdate() {
        let updated = SmartListRule(
            id: rule.id,
            type: selectedType,
            comparison: selectedComparison,
            value: ruleValue,
            isNegated: isNegated
        )
        onUpdate(updated)
    }

    private func defaultValue(for type: SmartListRuleType) -> SmartListRuleValue {
        switch type {
        case .playStatus: return .episodeStatus(.unplayed)
        case .downloadStatus: return .downloadStatus(.downloaded)
        case .dateAdded, .pubDate: return .relativeDate(.last7Days)
        case .duration: return .timeInterval(1800)
        case .rating: return .integer(3)
        case .podcast, .title, .description: return .string("")
        case .isFavorited, .isBookmarked, .isArchived: return .boolean(true)
        case .playbackPosition: return .double(0.5)
        }
    }
}

// MARK: - SmartPlaylistRuleValueEditor

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistRuleValueEditor: View {
    let ruleType: SmartListRuleType
    @Binding var value: SmartListRuleValue
    let onChange: () -> Void

    var body: some View {
        switch ruleType {
        case .playStatus:
            Picker("Status", selection: episodeStatusBinding) {
                ForEach(EpisodePlayStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .labelsHidden()

        case .downloadStatus:
            Picker("Download", selection: downloadStatusBinding) {
                ForEach(EpisodeDownloadStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .labelsHidden()

        case .dateAdded, .pubDate:
            Picker("Period", selection: relativeDateBinding) {
                ForEach(RelativeDatePeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .labelsHidden()

        case .duration:
            HStack {
                Text("Minutes:")
                    .font(.caption)
                TextField("Minutes", value: durationMinutesBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

        case .rating:
            Stepper("Rating: \(integerValueBinding.wrappedValue)", value: integerValueBinding, in: 1...5)

        case .podcast, .title, .description:
            VStack(alignment: .leading, spacing: 4) {
                TextField("Value", text: stringValueBinding)
                    .textFieldStyle(.roundedBorder)
                if case .string(let str) = value, str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter a value for this rule to match")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

        case .isFavorited, .isBookmarked, .isArchived:
            Toggle(ruleType.displayName, isOn: booleanValueBinding)

        case .playbackPosition:
            HStack {
                Text("Progress:")
                    .font(.caption)
                Slider(value: doubleValueBinding, in: 0...1, step: 0.1)
                Text("\(Int(doubleValueBinding.wrappedValue * 100))%")
                    .font(.caption)
                    .frame(width: 40)
            }
        }
    }

    // MARK: - Bindings

    private var episodeStatusBinding: Binding<EpisodePlayStatus> {
        Binding(
            get: {
                if case .episodeStatus(let status) = value { return status }
                return .unplayed
            },
            set: { value = .episodeStatus($0); onChange() }
        )
    }

    private var downloadStatusBinding: Binding<EpisodeDownloadStatus> {
        Binding(
            get: {
                if case .downloadStatus(let status) = value { return status }
                return .downloaded
            },
            set: { value = .downloadStatus($0); onChange() }
        )
    }

    private var relativeDateBinding: Binding<RelativeDatePeriod> {
        Binding(
            get: {
                if case .relativeDate(let period) = value { return period }
                return .last7Days
            },
            set: { value = .relativeDate($0); onChange() }
        )
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: {
                if case .timeInterval(let interval) = value { return Int(interval / 60) }
                return 30
            },
            set: { value = .timeInterval(TimeInterval($0 * 60)); onChange() }
        )
    }

    private var integerValueBinding: Binding<Int> {
        Binding(
            get: {
                if case .integer(let val) = value { return val }
                return 3
            },
            set: { value = .integer($0); onChange() }
        )
    }

    private var stringValueBinding: Binding<String> {
        Binding(
            get: {
                if case .string(let str) = value { return str }
                return ""
            },
            set: { value = .string($0); onChange() }
        )
    }

    private var booleanValueBinding: Binding<Bool> {
        Binding(
            get: {
                if case .boolean(let val) = value { return val }
                return true
            },
            set: { value = .boolean($0); onChange() }
        )
    }

    private var doubleValueBinding: Binding<Double> {
        Binding(
            get: {
                if case .double(let val) = value { return val }
                return 0.5
            },
            set: { value = .double($0); onChange() }
        )
    }
}

// MARK: - SmartPlaylistTemplatePicker

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistTemplatePicker: View {
    var viewModel: SmartPlaylistViewModel
    let onSelect: (SmartListRuleTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(SmartListTemplateCategory.allCases, id: \.self) { category in
                    let templates = viewModel.templatesByCategory()[category] ?? []
                    if !templates.isEmpty {
                        Section(category.displayName) {
                            ForEach(templates) { template in
                                Button {
                                    onSelect(template)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.headline)
                                        Text(template.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("Template.\(template.id)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SmartPlaylistRuleSummary

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistRuleSummary: View {
    let smartPlaylist: SmartEpisodeListV2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match \(smartPlaylist.rules.logic.displayName.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(smartPlaylist.rules.rules) { rule in
                HStack(spacing: 4) {
                    if rule.isNegated {
                        Text("NOT")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .fontWeight(.bold)
                    }
                    Text(rule.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(rule.comparison.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rule.value.displayValue)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            HStack(spacing: 12) {
                Label(smartPlaylist.sortBy.displayName, systemImage: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let max = smartPlaylist.maxEpisodes {
                    Label("Max \(max)", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if smartPlaylist.autoUpdate {
                    Label("Auto", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistEpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(episode.title)
                .font(.headline)
            if !episode.podcastTitle.isEmpty {
                Text(episode.podcastTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let duration = episode.duration {
                    Label(duration.smartPlaylistFormattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pubDate = episode.pubDate {
                    Label(pubDate.smartPlaylistRelativeDescription, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if episode.isPlayed {
                    Label("Played", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmartPlaylistEmptyView: View {
    let name: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No matching episodes")
                .font(.headline)
            Text("No episodes currently match the rules for \"\(name)\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Formatting Helpers

extension TimeInterval {
    fileprivate var smartPlaylistFormattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: self) ?? "--"
    }
}

extension Date {
    fileprivate var smartPlaylistRelativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
