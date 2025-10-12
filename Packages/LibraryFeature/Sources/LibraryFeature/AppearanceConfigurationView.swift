import CoreModels
import SettingsDomain
import SwiftUI

public struct AppearanceConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: AppearanceConfigurationController
  private let onSave: ((AppearanceSettings) -> Void)?

  @State private var showingResetConfirmation = false

  public init(
    controller: AppearanceConfigurationController,
    onSave: ((AppearanceSettings) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.onSave = onSave
  }

  public var body: some View {
    Form {
      previewSection
      themeSection
      tintSection
      accessibilitySection
    }
    .navigationTitle("Appearance")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Reset") { showingResetConfirmation = true }
          .disabled(!controller.hasUnsavedChanges)
          .accessibilityIdentifier("Appearance.Reset")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { Task { await commitChanges() } }
          .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          .accessibilityIdentifier("Appearance.Save")
      }
    }
    .task { await controller.loadBaseline() }
    .confirmationDialog(
      "Restore default appearance settings?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) { Task { await controller.resetToBaseline() } }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var previewSection: some View {
    Section("Preview") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Now Playing")
          .font(.headline)
          .foregroundStyle(.secondary)
        Text("Swift on the Server – Async Await in Practice")
          .font(.system(size: 17 * controller.typographyScale, weight: controller.highContrastEnabled ? .semibold : .regular))
          .foregroundStyle(previewColor)
          .lineLimit(2)
      }
      .padding(.vertical, 4)
      .accessibilityIdentifier("Appearance.Preview")
    }
  }

  private var previewColor: Color {
    tintColor(for: controller.preferredTint)
  }

  @ViewBuilder
  private var themeSection: some View {
    Section("Theme") {
      SettingsSegmentedPickerRow(
        "Display",
        selection: Binding(
          get: { controller.theme },
          set: { controller.setTheme($0) }
        ),
        options: AppearanceTheme.allCases,
        accessibilityIdentifier: "Appearance.Theme"
      ) { theme in
        Text(theme.displayName)
      }

      SettingsSliderRow(
        "Text size",
        value: Binding(
          get: { controller.typographyScale },
          set: { controller.setTypographyScale($0) }
        ),
        in: 0.8...1.5,
        step: 0.05,
        sliderAccessibilityIdentifier: "Appearance.Typography",
        valueAccessibilityIdentifier: "Appearance.Typography.Value",
        valueFont: .headline,
        valueForegroundStyle: .primary,
        footer: "Adjust overall typography scale across the app.",
        formatValue: { value in String(format: "%.2fx", value) }
      )
    }
  }

  @ViewBuilder
  private var tintSection: some View {
    Section("Tint") {
      let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(AppearanceTint.allCases, id: \.self) { tint in
          SettingsPresetButton(
            verbatim: tint.displayName,
            isActive: controller.preferredTint == tint,
            accessibilityIdentifier: "Appearance.Tint.\(tint.rawValue)"
          ) {
            controller.setPreferredTint(tint)
          }
          .overlay(
            Circle()
              .fill(tintColor(for: tint))
              .frame(width: 16, height: 16)
              .padding(.trailing, 12),
            alignment: .trailing
          )
        }
      }
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder
  private var accessibilitySection: some View {
    Section("Accessibility") {
      SettingsToggleRow(
        "Reduce motion",
        subtitle: "Limit large animations while navigating the app.",
        isOn: Binding(
          get: { controller.reduceMotionEnabled },
          set: { controller.setReduceMotionEnabled($0) }
        ),
        accessibilityIdentifier: "Appearance.ReduceMotion"
      )

      SettingsToggleRow(
        "Reduce haptics",
        subtitle: "Disable non-essential vibrations.",
        isOn: Binding(
          get: { controller.reduceHapticsEnabled },
          set: { controller.setReduceHapticsEnabled($0) }
        ),
        accessibilityIdentifier: "Appearance.ReduceHaptics"
      )

      SettingsToggleRow(
        "High contrast",
        subtitle: "Boost contrast for improved text legibility.",
        isOn: Binding(
          get: { controller.highContrastEnabled },
          set: { controller.setHighContrastEnabled($0) }
        ),
        accessibilityIdentifier: "Appearance.HighContrast"
      )
    }
  }

  private func tintColor(for tint: AppearanceTint) -> Color {
    switch tint {
    case .accent: return .accentColor
    case .blue: return .blue
    case .orange: return .orange
    case .purple: return .purple
    case .green: return .green
    case .pink: return .pink
    }
  }

  private func commitChanges() async {
    await controller.commitChanges()
    onSave?(controller.draft)
    dismiss()
  }
}
