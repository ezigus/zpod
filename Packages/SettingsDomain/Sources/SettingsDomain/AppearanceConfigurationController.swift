import CoreModels
import OSLog

@MainActor
public final class AppearanceConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "AppearanceConfigurationController")

  @Published public private(set) var draft: AppearanceSettings
  @Published private(set) var baseline: AppearanceSettings
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }

  public var theme: AppearanceTheme { draft.theme }
  public var preferredTint: AppearanceTint { draft.preferredTint }
  public var typographyScale: Double { draft.typographyScale }
  public var reduceMotionEnabled: Bool { draft.reduceMotionEnabled }
  public var reduceHapticsEnabled: Bool { draft.reduceHapticsEnabled }
  public var highContrastEnabled: Bool { draft.highContrastEnabled }

  private let service: AppearanceConfigurationServicing
  private var updatesTask: Task<Void, Never>?

  private let minScale: Double = 0.8
  private let maxScale: Double = 1.5

  public init(service: AppearanceConfigurationServicing) {
    self.service = service
    self.draft = AppearanceSettings.default
    self.baseline = AppearanceSettings.default
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let settings = await service.load()
    applyBaseline(settings)
  }

  public func bootstrap(with settings: AppearanceSettings) {
    applyBaseline(settings)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  public func setTheme(_ theme: AppearanceTheme) {
    updateDraft { $0.theme = theme }
  }

  public func setPreferredTint(_ tint: AppearanceTint) {
    updateDraft { $0.preferredTint = tint }
  }

  public func setTypographyScale(_ scale: Double) {
    let clamped = min(max(scale, minScale), maxScale)
    updateDraft { $0.typographyScale = clamped }
  }

  public func setReduceMotionEnabled(_ enabled: Bool) {
    updateDraft { $0.reduceMotionEnabled = enabled }
  }

  public func setReduceHapticsEnabled(_ enabled: Bool) {
    updateDraft { $0.reduceHapticsEnabled = enabled }
  }

  public func setHighContrastEnabled(_ enabled: Bool) {
    updateDraft { $0.highContrastEnabled = enabled }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    AppearanceConfigurationController.logger.debug("Saving appearance settings")
    await service.save(draft)
    applyBaseline(draft)
  }

  private func updateDraft(_ mutation: (inout AppearanceSettings) -> Void) {
    var updated = draft
    mutation(&updated)
    draft = updated
  }

  private func applyBaseline(_ settings: AppearanceSettings) {
    baseline = settings
    draft = settings
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

