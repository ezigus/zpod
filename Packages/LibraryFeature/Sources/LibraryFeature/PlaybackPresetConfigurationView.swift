import CoreModels
import SettingsDomain
import SwiftUI

public struct PlaybackPresetConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: PlaybackPresetConfigurationController
  private let onSave: ((PlaybackPresetLibrary) -> Void)?

  @State private var editingPreset: PlaybackPreset?
  @State private var isPresentingEditor = false
  @State private var showingResetConfirmation = false

  public init(
    controller: PlaybackPresetConfigurationController,
    onSave: ((PlaybackPresetLibrary) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    List {
      summarySection
      builtInSection
      customSection
      actionsSection
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Playback Presets")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") { showingResetConfirmation = true }
          .disabled(!controller.hasUnsavedChanges)
          .accessibilityIdentifier("PlaybackPresets.Reset")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await commitChanges() } }
          .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          .accessibilityIdentifier("PlaybackPresets.Save")
      }
    }
    .sheet(isPresented: $isPresentingEditor) {
      if let preset = editingPreset {
        PlaybackPresetEditorView(
          preset: preset,
          isBuiltIn: controller.draftLibrary.builtInPresets.contains(where: { $0.id == preset.id }),
          onDismiss: { isPresentingEditor = false },
          onSave: { updated in
            controller.updatePreset(updated)
            isPresentingEditor = false
          }
        )
      }
    }
    .confirmationDialog(
      "Restore default playback presets?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) {
        controller.resetToDefaults()
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var summarySection: some View {
    Section("Active Preset") {
      if let activeID = controller.draftLibrary.activePresetID,
         let preset = controller.draftLibrary.allPresets.first(where: { $0.id == activeID }) {
        VStack(alignment: .leading, spacing: 6) {
          Text(preset.name)
            .font(.headline)
          if let description = preset.description, !description.isEmpty {
            Text(description)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Text("Speed: \(String(format: "%.1fx", preset.playbackSpeed)) · Intro: \(preset.skipIntroSeconds)s · Outro: \(preset.skipOutroSeconds)s")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      } else {
        Text("No preset is active. Current playback settings are custom.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var builtInSection: some View {
    Section("Built-in Presets") {
      ForEach(controller.draftLibrary.builtInPresets) { preset in
        presetRow(preset, isBuiltIn: true)
      }
    }
  }

  @ViewBuilder
  private var customSection: some View {
    Section("Custom Presets") {
      if controller.draftLibrary.customPresets.isEmpty {
        Text("Create a custom preset to save your favourite playback settings.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(controller.draftLibrary.customPresets) { preset in
          presetRow(preset, isBuiltIn: false)
        }
      }
      Button {
        controller.createPreset()
        if let newPreset = controller.draftLibrary.customPresets.last {
          editingPreset = newPreset
          isPresentingEditor = true
        }
      } label: {
        Label("New Custom Preset", systemImage: "plus.circle")
      }
      .accessibilityIdentifier("PlaybackPresets.AddCustom")
    }
  }

  @ViewBuilder
  private var actionsSection: some View {
    Section("Actions") {
      Button(role: .none) {
        controller.resetToDefaults()
      } label: {
        Label("Restore Defaults", systemImage: "arrow.counterclockwise")
      }
      .accessibilityIdentifier("PlaybackPresets.RestoreDefaults")
    }
  }

  private func presetRow(_ preset: PlaybackPreset, isBuiltIn: Bool) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(preset.name)
          .font(.headline)
        if let description = preset.description, !description.isEmpty {
          Text(description)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text("Speed: \(String(format: "%.1fx", preset.playbackSpeed))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if controller.draftLibrary.activePresetID == preset.id {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentColor)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      controller.activatePreset(preset.id)
    }
    .contextMenu {
      Button("Edit") {
        editingPreset = preset
        isPresentingEditor = true
      }
      Button("Duplicate") {
        controller.duplicatePreset(preset.id)
      }
      if !isBuiltIn {
        Button("Delete", role: .destructive) {
          controller.deletePreset(preset.id)
        }
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Activate") {
        controller.activatePreset(preset.id)
      }.tint(.accentColor)

      Button("Edit") {
        editingPreset = preset
        isPresentingEditor = true
      }

      if !isBuiltIn {
        Button(role: .destructive) {
          controller.deletePreset(preset.id)
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.draftLibrary)
    dismiss()
  }
}

private struct PlaybackPresetEditorView: View {
  @State private var draft: PlaybackPreset
  let isBuiltIn: Bool
  let onDismiss: () -> Void
  let onSave: (PlaybackPreset) -> Void

  init(
    preset: PlaybackPreset,
    isBuiltIn: Bool,
    onDismiss: @escaping () -> Void,
    onSave: @escaping (PlaybackPreset) -> Void
  ) {
    _draft = State(initialValue: preset)
    self.isBuiltIn = isBuiltIn
    self.onDismiss = onDismiss
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField("Name", text: Binding(
            get: { draft.name },
            set: { draft.name = $0 }
          ))
          if !isBuiltIn {
            TextField("Description", text: Binding(
              get: { draft.description ?? "" },
              set: { draft.description = $0 }
            ))
          } else if let description = draft.description {
            Text(description)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section("Playback") {
          SettingsSliderRow(
            "Speed",
            value: Binding(
              get: { draft.playbackSpeed },
              set: { draft.playbackSpeed = $0 }
            ),
            in: 0.5...3.0,
            step: 0.05,
            sliderAccessibilityIdentifier: "PlaybackPresetEditor.Speed",
            valueAccessibilityIdentifier: "PlaybackPresetEditor.Speed.Value",
            valueFont: .headline,
            valueForegroundStyle: .primary,
            footer: "Playback speed when this preset is active.",
            formatValue: { String(format: "%.2fx", $0) }
          )

          SettingsStepperRow(
            value: Binding(
              get: { draft.skipForwardInterval },
              set: { draft.skipForwardInterval = $0 }
            ),
            in: 5...120,
            step: 5,
            accessibilityIdentifier: "PlaybackPresetEditor.SkipForward"
          ) { value in
            LocalizedStringKey("Skip forward: \(value) sec")
          }

          SettingsStepperRow(
            value: Binding(
              get: { draft.skipBackwardInterval },
              set: { draft.skipBackwardInterval = $0 }
            ),
            in: 5...120,
            step: 5,
            accessibilityIdentifier: "PlaybackPresetEditor.SkipBackward"
          ) { value in
            LocalizedStringKey("Skip backward: \(value) sec")
          }
        }

        Section("Skips") {
          SettingsStepperRow(
            value: Binding(
              get: { draft.skipIntroSeconds },
              set: { draft.skipIntroSeconds = $0 }
            ),
            in: 0...300,
            step: 5,
            accessibilityIdentifier: "PlaybackPresetEditor.SkipIntro"
          ) { value in
            LocalizedStringKey("Skip intro: \(value) sec")
          }

          SettingsStepperRow(
            value: Binding(
              get: { draft.skipOutroSeconds },
              set: { draft.skipOutroSeconds = $0 }
            ),
            in: 0...300,
            step: 5,
            accessibilityIdentifier: "PlaybackPresetEditor.SkipOutro"
          ) { value in
            LocalizedStringKey("Skip outro: \(value) sec")
          }
        }

        Section("Advanced") {
          SettingsToggleRow(
            "Continuous playback",
            isOn: Binding(
              get: { draft.continuousPlayback },
              set: { draft.continuousPlayback = $0 }
            ),
            accessibilityIdentifier: "PlaybackPresetEditor.Continuous"
          )

          SettingsToggleRow(
            "Crossfade",
            isOn: Binding(
              get: { draft.crossFadeEnabled },
              set: { draft.crossFadeEnabled = $0 }
            ),
            accessibilityIdentifier: "PlaybackPresetEditor.Crossfade"
          )

          if draft.crossFadeEnabled {
            SettingsSliderRow(
              "Crossfade duration",
              value: Binding(
                get: { draft.crossFadeDuration },
                set: { draft.crossFadeDuration = $0 }
              ),
              in: 0.0...10.0,
              step: 0.25,
              sliderAccessibilityIdentifier: "PlaybackPresetEditor.CrossfadeDuration",
              valueAccessibilityIdentifier: "PlaybackPresetEditor.CrossfadeDuration.Value",
              footer: "How long episodes overlap when crossfade is enabled.",
              formatValue: { String(format: "%.2f sec", $0) }
            )
          }

          SettingsToggleRow(
            "Auto mark as played",
            isOn: Binding(
              get: { draft.autoMarkAsPlayed },
              set: { draft.autoMarkAsPlayed = $0 }
            ),
            accessibilityIdentifier: "PlaybackPresetEditor.AutoMark"
          )

          SettingsSliderRow(
            "Played threshold",
            value: Binding(
              get: { draft.playedThreshold },
              set: { draft.playedThreshold = $0 }
            ),
            in: 0.5...0.99,
            step: 0.01,
            sliderAccessibilityIdentifier: "PlaybackPresetEditor.Threshold",
            valueAccessibilityIdentifier: "PlaybackPresetEditor.Threshold.Value",
            footer: "Percentage of an episode that must play before auto-mark applies.",
            formatValue: { String(format: "%.0f%%", $0 * 100) }
          )
        }
      }
      .navigationTitle("Edit Preset")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onDismiss)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onSave(draft)
          }
          .accessibilityIdentifier("PlaybackPresetEditor.Done")
        }
      }
    }
  }
}
