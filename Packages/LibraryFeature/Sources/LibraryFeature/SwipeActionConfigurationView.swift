#if os(iOS)
  import CoreModels
  import Foundation
  import OSLog
  import SettingsDomain
  import SharedUtilities
  import UIKit
  import SwiftUI

  public struct SwipeActionConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var controller: SwipeConfigurationController
    private let hapticsService: HapticFeedbackServicing
    private let onSave: ((SwipeConfiguration) -> Void)?
    private let debugEnabled = ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1"
    private let shouldAutoScrollPresets =
      ProcessInfo.processInfo.environment["UITEST_AUTO_SCROLL_PRESETS"] == "1"
    private static let logger = Logger(
      subsystem: "us.zig.zpod", category: "SwipeActionConfigurationView")
    private let shouldForceMaterialization =
      ProcessInfo.processInfo.environment["UITEST_SWIPE_PRELOAD_SECTIONS"] == "1"
    @State private var leadingFullSwipe: Bool
    @State private var trailingFullSwipe: Bool
    @State private var hapticsEnabledState: Bool
    @State private var hapticStyleState: SwipeHapticStyle
    @State private var baselineLoaded = false
    @State private var pendingAddEdge: SwipeConfigurationController.SwipeEdge?
    @State private var didMaterializeSections = false

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
        ScrollViewReader { proxy in
          listContent
            .onChange(of: baselineLoaded) { loaded in
              materializeSectionsIfNeeded(proxy: proxy, loaded: loaded)
            }
            .task {
              await controller.loadBaseline()
              baselineLoaded = true
              materializeSectionsIfNeeded(proxy: proxy, loaded: true)
            }
        }
        #if DEBUG
          .overlay(alignment: .topLeading) {
            if debugEnabled {
              debugStateProbe
              .allowsHitTesting(false)
            }
          }
        #endif
        .sheet(
          isPresented: Binding(
            get: { pendingAddEdge != nil },
            set: { if !$0 { pendingAddEdge = nil } }
          )
        ) {
          if let edge = pendingAddEdge {
            AddActionPicker(
              edge: edge,
              edgeIdentifier: edgeIdentifier(edge),
              actions: controller.availableActions(for: edge)
            ) { action in
              controller.addAction(action, edge: edge)
              pendingAddEdge = nil
            }
          }
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
            Button {
              dismiss()
            } label: {
              Text("Cancel")
                .accessibilityIdentifier("SwipeActions.Cancel")
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button {
              Task {
                do {
                  try await controller.commitChanges()
                  onSave?(controller.currentConfiguration)
                  dismiss()
                } catch {
                  // TODO: surface error state when service throws
                }
              }
            } label: {
              Text("Save")
                .accessibilityIdentifier("SwipeActions.Save")
            }
            .disabled(!controller.hasUnsavedChanges || controller.isSaving)
          }
        }
      }
    }

    private var listContent: some View {
      List {
        if baselineLoaded && shouldAutoScrollPresets {
          presetsSection.id("swipe-presets-top")
        }

        leadingSection.id("swipe-leading")
        trailingSection.id("swipe-trailing")
        hapticsSection.id("swipe-haptics")

        if baselineLoaded && !shouldAutoScrollPresets {
          presetsSection.id("swipe-presets-bottom")
        }
      }
      .platformInsetGroupedListStyle()
    }

    private var leadingSection: some View {
      Section(header: Text(String(localized: "Leading Actions", bundle: .main))) {
        ForEach(controller.leadingActions, id: \.self) { action in
          actionRow(for: action, edge: .leading)
        }

        if controller.canAddMoreActions(to: .leading) {
          addActionTrigger(for: .leading)
        }

        SettingsToggleRow(
          "Allow Full Swipe",
          isOn: $leadingFullSwipe,
          accessibilityIdentifier: "SwipeActions.Leading.FullSwipe"
        ) { newValue in
          controller.setFullSwipe(newValue, edge: .leading)
          debugLog("UI toggled leading full swipe -> \(newValue)")
        }
      }
    }

    private var trailingSection: some View {
      Section(header: Text(String(localized: "Trailing Actions", bundle: .main))) {
        ForEach(controller.trailingActions, id: \.self) { action in
          actionRow(for: action, edge: .trailing)
        }

        if controller.canAddMoreActions(to: .trailing) {
          addActionTrigger(for: .trailing)
        }

        SettingsToggleRow(
          "Allow Full Swipe",
          isOn: $trailingFullSwipe,
          accessibilityIdentifier: "SwipeActions.Trailing.FullSwipe"
        ) { newValue in
          controller.setFullSwipe(newValue, edge: .trailing)
          debugLog("UI toggled trailing full swipe -> \(newValue)")
        }

      }
    }

    private var hapticsSection: some View {
      Section(header: Text(String(localized: "Haptics", bundle: .main))) {
        SettingsToggleRow(
          "Enable Haptic Feedback",
          isOn: $hapticsEnabledState,
          accessibilityIdentifier: "SwipeActions.Haptics.Toggle"
        ) { newValue in
          controller.setHapticsEnabled(newValue)
          guard newValue else { return }
          hapticsService.selectionChanged()
        }

        SettingsSegmentedPickerRow(
          "Intensity",
          selection: $hapticStyleState,
          options: SwipeHapticStyle.allCases,
          accessibilityIdentifier: "SwipeActions.Haptics.StylePicker"
        ) { style in
          Text(style.description).tag(style)
        }
        .disabled(!hapticsEnabledState)
        .onChange(of: hapticStyleState) { newStyle in
          controller.setHapticStyle(newStyle)
          hapticsService.impact(HapticFeedbackIntensity(style: newStyle))
        }
      }
    }

    private var presetsSection: some View {
      Section(header: Text(String(localized: "Presets", bundle: .main))) {
        presetRow(
          title: String(localized: "Restore Default", bundle: .main),
          identifier: "SwipeActions.Preset.Default",
          preset: .default
        )
        .id("SwipeActions.Preset.Default")

        presetRow(
          title: String(localized: "Playback Focused", bundle: .main),
          identifier: "SwipeActions.Preset.Playback",
          preset: .playbackFocused
        )
        .id("SwipeActions.Preset.Playback")

        presetRow(
          title: String(localized: "Organization Focused", bundle: .main),
          identifier: "SwipeActions.Preset.Organization",
          preset: .organizationFocused
        )
        .id("SwipeActions.Preset.Organization")

        presetRow(
          title: String(localized: "Download Focused", bundle: .main),
          identifier: "SwipeActions.Preset.Download",
          preset: .downloadFocused
        )
        .id("SwipeActions.Preset.Download")

      }
    }

    private func addActionTrigger(for edge: SwipeConfigurationController.SwipeEdge) -> some View {
      Button {
        pendingAddEdge = edge
      } label: {
        HStack {
          Text(String(localized: "Add Action", bundle: .main))
          Spacer()
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.secondary)
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

    private func materializeSectionsIfNeeded(
      proxy: ScrollViewProxy,
      loaded: Bool
    ) {
      guard loaded, shouldForceMaterialization, !didMaterializeSections else { return }
      didMaterializeSections = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        proxy.scrollTo("swipe-trailing", anchor: .bottom)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          proxy.scrollTo("swipe-haptics", anchor: .bottom)
          // Don't scroll back to top - keep sections visible for tests
          // SwiftUI's lazy List will de-materialize off-screen content
        }
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
      SettingsPresetButton(
        LocalizedStringKey(title),
        isActive: isPresetActive(preset),
        accessibilityIdentifier: identifier
      ) {
        debugLog("UI tapped preset \(identifier)")
        if debugEnabled,
          let suiteName = ProcessInfo.processInfo.environment["UITEST_USER_DEFAULTS_SUITE"],
          let debugDefaults = UserDefaults(suiteName: suiteName)
        {
          debugDefaults.set(identifier, forKey: "SwipeActions.Debug.LastPreset")
        }
        controller.applyPreset(preset)
      }
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
        return
          "Leading=\(leading);Trailing=\(trailing);Full=\(fullLeading)/\(fullTrailing);Haptics=\(haptics);Unsaved=\(unsaved);Baseline=\(baseline)"
      }
    #endif

    private func debugLog(_ message: String) {
      guard debugEnabled else { return }
      Self.logger.debug("[SwipeConfigDebug] \(message, privacy: .public)")
    }
  }

#else
  import CoreModels
  import Foundation
  import OSLog
  import SettingsDomain
  import SharedUtilities
  import SwiftUI

  public struct SwipeActionConfigurationView: View {
    public init(
      controller: SwipeConfigurationController,
      hapticsService: HapticFeedbackServicing = HapticFeedbackService.shared,
      onSave: ((SwipeConfiguration) -> Void)? = nil
    ) {}

    public var body: some View {
      Text("Swipe configuration is available on iOS only.")
    }
  }
#endif

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

private struct AddActionPicker: View {
  @Environment(\.dismiss) private var dismiss
  let edge: SwipeConfigurationController.SwipeEdge
  let edgeIdentifier: String
  let actions: [SwipeActionType]
  let onSelect: (SwipeActionType) -> Void

  var body: some View {
    NavigationStack {
      List(actions, id: \.self) { action in
        Button {
          onSelect(action)
          dismiss()
        } label: {
          HStack {
            Text(action.displayName)
              .foregroundStyle(Color.primary)
            Spacer()
          }
        }
        .accessibilityIdentifier(
          "SwipeActions.Add." + edgeIdentifier + "." + action.displayName
        )
      }
      .platformInsetGroupedListStyle()
      .navigationTitle(title)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var title: String {
    switch edge {
    case .leading:
      return String(localized: "Add Leading Action", bundle: .main)
    case .trailing:
      return String(localized: "Add Trailing Action", bundle: .main)
    }
  }
}
