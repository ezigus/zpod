import CoreModels
import SettingsDomain
import SharedUtilities
import SwiftUI
import OSLog

public struct SwipeActionConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var controller: SwipeConfigurationController
  private let hapticsService: HapticFeedbackServicing
  private let onSave: ((SwipeConfiguration) -> Void)?
  private let debugEnabled = ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1"
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "SwipeActionConfigurationView")
  @State private var leadingFullSwipe: Bool
  @State private var trailingFullSwipe: Bool
  @State private var hapticsEnabledState: Bool
  @State private var hapticStyleState: SwipeHapticStyle
  @State private var baselineLoaded = false

  public init(
    controller: SwipeConfigurationController,
    hapticsService: HapticFeedbackServicing = HapticFeedbackService.shared,
    onSave: ((SwipeConfiguration) -> Void)? = nil
  ) {
    self._controller = ObservedObject(initialValue: controller)
    self.hapticsService = hapticsService
    self.onSave = onSave
    self._leadingFullSwipe = State(initialValue: controller.allowFullSwipeLeading)
    self._trailingFullSwipe = State(initialValue: controller.allowFullSwipeTrailing)
    self._hapticsEnabledState = State(initialValue: controller.hapticsEnabled)
    self._hapticStyleState = State(initialValue: controller.hapticStyle)
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 24) {
          leadingSection
          trailingSection
          hapticsSection
          presetsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
      .task {
        await controller.loadBaseline()
        baselineLoaded = true
      }
      .onReceive(controller.$draft) { draft in
        leadingFullSwipe = draft.swipeActions.allowFullSwipeLeading
        trailingFullSwipe = draft.swipeActions.allowFullSwipeTrailing
        hapticsEnabledState = draft.swipeActions.hapticFeedbackEnabled
        hapticStyleState = draft.hapticStyle
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
              do {
                try await controller.commitChanges()
                onSave?(controller.currentConfiguration)
                dismiss()
              } catch {
                // TODO: surface error state when service throws
              }
            }
          }
          .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          .accessibilityIdentifier("SwipeActions.Save")
        }
      }
    }
  }

  private var leadingSection: some View {
    configurationSection(title: String(localized: "Leading Actions", bundle: .main)) {
      ForEach(controller.leadingActions, id: \.self) { action in
        actionRow(for: action, edge: .leading)
      }

      if controller.canAddMoreActions(to: .leading) {
        addActionMenu(for: .leading)
      }

      Toggle(
        "Allow Full Swipe",
        isOn: $leadingFullSwipe
      )
      .toggleStyle(.switch)
      .accessibilityIdentifier("SwipeActions.Leading.FullSwipe")
      .onChange(of: leadingFullSwipe) { newValue in
        controller.setFullSwipe(newValue, edge: .leading)
        debugLog("UI toggled leading full swipe -> \(newValue)")
      }
    }
  }

  private var trailingSection: some View {
    configurationSection(title: String(localized: "Trailing Actions", bundle: .main)) {
      ForEach(controller.trailingActions, id: \.self) { action in
        actionRow(for: action, edge: .trailing)
      }

      if controller.canAddMoreActions(to: .trailing) {
        addActionMenu(for: .trailing)
      }

      Toggle(
        "Allow Full Swipe",
        isOn: $trailingFullSwipe
      )
      .toggleStyle(.switch)
      .accessibilityIdentifier("SwipeActions.Trailing.FullSwipe")
      .onChange(of: trailingFullSwipe) { newValue in
        controller.setFullSwipe(newValue, edge: .trailing)
        debugLog("UI toggled trailing full swipe -> \(newValue)")
      }

    }
  }

  private var hapticsSection: some View {
    configurationSection(title: String(localized: "Haptics", bundle: .main)) {
      Toggle(
        "Enable Haptic Feedback",
        isOn: $hapticsEnabledState
      )
      .toggleStyle(.switch)
      .accessibilityIdentifier("SwipeActions.Haptics.Toggle")
      .onChange(of: hapticsEnabledState) { newValue in
        controller.setHapticsEnabled(newValue)
        guard newValue else { return }
        hapticsService.selectionChanged()
      }

      Picker(
        "Intensity",
        selection: $hapticStyleState
      ) {
        ForEach(SwipeHapticStyle.allCases, id: \.self) { style in
          Text(style.description).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("SwipeActions.Haptics.StylePicker")
      .disabled(!hapticsEnabledState)
      .onChange(of: hapticStyleState) { newStyle in
        controller.setHapticStyle(newStyle)
        hapticsService.impact(HapticFeedbackIntensity(style: newStyle))
      }
    }
  }

  private var presetsSection: some View {
    configurationSection(title: String(localized: "Presets", bundle: .main)) {
      presetRow(
        title: String(localized: "Restore Default", bundle: .main),
        identifier: "SwipeActions.Preset.Default",
        preset: .default
      )

      presetRow(
        title: String(localized: "Playback Focused", bundle: .main),
        identifier: "SwipeActions.Preset.Playback",
        preset: .playbackFocused
      )

      presetRow(
        title: String(localized: "Organization Focused", bundle: .main),
        identifier: "SwipeActions.Preset.Organization",
        preset: .organizationFocused
      )

      presetRow(
        title: String(localized: "Download Focused", bundle: .main),
        identifier: "SwipeActions.Preset.Download",
        preset: .downloadFocused
      )

      #if DEBUG
        debugStateProbe
      #endif
    }
  }

  private func addActionMenu(for edge: SwipeConfigurationController.SwipeEdge) -> some View {
    Menu("Add Action") {
      ForEach(controller.availableActions(for: edge), id: \.self) { action in
        Button(action.displayName) {
          controller.addAction(action, edge: edge)
        }
        .accessibilityIdentifier(
          "SwipeActions.Add." + edgeIdentifier(edge) + "." + action.displayName)
      }
    }
    .accessibilityIdentifier("SwipeActions.Add." + edgeIdentifier(edge))
  }

  private func edgeIdentifier(_ edge: SwipeConfigurationController.SwipeEdge) -> String {
    switch edge {
    case .leading:
      return "Leading"
    case .trailing:
      return "Trailing"
    }
  }

  @ViewBuilder
  private func configurationSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(LocalizedStringKey(title))
        .font(.headline)
        .foregroundStyle(Color.primary)

      VStack(alignment: .leading, spacing: 8) {
        content()
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color(uiColor: .secondarySystemGroupedBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
      )
    }
  }

  @ViewBuilder
  private func actionRow(
    for action: SwipeActionType,
    edge: SwipeConfigurationController.SwipeEdge
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: action.systemIcon)
        .foregroundStyle(Color(action.colorTint))
        .font(.system(size: 18, weight: .semibold))

      Text(action.displayName)
        .font(.body)
        .foregroundStyle(Color.primary)

      Spacer()

      Button {
        controller.removeAction(action, edge: edge)
      } label: {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(Color.red)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Remove \(action.displayName)")
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .accessibilityIdentifier(
      "SwipeActions." + edgeIdentifier(edge) + "." + action.displayName
    )
  }

  private func presetRow(
    title: String,
    identifier: String,
    preset: SwipeActionSettings
  ) -> some View {
    Button {
      debugLog("UI tapped preset \(identifier)")
      controller.applyPreset(preset)
    } label: {
      HStack {
        Text(title)
          .foregroundStyle(Color.primary)
        Spacer()
        if isPresetActive(preset) {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .accessibilityIdentifier(identifier)
  }

  private func isPresetActive(_ preset: SwipeActionSettings) -> Bool {
    controller.leadingActions == preset.leadingActions
      && controller.trailingActions == preset.trailingActions
      && controller.allowFullSwipeLeading == preset.allowFullSwipeLeading
      && controller.allowFullSwipeTrailing == preset.allowFullSwipeTrailing
      && controller.hapticsEnabled == preset.hapticFeedbackEnabled
  }

  #if DEBUG
    private var debugStateProbe: some View {
      Text(debugStateSummary)
        .font(.caption2)
        .opacity(0.001)
        .accessibilityHidden(false)
        .accessibilityIdentifier("SwipeActions.Debug.StateSummary")
        .accessibilityLabel("SwipeActions.Debug.StateSummary")
        .accessibilityValue(debugStateSummary)
    }

    private var debugStateSummary: String {
      let leading = controller.leadingActions.map(\.rawValue).joined(separator: ",")
      let trailing = controller.trailingActions.map(\.rawValue).joined(separator: ",")
      let fullLeading = controller.allowFullSwipeLeading ? "1" : "0"
      let fullTrailing = controller.allowFullSwipeTrailing ? "1" : "0"
      let haptics = controller.hapticsEnabled ? "1" : "0"
      let unsaved = controller.hasUnsavedChanges ? "1" : "0"
      let baseline = baselineLoaded ? "1" : "0"
      return "Leading=\(leading);Trailing=\(trailing);Full=\(fullLeading)/\(fullTrailing);Haptics=\(haptics);Unsaved=\(unsaved);Baseline=\(baseline)"
    }
  #endif

  private func debugLog(_ message: String) {
    guard debugEnabled else { return }
    Self.logger.debug("[SwipeConfigDebug] \(message, privacy: .public)")
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
