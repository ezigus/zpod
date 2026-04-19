//
//  PodcastCustomSettingsView.swift
//  LibraryFeature
//
//  Created for Issue #478: [06.5.1] PodcastCustomSettingsView scaffolding, access points,
//  and Reset All.
//
//  This is the outer scaffold for per-podcast custom settings. Placeholder sections
//  will be replaced with real controls in 06.5.2+.
//

import CoreModels
import SettingsDomain
import SwiftUI

/// Per-podcast settings view — scaffold with placeholder sections and functional Reset All.
///
/// Entry points:
/// - Long-press context menu on a podcast card in the Library
/// - Gear button in the podcast detail (EpisodeListView) toolbar
@MainActor
public struct PodcastCustomSettingsView: View {
    @StateObject private var viewModel: PodcastCustomSettingsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    public init(podcast: Podcast, settingsManager: SettingsManager) {
        _viewModel = StateObject(
            wrappedValue: PodcastCustomSettingsViewModel(
                podcast: podcast,
                settingsManager: settingsManager
            )
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isResetting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Reset to Global Defaults")
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isResetting)
                    .accessibilityIdentifier("PodcastCustomSettings.ResetButton")
                }

                Section(header: Text("Download Settings")) {
                    Text("Custom download settings coming in a future update.")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("PodcastCustomSettings.DownloadPlaceholder")
                }

                Section(header: Text("Retention Settings")) {
                    Text("Custom retention settings coming in a future update.")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("PodcastCustomSettings.RetentionPlaceholder")
                }

                Section(header: Text("Playback Settings")) {
                    Text("Custom playback settings coming in a future update.")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("PodcastCustomSettings.PlaybackPlaceholder")
                }

                Section(header: Text("Sort Settings")) {
                    Text("Custom sort settings coming in a future update.")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("PodcastCustomSettings.SortPlaceholder")
                }

                Section(header: Text("Priority Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Download Priority")
                            Spacer()
                            Text(priorityLabel(viewModel.priority))
                                .foregroundColor(priorityColor(viewModel.priority))
                                .monospacedDigit()
                                .accessibilityIdentifier("PodcastCustomSettings.PriorityValueLabel")
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.priority) },
                                set: { viewModel.priority = Int($0.rounded()) }
                            ),
                            in: -10...10,
                            step: 1
                        )
                        .accessibilityIdentifier("PodcastCustomSettings.PrioritySlider")
                        .accessibilityValue("\(viewModel.priority)")
                        Text("Negative values delay downloads; positive values boost them ahead of others.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .task {
                        await viewModel.loadPriority()
                    }
                    .onChange(of: viewModel.priority) { _ in
                        Task { await viewModel.savePriority() }
                    }
                }

                Section(header: Text("Notification Settings")) {
                    Text("Custom notification settings coming in a future update.")
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("PodcastCustomSettings.NotificationPlaceholder")
                }
            }
            .navigationTitle(viewModel.podcast.title)
            .platformNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("PodcastCustomSettings.DoneButton")
                }
            }
        }
        .alert(
            "Reset Settings",
            isPresented: $showResetConfirmation
        ) {
            Button("Cancel", role: .cancel) { showResetConfirmation = false }
                .accessibilityIdentifier("PodcastCustomSettings.ResetCancelButton")
            Button("Reset", role: .destructive) {
                Task { @MainActor in
                    await viewModel.resetSettings()?.value
                    dismiss()
                }
            }
            .accessibilityIdentifier("PodcastCustomSettings.ResetConfirmButton")
        } message: {
            Text(
                "Reset all custom settings for \(viewModel.podcast.title)? This cannot be undone."
            )
        }
    }

    // MARK: - Priority helpers

    private func priorityLabel(_ value: Int) -> String {
        switch value {
        case ..<0: return "\(value)  Deprioritized"
        case 1...: return "+\(value)  Prioritized"
        default:   return "0  Normal"
        }
    }

    private func priorityColor(_ value: Int) -> Color {
        if value < 0 { return .orange }
        if value > 0 { return .blue }
        return .secondary
    }
}
