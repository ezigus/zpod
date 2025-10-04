import CoreModels
import Foundation
import SettingsDomain

@MainActor
public protocol UISettingsManaging: AnyObject {
  var globalUISettings: UISettings { get }
  func updateGlobalUISettings(_ settings: UISettings) async
}

extension UISettingsManaging {
  public func loadPersistedUISettings() async -> UISettings {
    globalUISettings
  }
}

extension SettingsManager: UISettingsManaging {}

@MainActor
final class SwipeActionConfigurationViewModel: ObservableObject {
  enum SwipeEdge {
    case leading
    case trailing
  }

  @Published private(set) var leadingActions: [SwipeActionType]
  @Published private(set) var trailingActions: [SwipeActionType]
  @Published private(set) var allowFullSwipeLeading: Bool
  @Published private(set) var allowFullSwipeTrailing: Bool
  @Published private(set) var hapticsEnabled: Bool
  @Published private(set) var hapticStyle: SwipeHapticStyle
  @Published private(set) var isSaving = false

  var availableActions: [SwipeActionType] {
    SwipeActionType.allCases
  }

  var hasUnsavedChanges: Bool {
    currentSettings != originalSettings
  }

  private let settingsManager: UISettingsManaging
  private var originalSettings: UISettings
  private var baselineRefreshCompleted = false

  init(initialSettings: UISettings, settingsManager: UISettingsManaging) {
    self.settingsManager = settingsManager
    self.originalSettings = initialSettings
    let swipeSettings = initialSettings.swipeActions
    self.leadingActions = swipeSettings.leadingActions
    self.trailingActions = swipeSettings.trailingActions
    self.allowFullSwipeLeading = swipeSettings.allowFullSwipeLeading
    self.allowFullSwipeTrailing = swipeSettings.allowFullSwipeTrailing
    self.hapticsEnabled = swipeSettings.hapticFeedbackEnabled
    self.hapticStyle = initialSettings.hapticStyle

  }

  func addAction(_ action: SwipeActionType, to edge: SwipeEdge) {
    switch edge {
    case .leading:
      leadingActions = inserting(action, into: leadingActions)
    case .trailing:
      trailingActions = inserting(action, into: trailingActions)
    }
  }

  func removeActions(at offsets: IndexSet, from edge: SwipeEdge) {
    switch edge {
    case .leading:
      leadingActions.remove(atOffsets: offsets)
    case .trailing:
      trailingActions.remove(atOffsets: offsets)
    }
  }

  func availableActions(for edge: SwipeEdge) -> [SwipeActionType] {
    let existing: [SwipeActionType]
    switch edge {
    case .leading:
      existing = leadingActions
    case .trailing:
      existing = trailingActions
    }
    return availableActions.filter { !existing.contains($0) }
  }

  func canAddMoreActions(to edge: SwipeEdge) -> Bool {
    switch edge {
    case .leading:
      return leadingActions.count < 3
    case .trailing:
      return trailingActions.count < 3
    }
  }

  func removeAction(_ action: SwipeActionType, from edge: SwipeEdge) {
    switch edge {
    case .leading:
      leadingActions.removeAll { $0 == action }
    case .trailing:
      trailingActions.removeAll { $0 == action }
    }
  }

  func moveAction(from offsets: IndexSet, to destination: Int, on edge: SwipeEdge) {
    switch edge {
    case .leading:
      leadingActions.move(fromOffsets: offsets, toOffset: destination)
    case .trailing:
      trailingActions.move(fromOffsets: offsets, toOffset: destination)
    }
  }

  func toggleFullSwipe(_ edge: SwipeEdge) {
    switch edge {
    case .leading:
      allowFullSwipeLeading.toggle()
    case .trailing:
      allowFullSwipeTrailing.toggle()
    }
  }

  func setFullSwipe(_ enabled: Bool, for edge: SwipeEdge) {
    switch edge {
    case .leading:
      allowFullSwipeLeading = enabled
    case .trailing:
      allowFullSwipeTrailing = enabled
    }
    #if DEBUG
      print(
        "[SwipeConfigDebug] setFullSwipe edge=\(edge) enabled=\(enabled) leading=\(allowFullSwipeLeading) trailing=\(allowFullSwipeTrailing)"
      )
    #endif
  }

  func setHapticsEnabled(_ enabled: Bool) {
    hapticsEnabled = enabled
    #if DEBUG
      print("[SwipeConfigDebug] setHapticsEnabled=\(enabled)")
    #endif
  }

  func setHapticStyle(_ style: SwipeHapticStyle) {
    hapticStyle = style
    #if DEBUG
      print("[SwipeConfigDebug] setHapticStyle=\(style)")
    #endif
  }

  func applyPreset(_ preset: SwipeActionSettings) {
    leadingActions = preset.leadingActions
    trailingActions = preset.trailingActions
    allowFullSwipeLeading = preset.allowFullSwipeLeading
    allowFullSwipeTrailing = preset.allowFullSwipeTrailing
    hapticsEnabled = preset.hapticFeedbackEnabled
    #if DEBUG
      print(
        "[SwipeConfigDebug] applyPreset leading=\(leadingActions) trailing=\(trailingActions) fullLeading=\(allowFullSwipeLeading) fullTrailing=\(allowFullSwipeTrailing)"
      )
    #endif
  }

  func resetToOriginal() {
    leadingActions = originalSettings.swipeActions.leadingActions
    trailingActions = originalSettings.swipeActions.trailingActions
    allowFullSwipeLeading = originalSettings.swipeActions.allowFullSwipeLeading
    allowFullSwipeTrailing = originalSettings.swipeActions.allowFullSwipeTrailing
    hapticsEnabled = originalSettings.swipeActions.hapticFeedbackEnabled
    hapticStyle = originalSettings.hapticStyle
  }

  func saveChanges() async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    let newSettings = currentSettings
    #if DEBUG
      print(
        "[SwipeConfigDebug] saveChanges invoked leading=\(newSettings.swipeActions.leadingActions) "
          + "trailing=\(newSettings.swipeActions.trailingActions) fullLeading=\(newSettings.swipeActions.allowFullSwipeLeading) fullTrailing=\(newSettings.swipeActions.allowFullSwipeTrailing)"
      )
    #endif
    await settingsManager.updateGlobalUISettings(newSettings)
    originalSettings = newSettings
    baselineRefreshCompleted = true
  }
  
  func ensureLatestBaseline(timeout: TimeInterval = 20.0) async {
    let persisted = await settingsManager.loadPersistedUISettings()
    let persistedApplied = await MainActor.run { () -> Bool in
      guard !baselineRefreshCompleted else { return true }
      guard currentSettings == originalSettings else {
        baselineRefreshCompleted = true
        return true
      }
      guard persisted != originalSettings else { return false }
      applyBaseline(persisted)
      baselineRefreshCompleted = true
      return true
    }

    if persistedApplied { return }

    let interval: TimeInterval = 0.05
    let maxAttempts = max(Int((timeout / interval).rounded(.up)), 1)

    for attempt in 0..<maxAttempts {
      if Task.isCancelled { return }

      let shouldStop = await MainActor.run { () -> Bool in
        if baselineRefreshCompleted { return true }
        if currentSettings != originalSettings {
          baselineRefreshCompleted = true
          return true
        }
        let latest = settingsManager.globalUISettings
        guard latest != originalSettings else {
          return false
        }
        applyBaseline(latest)
        baselineRefreshCompleted = true
        return true
      }

      if shouldStop { return }
      if attempt == maxAttempts - 1 {
        await MainActor.run { baselineRefreshCompleted = true }
        return
      }

      do {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
      } catch {
        return
      }
    }
  }

  @MainActor
  private func applyBaseline(_ settings: UISettings) {
    originalSettings = settings
    let swipeSettings = settings.swipeActions
    leadingActions = swipeSettings.leadingActions
    trailingActions = swipeSettings.trailingActions
    allowFullSwipeLeading = swipeSettings.allowFullSwipeLeading
    allowFullSwipeTrailing = swipeSettings.allowFullSwipeTrailing
    hapticsEnabled = swipeSettings.hapticFeedbackEnabled
    hapticStyle = settings.hapticStyle
  }

  private var currentSettings: UISettings {
    UISettings(
      swipeActions: SwipeActionSettings(
        leadingActions: leadingActions,
        trailingActions: trailingActions,
        allowFullSwipeLeading: allowFullSwipeLeading,
        allowFullSwipeTrailing: allowFullSwipeTrailing,
        hapticFeedbackEnabled: hapticsEnabled
      ),
      hapticStyle: hapticStyle
    )
  }

  private func inserting(_ action: SwipeActionType, into list: [SwipeActionType])
    -> [SwipeActionType]
  {
    guard !list.contains(action) else { return list }
    var updated = list
    updated.append(action)
    return Array(updated.prefix(3))
  }

}
