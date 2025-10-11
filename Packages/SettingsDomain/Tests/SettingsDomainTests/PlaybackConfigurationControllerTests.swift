import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class PlaybackConfigurationControllerTests: XCTestCase {
  func testLoadBaselinePopulatesDraft() async {
    let initial = PlaybackSettings(
      playbackSpeed: 1.2,
      skipIntroSeconds: 15,
      skipOutroSeconds: 5,
      continuousPlayback: false,
      crossFadeEnabled: true,
      crossFadeDuration: 2.5,
      volumeBoostEnabled: true,
      smartSpeedEnabled: true,
      skipForwardInterval: 45,
      skipBackwardInterval: 20,
      autoMarkAsPlayed: true,
      playedThreshold: 0.75
    )

    let service = InMemoryPlaybackConfigurationService(initial: initial)
    let controller = PlaybackConfigurationController(service: service)

    await controller.loadBaseline()

    XCTAssertEqual(controller.playbackSpeed, 1.2)
    XCTAssertEqual(controller.skipIntroSeconds, 15)
    XCTAssertEqual(controller.skipOutroSeconds, 5)
    XCTAssertEqual(controller.skipForwardInterval, 45)
    XCTAssertTrue(controller.crossFadeEnabled)
    XCTAssertTrue(controller.volumeBoostEnabled)
    XCTAssertTrue(controller.autoMarkAsPlayedEnabled)
    XCTAssertFalse(controller.hasUnsavedChanges)
  }

  func testMutationsMarkUnsavedAndCommitPersists() async {
    let service = InMemoryPlaybackConfigurationService(initial: PlaybackSettings())
    let controller = PlaybackConfigurationController(service: service)
    await controller.loadBaseline()

    controller.setPlaybackSpeed(1.6)
    controller.setSkipForwardInterval(45)
    controller.setVolumeBoostEnabled(true)

    XCTAssertTrue(controller.hasUnsavedChanges)

    await controller.commitChanges()

    XCTAssertFalse(controller.hasUnsavedChanges)
    let saved = await service.load()
    XCTAssertEqual(saved.playbackSpeed, 1.6)
    XCTAssertEqual(saved.skipForwardInterval, 45)
    XCTAssertTrue(saved.volumeBoostEnabled)
  }

  func testResetToBaselineClearsDraft() async {
    let service = InMemoryPlaybackConfigurationService(initial: PlaybackSettings(playbackSpeed: 1.3))
    let controller = PlaybackConfigurationController(service: service)
    await controller.loadBaseline()

    controller.setPlaybackSpeed(2.0)
    XCTAssertTrue(controller.hasUnsavedChanges)

    await controller.resetToBaseline()

    XCTAssertEqual(controller.playbackSpeed, 1.3)
    XCTAssertFalse(controller.hasUnsavedChanges)
  }
}

actor InMemoryPlaybackConfigurationService: PlaybackConfigurationServicing {
  private var value: PlaybackSettings

  init(initial: PlaybackSettings) {
    value = initial
  }

  func load() async -> PlaybackSettings { value }

  func save(_ settings: PlaybackSettings) async {
    value = settings
  }

  nonisolated func updatesStream() -> AsyncStream<PlaybackSettings> {
    AsyncStream { continuation in
      continuation.onTermination = { _ in }
    }
  }
}
