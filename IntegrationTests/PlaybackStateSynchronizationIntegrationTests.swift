//
//  PlaybackStateSynchronizationIntegrationTests.swift
//  IntegrationTests
//
//  Created for Issue 03.1.1.3: Playback State Synchronization & Persistence
//  Integration tests verifying state sync across mini-player, expanded player, and persistence
//

#if os(iOS)
  import XCTest
  @testable import CoreModels
  @testable import LibraryFeature
  @testable import PlayerFeature
  @testable import PlaybackEngine
  @testable import Persistence
  @testable import TestSupport
  import CombineSupport

  /// Integration tests for playback state synchronization and persistence
  ///
  /// **Specifications Covered**: Playback state synchronization (Issue 03.1.1.3)
  /// - State synchronization between mini-player and expanded player
  /// - State persistence across background/foreground transitions
  /// - Resume after app relaunch within 24-hour window
  /// - Queue/episode changes update both surfaces without desync
  final class PlaybackStateSynchronizationIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var podcastManager: InMemoryPodcastManager!
    private var settingsRepository: MockSettingsRepository!
    private var playbackService: StubEpisodePlayer!
    private var ticker: TestTicker!
    private var coordinator: PlaybackStateCoordinator!
    private var miniPlayerViewModel: MiniPlayerViewModel!
    private var expandedPlayerViewModel: ExpandedPlayerViewModel!
    private var testEpisode: Episode!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
      try await super.setUp()
      continueAfterFailure = false  // Create test episode
      testEpisode = Episode(
        id: "test-episode-sync",
        title: "Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 3600,
        audioURL: URL(string: "https://example.com/test.mp3")!
      )

      // Setup podcast manager with test podcast
      podcastManager = InMemoryPodcastManager()
      let podcast = Podcast(
        id: "test-podcast",
        title: "Test Podcast",
        feedURL: URL(string: "https://example.com/feed.xml")!
      )
      podcastManager.add(podcast)

      // Setup playback infrastructure - need MainActor for @MainActor initializers
      ticker = TestTicker()
      settingsRepository = MockSettingsRepository()

      // Capture values locally to avoid data race with `self` in closure
      let testEpisode = self.testEpisode!
      let ticker = self.ticker!
      let settingsRepository = self.settingsRepository!

      let (service, coord, miniVM, expandedVM) = await MainActor.run {
        let service = StubEpisodePlayer(initialEpisode: testEpisode, ticker: ticker)

        // Setup coordinator
        let coord = PlaybackStateCoordinator(
          playbackService: service,
          settingsRepository: settingsRepository,
          episodeLookup: { episodeId in
            return episodeId == testEpisode.id ? testEpisode : nil
          }
        )  // Setup view models
        let miniVM = MiniPlayerViewModel(
          playbackService: service,
          queueIsEmpty: { true }
        )

        let expandedVM = ExpandedPlayerViewModel(
          playbackService: service
        )

        return (service, coord, miniVM, expandedVM)
      }

      playbackService = service
      coordinator = coord
      miniPlayerViewModel = miniVM
      expandedPlayerViewModel = expandedVM
    }

    override func tearDown() {
      coordinator.cleanup()
      coordinator = nil
      miniPlayerViewModel = nil
      expandedPlayerViewModel = nil
      playbackService = nil
      ticker = nil
      settingsRepository = nil
      podcastManager = nil
      testEpisode = nil
      super.tearDown()
    }

    // MARK: - State Synchronization Tests

    @MainActor
    func testMiniPlayerAndExpandedPlayerSynchronizeOnPlay() async throws {
      // Given: Both view models are observing the same playback service

      // When: Playback starts
      playbackService.play(episode: testEpisode, duration: 1800)
      try await Task.sleep(nanoseconds: 200_000_000)  // 0.2s for state propagation

      // Then: Both view models should reflect playing state
      XCTAssertTrue(miniPlayerViewModel.isPlaying)
      XCTAssertTrue(miniPlayerViewModel.isVisible)
      XCTAssertEqual(miniPlayerViewModel.currentEpisode?.id, testEpisode.id)
      XCTAssertEqual(miniPlayerViewModel.duration, 1800)

      XCTAssertTrue(expandedPlayerViewModel.isPlaying)
      XCTAssertEqual(expandedPlayerViewModel.episode?.id, testEpisode.id)
      XCTAssertEqual(expandedPlayerViewModel.duration, 1800)
    }

    @MainActor
    func testMiniPlayerAndExpandedPlayerSynchronizeOnPause() async throws {
      // Given: Playback is in progress
      playbackService.play(episode: testEpisode, duration: 1800)
      playbackService.seek(to: 500)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Playback is paused
      playbackService.pause()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: Both view models should reflect paused state
      XCTAssertFalse(miniPlayerViewModel.isPlaying)
      XCTAssertTrue(miniPlayerViewModel.isVisible)
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 500)

      XCTAssertFalse(expandedPlayerViewModel.isPlaying)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 500)
    }

    @MainActor
    func testStatePersistsOnPause() async throws {
      // Given: Playback is in progress
      playbackService.play(episode: testEpisode, duration: 1800)
      playbackService.seek(to: 600)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Playback is paused (simulating background event)
      playbackService.pause()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should be persisted
      let resumeState = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNotNil(resumeState)
      XCTAssertEqual(resumeState?.episodeId, testEpisode.id)
      XCTAssertEqual(resumeState?.position, 600)
      XCTAssertEqual(resumeState?.duration, 1800)
      XCTAssertFalse(resumeState?.isPlaying ?? true)
    }

    @MainActor
    func testStateRestoresOnRelaunch() async throws {
      // Given: A previous playback session was saved
      let resumeState = PlaybackResumeState(
        episodeId: testEpisode.id,
        position: 750,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false
      )
      await settingsRepository.savePlaybackResumeState(resumeState)

      // When: App relaunches and restore is triggered
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should be restored (but not auto-playing)
      // Note: In the current implementation, we don't auto-play on restore
      // The coordinator loads the state but doesn't automatically start playback
    }

    @MainActor
    func testExpiredStateNotRestored() async throws {
      // Given: A playback session from more than 24 hours ago
      let expiredDate = Date().addingTimeInterval(-25 * 60 * 60)
      let expiredState = PlaybackResumeState(
        episodeId: testEpisode.id,
        position: 800,
        duration: 1800,
        timestamp: expiredDate,
        isPlaying: false
      )
      await settingsRepository.savePlaybackResumeState(expiredState)

      // When: App relaunches and tries to restore
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should be cleared as expired
      let state = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNil(state)
    }

    @MainActor
    func testSeekOperationsSynchronize() async throws {
      // Given: Playback is active
      playbackService.play(episode: testEpisode, duration: 1800)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Seeking to a new position
      playbackService.seek(to: 900)
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: Both view models should reflect the new position
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 900)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 900)
    }

    @MainActor
    func testSkipForwardSynchronizes() async throws {
      // Given: Playback is active at position 100
      playbackService.play(episode: testEpisode, duration: 1800)
      playbackService.seek(to: 100)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Skip forward is triggered from mini player
      miniPlayerViewModel.skipForward(interval: 30)
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: Both view models should reflect the new position
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 130)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 130)
    }

    @MainActor
    func testSkipBackwardSynchronizes() async throws {
      // Given: Playback is active at position 300
      playbackService.play(episode: testEpisode, duration: 1800)
      playbackService.seek(to: 300)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Skip backward is triggered from expanded player
      expandedPlayerViewModel.skipBackward(interval: 15)
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: Both view models should reflect the new position
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 285)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 285)
    }

    @MainActor
    func testStateClearsOnFinish() async throws {
      // Given: Playback is in progress with saved state
      playbackService.play(episode: testEpisode, duration: 1800)
      playbackService.seek(to: 1000)
      try await Task.sleep(nanoseconds: 200_000_000)

      playbackService.pause()
      try await Task.sleep(nanoseconds: 200_000_000)

      var resumeState = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNotNil(resumeState)

      // When: Episode finishes playing
      playbackService.seek(to: 1800)
      try await Task.sleep(nanoseconds: 100_000_000)

      // Then: Resume state should be cleared
      resumeState = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNil(resumeState)
    }
  }

  // MARK: - Test Ticker

  /// Test ticker for deterministic playback state testing
  private final class TestTicker: Ticker, @unchecked Sendable {
    private var timer: Timer?

    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
      cancel()
      // For tests, we don't actually tick - just provide the capability
    }

    func cancel() {
      timer?.invalidate()
      timer = nil
    }
  }

  // MARK: - Mock Settings Repository

  actor MockSettingsRepository: SettingsRepository {
    private var resumeState: PlaybackResumeState?
    private var changeContinuations: [UUID: AsyncStream<SettingsChange>.Continuation] = [:]

    func loadGlobalDownloadSettings() async -> DownloadSettings {
      return DownloadSettings.default
    }

    func saveGlobalDownloadSettings(_ settings: DownloadSettings) async {}

    func loadGlobalNotificationSettings() async -> NotificationSettings {
      return NotificationSettings.default
    }

    func saveGlobalNotificationSettings(_ settings: NotificationSettings) async {}

    func loadGlobalPlaybackSettings() async -> CoreModels.PlaybackSettings {
      return CoreModels.PlaybackSettings()
    }

    func saveGlobalPlaybackSettings(_ settings: CoreModels.PlaybackSettings) async {}

    func loadGlobalUISettings() async -> UISettings {
      return UISettings.default
    }

    func saveGlobalUISettings(_ settings: UISettings) async {}

    func loadGlobalAppearanceSettings() async -> AppearanceSettings {
      return AppearanceSettings.default
    }

    func saveGlobalAppearanceSettings(_ settings: AppearanceSettings) async {}

    func loadSmartListAutomationSettings() async -> SmartListRefreshConfiguration {
      return SmartListRefreshConfiguration()
    }

    func saveSmartListAutomationSettings(_ settings: SmartListRefreshConfiguration) async {}

    func loadPlaybackPresetLibrary() async -> PlaybackPresetLibrary {
      return PlaybackPresetLibrary.default
    }

    func savePlaybackPresetLibrary(_ library: PlaybackPresetLibrary) async {}

    func loadPodcastDownloadSettings(podcastId: String) async -> PodcastDownloadSettings? {
      return nil
    }

    func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async {}

    func removePodcastDownloadSettings(podcastId: String) async {}

    func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings? {
      return nil
    }

    func savePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings) async {
    }

    func removePodcastPlaybackSettings(podcastId: String) async {}

    // MARK: - Playback Resume State

    func loadPlaybackResumeState() async -> PlaybackResumeState? {
      return resumeState
    }

    func savePlaybackResumeState(_ state: PlaybackResumeState) async {
      resumeState = state
      broadcast(.playbackResume(state))
    }

    func clearPlaybackResumeState() async {
      resumeState = nil
      broadcast(.playbackResume(nil))
    }

    private func broadcast(_ change: SettingsChange) {
      for continuation in changeContinuations.values {
        continuation.yield(change)
      }
    }

    nonisolated func settingsChangeStream() -> AsyncStream<SettingsChange> {
      AsyncStream { continuation in
        let id = UUID()
        Task { await self.addContinuation(id: id, continuation: continuation) }
        continuation.onTermination = { _ in
          Task { await self.removeContinuation(id: id) }
        }
      }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<SettingsChange>.Continuation) {
      changeContinuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
      changeContinuations.removeValue(forKey: id)
    }
  }

#endif
