import XCTest
import CoreModels
import Persistence
@testable import SettingsDomain

final class PlaybackConfigurationServiceTests: XCTestCase {
  func testLoadReturnsDefaultsWhenEmpty() async {
    let suiteName = "playback-service-empty-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = PlaybackConfigurationService(repository: repository)

    let settings = await service.load()
    XCTAssertEqual(settings, PlaybackSettings())
  }

  func testSavePersistsAcrossInstances() async {
    let suiteName = "playback-service-roundtrip-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = PlaybackConfigurationService(repository: repository)
    let expected = PlaybackSettings(
      playbackSpeed: 1.25,
      skipIntroSeconds: 10,
      skipOutroSeconds: 5,
      continuousPlayback: false,
      crossFadeEnabled: true,
      crossFadeDuration: 3.0,
      volumeBoostEnabled: true,
      smartSpeedEnabled: true,
      globalPlaybackSpeed: 1.2,
      skipForwardInterval: 45,
      skipBackwardInterval: 20,
      autoMarkAsPlayed: true,
      playedThreshold: 0.8
    )

    await service.save(expected)

    let reloaded = await PlaybackConfigurationService(repository: repository).load()
    XCTAssertEqual(reloaded, expected)
  }

  func testUpdatesStreamPublishesChanges() async {
    let suiteName = "playback-service-stream-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = PlaybackConfigurationService(repository: repository)
    let expectation = expectation(description: "Received playback update")

    let task = Task {
      var iterator = service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        if next.playbackSpeed == 1.75 {
          expectation.fulfill()
          break
        }
      }
    }

    await service.save(PlaybackSettings(playbackSpeed: 1.75))

    await fulfillment(of: [expectation], timeout: 1.0)
    task.cancel()
  }
}
