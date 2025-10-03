import CoreModels
import SettingsDomain
import SharedUtilities
import SwiftUI

public struct SwipeActionConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var viewModel: SwipeActionConfigurationViewModel
  private let hapticsService: HapticFeedbackServicing
  private let onSave: (() -> Void)?

  public init(
    settingsManager: UISettingsManaging,
    hapticsService: HapticFeedbackServicing = HapticFeedbackService.shared,
    onSave: (() -> Void)? = nil
  ) {
    self.viewModel = SwipeActionConfigurationViewModel(settingsManager: settingsManager)
    self.hapticsService = hapticsService
    self.onSave = onSave
  }

  public var body: some View {
    NavigationStack {
      Form {
        leadingSection
        trailingSection
        hapticsSection
        presetsSection
      }
      .navigationTitle("Swipe Actions")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .accessibilityIdentifier("SwipeActions.Cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              await viewModel.saveChanges()
              onSave?()
              dismiss()
            }
          }
          .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
          .accessibilityIdentifier("SwipeActions.Save")
        }
      }
    }
  }

  private var leadingSection: some View {
    Section("Leading Actions") {
      actionsList(for: .leading, actions: viewModel.leadingActions)
      if viewModel.canAddMoreActions(to: .leading) {
        addActionMenu(for: .leading)
      }
      Toggle(
        "Allow Full Swipe",
        isOn: Binding(
          get: { viewModel.allowFullSwipeLeading },
          set: { viewModel.setFullSwipe($0, for: .leading) }
        )
      )
      .accessibilityIdentifier("SwipeActions.Leading.FullSwipe")
    }
  }

  private var trailingSection: some View {
    Section("Trailing Actions") {
      actionsList(for: .trailing, actions: viewModel.trailingActions)
      if viewModel.canAddMoreActions(to: .trailing) {
        addActionMenu(for: .trailing)
      }
      Toggle(
        "Allow Full Swipe",
        isOn: Binding(
          get: { viewModel.allowFullSwipeTrailing },
          set: { viewModel.setFullSwipe($0, for: .trailing) }
        )
      )
      .accessibilityIdentifier("SwipeActions.Trailing.FullSwipe")
    }
  }

  private var hapticsSection: some View {
    Section("Haptics") {
      Toggle(
        "Enable Haptic Feedback",
        isOn: Binding(
          get: { viewModel.hapticsEnabled },
          set: { newValue in
            viewModel.setHapticsEnabled(newValue)
            guard newValue else { return }
            hapticsService.selectionChanged()
          }
        )
      )
      .accessibilityIdentifier("SwipeActions.Haptics.Toggle")

      Picker(
        "Intensity",
        selection: Binding(
          get: { viewModel.hapticStyle },
          set: { newStyle in
            viewModel.setHapticStyle(newStyle)
            hapticsService.impact(HapticFeedbackIntensity(style: newStyle))
          }
        )
      ) {
        ForEach(SwipeHapticStyle.allCases, id: \.self) { style in
          Text(style.description).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("SwipeActions.Haptics.StylePicker")
      .disabled(!viewModel.hapticsEnabled)
    }
  }

  private var presetsSection: some View {
    Section("Presets") {
      Button("Restore Default") {
        viewModel.applyPreset(.default)
      }
      .accessibilityIdentifier("SwipeActions.Preset.Default")

      Button("Playback Focused") {
        viewModel.applyPreset(.playbackFocused)
      }
      .accessibilityIdentifier("SwipeActions.Preset.Playback")

      Button("Organization Focused") {
        viewModel.applyPreset(.organizationFocused)
      }
      .accessibilityIdentifier("SwipeActions.Preset.Organization")

      Button("Download Focused") {
        viewModel.applyPreset(.downloadFocused)
      }
      .accessibilityIdentifier("SwipeActions.Preset.Download")
    }
  }

  private func actionsList(
    for edge: SwipeActionConfigurationViewModel.SwipeEdge, actions: [SwipeActionType]
  ) -> some View {
    ForEach(actions, id: \.self) { action in
      HStack {
        Image(systemName: action.systemIcon)
          .foregroundStyle(Color(action.colorTint))
        Text(action.displayName)
      }
      .accessibilityIdentifier("SwipeActions." + edgeIdentifier(edge) + "." + action.displayName)
    }
    .onDelete { indexSet in
      viewModel.removeActions(at: indexSet, from: edge)
    }
  }

  private func addActionMenu(for edge: SwipeActionConfigurationViewModel.SwipeEdge) -> some View {
    Menu("Add Action") {
      ForEach(viewModel.availableActions(for: edge), id: \.self) { action in
        Button(action.displayName) {
          viewModel.addAction(action, to: edge)
        }
        .accessibilityIdentifier(
          "SwipeActions.Add." + edgeIdentifier(edge) + "." + action.displayName)
      }
    }
    .accessibilityIdentifier("SwipeActions.Add." + edgeIdentifier(edge))
  }

  private func edgeIdentifier(_ edge: SwipeActionConfigurationViewModel.SwipeEdge) -> String {
    switch edge {
    case .leading:
      return "Leading"
    case .trailing:
      return "Trailing"
    }
  }
}

extension Color {
  fileprivate init(_ tint: SwipeActionColor) {
    switch tint {
    case .blue:
      self = .blue
    case .green:
      self = .green
    case .yellow:
      self = .yellow
    case .orange:
      self = .orange
    case .purple:
      self = .purple
    case .red:
      self = .red
    case .gray:
      self = .gray
    }
  }
}
