import CoreModels
import Foundation
import SettingsDomain

@MainActor
public protocol UISettingsManaging: AnyObject {
  var globalUISettings: UISettings { get }
  func updateGlobalUISettings(_ settings: UISettings) async
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

  init(settingsManager: UISettingsManaging) {
    self.settingsManager = settingsManager
    let settings = settingsManager.globalUISettings
    self.originalSettings = settings
    let swipeSettings = settings.swipeActions
    self.leadingActions = swipeSettings.leadingActions
    self.trailingActions = swipeSettings.trailingActions
    self.allowFullSwipeLeading = swipeSettings.allowFullSwipeLeading
    self.allowFullSwipeTrailing = swipeSettings.allowFullSwipeTrailing
    self.hapticsEnabled = swipeSettings.hapticFeedbackEnabled
    self.hapticStyle = settings.hapticStyle
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
  }

  func setHapticsEnabled(_ enabled: Bool) {
    hapticsEnabled = enabled
  }

  func setHapticStyle(_ style: SwipeHapticStyle) {
    hapticStyle = style
  }

  func applyPreset(_ preset: SwipeActionSettings) {
    leadingActions = preset.leadingActions
    trailingActions = preset.trailingActions
    allowFullSwipeLeading = preset.allowFullSwipeLeading
    allowFullSwipeTrailing = preset.allowFullSwipeTrailing
    hapticsEnabled = preset.hapticFeedbackEnabled
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
    await settingsManager.updateGlobalUISettings(newSettings)
    originalSettings = newSettings
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
