import CoreModels
import OSLog

@MainActor
public final class DownloadConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "DownloadConfigurationController")

  struct Draft: Equatable {
    var autoDownloadEnabled: Bool
    var wifiOnly: Bool
    var maxConcurrentDownloads: Int
    var retentionPolicy: RetentionPolicy
    var updateFrequency: UpdateFrequency
  }

  @Published private(set) var draft: Draft
  @Published private(set) var baseline: Draft
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }
  public var autoDownloadEnabled: Bool { draft.autoDownloadEnabled }
  public var wifiOnlyEnabled: Bool { draft.wifiOnly }
  public var maxConcurrentDownloads: Int { draft.maxConcurrentDownloads }
  public var retentionPolicy: RetentionPolicy { draft.retentionPolicy }
  public var updateFrequency: UpdateFrequency { draft.updateFrequency }

  private let service: DownloadConfigurationServicing
  private var updatesTask: Task<Void, Never>?

  public init(service: DownloadConfigurationServicing) {
    self.service = service
    let defaults = DownloadConfigurationController.makeDraft(from: DownloadSettings.default)
    self.draft = defaults
    self.baseline = defaults
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let settings = await service.load()
    applyBaseline(settings)
  }

  public func bootstrap(with settings: DownloadSettings) {
    applyBaseline(settings)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  public func setAutoDownloadEnabled(_ enabled: Bool) {
    updateDraft { $0.autoDownloadEnabled = enabled }
  }

  public func setWifiOnlyEnabled(_ enabled: Bool) {
    updateDraft { $0.wifiOnly = enabled }
  }

  public func setMaxConcurrentDownloads(_ count: Int) {
    let clamped = max(ValidationConstants.minConcurrentDownloads, min(ValidationConstants.maxConcurrentDownloads, count))
    updateDraft { $0.maxConcurrentDownloads = clamped }
  }

  public func setRetentionPolicy(_ policy: RetentionPolicy) {
    updateDraft { $0.retentionPolicy = policy }
  }

  public func setUpdateFrequency(_ frequency: UpdateFrequency) {
    updateDraft { $0.updateFrequency = frequency }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    let settings = makeSettings(from: draft)
    DownloadConfigurationController.logger.debug("Saving download settings")
    await service.save(settings)
    applyBaseline(settings)
  }

  public var currentSettings: DownloadSettings {
    makeSettings(from: draft)
  }

  // MARK: - Private helpers

  private func applyBaseline(_ settings: DownloadSettings) {
    baseline = DownloadConfigurationController.makeDraft(from: settings)
    draft = baseline
  }

  private func updateDraft(_ mutation: (inout Draft) -> Void) {
    var newDraft = draft
    mutation(&newDraft)
    draft = newDraft
  }

  private func makeSettings(from draft: Draft) -> DownloadSettings {
    DownloadSettings(
      autoDownloadEnabled: draft.autoDownloadEnabled,
      wifiOnly: draft.wifiOnly,
      maxConcurrentDownloads: draft.maxConcurrentDownloads,
      retentionPolicy: draft.retentionPolicy,
      defaultUpdateFrequency: draft.updateFrequency
    )
  }

  private func startObservingUpdates() {
    updatesTask = Task { [weak self] in
      guard let self else { return }
      var updates = service.updatesStream().makeAsyncIterator()
      while let next = await updates.next() {
        await MainActor.run { [weak self] in
          self?.applyBaseline(next)
        }
      }
    }
  }

  private static func makeDraft(from settings: DownloadSettings) -> Draft {
    Draft(
      autoDownloadEnabled: settings.autoDownloadEnabled,
      wifiOnly: settings.wifiOnly,
      maxConcurrentDownloads: settings.maxConcurrentDownloads,
      retentionPolicy: settings.retentionPolicy,
      updateFrequency: settings.defaultUpdateFrequency
    )
  }
}
