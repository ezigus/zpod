//
//  SmartListRuleBuilderView.swift
//  LibraryFeature
//
//  Advanced rule builder for smart episode lists
//

import SwiftUI
import CoreModels

// MARK: - Smart List Rule Builder Model

public class SmartListRuleBuilder: ObservableObject {
    @Published var type: SmartListRuleType
    @Published var comparison: SmartListComparison
    @Published var value: SmartListRuleValue?
    @Published var isNegated: Bool
    
    // Intermediate values for building complex rule values
    @Published var stringValue: String = ""
    @Published var intValue: Int = 0
    @Published var doubleValue: Double = 0.0
    @Published var boolValue: Bool = false
    @Published var dateValue: Date = Date()
    @Published var startDateValue: Date = Date()
    @Published var endDateValue: Date = Date()
    @Published var timeIntervalValue: TimeInterval = 0
    @Published var relativeDateValue: RelativeDatePeriod = .today
    @Published var episodeStatusValue: EpisodePlayStatus = .unplayed
    @Published var downloadStatusValue: EpisodeDownloadStatus = .notDownloaded
    
    public init() {
        self.type = .playStatus
        self.comparison = .equals
        self.isNegated = false
        self.value = .episodeStatus(.unplayed)
    }
    
    public init(from rule: SmartListRule) {
        self.type = rule.type
        self.comparison = rule.comparison
        self.isNegated = rule.isNegated
        self.value = rule.value
        
        // Populate intermediate values based on the rule value
        switch rule.value {
        case .boolean(let boolVal):
            self.boolValue = boolVal
        case .integer(let intVal):
            self.intValue = intVal
        case .double(let doubleVal):
            self.doubleValue = doubleVal
        case .string(let stringVal):
            self.stringValue = stringVal
        case .date(let dateVal):
            self.dateValue = dateVal
        case .dateRange(let start, let end):
            self.startDateValue = start
            self.endDateValue = end
        case .timeInterval(let interval):
            self.timeIntervalValue = interval
        case .relativeDate(let period):
            self.relativeDateValue = period
        case .episodeStatus(let status):
            self.episodeStatusValue = status
        case .downloadStatus(let status):
            self.downloadStatusValue = status
        }
    }
    
    public func buildRule() -> SmartListRule? {
        guard let ruleValue = buildRuleValue() else { return nil }
        
        return SmartListRule(
            type: type,
            comparison: comparison,
            value: ruleValue,
            isNegated: isNegated
        )
    }
    
    var valueDisplayText: String? {
        return value?.displayValue
    }
    
    // MARK: - Private Methods
    
    private func buildRuleValue() -> SmartListRuleValue? {
        switch type {
        case .playStatus:
            return .episodeStatus(episodeStatusValue)
        case .downloadStatus:
            return .downloadStatus(downloadStatusValue)
        case .dateAdded, .pubDate:
            switch comparison {
            case .between:
                return .dateRange(start: startDateValue, end: endDateValue)
            case .within:
                return .relativeDate(relativeDateValue)
            default:
                return .date(dateValue)
            }
        case .duration, .playbackPosition:
            return .timeInterval(timeIntervalValue)
        case .rating:
            return .integer(intValue)
        case .podcast, .title, .description:
            return stringValue.isEmpty ? nil : .string(stringValue)
        case .isFavorited, .isBookmarked, .isArchived:
            return .boolean(boolValue)
        }
    }
}

// MARK: - Smart List Rule Builder View

public struct SmartListRuleBuilderView: View {
    @StateObject private var ruleBuilder: SmartListRuleBuilder
    @Environment(\.dismiss) private var dismiss
    
    private let onSave: (SmartListRuleBuilder) -> Void
    private let isEditing: Bool
    
    public init(rule: SmartListRuleBuilder? = nil, onSave: @escaping (SmartListRuleBuilder) -> Void) {
        if let rule = rule {
            self._ruleBuilder = StateObject(wrappedValue: rule)
            self.isEditing = true
        } else {
            self._ruleBuilder = StateObject(wrappedValue: SmartListRuleBuilder())
            self.isEditing = false
        }
        self.onSave = onSave
    }
    
    public var body: some View {
        NavigationView {
            Form {
                ruleTypeSection
                comparisonSection
                valueSection
                negationSection
                previewSection
            }
            .navigationTitle(isEditing ? "Edit Rule" : "Add Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(ruleBuilder)
                        dismiss()
                    }
                    .disabled(!isValidRule)
                }
            }
        }
        .onChange(of: ruleBuilder.type) { _, newType in
            updateComparisonForType(newType)
            updateValueForType(newType)
        }
        .onChange(of: ruleBuilder.comparison) { _, _ in
            updateRuleValue()
        }
    }
    
    // MARK: - Form Sections
    
    private var ruleTypeSection: some View {
        Section("Rule Type") {
            Picker("Type", selection: $ruleBuilder.type) {
                ForEach(SmartListRuleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var comparisonSection: some View {
        Section("Comparison") {
            Picker("Comparison", selection: $ruleBuilder.comparison) {
                ForEach(ruleBuilder.type.availableComparisons, id: \.self) { comparison in
                    Text(comparison.displayName).tag(comparison)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var valueSection: some View {
        Section("Value") {
            valueInputView
        }
    }
    
    private var negationSection: some View {
        Section {
            Toggle("Negate (NOT)", isOn: $ruleBuilder.isNegated)
        } footer: {
            Text("When enabled, this rule will exclude episodes that match the criteria")
        }
    }
    
    private var previewSection: some View {
        Section("Preview") {
            if let rule = ruleBuilder.buildRule() {
                RuleChip(rule: rule)
            } else {
                Text("Configure all fields to see preview")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    // MARK: - Value Input Views
    
    @ViewBuilder
    private var valueInputView: some View {
        switch ruleBuilder.type {
        case .playStatus:
            Picker("Status", selection: $ruleBuilder.episodeStatusValue) {
                ForEach(EpisodePlayStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .onChange(of: ruleBuilder.episodeStatusValue) { _, _ in updateRuleValue() }
            
        case .downloadStatus:
            Picker("Status", selection: $ruleBuilder.downloadStatusValue) {
                ForEach(EpisodeDownloadStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .onChange(of: ruleBuilder.downloadStatusValue) { _, _ in updateRuleValue() }
            
        case .dateAdded, .pubDate:
            dateValueInput
            
        case .duration, .playbackPosition:
            durationValueInput
            
        case .rating:
            ratingValueInput
            
        case .podcast, .title, .description:
            TextField("Text to match", text: $ruleBuilder.stringValue)
                .onChange(of: ruleBuilder.stringValue) { _, _ in updateRuleValue() }
            
        case .isFavorited, .isBookmarked, .isArchived:
            Picker("Value", selection: $ruleBuilder.boolValue) {
                Text("Yes").tag(true)
                Text("No").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: ruleBuilder.boolValue) { _, _ in updateRuleValue() }
        }
    }
    
    private var dateValueInput: some View {
        Group {
            switch ruleBuilder.comparison {
            case .between:
                DatePicker("Start Date", selection: $ruleBuilder.startDateValue, displayedComponents: .date)
                    .onChange(of: ruleBuilder.startDateValue) { _, _ in updateRuleValue() }
                DatePicker("End Date", selection: $ruleBuilder.endDateValue, displayedComponents: .date)
                    .onChange(of: ruleBuilder.endDateValue) { _, _ in updateRuleValue() }
                
            case .within:
                Picker("Period", selection: $ruleBuilder.relativeDateValue) {
                    ForEach(RelativeDatePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: ruleBuilder.relativeDateValue) { _, _ in updateRuleValue() }
                
            default:
                DatePicker("Date", selection: $ruleBuilder.dateValue, displayedComponents: .date)
                    .onChange(of: ruleBuilder.dateValue) { _, _ in updateRuleValue() }
            }
        }
    }
    
    private var durationValueInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duration:")
                Spacer()
                Text(formatDuration(ruleBuilder.timeIntervalValue))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                DurationSlider(
                    title: "Hours",
                    value: Binding(
                        get: { ruleBuilder.timeIntervalValue / 3600 },
                        set: { newValue in
                            let minutes = (ruleBuilder.timeIntervalValue.truncatingRemainder(dividingBy: 3600)) / 60
                            let seconds = ruleBuilder.timeIntervalValue.truncatingRemainder(dividingBy: 60)
                            ruleBuilder.timeIntervalValue = newValue * 3600 + minutes * 60 + seconds
                            updateRuleValue()
                        }
                    ),
                    range: 0...10,
                    step: 0.5
                )
                
                DurationSlider(
                    title: "Minutes",
                    value: Binding(
                        get: { (ruleBuilder.timeIntervalValue.truncatingRemainder(dividingBy: 3600)) / 60 },
                        set: { newValue in
                            let hours = floor(ruleBuilder.timeIntervalValue / 3600)
                            let seconds = ruleBuilder.timeIntervalValue.truncatingRemainder(dividingBy: 60)
                            ruleBuilder.timeIntervalValue = hours * 3600 + newValue * 60 + seconds
                            updateRuleValue()
                        }
                    ),
                    range: 0...59,
                    step: 1
                )
            }
            
            // Quick duration presets
            HStack {
                ForEach([
                    ("5m", 300.0),
                    ("15m", 900.0),
                    ("30m", 1800.0),
                    ("1h", 3600.0),
                    ("2h", 7200.0)
                ], id: \.0) { label, duration in
                    Button(label) {
                        ruleBuilder.timeIntervalValue = duration
                        updateRuleValue()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var ratingValueInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rating:")
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= ruleBuilder.intValue ? "star.fill" : "star")
                            .foregroundColor(star <= ruleBuilder.intValue ? .yellow : .gray)
                            .onTapGesture {
                                ruleBuilder.intValue = star
                                updateRuleValue()
                            }
                    }
                }
            }
            
            Slider(value: Binding(
                get: { Double(ruleBuilder.intValue) },
                set: { ruleBuilder.intValue = Int($0) }
            ), in: 1...5, step: 1)
            .onChange(of: ruleBuilder.intValue) { _, _ in updateRuleValue() }
        }
    }
    
    // MARK: - Helper Methods
    
    private var isValidRule: Bool {
        switch ruleBuilder.type {
        case .podcast, .title, .description:
            return !ruleBuilder.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }
    
    private func updateComparisonForType(_ type: SmartListRuleType) {
        let availableComparisons = type.availableComparisons
        if !availableComparisons.contains(ruleBuilder.comparison) {
            ruleBuilder.comparison = availableComparisons.first ?? .equals
        }
    }
    
    private func updateValueForType(_ type: SmartListRuleType) {
        // Reset values when type changes
        switch type {
        case .playStatus:
            ruleBuilder.episodeStatusValue = .unplayed
        case .downloadStatus:
            ruleBuilder.downloadStatusValue = .notDownloaded
        case .duration, .playbackPosition:
            ruleBuilder.timeIntervalValue = 1800 // 30 minutes default
        case .rating:
            ruleBuilder.intValue = 4
        case .podcast, .title, .description:
            ruleBuilder.stringValue = ""
        case .isFavorited, .isBookmarked, .isArchived:
            ruleBuilder.boolValue = true
        case .dateAdded, .pubDate:
            ruleBuilder.dateValue = Date()
            ruleBuilder.relativeDateValue = .thisWeek
        }
        
        updateRuleValue()
    }
    
    private func updateRuleValue() {
        ruleBuilder.value = ruleBuilder.buildRuleValue()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Duration Slider Component

struct DurationSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: step)
        }
    }
}

