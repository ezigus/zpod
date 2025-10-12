import CoreModels
import SettingsDomain
import SwiftUI

public struct NotificationsConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: NotificationsConfigurationController
  private let onSave: ((NotificationSettings) -> Void)?

  @State private var showingResetConfirmation = false

  public init(
    controller: NotificationsConfigurationController,
    onSave: ((NotificationSettings) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    Form {
      alertsSection
      deliverySection
      quietHoursSection
    }
    .navigationTitle("Notifications")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") { showingResetConfirmation = true }
          .disabled(!controller.hasUnsavedChanges)
          .accessibilityIdentifier("Notifications.Reset")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await commitChanges() } }
          .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          .accessibilityIdentifier("Notifications.Save")
      }
    }
    .task { await controller.loadBaseline() }
    .confirmationDialog(
      "Restore default notification settings?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) { Task { await controller.resetToBaseline() } }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var alertsSection: some View {
    Section("Alerts") {
      SettingsToggleRow(
        "New episodes",
        subtitle: "Receive alerts when subscriptions publish new content.",
        isOn: Binding(
          get: { controller.newEpisodeNotificationsEnabled },
          set: { controller.setNewEpisodeNotificationsEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.NewEpisodes"
      )

      SettingsToggleRow(
        "Downloads",
        subtitle: "Notify me when queued downloads finish.",
        isOn: Binding(
          get: { controller.downloadCompleteNotificationsEnabled },
          set: { controller.setDownloadCompleteNotificationsEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.Downloads"
      )

      SettingsToggleRow(
        "Playback reminders",
        subtitle: "Remind me about unfinished episodes and recommendations.",
        isOn: Binding(
          get: { controller.playbackNotificationsEnabled },
          set: { controller.setPlaybackNotificationsEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.Playback"
      )
    }
  }

  @ViewBuilder
  private var deliverySection: some View {
    Section("Delivery") {
      SettingsSegmentedPickerRow(
        "Schedule",
        selection: Binding(
          get: { controller.deliverySchedule },
          set: { controller.setDeliverySchedule($0) }
        ),
        options: NotificationDeliverySchedule.allCases,
        accessibilityIdentifier: "Notifications.Schedule",
        footer: "Choose how we batch alerts across the day."
      ) { option in
        Text(option.localizedDescription)
      }

      SettingsToggleRow(
        "Focus mode awareness",
        subtitle: "Pause non-critical alerts when system Focus modes are active.",
        isOn: Binding(
          get: { controller.focusModeIntegrationEnabled },
          set: { controller.setFocusModeIntegrationEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.FocusMode"
      )

      SettingsToggleRow(
        "Live Activities",
        subtitle: "Show now playing details in Live Activities and Dynamic Island.",
        isOn: Binding(
          get: { controller.liveActivitiesEnabled },
          set: { controller.setLiveActivitiesEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.LiveActivities"
      )

      SettingsToggleRow(
        "Sounds",
        subtitle: "Play notification sounds for priority alerts.",
        isOn: Binding(
          get: { controller.soundEnabled },
          set: { controller.setSoundEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.Sounds"
      )
    }
  }

  @ViewBuilder
  private var quietHoursSection: some View {
    Section("Quiet Hours") {
      SettingsToggleRow(
        "Enable quiet hours",
        subtitle: "Silence notifications overnight or during downtime.",
        isOn: Binding(
          get: { controller.quietHoursEnabled },
          set: { controller.setQuietHoursEnabled($0) }
        ),
        accessibilityIdentifier: "Notifications.QuietHours"
      )

      if controller.quietHoursEnabled {
        DatePicker(
          "Start",
          selection: Binding(
            get: { controller.quietHoursStart },
            set: { controller.setQuietHoursStart($0) }
          ),
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .accessibilityIdentifier("Notifications.QuietHours.Start")

        DatePicker(
          "End",
          selection: Binding(
            get: { controller.quietHoursEnd },
            set: { controller.setQuietHoursEnd($0) }
          ),
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .accessibilityIdentifier("Notifications.QuietHours.End")

        Text("Quiet hours suppress notifications until the end time, except for priority alerts.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.draft)
    dismiss()
  }
}

