#if os(iOS) || os(macOS)
  import CoreModels
  import Foundation
  import OSLog
  import SettingsDomain
  import SharedUtilities
  import SwiftUI

  public struct SwipeActionConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var controller: SwipeConfigurationController
    private let hapticsService: HapticFeedbackServicing
    private let onSave: ((SwipeConfiguration) -> Void)?
    private let debugEnabled = ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1"
    private let shouldAutoScrollPresets =
      ProcessInfo.processInfo.environment["UITEST_AUTO_SCROLL_PRESETS"] == "1"
    private let shouldForceMaterialization =
      ProcessInfo.processInfo.environment["UITEST_SWIPE_PRELOAD_SECTIONS"] == "1"
    private static let logger = Logger(
      subsystem: "us.zig.zpod", category: "SwipeActionConfigurationView")
    @State private var hapticsToggleProbe: UUID = .init()
    @State private var baselineLoaded = false
    @State private var pendingAddEdge: SwipeConfigurationController.SwipeEdge?
    @State private var materializationTriggered = false
    @State private var materializationComplete = false

    public init(
      controller: SwipeConfigurationController,
      hapticsService: HapticFeedbackServicing = HapticFeedbackService.shared,
      onSave: ((SwipeConfiguration) -> Void)? = nil
    ) {
      self._controller = ObservedObject(initialValue: controller)
      self.hapticsService = hapticsService
      self.onSave = onSave
    }

    public var body: some View {
      NavigationStack {
        ScrollViewReader { proxy in
          List {
            Color.clear
              .frame(height: 0)
              .accessibilityHidden(true)
              .id("swipe-top")

            // WORKAROUND: haptics section MUST come before leadingSection/trailingSection
            // Placing it after trailingSection causes SwiftUI to skip rendering completely
            hapticsSection
              .id("swipe-haptics")

            leadingSection
              .id("swipe-leading")
            trailingSection
              .id("swipe-trailing")

            // Presets moved to bottom so both action toggles are visible without scrolling
            presetsSection
            Color.clear
              .frame(height: 0)
              .accessibilityHidden(true)
              .id("swipe-presets-bottom")

          }
          .accessibilityIdentifier("SwipeActions.List")
          .platformInsetGroupedListStyle()
          #if DEBUG
            .overlay(alignment: .topLeading) {
              if debugEnabled {
                debugStateProbe
                .allowsHitTesting(false)
              }
            }
            .overlay(alignment: .topTrailing) {
              if debugEnabled {
                materializationProbe
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
          .task {
            await controller.loadBaseline()
            baselineLoaded = true
          }
          .onChange(of: baselineLoaded) { loaded in
            guard loaded else { return }

            // UITEST DEBUG HOOK: Direct scroll to target identifier
            // Replaces multi-pass scroll sweeps with deterministic jump
            #if DEBUG
            if let targetID = ProcessInfo.processInfo.environment["UITEST_SWIPE_SCROLL_TO"] {
              Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms for list layout
                withAnimation {
                  proxy.scrollTo(targetID, anchor: .center)
                }
              }
            }
            #endif

            // Standard materialization for non-debug test runs
            guard shouldForceMaterialization, !materializationTriggered else { return }
            materializationTriggered = true
            materializationComplete = false
            Task { @MainActor in
              // Give the list a brief moment to lay out before forcing scrolls
              try? await Task.sleep(nanoseconds: 150_000_000)
              await materializeSections(proxy: proxy)
            }
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
    }

    @MainActor
    private func materializeSections(proxy: ScrollViewProxy) async {
      let transaction = Transaction(animation: .default)
      withTransaction(transaction) {
        proxy.scrollTo("swipe-trailing", anchor: .top)
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
      withTransaction(transaction) {
        proxy.scrollTo("swipe-presets-bottom", anchor: .bottom)
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
      withTransaction(transaction) {
        proxy.scrollTo("swipe-haptics", anchor: .top)
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
      withTransaction(transaction) {
        proxy.scrollTo("swipe-top", anchor: .top)
      }
      materializationComplete = true
    }

    private var leadingSection: some View {
      print("[SwipeConfigView] ⚠️ leadingSection computed property accessed")
      return Section(header: Text(String(localized: "Leading Actions", bundle: .main))) {
        ForEach(controller.leadingActions, id: \.self) { action in
          actionRow(for: action, edge: .leading)
        }

        SettingsToggleRow(
          "Allow Full Swipe",
          isOn: Binding(
            get: { controller.allowFullSwipeLeading },
            set: { controller.setFullSwipe($0, edge: .leading) }
          ),
          accessibilityIdentifier: "SwipeActions.Leading.FullSwipe"
        ) { newValue in
          debugLog("UI toggled leading full swipe -> \(newValue)")
        }

        if controller.canAddMoreActions(to: .leading) {
          addActionTrigger(for: .leading)
        }
      }
    }

    private var trailingSection: some View {
      print("[SwipeConfigView] ⚠️ trailingSection computed property accessed")
      return Section(header: Text(String(localized: "Trailing Actions", bundle: .main))) {
        ForEach(controller.trailingActions, id: \.self) { action in
          actionRow(for: action, edge: .trailing)
        }

        SettingsToggleRow(
          "Allow Full Swipe",
          isOn: Binding(
            get: { controller.allowFullSwipeTrailing },
            set: { controller.setFullSwipe($0, edge: .trailing) }
          ),
          accessibilityIdentifier: "SwipeActions.Trailing.FullSwipe"
        ) { newValue in
          debugLog("UI toggled trailing full swipe -> \(newValue)")
        }

        if controller.canAddMoreActions(to: .trailing) {
          addActionTrigger(for: .trailing)
        }

      }
    }

    private var hapticsSection: some View {
      Section(header: Text(String(localized: "Haptics", bundle: .main))) {
        SettingsToggleRow(
          "Enable Haptic Feedback",
          isOn: Binding(
            get: { controller.hapticsEnabled },
            set: { controller.setHapticsEnabled($0) }
          ),
          accessibilityIdentifier: "SwipeActions.Haptics.Toggle"
        ) { newValue in
          guard newValue else { return }
          hapticsService.selectionChanged()
        }

        SettingsSegmentedPickerRow(
          "Intensity",
          selection: Binding(
            get: { controller.hapticStyle },
            set: { controller.setHapticStyle($0) }
          ),
          options: SwipeHapticStyle.allCases,
          accessibilityIdentifier: "SwipeActions.Haptics.StylePicker"
        ) { style in
          Text(style.description).tag(style)
        }
        .disabled(!controller.hapticsEnabled)
        .onChange(of: controller.hapticStyle) { newStyle in
          hapticsService.impact(HapticFeedbackIntensity(style: newStyle))
        }
      }
    }

    #if DEBUG
      private var materializationProbe: some View {
        Text("Materialized=\(materializationComplete ? "1" : "0")")
          .font(.caption2)
          .opacity(0.001)
          .accessibilityHidden(false)
          .accessibilityIdentifier("SwipeActions.Debug.Materialized")
          .accessibilityLabel("SwipeActions.Debug.Materialized")
          .accessibilityValue("Materialized=\(materializationComplete ? "1" : "0")")
      }
    #endif

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
        let probe = hapticsToggleProbe.uuidString
        let controllerID = controller.debugIdentifier
        return
          "Leading=\(leading);Trailing=\(trailing);Full=\(fullLeading)/\(fullTrailing);Haptics=\(haptics);Unsaved=\(unsaved);Baseline=\(baseline);Probe=\(probe);Controller=\(controllerID)"
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
