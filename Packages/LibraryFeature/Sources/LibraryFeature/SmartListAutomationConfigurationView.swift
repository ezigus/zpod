import CoreModels
import SettingsDomain
import SwiftUI

public struct SmartListAutomationConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: SmartListAutomationConfigurationController
  private let onSave: ((SmartListRefreshConfiguration) -> Void)?

  @State private var showingResetConfirmation = false

  public init(
    controller: SmartListAutomationConfigurationController,
    onSave: ((SmartListRefreshConfiguration) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    Form {
      automationSection
      timingSection
      advancedSection
      diagnosticsSection
    }
    .navigationTitle("Smart Lists")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") { showingResetConfirmation = true }
          .disabled(!controller.hasUnsavedChanges)
          .accessibilityIdentifier("SmartListAutomation.Reset")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await commitChanges() } }
          .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          .accessibilityIdentifier("SmartListAutomation.Save")
      }
    }
    .task { await controller.loadBaseline() }
    .confirmationDialog(
      "Restore smart list automation defaults?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) { Task { await controller.resetToBaseline() } }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var automationSection: some View {
    Section("Automation") {
      SettingsToggleRow(
        "Background updates",
        subtitle: "Keep smart lists current in the background.",
        isOn: Binding(
          get: { controller.isEnabled },
          set: { controller.setEnabled($0) }
        ),
        accessibilityIdentifier: "SmartListAutomation.Enabled"
      )

      Text(controller.isEnabled ? "Automation is enabled." : "Automation is paused.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var timingSection: some View {
    Section("Timing") {
      SettingsSliderRow(
        "Refresh interval",
        value: Binding(
          get: { controller.globalInterval },
          set: { controller.setGlobalInterval($0) }
        ),
        in: 60...14400,
        step: 60,
        sliderAccessibilityIdentifier: "SmartListAutomation.Interval",
        valueAccessibilityIdentifier: "SmartListAutomation.Interval.Value",
        valueFont: .headline,
        valueForegroundStyle: .primary,
        footer: "Choose how often smart lists evaluate in the background.",
        formatValue: { value in intervalFormatter(value) }
      )
      .disabled(!controller.isEnabled)
    }
  }

  @ViewBuilder
  private var advancedSection: some View {
    Section("Advanced") {
      SettingsStepperRow(
        value: Binding(
          get: { controller.maxRefreshPerCycle },
          set: { controller.setMaxRefreshPerCycle($0) }
        ),
        in: 1...50,
        step: 1,
        accessibilityIdentifier: "SmartListAutomation.MaxPerCycle"
      ) { value in
        LocalizedStringKey("Refresh up to \(value) lists per cycle")
      }
      .disabled(!controller.isEnabled)

      SettingsToggleRow(
        "Refresh on foreground",
        subtitle: "Trigger a refresh when you return to the app.",
        isOn: Binding(
          get: { controller.refreshOnForeground },
          set: { controller.setRefreshOnForeground($0) }
        ),
        accessibilityIdentifier: "SmartListAutomation.Foreground"
      )
      .disabled(!controller.isEnabled)

      SettingsToggleRow(
        "Refresh on network change",
        subtitle: "Re-evaluate when connectivity improves.",
        isOn: Binding(
          get: { controller.refreshOnNetworkChange },
          set: { controller.setRefreshOnNetworkChange($0) }
        ),
        accessibilityIdentifier: "SmartListAutomation.Network"
      )
      .disabled(!controller.isEnabled)
    }
  }

  @ViewBuilder
  private var diagnosticsSection: some View {
    Section("Diagnostics") {
      VStack(alignment: .leading, spacing: 8) {
        Text("Background automation keeps smart lists aligned with new episodes and filters.")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text("Adjust intervals if you notice battery impact or prefer less frequent updates.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("SmartListAutomation.Diagnostics")
    }
  }

  private func intervalFormatter(_ value: Double) -> String {
    let minutes = Int(value / 60)
    if minutes < 60 {
      return "\(minutes) min"
    }
    let hours = Double(minutes) / 60.0
    return String(format: "%.1f hr", hours)
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.draft)
    dismiss()
  }
}

