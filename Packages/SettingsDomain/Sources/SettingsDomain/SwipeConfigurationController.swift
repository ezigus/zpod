import Foundation
import CoreModels

@MainActor
public final class SwipeConfigurationController: ObservableObject, FeatureConfigurationControlling {
  @Published public private(set) var draft: SwipeConfiguration
  @Published private(set) var baseline: SwipeConfiguration
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }
  public var leadingActions: [SwipeActionType] { draft.swipeActions.leadingActions }
  public var trailingActions: [SwipeActionType] { draft.swipeActions.trailingActions }
  public var allowFullSwipeLeading: Bool { draft.swipeActions.allowFullSwipeLeading }
  public var allowFullSwipeTrailing: Bool { draft.swipeActions.allowFullSwipeTrailing }
  public var hapticsEnabled: Bool { draft.swipeActions.hapticFeedbackEnabled }
  public var hapticStyle: SwipeHapticStyle { draft.hapticStyle }
  public var currentConfiguration: SwipeConfiguration { draft }

  private let service: SwipeConfigurationServicing
  private var updatesTask: Task<Void, Never>?

  public init(service: SwipeConfigurationServicing) {
    self.service = service
    self.draft = .default
    self.baseline = .default
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let configuration = await service.load()
    applyBaseline(configuration)
  }

  public func bootstrap(with configuration: SwipeConfiguration) {
    applyBaseline(configuration)
  }

  public func updateDraft(_ mutation: (inout SwipeConfiguration) -> Void) {
    var next = draft
    mutation(&next)
    normalizeAndAssign(next)
  }

  public func applyPreset(_ preset: SwipeActionSettings) {
    print("[SwipeConfigController] applyPreset -> leading=\(preset.leadingActions.map(\.rawValue))")
    updateDraft { draft in
      draft.swipeActions = SwipeActionSettings(
        leadingActions: preset.leadingActions,
        trailingActions: preset.trailingActions,
        allowFullSwipeLeading: preset.allowFullSwipeLeading,
        allowFullSwipeTrailing: preset.allowFullSwipeTrailing,
        hapticFeedbackEnabled: preset.hapticFeedbackEnabled
      )
    }
  }

  public func setHapticsEnabled(_ enabled: Bool) {
    updateDraft { draft in
      draft.swipeActions = SwipeActionSettings(
        leadingActions: draft.swipeActions.leadingActions,
        trailingActions: draft.swipeActions.trailingActions,
        allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
        allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
        hapticFeedbackEnabled: enabled
      )
    }
  }

  public func setHapticStyle(_ style: SwipeHapticStyle) {
    updateDraft { draft in
      draft.hapticStyle = style
    }
  }

  public func setFullSwipe(_ enabled: Bool, edge: SwipeEdge) {
    updateDraft { draft in
      let settings = draft.swipeActions
      switch edge {
      case .leading:
        draft.swipeActions = SwipeActionSettings(
          leadingActions: settings.leadingActions,
          trailingActions: settings.trailingActions,
          allowFullSwipeLeading: enabled,
          allowFullSwipeTrailing: settings.allowFullSwipeTrailing,
          hapticFeedbackEnabled: settings.hapticFeedbackEnabled
        )
      case .trailing:
        draft.swipeActions = SwipeActionSettings(
          leadingActions: settings.leadingActions,
          trailingActions: settings.trailingActions,
          allowFullSwipeLeading: settings.allowFullSwipeLeading,
          allowFullSwipeTrailing: enabled,
          hapticFeedbackEnabled: settings.hapticFeedbackEnabled
        )
      }
    }
  }

  public func addAction(_ action: SwipeActionType, edge: SwipeEdge) {
    updateDraft { draft in
      switch edge {
      case .leading:
        var actions = draft.swipeActions.leadingActions
        guard actions.count < 3 else { return }
        guard !actions.contains(action) else { return }
        actions.append(action)
        draft.swipeActions = SwipeActionSettings(
          leadingActions: actions,
          trailingActions: draft.swipeActions.trailingActions,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      case .trailing:
        var actions = draft.swipeActions.trailingActions
        guard actions.count < 3 else { return }
        guard !actions.contains(action) else { return }
        actions.append(action)
        draft.swipeActions = SwipeActionSettings(
          leadingActions: draft.swipeActions.leadingActions,
          trailingActions: actions,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      }
    }
  }

  public func removeAction(_ action: SwipeActionType, edge: SwipeEdge) {
    updateDraft { draft in
      switch edge {
      case .leading:
        let filtered = draft.swipeActions.leadingActions.filter { $0 != action }
        draft.swipeActions = SwipeActionSettings(
          leadingActions: filtered,
          trailingActions: draft.swipeActions.trailingActions,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      case .trailing:
        let filtered = draft.swipeActions.trailingActions.filter { $0 != action }
        draft.swipeActions = SwipeActionSettings(
          leadingActions: draft.swipeActions.leadingActions,
          trailingActions: filtered,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      }
    }
  }

  public func availableActions(for edge: SwipeEdge) -> [SwipeActionType] {
    switch edge {
    case .leading:
      return SwipeActionType.allCases.filter { !draft.swipeActions.leadingActions.contains($0) }
    case .trailing:
      return SwipeActionType.allCases.filter { !draft.swipeActions.trailingActions.contains($0) }
    }
  }

  public func canAddMoreActions(to edge: SwipeEdge) -> Bool {
    switch edge {
    case .leading:
      return draft.swipeActions.leadingActions.count < 3
    case .trailing:
      return draft.swipeActions.trailingActions.count < 3
    }
  }

  public func moveAction(from offsets: IndexSet, to destination: Int, edge: SwipeEdge) {
    updateDraft { draft in
      switch edge {
      case .leading:
        var actions = draft.swipeActions.leadingActions
        actions.move(fromOffsets: offsets, toOffset: destination)
        draft.swipeActions = SwipeActionSettings(
          leadingActions: actions,
          trailingActions: draft.swipeActions.trailingActions,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      case .trailing:
        var actions = draft.swipeActions.trailingActions
        actions.move(fromOffsets: offsets, toOffset: destination)
        draft.swipeActions = SwipeActionSettings(
          leadingActions: draft.swipeActions.leadingActions,
          trailingActions: actions,
          allowFullSwipeLeading: draft.swipeActions.allowFullSwipeLeading,
          allowFullSwipeTrailing: draft.swipeActions.allowFullSwipeTrailing,
          hapticFeedbackEnabled: draft.swipeActions.hapticFeedbackEnabled
        )
      }
    }
  }

  public func commitChanges() async throws {
    guard hasUnsavedChanges else { return }
    isSaving = true
    let pending = draft
    defer { isSaving = false }
    try await service.save(pending)
    applyBaseline(pending)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  private func applyBaseline(_ configuration: SwipeConfiguration) {
    baseline = configuration
    draft = configuration
  }

  private func normalizeAndAssign(_ configuration: SwipeConfiguration) {
    draft = SwipeConfiguration(
      swipeActions: SwipeActionSettings(
        leadingActions: configuration.swipeActions.leadingActions,
        trailingActions: configuration.swipeActions.trailingActions,
        allowFullSwipeLeading: configuration.swipeActions.allowFullSwipeLeading,
        allowFullSwipeTrailing: configuration.swipeActions.allowFullSwipeTrailing,
        hapticFeedbackEnabled: configuration.swipeActions.hapticFeedbackEnabled
      ),
      hapticStyle: configuration.hapticStyle
    )
  }

  private func startObservingUpdates() {
    updatesTask = Task { [weak self] in
      guard let self else { return }
      var iterator = self.service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        await MainActor.run { [weak self] in
          guard let self else { return }
          if self.hasUnsavedChanges { return }
          self.applyBaseline(next)
        }
      }
    }
  }

  public enum SwipeEdge {
    case leading
    case trailing
  }
}
