#if os(iOS)
  import XCTest
  import CombineSupport
  @testable import CoreModels
  @testable import LibraryFeature
  @testable import Persistence
  @testable import SettingsDomain
  import PlaybackEngine

  /// Integration tests verifying the settings → coordinator → auto-mark-as-played chain
  /// for Issue 06.4.1: Completion Threshold Setting.
  ///
  /// These tests exercise the full flow:
  ///   1. `PlaybackSettings.playedThreshold` is persisted to / loaded from `SettingsManager`
  ///   2. The threshold is forwarded to `EpisodePlaybackCoordinator`
  ///   3. Reaching the threshold triggers the episode-update handler with `isPlayed = true`
  @MainActor
  final class CompletionThresholdIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var repository: UserDefaultsSettingsRepository!
    private var mockPlaybackService: MockCompletionPlaybackService!
    private var updatedEpisodes: [Episode] = []
    private let testEpisode = Episode(
      id: "int-episode-1",
      title: "Integration Test Episode",
      podcastID: "int-podcast",
      pubDate: Date(),
      duration: 3600,
      description: ""
    )

    override func setUpWithError() throws {
      try super.setUpWithError()
      continueAfterFailure = false
      suiteName = "CompletionThresholdIntegration.\(UUID().uuidString)"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        XCTFail("Failed to create isolated UserDefaults suite")
        return
      }
      defaults.removePersistentDomain(forName: suiteName)
      repository = UserDefaultsSettingsRepository(suiteName: suiteName)
      mockPlaybackService = MockCompletionPlaybackService()
      updatedEpisodes = []
    }

    override func tearDownWithError() throws {
      if let suiteName {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
      }
      repository = nil
      mockPlaybackService = nil
      updatedEpisodes = []
      suiteName = nil
      try super.tearDownWithError()
    }

    // MARK: - Settings persistence

    /// Saving a `playedThreshold` to settings and reloading it returns the same value.
    @MainActor
    func testSavedThresholdPersistsAcrossManagerInstances() async throws {
      let manager = SettingsManager(repository: repository)
      await manager.updateGlobalPlaybackSettings(PlaybackSettings(playedThreshold: 0.90))

      let reloadedManager = SettingsManager(repository: repository)
      await reloadedManager.waitForInitialLoad()

      XCTAssertEqual(reloadedManager.globalPlaybackSettings.playedThreshold, 0.90,
        "Threshold saved to settings should survive a manager reload")
    }

    /// Default threshold from settings is nil (unset) when none has been saved.
    /// Callers apply the 0.95 fallback via `?? 0.95`; this test verifies the
    /// raw property so a bug returning an unexpected non-nil value is caught.
    @MainActor
    func testDefaultThresholdFromSettingsIs95() async throws {
      let manager = SettingsManager(repository: repository)
      await manager.waitForInitialLoad()

      XCTAssertNil(manager.globalPlaybackSettings.playedThreshold,
        "playedThreshold should be nil (unset) when no custom threshold has been persisted")
    }

    // MARK: - Settings → Coordinator → downstream

    /// A threshold saved to settings, loaded from settings, and forwarded to the
    /// coordinator correctly triggers auto-mark-as-played at that threshold.
    @MainActor
    func testSettingsThresholdFlowsWith90PercentToCoordinator() async throws {
      // 1. Save 90% threshold to settings
      let manager = SettingsManager(repository: repository)
      await manager.updateGlobalPlaybackSettings(PlaybackSettings(playedThreshold: 0.90))
      await manager.waitForInitialLoad()

      // 2. Read threshold from settings (mirrors what EpisodeListView does)
      let threshold = manager.globalPlaybackSettings.playedThreshold ?? 0.95
      XCTAssertEqual(threshold, 0.90, "Settings should return the persisted 90% threshold")

      // 3. Create coordinator using the settings-sourced threshold
      let coordinator = EpisodePlaybackCoordinator(
        playbackService: mockPlaybackService,
        episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
        episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) },
        playbackThreshold: threshold
      )
      defer { coordinator.stopMonitoring() }

      await coordinator.quickPlayEpisode(testEpisode)

      // 4. Simulate playback at exactly 90% of 3600s = 3240s
      mockPlaybackService.sendState(.playing(testEpisode, position: 3240, duration: 3600))
      try await Task.sleep(nanoseconds: 100_000_000)

      // 5. Verify downstream: episode marked as played
      XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
        "Episode at 90% (settings-sourced threshold) should be marked played")
    }

    /// A threshold saved as 99% flows correctly end-to-end and does NOT fire at 98%.
    @MainActor
    func testSettingsThresholdFlowsWith99PercentToCoordinator() async throws {
      let manager = SettingsManager(repository: repository)
      await manager.updateGlobalPlaybackSettings(PlaybackSettings(playedThreshold: 0.99))
      await manager.waitForInitialLoad()

      let threshold = manager.globalPlaybackSettings.playedThreshold ?? 0.95
      XCTAssertEqual(threshold, 0.99)

      let coordinator = EpisodePlaybackCoordinator(
        playbackService: mockPlaybackService,
        episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
        episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) },
        playbackThreshold: threshold
      )
      defer { coordinator.stopMonitoring() }

      await coordinator.quickPlayEpisode(testEpisode)

      // At 98% (3528s) — should NOT trigger
      mockPlaybackService.sendState(.playing(testEpisode, position: 3528, duration: 3600))
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true, "98% should not trigger 99% threshold")

      // At exactly 99% (3564s) — should trigger
      mockPlaybackService.sendState(.playing(testEpisode, position: 3564, duration: 3600))
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false, "99% should trigger 99% threshold")
    }

    /// Updating the threshold via `coordinator.updatePlaybackThreshold()` is respected
    /// immediately for subsequent playback events.
    @MainActor
    func testRuntimeThresholdUpdateIsRespected() async throws {
      let coordinator = EpisodePlaybackCoordinator(
        playbackService: mockPlaybackService,
        episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
        episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) },
        playbackThreshold: 0.95
      )
      defer { coordinator.stopMonitoring() }

      await coordinator.quickPlayEpisode(testEpisode)

      // Below 95% — no trigger
      mockPlaybackService.sendState(.playing(testEpisode, position: 3240, duration: 3600))
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true, "3240s (90%) should not trigger 95% threshold")

      // Dynamically lower threshold to 90%
      coordinator.updatePlaybackThreshold(0.90)

      // Re-send the same position — should now trigger with the new 90% threshold
      let countBefore = updatedEpisodes.count
      mockPlaybackService.sendState(.playing(testEpisode, position: 3240, duration: 3600))
      try await Task.sleep(nanoseconds: 100_000_000)
      XCTAssertGreaterThan(updatedEpisodes.count, countBefore, "State update should be processed")
      XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
        "3240s (90%) should trigger after threshold lowered to 90%")
    }
  }

  // MARK: - Mock

  private final class MockCompletionPlaybackService: EpisodePlaybackService {
    private let subject = PassthroughSubject<EpisodePlaybackState, Never>()

    var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
      subject.eraseToAnyPublisher()
    }

    func play(episode: Episode, duration: TimeInterval?) {}
    func pause() {}

    func sendState(_ state: EpisodePlaybackState) {
      subject.send(state)
    }
  }

#endif
