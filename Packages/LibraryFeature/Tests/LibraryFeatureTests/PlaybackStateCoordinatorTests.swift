#if os(iOS)
  //
  //  PlaybackStateCoordinatorTests.swift
  //  LibraryFeatureTests
  //
  //  Created for Issue 03.1.1.3: Playback State Synchronization & Persistence
  //  Tests for playback state persistence and lifecycle management
  //

  import XCTest
  import CombineSupport
  @testable import LibraryFeature
  import CoreModels
  import PlaybackEngine
  import Persistence
  import SharedUtilities

  final class PlaybackStateCoordinatorTests: XCTestCase {

    private var coordinator: PlaybackStateCoordinator!
    private var mockPlaybackService: MockEpisodePlaybackService!
    private var mockRepository: MockSettingsRepository!
    private var testEpisode: Episode!
    private var episodeLookupMap: [String: Episode] = [:]
    private var alertPresenter: PlaybackAlertPresenter!

    @MainActor
    override func setUpWithError() throws {
      continueAfterFailure = false

      testEpisode = Episode(
        id: "test-episode-1",
        title: "Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 1800,
        description: "Test description"
      )

      episodeLookupMap = [testEpisode.id: testEpisode]
      mockPlaybackService = MockEpisodePlaybackService()
      mockRepository = MockSettingsRepository()
      alertPresenter = PlaybackAlertPresenter()

      coordinator = PlaybackStateCoordinator(
        playbackService: mockPlaybackService,
        settingsRepository: mockRepository,
        episodeLookup: { [weak self] id in
          return self?.episodeLookupMap[id]
        },
        alertPresenter: alertPresenter
      )
    }

    @MainActor
    override func tearDownWithError() throws {
      coordinator.cleanup()
      coordinator = nil
      mockPlaybackService = nil
      mockRepository = nil
      episodeLookupMap = [:]
      testEpisode = nil
      alertPresenter = nil
    }

    // MARK: - Persistence Tests

    @MainActor
    func testPersistsStateOnPause() async throws {
      // Given: Playback is in progress
      mockPlaybackService.sendState(.playing(testEpisode, position: 300, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)  // 0.2s

      // When: Playback is paused
      mockPlaybackService.sendState(.paused(testEpisode, position: 300, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)  // 0.2s

      // Then: State should be persisted
      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNotNil(savedState)
      XCTAssertEqual(savedState?.episodeId, testEpisode.id)
      XCTAssertEqual(savedState?.position, 300)
      XCTAssertEqual(savedState?.duration, 1800)
      XCTAssertFalse(savedState?.isPlaying ?? true)
      XCTAssertEqual(savedState?.episode?.id, testEpisode.id)
    }

    @MainActor
    func testClearsStateOnFinish() async throws {
      // Given: Playback is in progress and state is persisted
      mockPlaybackService.sendState(.playing(testEpisode, position: 300, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      mockPlaybackService.sendState(.paused(testEpisode, position: 300, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      var savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNotNil(savedState)

      // When: Episode finishes
      mockPlaybackService.sendState(.finished(testEpisode, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should be cleared
      savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
    }

    @MainActor
    func testDoesNotPersistAtBeginning() async throws {
      // Given: Playback just started
      mockPlaybackService.sendState(.playing(testEpisode, position: 0, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Paused at the beginning
      mockPlaybackService.sendState(.paused(testEpisode, position: 0, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should not be persisted
      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
    }

    @MainActor
    func testDoesNotPersistAtEnd() async throws {
      // Given: Playback near the end
      mockPlaybackService.sendState(.playing(testEpisode, position: 1800, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      // When: Paused at the end
      mockPlaybackService.sendState(.paused(testEpisode, position: 1800, duration: 1800))
      try await Task.sleep(nanoseconds: 200_000_000)

      // Then: State should not be persisted
      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
    }

    // MARK: - Resume Tests

    @MainActor
    func testRestoresValidState() async throws {
      // Given: Valid resume state exists
    let resumeState = PlaybackResumeState(
      episodeId: testEpisode.id,
      position: 500,
      duration: 1800,
      timestamp: Date(),
      isPlaying: false,
      episode: testEpisode
    )
      await mockRepository.savePlaybackResumeState(resumeState)

      // When: Restore is requested
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 100_000_000)

      // Then: Episode should be available for playback
      let injectedState = mockPlaybackService.injectedStates.last
      guard case .paused(let injectedEpisode, let position, let duration)? = injectedState else {
        XCTFail("Expected injected paused state")
        return
      }
      XCTAssertEqual(injectedEpisode.id, testEpisode.id)
      XCTAssertEqual(position, 500, accuracy: 0.1)
      XCTAssertEqual(duration, 1800, accuracy: 0.1)
    }

    @MainActor
    func testClearsExpiredState() async throws {
      // Given: Expired resume state (older than 24 hours)
      let expiredDate = Date().addingTimeInterval(-25 * 60 * 60)  // 25 hours ago
    let resumeState = PlaybackResumeState(
      episodeId: testEpisode.id,
      position: 500,
      duration: 1800,
      timestamp: expiredDate,
      isPlaying: false,
      episode: testEpisode
    )
      await mockRepository.savePlaybackResumeState(resumeState)

      // When: Restore is requested
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 100_000_000)

      // Then: State should be cleared and alert shown
      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
      XCTAssertEqual(alertPresenter.currentAlert?.descriptor.title, "Session Expired")
    }

    @MainActor
    func testClearsStateForMissingEpisode() async throws {
      // Given: Resume state for non-existent episode
      let resumeState = PlaybackResumeState(
        episodeId: "non-existent-episode",
        position: 500,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false,
        episode: nil
      )
      await mockRepository.savePlaybackResumeState(resumeState)

      // When: Restore is requested
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 100_000_000)

      // Then: State should be cleared
      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertNil(savedState)
    }

    @MainActor
    func testRestoresUsingSnapshotWhenLookupFails() async throws {
      // Given: Episode lookup cannot find the episode but snapshot exists
      episodeLookupMap = [:]
      let resumeState = PlaybackResumeState(
        episodeId: testEpisode.id,
        position: 250,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false,
        episode: testEpisode
      )
      await mockRepository.savePlaybackResumeState(resumeState)

      // When: Restore is requested
      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 100_000_000)

      // Then: Coordinator should inject the snapshot into playback service
      guard case .paused(let episode, let position, let duration)? =
        mockPlaybackService.injectedStates.last
      else {
        XCTFail("Expected injected paused state")
        return
      }
      XCTAssertEqual(episode.id, testEpisode.id)
      XCTAssertEqual(position, 250, accuracy: 0.1)
      XCTAssertEqual(duration, 1800, accuracy: 0.1)
    }

    @MainActor
    func testMissingEpisodeTriggersAlert() async throws {
      let resumeState = PlaybackResumeState(
        episodeId: "missing",
        position: 100,
        duration: 1800,
        timestamp: Date(),
        isPlaying: false,
        episode: nil
      )
      await mockRepository.savePlaybackResumeState(resumeState)

      await coordinator.restorePlaybackIfNeeded()
      try await Task.sleep(nanoseconds: 50_000_000)

      XCTAssertEqual(alertPresenter.currentAlert?.descriptor.title, "Episode Unavailable")
    }

    @MainActor
    func testReportPlaybackErrorPublishesAlert() async throws {
      coordinator.reportPlaybackError(.streamFailed)
      try await Task.sleep(nanoseconds: 50_000_000)
      XCTAssertEqual(alertPresenter.currentAlert?.descriptor.title, "Playback Failed")
    }

    @MainActor
    func testStreamFailureStatePersistsPositionAndShowsAlert() async throws {
      let position: TimeInterval = 420
      mockPlaybackService.sendState(
        .failed(testEpisode, position: position, duration: 1800, error: .streamFailed)
      )
      try await Task.sleep(nanoseconds: 200_000_000)

      let savedState = await mockRepository.loadPlaybackResumeState()
      XCTAssertEqual(savedState?.position, position)
      XCTAssertEqual(alertPresenter.currentAlert?.descriptor.title, "Playback Failed")
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

    func loadGlobalPlaybackSettings() async -> PlaybackSettings {
      return PlaybackSettings()
    }

    func saveGlobalPlaybackSettings(_ settings: PlaybackSettings) async {}

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

  // MARK: - Mock Playback Service

  private class MockEpisodePlaybackService: EpisodePlaybackService, EpisodePlaybackStateInjecting {
    var playWasCalled = false
    var lastPlayedEpisode: Episode?
    var lastPlayedDuration: TimeInterval?
    var injectedStates: [EpisodePlaybackState] = []

    private let stateSubject = PassthroughSubject<EpisodePlaybackState, Never>()

    var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
      stateSubject.eraseToAnyPublisher()
    }

    func play(episode: Episode, duration: TimeInterval?) {
      playWasCalled = true
      lastPlayedEpisode = episode
      lastPlayedDuration = duration ?? 0
    }

    func pause() {
      // No-op for mock
    }

    func sendState(_ state: EpisodePlaybackState) {
      stateSubject.send(state)
    }

    func injectPlaybackState(_ state: EpisodePlaybackState) {
      injectedStates.append(state)
      stateSubject.send(state)
    }
  }

#endif
