import CoreModels
import SettingsDomain
import SwiftUI

public struct PlaybackConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: PlaybackConfigurationController
  private let onSave: ((PlaybackSettings) -> Void)?

  @State private var showingResetConfirmation = false

  public init(
    controller: PlaybackConfigurationController,
    onSave: ((PlaybackSettings) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    Form {
      playbackSpeedSection
      skipControlsSection
      enhancementsSection
    }
    .navigationTitle("Playback")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") {
          showingResetConfirmation = true
        }
        .disabled(!controller.hasUnsavedChanges)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          Task { await commitChanges() }
        }
        .disabled(!controller.hasUnsavedChanges || controller.isSaving)
      }
    }
    .task { await controller.loadBaseline() }
    .confirmationDialog(
      "Restore default playback settings?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) {
        Task { await controller.resetToBaseline() }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var playbackSpeedSection: some View {
    Section("Playback Speed") {
      VStack(alignment: .leading, spacing: 8) {
        Slider(
          value: Binding(
            get: { controller.playbackSpeed },
            set: { controller.setPlaybackSpeed($0) }
          ),
          in: 0.5...3.0,
          step: 0.1
        )
        .accessibilityIdentifier("Playback.SpeedSlider")

        Text(String(format: "%.1fx", controller.playbackSpeed))
          .font(.headline)
          .accessibilityIdentifier("Playback.SpeedValue")
      }

      SettingsToggleRow(
        "Continuous playback",
        isOn: Binding(
          get: { controller.continuousPlaybackEnabled },
          set: { controller.setContinuousPlayback($0) }
        ),
        accessibilityIdentifier: "Playback.ContinuousToggle"
      )

      SettingsToggleRow(
        "Smart speed",
        isOn: Binding(
          get: { controller.smartSpeedEnabled },
          set: { controller.setSmartSpeedEnabled($0) }
        ),
        accessibilityIdentifier: "Playback.SmartSpeedToggle"
      )
    }
  }

  @ViewBuilder
  private var skipControlsSection: some View {
    Section("Skip Controls") {
      Stepper(value: Binding(
        get: { controller.skipForwardInterval },
        set: { controller.setSkipForwardInterval($0) }
      ), in: 5...120, step: 5) {
        Text("Skip forward: \(controller.skipForwardInterval) sec")
      }
      .accessibilityIdentifier("Playback.SkipForwardStepper")

      Stepper(value: Binding(
        get: { controller.skipBackwardInterval },
        set: { controller.setSkipBackwardInterval($0) }
      ), in: 5...120, step: 5) {
        Text("Skip backward: \(controller.skipBackwardInterval) sec")
      }
      .accessibilityIdentifier("Playback.SkipBackwardStepper")

      Stepper(value: Binding(
        get: { controller.skipIntroSeconds },
        set: { controller.setSkipIntroSeconds($0) }
      ), in: 0...300, step: 5) {
        Text("Skip intro: \(controller.skipIntroSeconds) sec")
      }
      .accessibilityIdentifier("Playback.SkipIntroStepper")

      Stepper(value: Binding(
        get: { controller.skipOutroSeconds },
        set: { controller.setSkipOutroSeconds($0) }
      ), in: 0...300, step: 5) {
        Text("Skip outro: \(controller.skipOutroSeconds) sec")
      }
      .accessibilityIdentifier("Playback.SkipOutroStepper")
    }
  }

  @ViewBuilder
  private var enhancementsSection: some View {
    Section("Enhancements") {
      SettingsToggleRow(
        "Volume boost",
        isOn: Binding(
          get: { controller.volumeBoostEnabled },
          set: { controller.setVolumeBoostEnabled($0) }
        ),
        accessibilityIdentifier: "Playback.VolumeBoostToggle"
      )

      SettingsToggleRow(
        "Crossfade",
        isOn: Binding(
          get: { controller.crossFadeEnabled },
          set: { controller.setCrossFadeEnabled($0) }
        ),
        accessibilityIdentifier: "Playback.CrossfadeToggle"
      )

      if controller.crossFadeEnabled {
        Slider(
          value: Binding(
            get: { controller.crossFadeDuration },
            set: { controller.setCrossFadeDuration($0) }
          ),
          in: 0.5...10,
          step: 0.5
        ) {
          Text("Crossfade duration")
        }
        Text(String(format: "%.1f seconds", controller.crossFadeDuration))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("Playback.CrossfadeDurationValue")
      }

      SettingsToggleRow(
        "Auto mark as played",
        isOn: Binding(
          get: { controller.autoMarkAsPlayedEnabled },
          set: { controller.setAutoMarkAsPlayed($0) }
        ),
        accessibilityIdentifier: "Playback.AutoMarkToggle"
      )

      if controller.autoMarkAsPlayedEnabled {
        Slider(
          value: Binding(
            get: { controller.playedThreshold },
            set: { controller.setPlayedThreshold($0) }
          ),
          in: 0.5...0.99
        ) {
          Text("Played threshold")
        }
        Text(String(format: "%.0f%% of episode", controller.playedThreshold * 100))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("Playback.PlayedThresholdValue")
      }
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.currentSettings)
    dismiss()
  }
}
