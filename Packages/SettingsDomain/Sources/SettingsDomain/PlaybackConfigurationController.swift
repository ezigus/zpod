import CoreModels
import OSLog

@MainActor
public final class PlaybackConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackConfigurationController")

  @Published public private(set) var draft: PlaybackSettings
  @Published private(set) var baseline: PlaybackSettings
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }
  public var playbackSpeed: Double { draft.playbackSpeed }
  public var skipIntroSeconds: Int { draft.skipIntroSeconds }
  public var skipOutroSeconds: Int { draft.skipOutroSeconds }
  public var skipForwardInterval: Int { draft.skipForwardInterval ?? 30 }
  public var skipBackwardInterval: Int { draft.skipBackwardInterval ?? 15 }
  public var crossFadeDuration: Double { draft.crossFadeDuration }
  public var continuousPlaybackEnabled: Bool { draft.continuousPlayback }
  public var crossFadeEnabled: Bool { draft.crossFadeEnabled }
  public var volumeBoostEnabled: Bool { draft.volumeBoostEnabled }
  public var smartSpeedEnabled: Bool { draft.smartSpeedEnabled }
  public var autoMarkAsPlayedEnabled: Bool { draft.autoMarkAsPlayed ?? false }
  public var playedThreshold: Double { draft.playedThreshold ?? 0.9 }
  public var currentSettings: PlaybackSettings { draft }

  private let service: PlaybackConfigurationServicing
  private var updatesTask: Task<Void, Never>?

  public init(service: PlaybackConfigurationServicing) {
    self.service = service
    self.draft = PlaybackSettings()
    self.baseline = PlaybackSettings()
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let settings = await service.load()
    applyBaseline(settings)
  }

  public func bootstrap(with settings: PlaybackSettings) {
    applyBaseline(settings)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  public func setPlaybackSpeed(_ speed: Double) {
    updateDraft { $0.playbackSpeed = clamp(speed, lower: 0.5, upper: 3.0) }
  }

  public func setSkipIntroSeconds(_ seconds: Int) {
    updateDraft { $0.skipIntroSeconds = max(0, seconds) }
  }

  public func setSkipOutroSeconds(_ seconds: Int) {
    updateDraft { $0.skipOutroSeconds = max(0, seconds) }
  }

  public func setSkipForwardInterval(_ interval: Int) {
    updateDraft { $0.skipForwardInterval = max(5, interval) }
  }

  public func setSkipBackwardInterval(_ interval: Int) {
    updateDraft { $0.skipBackwardInterval = max(5, interval) }
  }

  public func setContinuousPlayback(_ enabled: Bool) {
    updateDraft { $0.continuousPlayback = enabled }
  }

  public func setCrossFadeEnabled(_ enabled: Bool) {
    updateDraft { $0.crossFadeEnabled = enabled }
  }

  public func setCrossFadeDuration(_ duration: Double) {
    updateDraft { $0.crossFadeDuration = clamp(duration, lower: 0.5, upper: 10.0) }
  }

  public func setVolumeBoostEnabled(_ enabled: Bool) {
    updateDraft { $0.volumeBoostEnabled = enabled }
  }

  public func setSmartSpeedEnabled(_ enabled: Bool) {
    updateDraft { $0.smartSpeedEnabled = enabled }
  }

  public func setAutoMarkAsPlayed(_ enabled: Bool) {
    updateDraft { $0.autoMarkAsPlayed = enabled }
  }

  public func setPlayedThreshold(_ threshold: Double) {
    updateDraft { $0.playedThreshold = clamp(threshold, lower: 0.5, upper: 0.99) }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    PlaybackConfigurationController.logger.debug("Saving playback settings")
    await service.save(draft)
    applyBaseline(draft)
  }

  private func updateDraft(_ mutation: (inout PlaybackSettings) -> Void) {
    var updated = draft
    mutation(&updated)
    draft = updated
  }

  private func applyBaseline(_ settings: PlaybackSettings) {
    baseline = settings
    draft = settings
  }

  private func startObservingUpdates() {
    updatesTask = Task { [weak self] in
      guard let self else { return }
      var stream = service.updatesStream().makeAsyncIterator()
      while let next = await stream.next() {
        await MainActor.run { [weak self] in
          self?.applyBaseline(next)
        }
      }
    }
  }

  private func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    min(max(value, lower), upper)
  }
}
