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
      SettingsSliderRow(
        "Playback speed",
        value: Binding(
          get: { controller.playbackSpeed },
          set: { controller.setPlaybackSpeed($0) }
        ),
        in: 0.5...3.0,
        step: 0.1,
        sliderAccessibilityIdentifier: "Playback.SpeedSlider",
        valueAccessibilityIdentifier: "Playback.SpeedValue",
        valueFont: .headline,
        valueForegroundStyle: .primary,
        footer: "Adjust playback speed between half and triple speed.",
        formatValue: { value in String(format: "%.1fx", value) }
      )

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
        subtitle: "Trim silence without changing voice pitch.",
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
      SettingsStepperRow(
        value: Binding(
          get: { controller.skipForwardInterval },
          set: { controller.setSkipForwardInterval($0) }
        ),
        in: 5...120,
        step: 5,
        accessibilityIdentifier: "Playback.SkipForwardStepper"
      ) { value in
        LocalizedStringKey("Skip forward: \(value) sec")
      }

      SettingsStepperRow(
        value: Binding(
          get: { controller.skipBackwardInterval },
          set: { controller.setSkipBackwardInterval($0) }
        ),
        in: 5...120,
        step: 5,
        accessibilityIdentifier: "Playback.SkipBackwardStepper"
      ) { value in
        LocalizedStringKey("Skip backward: \(value) sec")
      }

      SettingsStepperRow(
        value: Binding(
          get: { controller.skipIntroSeconds },
          set: { controller.setSkipIntroSeconds($0) }
        ),
        in: 0...300,
        step: 5,
        accessibilityIdentifier: "Playback.SkipIntroStepper"
      ) { value in
        LocalizedStringKey("Skip intro: \(value) sec")
      }

      SettingsStepperRow(
        value: Binding(
          get: { controller.skipOutroSeconds },
          set: { controller.setSkipOutroSeconds($0) }
        ),
        in: 0...300,
        step: 5,
        accessibilityIdentifier: "Playback.SkipOutroStepper"
      ) { value in
        LocalizedStringKey("Skip outro: \(value) sec")
      }
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
        SettingsSliderRow(
          "Crossfade duration",
          value: Binding(
            get: { controller.crossFadeDuration },
            set: { controller.setCrossFadeDuration($0) }
          ),
          in: 0.5...10,
          step: 0.5,
          valueAccessibilityIdentifier: "Playback.CrossfadeDurationValue",
          footer: "Fade between episodes to avoid abrupt starts/stops.",
          formatValue: { value in String(format: "%.1f seconds", value) }
        )
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
        SettingsSliderRow(
          "Played threshold",
          value: Binding(
            get: { controller.playedThreshold },
            set: { controller.setPlayedThreshold($0) }
          ),
          in: 0.5...0.99,
          step: 0.01,
          valueAccessibilityIdentifier: "Playback.PlayedThresholdValue",
          footer: "Episodes will auto-mark as played once the threshold is reached.",
          formatValue: { value in String(format: "%.0f%% of episode", value * 100) }
        )
      }
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.currentSettings)
    dismiss()
  }
}
