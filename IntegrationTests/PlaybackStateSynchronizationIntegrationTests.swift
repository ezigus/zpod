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
  import SharedUtilities

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
    private var nextEpisode: Episode!
    private var alertPresenter: PlaybackAlertPresenter!
    private var libraryIsReady = true

    // MARK: - Setup & Teardown

    override func setUp() async throws {
      try await super.setUp()
      continueAfterFailure = false  // Create test episode
      libraryIsReady = true
      testEpisode = Episode(
        id: "test-episode-sync",
        title: "Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 3600,
        audioURL: URL(string: "https://example.com/test.mp3")!
      )

      nextEpisode = Episode(
        id: "test-episode-next",
        title: "Next Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 2400,
        audioURL: URL(string: "https://example.com/next.mp3")!
      )

      // Setup podcast manager with test podcast
      podcastManager = InMemoryPodcastManager()
      let podcast = Podcast(
        id: "test-podcast",
        title: "Test Podcast",
        feedURL: URL(string: "https://example.com/feed.xml")!,
        episodes: [testEpisode, nextEpisode]
      )
      podcastManager.add(podcast)
      let manager = podcastManager  // capture for concurrency-safe use

      // Setup playback infrastructure - need MainActor for @MainActor initializers
      ticker = TestTicker()
      settingsRepository = MockSettingsRepository()

      // Capture values locally to avoid data race with `self` in closure
      let testEpisode = self.testEpisode!
      let ticker = self.ticker!
      let settingsRepository = self.settingsRepository!
      let isLibraryReady = { [weak self] in self?.libraryIsReady ?? true }

      let (service, coord, miniVM, expandedVM, presenter) = await MainActor.run {
        let service = StubEpisodePlayer(initialEpisode: testEpisode, ticker: ticker)
        let presenter = PlaybackAlertPresenter()

        // Setup coordinator
        let coord = PlaybackStateCoordinator(
          playbackService: service,
          settingsRepository: settingsRepository,
          episodeLookup: { episodeId in
            manager?
              .all()
              .flatMap { $0.episodes }
              .first(where: { $0.id == episodeId })
          },
          isLibraryReady: isLibraryReady,
          alertPresenter: presenter
        )  // Setup view models
        let miniVM = MiniPlayerViewModel(
          playbackService: service,
          queueIsEmpty: { true },
          alertPresenter: presenter
        )

        let expandedVM = ExpandedPlayerViewModel(
          playbackService: service,
          alertPresenter: presenter
        )

        return (service, coord, miniVM, expandedVM, presenter)
      }

      playbackService = service
      coordinator = coord
      miniPlayerViewModel = miniVM
      expandedPlayerViewModel = expandedVM
      alertPresenter = presenter
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
      nextEpisode = nil
      alertPresenter = nil
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
        isPlaying: false,
        episode: testEpisode
      )
      await settingsRepository.savePlaybackResumeState(resumeState)

      // When: App relaunches and restore is triggered
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: UI surfaces should reflect the restored episode
      XCTAssertTrue(miniPlayerViewModel.isVisible)
      XCTAssertEqual(miniPlayerViewModel.currentEpisode?.id, testEpisode.id)
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 750, accuracy: 0.1)
      XCTAssertFalse(miniPlayerViewModel.isPlaying)

      XCTAssertEqual(expandedPlayerViewModel.episode?.id, testEpisode.id)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 750, accuracy: 0.1)
      XCTAssertFalse(expandedPlayerViewModel.isPlaying)
    }

    @MainActor
    func testRestoreDefersUntilLibraryReady() async throws {
      // Given: Library has not loaded yet but resume state exists
      libraryIsReady = false
      podcastManager.remove(id: "test-podcast")
      let resumeState = PlaybackResumeState(
        episodeId: testEpisode.id,
        position: 400,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false,
        episode: testEpisode
      )
      await settingsRepository.savePlaybackResumeState(resumeState)

      // When: Restore is triggered
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State is preserved but UI does not restore yet
      let savedState = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNotNil(savedState)
      XCTAssertFalse(miniPlayerViewModel.isVisible)
      XCTAssertNil(miniPlayerViewModel.currentEpisode)

      // When: Library finishes loading, restore should succeed
      libraryIsReady = true
      let podcast = Podcast(
        id: "test-podcast",
        title: "Test Podcast",
        feedURL: URL(string: "https://example.com/feed.xml")!,
        episodes: [testEpisode, nextEpisode]
      )
      podcastManager.add(podcast)
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: UI reflects restored episode
      XCTAssertTrue(miniPlayerViewModel.isVisible)
      XCTAssertEqual(miniPlayerViewModel.currentEpisode?.id, testEpisode.id)
      XCTAssertEqual(miniPlayerViewModel.currentPosition, 400, accuracy: 0.1)
      XCTAssertFalse(miniPlayerViewModel.isPlaying)

      XCTAssertEqual(expandedPlayerViewModel.episode?.id, testEpisode.id)
      XCTAssertEqual(expandedPlayerViewModel.currentPosition, 400, accuracy: 0.1)
      XCTAssertFalse(expandedPlayerViewModel.isPlaying)
    }

    @MainActor
    func testMissingEpisodeClearsStateWithoutAlert() async throws {
      let resumeState = PlaybackResumeState(
        episodeId: "missing-episode",
        position: 150,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false
      )
      await settingsRepository.savePlaybackResumeState(resumeState)

      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 200_000_000)

      let savedState = await settingsRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
      XCTAssertNil(miniPlayerViewModel.playbackAlert)
      XCTAssertFalse(miniPlayerViewModel.isVisible)
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

    // MARK: - Queue Synchronization Tests

    @MainActor
    func testQueueAdvanceKeepsPlayersInSync() async throws {
      let queueAwareMini = MiniPlayerViewModel(
        playbackService: playbackService,
        queueIsEmpty: { false },
        alertPresenter: alertPresenter
      )

      let queueAwareExpanded = ExpandedPlayerViewModel(
        playbackService: playbackService,
        alertPresenter: alertPresenter
      )

      playbackService.play(episode: testEpisode, duration: 1800)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Episode finishes and queue advances immediately
      playbackService.play(episode: nextEpisode, duration: nextEpisode.duration ?? 2400)
      try await Task.sleep(nanoseconds: 200_000_000)

      XCTAssertEqual(queueAwareMini.displayState.episode?.id, nextEpisode.id)
      XCTAssertTrue(queueAwareMini.isPlaying)
      XCTAssertEqual(queueAwareExpanded.episode?.id, nextEpisode.id)
      XCTAssertTrue(queueAwareExpanded.isPlaying)

      _ = queueAwareMini
      _ = queueAwareExpanded
    }

    @MainActor
    func testQueuePlayNowTransitionsToPreviousEpisode() async throws {
      let queueAwareMini = MiniPlayerViewModel(
        playbackService: playbackService,
        queueIsEmpty: { false },
        alertPresenter: alertPresenter
      )

      let queueAwareExpanded = ExpandedPlayerViewModel(
        playbackService: playbackService,
        alertPresenter: alertPresenter
      )

      // When: Play next episode
      playbackService.play(episode: nextEpisode, duration: nextEpisode.duration ?? 2400)
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: Both players transition to next episode
      XCTAssertEqual(queueAwareMini.displayState.episode?.id, nextEpisode.id)
      XCTAssertEqual(queueAwareExpanded.episode?.id, nextEpisode.id)

      // When: Play test episode
      playbackService.play(episode: testEpisode, duration: testEpisode.duration ?? 1800)
      try await Task.sleep(nanoseconds: 200_000_000)

      XCTAssertEqual(queueAwareMini.displayState.episode?.id, testEpisode.id)
      XCTAssertTrue(queueAwareMini.isVisible)
      XCTAssertEqual(queueAwareExpanded.episode?.id, testEpisode.id)
      XCTAssertTrue(queueAwareExpanded.isPlaying)
    }

    // MARK: - Failure Handling Tests

    @MainActor
    func testStreamFailureSurfacesAlertAndPausesPlayback() async throws {
      playbackService.play(episode: testEpisode, duration: 2400)
      try await Task.sleep(nanoseconds: 200_000_000)
      playbackService.seek(to: 300)
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Stream fails
      playbackService.failPlayback(error: .streamFailed)
      try await Task.sleep(nanoseconds: 200_000_000)

      XCTAssertEqual(miniPlayerViewModel.playbackAlert?.descriptor.title, "Playback Failed")
      XCTAssertFalse(miniPlayerViewModel.isPlaying)
      XCTAssertFalse(expandedPlayerViewModel.isPlaying)
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

    func settingsChangeStream() async -> AsyncStream<SettingsChange> {
      AsyncStream { continuation in
        let id = UUID()
        addContinuation(id: id, continuation: continuation)
        continuation.onTermination = { [weak self] _ in
          guard let self else { return }
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
