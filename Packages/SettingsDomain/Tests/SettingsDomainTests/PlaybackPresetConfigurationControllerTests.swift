import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class PlaybackPresetConfigurationControllerTests: XCTestCase {
  private var service: InMemoryPlaybackPresetService!
  private var appliedPreset: PlaybackPreset?
  private var appliedLibrary: PlaybackPresetLibrary?
  private var controller: PlaybackPresetConfigurationController!

  override func setUp() async throws {
    service = InMemoryPlaybackPresetService(initial: .default)
    controller = PlaybackPresetConfigurationController(
      service: service,
      applyPresetHandler: { preset, library in
        self.appliedPreset = preset
        self.appliedLibrary = library
      }
    )
  }

  override func tearDown() async throws {
    controller = nil
    service = nil
    appliedPreset = nil
    appliedLibrary = nil
  }

  func testLoadBaselineInitialisesLibrary() async {
    await controller.loadBaseline()
    XCTAssertFalse(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.draftLibrary.builtInPresets.count, PlaybackPresetLibrary.defaultBuiltInPresets.count)
  }

  func testCreateCustomPresetAddsPreset() async {
    await controller.loadBaseline()
    controller.createPreset()
    XCTAssertTrue(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.draftLibrary.customPresets.count, 1)
  }

  func testCommitChangesSavesLibraryAndAppliesPreset() async {
    await controller.loadBaseline()
    controller.createPreset()
    guard let customID = controller.draftLibrary.customPresets.first?.id else {
      XCTFail("Expected custom preset")
      return
    }
    controller.activatePreset(customID)

    await controller.commitChanges()
    XCTAssertFalse(controller.hasUnsavedChanges)
    XCTAssertEqual(appliedLibrary?.activePresetID, customID)
    XCTAssertEqual(appliedPreset?.id, customID)
  }

  func testResetToDefaultsRestoresBuiltInPresets() async {
    await controller.loadBaseline()
    controller.createPreset()
    controller.resetToDefaults()
    XCTAssertEqual(controller.draftLibrary.customPresets.count, 0)
    XCTAssertEqual(controller.draftLibrary.builtInPresets.count, PlaybackPresetLibrary.defaultBuiltInPresets.count)
  }
}

// MARK: - Test Double

actor InMemoryPlaybackPresetService: PlaybackPresetConfigurationServicing {
  private var stored: PlaybackPresetLibrary
  private var continuation: AsyncStream<PlaybackPresetLibrary>.Continuation?

  init(initial: PlaybackPresetLibrary) {
    stored = initial
  }

  func loadLibrary() async -> PlaybackPresetLibrary { stored }

  func saveLibrary(_ library: PlaybackPresetLibrary) async {
    stored = library
    continuation?.yield(library)
  }

  nonisolated func updatesStream() -> AsyncStream<PlaybackPresetLibrary> {
    AsyncStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  private func storeContinuation(_ continuation: AsyncStream<PlaybackPresetLibrary>.Continuation) {
    self.continuation = continuation
  }
}

