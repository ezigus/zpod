import CoreModels
import SettingsDomain
import SwiftUI

public struct DownloadConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: DownloadConfigurationController
  private let onSave: ((DownloadSettings) -> Void)?

  public init(
    controller: DownloadConfigurationController,
    onSave: ((DownloadSettings) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    Form {
      automaticDownloadSection
      limitsSection
      retentionSection
    }
    .navigationTitle("Downloads")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") {
          Task { await controller.resetToBaseline() }
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
  }

  private var automaticDownloadSection: some View {
    Section("Automatic Downloads") {
      SettingsToggleRow(
        "Enable downloads for new episodes",
        isOn: Binding(
          get: { controller.autoDownloadEnabled },
          set: { controller.setAutoDownloadEnabled($0) }
        ),
        accessibilityIdentifier: "Download.AutoToggle"
      )

      SettingsToggleRow(
        "Require Wi-Fi",
        isOn: Binding(
          get: { controller.wifiOnlyEnabled },
          set: { controller.setWifiOnlyEnabled($0) }
        ),
        accessibilityIdentifier: "Download.WifiOnlyToggle"
      )
    }
  }

  private var limitsSection: some View {
    Section("Limits") {
      SettingsStepperRow(
        value: Binding(
          get: { controller.maxConcurrentDownloads },
          set: { controller.setMaxConcurrentDownloads($0) }
        ),
        in: ValidationConstants.minConcurrentDownloads...ValidationConstants.maxConcurrentDownloads,
        accessibilityIdentifier: "Download.ConcurrentStepper",
        footer: "Higher values allow more simultaneous downloads but may impact bandwidth."
      ) { value in
        LocalizedStringKey("Concurrent downloads: \(value)")
      }

      SettingsPickerRow(
        "Refresh frequency",
        selection: Binding(
          get: { controller.updateFrequency },
          set: { controller.setUpdateFrequency($0) }
        ),
        options: UpdateFrequency.allCases,
        accessibilityIdentifier: "Download.UpdateFrequencyPicker",
        footer: "Controls how often new episodes are discovered."
      ) { frequency in
        Text(frequency.displayName).tag(frequency)
      }
    }
  }

  private var retentionSection: some View {
    Section("Retention") {
      SettingsPickerRow(
        "Keep episodes",
        selection: Binding(
          get: { controller.retentionPolicy },
          set: { controller.setRetentionPolicy($0) }
        ),
        options: RetentionPolicyOption
          .options(including: controller.retentionPolicy)
          .map(\.policy),
        accessibilityIdentifier: "Download.RetentionPicker",
        footer: "Determines when completed episodes are removed."
      ) { policy in
        Text(RetentionPolicyOption.label(for: policy)).tag(policy)
      }
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.currentSettings)
    dismiss()
  }
}

private struct RetentionPolicyOption: Hashable {
  let policy: RetentionPolicy
  let label: String

  static func options(including policy: RetentionPolicy) -> [RetentionPolicyOption] {
    var options: [RetentionPolicyOption] = [
      RetentionPolicyOption(policy: .keepAll, label: "Keep all episodes"),
      RetentionPolicyOption(policy: .keepLatest(5), label: "Keep latest 5 episodes"),
      RetentionPolicyOption(policy: .keepLatest(10), label: "Keep latest 10 episodes"),
      RetentionPolicyOption(policy: .deleteAfterDays(7), label: "Delete after 7 days"),
      RetentionPolicyOption(policy: .deleteAfterDays(30), label: "Delete after 30 days"),
      RetentionPolicyOption(policy: .deleteAfterPlayed, label: "Delete once played")
    ]

    if !options.contains(where: { $0.policy == policy }) {
      options.append(RetentionPolicyOption(policy: policy, label: label(for: policy)))
    }

    return options
  }

  static func label(for policy: RetentionPolicy) -> String {
    switch policy {
    case .keepAll:
      return "Keep all episodes"
    case .keepLatest(let count):
      return "Keep latest \(count) episodes"
    case .deleteAfterDays(let days):
      return "Delete after \(days) days"
    case .deleteAfterPlayed:
      return "Delete once played"
    }
  }
}

private extension UpdateFrequency {
  var displayName: String {
    switch self {
    case .fifteenMinutes: return "Every 15 minutes"
    case .thirtyMinutes: return "Every 30 minutes"
    case .hourly: return "Hourly"
    case .every3Hours: return "Every 3 hours"
    case .every6Hours: return "Every 6 hours"
    case .every12Hours: return "Every 12 hours"
    case .daily: return "Daily"
    case .every3Days: return "Every 3 days"
    case .weekly: return "Weekly"
    case .manual: return "Manual"
    }
  }
}

extension RetentionPolicy: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .keepAll:
      hasher.combine("keepAll")
    case .keepLatest(let count):
      hasher.combine("keepLatest")
      hasher.combine(count)
    case .deleteAfterDays(let days):
      hasher.combine("deleteAfterDays")
      hasher.combine(days)
    case .deleteAfterPlayed:
      hasher.combine("deleteAfterPlayed")
    }
  }
}
