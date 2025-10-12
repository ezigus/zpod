import CoreModels
import OSLog

@MainActor
public final class SmartListAutomationConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "SmartListAutomationConfigurationController")

  @Published public private(set) var draft: SmartListRefreshConfiguration
  @Published private(set) var baseline: SmartListRefreshConfiguration
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }

  public var isEnabled: Bool { draft.isEnabled }
  public var globalInterval: TimeInterval { draft.globalInterval }
  public var maxRefreshPerCycle: Int { draft.maxRefreshPerCycle }
  public var refreshOnForeground: Bool { draft.refreshOnForeground }
  public var refreshOnNetworkChange: Bool { draft.refreshOnNetworkChange }

  private let service: SmartListAutomationConfigurationServicing
  private var updatesTask: Task<Void, Never>?

  private let minInterval: TimeInterval = 60
  private let maxInterval: TimeInterval = 4 * 60 * 60 // 4 hours

  public init(service: SmartListAutomationConfigurationServicing) {
    self.service = service
    self.draft = SmartListRefreshConfiguration()
    self.baseline = SmartListRefreshConfiguration()
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let configuration = await service.load()
    applyBaseline(configuration)
  }

  public func bootstrap(with configuration: SmartListRefreshConfiguration) {
    applyBaseline(configuration)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  public func setEnabled(_ enabled: Bool) {
    updateDraft {
      $0 = SmartListRefreshConfiguration(
        isEnabled: enabled,
        globalInterval: $0.globalInterval,
        maxRefreshPerCycle: $0.maxRefreshPerCycle,
        refreshOnForeground: $0.refreshOnForeground,
        refreshOnNetworkChange: $0.refreshOnNetworkChange
      )
    }
  }

  public func setGlobalInterval(_ interval: TimeInterval) {
    let clamped = min(max(interval, minInterval), maxInterval)
    updateDraft {
      $0 = SmartListRefreshConfiguration(
        isEnabled: $0.isEnabled,
        globalInterval: clamped,
        maxRefreshPerCycle: $0.maxRefreshPerCycle,
        refreshOnForeground: $0.refreshOnForeground,
        refreshOnNetworkChange: $0.refreshOnNetworkChange
      )
    }
  }

  public func setMaxRefreshPerCycle(_ count: Int) {
    let value = max(1, count)
    updateDraft {
      $0 = SmartListRefreshConfiguration(
        isEnabled: $0.isEnabled,
        globalInterval: $0.globalInterval,
        maxRefreshPerCycle: value,
        refreshOnForeground: $0.refreshOnForeground,
        refreshOnNetworkChange: $0.refreshOnNetworkChange
      )
    }
  }

  public func setRefreshOnForeground(_ enabled: Bool) {
    updateDraft {
      $0 = SmartListRefreshConfiguration(
        isEnabled: $0.isEnabled,
        globalInterval: $0.globalInterval,
        maxRefreshPerCycle: $0.maxRefreshPerCycle,
        refreshOnForeground: enabled,
        refreshOnNetworkChange: $0.refreshOnNetworkChange
      )
    }
  }

  public func setRefreshOnNetworkChange(_ enabled: Bool) {
    updateDraft {
      $0 = SmartListRefreshConfiguration(
        isEnabled: $0.isEnabled,
        globalInterval: $0.globalInterval,
        maxRefreshPerCycle: $0.maxRefreshPerCycle,
        refreshOnForeground: $0.refreshOnForeground,
        refreshOnNetworkChange: enabled
      )
    }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    SmartListAutomationConfigurationController.logger.debug("Saving smart list automation settings")
    await service.save(draft)
    applyBaseline(draft)
  }

  private func updateDraft(_ mutation: (inout SmartListRefreshConfiguration) -> Void) {
    var updated = draft
    mutation(&updated)
    draft = updated
  }

  private func applyBaseline(_ configuration: SmartListRefreshConfiguration) {
    baseline = configuration
    draft = configuration
  }

  private func startObservingUpdates() {
    updatesTask = Task { [weak self] in
      guard let self else { return }
      var iterator = service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        await MainActor.run { [weak self] in
          self?.applyBaseline(next)
        }
      }
    }
  }
}

