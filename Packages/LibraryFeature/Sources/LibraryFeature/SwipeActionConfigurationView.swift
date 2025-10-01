//
//  SwipeActionConfigurationView.swift
//  LibraryFeature
//
//  Created for Issue 02.1.6: Swipe Gestures and Quick Actions
//

import SwiftUI
import CoreModels
import SettingsDomain

/// View for configuring swipe gesture actions on episode lists
@MainActor
public struct SwipeActionConfigurationView: View {
    @ObservedObject private var settingsManager: SettingsManager
    @State private var leadingActions: [SwipeActionType]
    @State private var trailingActions: [SwipeActionType]
    @State private var allowFullSwipeLeading: Bool
    @State private var allowFullSwipeTrailing: Bool
    @State private var hapticFeedbackEnabled: Bool
    @State private var hapticStyle: SwipeHapticStyle
    @State private var showingPreset = false
    @Environment(\.dismiss) private var dismiss
    
    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        let currentSettings = settingsManager.globalUISettings.swipeActions
        self._leadingActions = State(initialValue: currentSettings.leadingActions)
        self._trailingActions = State(initialValue: currentSettings.trailingActions)
        self._allowFullSwipeLeading = State(initialValue: currentSettings.allowFullSwipeLeading)
        self._allowFullSwipeTrailing = State(initialValue: currentSettings.allowFullSwipeTrailing)
        self._hapticFeedbackEnabled = State(initialValue: currentSettings.hapticFeedbackEnabled)
        self._hapticStyle = State(initialValue: settingsManager.globalUISettings.hapticStyle)
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Configure which actions appear when you swipe left or right on episodes in your library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Swipe Right (Leading Edge)") {
                    ForEach(Array(leadingActions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            Image(systemName: action.systemIcon)
                                .foregroundStyle(colorForAction(action))
                            Text(action.displayName)
                            Spacer()
                            Button {
                                leadingActions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    if leadingActions.count < 3 {
                        Menu {
                            ForEach(availableActionsForLeading, id: \.self) { action in
                                Button {
                                    leadingActions.append(action)
                                } label: {
                                    Label(action.displayName, systemImage: action.systemIcon)
                                }
                            }
                        } label: {
                            Label("Add Action", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Toggle("Allow Full Swipe", isOn: $allowFullSwipeLeading)
                        .accessibilityIdentifier("Allow Full Swipe Leading")
                }
                
                Section("Swipe Left (Trailing Edge)") {
                    ForEach(Array(trailingActions.enumerated()), id: \.offset) { index, action in
                        HStack {
                            Image(systemName: action.systemIcon)
                                .foregroundStyle(colorForAction(action))
                            Text(action.displayName)
                            Spacer()
                            Button {
                                trailingActions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    if trailingActions.count < 3 {
                        Menu {
                            ForEach(availableActionsForTrailing, id: \.self) { action in
                                Button {
                                    trailingActions.append(action)
                                } label: {
                                    Label(action.displayName, systemImage: action.systemIcon)
                                }
                            }
                        } label: {
                            Label("Add Action", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Toggle("Allow Full Swipe", isOn: $allowFullSwipeTrailing)
                        .accessibilityIdentifier("Allow Full Swipe Trailing")
                }
                
                Section("Haptic Feedback") {
                    Toggle("Enable Haptic Feedback", isOn: $hapticFeedbackEnabled)
                        .accessibilityIdentifier("Enable Haptic Feedback")
                    
                    if hapticFeedbackEnabled {
                        Picker("Feedback Style", selection: $hapticStyle) {
                            ForEach([SwipeHapticStyle.light, .medium, .heavy, .soft, .rigid], id: \.self) { style in
                                Text(style.description).tag(style)
                            }
                        }
                        .accessibilityIdentifier("Haptic Style Picker")
                    }
                }
                
                Section {
                    Button("Load Preset Configuration") {
                        showingPreset = true
                    }
                    .accessibilityIdentifier("Load Preset")
                }
            }
            .navigationTitle("Swipe Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .accessibilityIdentifier("Save Swipe Settings")
                }
            }
            .confirmationDialog("Choose Preset", isPresented: $showingPreset) {
                Button("Default") {
                    loadPreset(.default)
                }
                Button("Playback Focused") {
                    loadPreset(.playbackFocused)
                }
                Button("Organization Focused") {
                    loadPreset(.organizationFocused)
                }
                Button("Download Focused") {
                    loadPreset(.downloadFocused)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select a preset configuration for swipe actions")
            }
        }
        .accessibilityIdentifier("Swipe Action Configuration View")
    }
    
    private var availableActionsForLeading: [SwipeActionType] {
        SwipeActionType.allCases.filter { !leadingActions.contains($0) }
    }
    
    private var availableActionsForTrailing: [SwipeActionType] {
        SwipeActionType.allCases.filter { !trailingActions.contains($0) }
    }
    
    private func colorForAction(_ action: SwipeActionType) -> Color {
        switch action.colorTint {
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .gray: return .gray
        }
    }
    
    private func loadPreset(_ preset: SwipeActionSettings) {
        leadingActions = preset.leadingActions
        trailingActions = preset.trailingActions
        allowFullSwipeLeading = preset.allowFullSwipeLeading
        allowFullSwipeTrailing = preset.allowFullSwipeTrailing
        hapticFeedbackEnabled = preset.hapticFeedbackEnabled
    }
    
    private func saveSettings() {
        let newSwipeSettings = SwipeActionSettings(
            leadingActions: leadingActions,
            trailingActions: trailingActions,
            allowFullSwipeLeading: allowFullSwipeLeading,
            allowFullSwipeTrailing: allowFullSwipeTrailing,
            hapticFeedbackEnabled: hapticFeedbackEnabled
        )
        
        let newUISettings = UISettings(
            swipeActions: newSwipeSettings,
            hapticStyle: hapticStyle
        )
        
        Task {
            await settingsManager.updateGlobalUISettings(newUISettings)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
