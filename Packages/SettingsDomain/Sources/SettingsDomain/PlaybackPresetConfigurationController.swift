import CoreModels
import OSLog

@MainActor
public final class PlaybackPresetConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPresetConfigurationController")

  @Published public private(set) var draftLibrary: PlaybackPresetLibrary
  @Published private(set) var baselineLibrary: PlaybackPresetLibrary
  @Published public private(set) var isSaving = false
  @Published public var selectedPresetID: String?

  public var hasUnsavedChanges: Bool { draftLibrary != baselineLibrary }

  private let service: PlaybackPresetConfigurationServicing
  private let applyPresetHandler: (PlaybackPreset?, PlaybackPresetLibrary) -> Void
  private var updatesTask: Task<Void, Never>?

  public init(
    service: PlaybackPresetConfigurationServicing,
    applyPresetHandler: @escaping (PlaybackPreset?, PlaybackPresetLibrary) -> Void
  ) {
    self.service = service
    self.applyPresetHandler = applyPresetHandler
    self.draftLibrary = .default
    self.baselineLibrary = .default
    self.selectedPresetID = PlaybackPresetLibrary.default.activePresetID
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let library = await service.loadLibrary()
    applyBaseline(library)
  }

  public func bootstrap(with library: PlaybackPresetLibrary) {
    applyBaseline(library)
  }

  public func resetToBaseline() async {
    draftLibrary = baselineLibrary
    selectedPresetID = draftLibrary.activePresetID ?? draftLibrary.allPresets.first?.id
  }

  public func resetToDefaults() {
    let defaults = PlaybackPresetLibrary(
      builtInPresets: PlaybackPresetLibrary.defaultBuiltInPresets,
      customPresets: [],
      activePresetID: PlaybackPresetLibrary.defaultBuiltInPresets.first?.id
    )
    draftLibrary = defaults
    selectedPresetID = defaults.activePresetID
  }

  public func activatePreset(_ id: String) {
    guard draftLibrary.allPresets.contains(where: { $0.id == id }) else { return }
    draftLibrary.activePresetID = id
    selectedPresetID = id
  }

  public func selectPreset(_ id: String?) {
    selectedPresetID = id
  }

  public func createPreset(from preset: PlaybackPreset? = nil) {
    let source = preset ?? draftLibrary.allPresets.first ?? PlaybackPresetLibrary.defaultBuiltInPresets[0]
    var newPreset = PlaybackPreset(
      id: UUID().uuidString,
      name: "Custom Preset",
      description: "",
      playbackSpeed: source.playbackSpeed,
      skipForwardInterval: source.skipForwardInterval,
      skipBackwardInterval: source.skipBackwardInterval,
      skipIntroSeconds: source.skipIntroSeconds,
      skipOutroSeconds: source.skipOutroSeconds,
      continuousPlayback: source.continuousPlayback,
      crossFadeEnabled: source.crossFadeEnabled,
      crossFadeDuration: source.crossFadeDuration,
      autoMarkAsPlayed: source.autoMarkAsPlayed,
      playedThreshold: source.playedThreshold
    )
    ensurePresetValues(&newPreset)
    draftLibrary.customPresets.append(newPreset)
    selectedPresetID = newPreset.id
  }

  public func duplicatePreset(_ id: String) {
    guard let preset = draftLibrary.allPresets.first(where: { $0.id == id }) else { return }
    createPreset(from: preset)
  }

  public func deletePreset(_ id: String) {
    if draftLibrary.builtInPresets.contains(where: { $0.id == id }) {
      return // built-in presets are immutable
    }
    draftLibrary.customPresets.removeAll { $0.id == id }
    if draftLibrary.activePresetID == id {
      draftLibrary.activePresetID = draftLibrary.allPresets.first?.id
      selectedPresetID = draftLibrary.activePresetID
    }
  }

  public func updatePreset(_ preset: PlaybackPreset) {
    guard let index = draftLibrary.customPresets.firstIndex(where: { $0.id == preset.id })
        ?? draftLibrary.builtInPresets.firstIndex(where: { $0.id == preset.id }) else { return }

    var updated = preset
    ensurePresetValues(&updated)

    if index < draftLibrary.builtInPresets.count && draftLibrary.builtInPresets[index].id == updated.id {
      draftLibrary.builtInPresets[index] = updated
    } else if let customIndex = draftLibrary.customPresets.firstIndex(where: { $0.id == updated.id }) {
      draftLibrary.customPresets[customIndex] = updated
    }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    PlaybackPresetConfigurationController.logger.debug("Saving playback preset library")
    await service.saveLibrary(draftLibrary)
    applyBaseline(draftLibrary)
    let activePreset = draftLibrary.allPresets.first(where: { $0.id == draftLibrary.activePresetID })
    applyPresetHandler(activePreset, draftLibrary)
  }

  private func ensurePresetValues(_ preset: inout PlaybackPreset) {
    preset.playbackSpeed = min(max(preset.playbackSpeed, 0.5), 3.0)
    preset.skipForwardInterval = max(5, preset.skipForwardInterval)
    preset.skipBackwardInterval = max(5, preset.skipBackwardInterval)
    preset.skipIntroSeconds = max(0, preset.skipIntroSeconds)
    preset.skipOutroSeconds = max(0, preset.skipOutroSeconds)
    preset.crossFadeDuration = min(max(preset.crossFadeDuration, 0.0), 10.0)
    preset.playedThreshold = min(max(preset.playedThreshold, 0.5), 0.99)
  }

  private func applyBaseline(_ library: PlaybackPresetLibrary) {
    baselineLibrary = library
    draftLibrary = library
    selectedPresetID = library.activePresetID ?? library.allPresets.first?.id
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
