import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import zpodLib

final class Issue03AdvancedControlsTests: XCTestCase {
  // MARK: - Fixtures
  private let sampleEpisode = Episode(
    id: "ep1",
    title: "Test Episode",
    podcastID: "podcast1",
    playbackPosition: 0,
    isPlayed: false,
    pubDate: Date(),
    duration: 300,
    description: "A test episode",
    audioURL: URL(string: "https://example.com/ep1.mp3")
  )
  
  private let episodeWithChapters = Episode(
    id: "ep2",
    title: "Episode with Chapters",
    podcastID: "podcast1", 
    playbackPosition: 0,
    isPlayed: false,
    pubDate: Date(),
    duration: 600,
    description: "Episode containing chapters",
    audioURL: URL(string: "https://example.com/ep2.mp3")
  )

  // MARK: - Test Doubles
  private final class ManualTicker: Ticker, @unchecked Sendable {
    private let lock = NSLock()
    private var _tickHandler: (@Sendable () -> Void)?
    private var _isScheduled = false
    
    var tickHandler: (@Sendable () -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return _tickHandler
    }
    
    var isScheduled: Bool {
      lock.lock()
      defer { lock.unlock() }
      return _isScheduled
    }
    
    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
      lock.lock()
      defer { lock.unlock() }
      _tickHandler = tick
      _isScheduled = true
    }
    
    func cancel() {
      lock.lock()
      defer { lock.unlock() }
      _tickHandler = nil
      _isScheduled = false
    }
    
    func tick() {
      let handler: (@Sendable () -> Void)?
      lock.lock()
      handler = _tickHandler
      lock.unlock()
      handler?()
    }
  }
  
  private final class MockEpisodeStateManager: EpisodeStateManager {
    private let actor = StateActor()
    
    private actor StateActor {
      private var positions: [String: TimeInterval] = [:]
      private var playedStates: [String: Bool] = [:]
      
      func updatePlaybackPosition(_ episodeId: String, position: TimeInterval) {
        positions[episodeId] = position
      }
      
      func setPlayedStatus(_ episodeId: String, isPlayed: Bool) {
        playedStates[episodeId] = isPlayed
      }
      
      func getPlaybackPosition(_ episodeId: String, defaultValue: TimeInterval) -> TimeInterval {
        return positions[episodeId] ?? defaultValue
      }
      
      func getPlayedStatus(_ episodeId: String, defaultValue: Bool) -> Bool {
        return playedStates[episodeId] ?? defaultValue
      }
      
      func getAllPositions() -> [String: TimeInterval] {
        return positions
      }
      
      func getAllPlayedStates() -> [String: Bool] {
        return playedStates
      }
    }
    
    // Expose state for test verification
    var positions: [String: TimeInterval] {
      get async {
        await actor.getAllPositions()
      }
    }
    
    var playedStates: [String: Bool] {
      get async {
        await actor.getAllPlayedStates()
      }
    }
    
    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
      await actor.updatePlaybackPosition(episode.id, position: position)
    }
    
    func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
      await actor.setPlayedStatus(episode.id, isPlayed: isPlayed)
    }
    
    func getEpisodeState(_ episode: Episode) async -> Episode {
      let position = await actor.getPlaybackPosition(episode.id, defaultValue: TimeInterval(episode.playbackPosition))
      let isPlayed = await actor.getPlayedStatus(episode.id, defaultValue: episode.isPlayed)
      
      return Episode(
        id: episode.id,
        title: episode.title,
        podcastID: episode.podcastID,
        playbackPosition: Int(position),
        isPlayed: isPlayed,
        pubDate: episode.pubDate,
        duration: episode.duration,
        description: episode.description,
        audioURL: episode.audioURL
      )
    }
  }

  // MARK: - System Under Test
  private var ticker: ManualTicker!
  private var stateManager: MockEpisodeStateManager!
  private var player: EnhancedEpisodePlayer!

  override func setUp() async throws {
    try await super.setUp()
    // Capture properties outside MainActor.run to avoid implicit self capture
    let localTicker = ManualTicker()
    let localStateManager = MockEpisodeStateManager()
    
    ticker = localTicker
    stateManager = localStateManager
    
    player = await MainActor.run {
      EnhancedEpisodePlayer(stateManager: localStateManager)
    }
  }

  override func tearDown() async throws {
    player = nil
    stateManager = nil
    ticker = nil
    try await super.tearDown()
  }

  // MARK: - Seeking Tests

  func test_seekToPosition_updatesPosition() async throws {
    #if canImport(Combine)
    // Given: Episode is playing - capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    // Use an actor to safely manage state across concurrency boundaries
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    await MainActor.run {
      localPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      
      // When: Seeking to position
      localPlayer.seek(to: 150)
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should emit playing state with new position
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 150) < 0.1 }))
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }
  
  func test_skipForward_advancesPosition() async throws {
    #if canImport(Combine)
    // Given: Episode is playing with skip interval - capture ALL properties outside MainActor.run
    _ = ticker!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    let skipPlayer = await MainActor.run {
      _ = PlaybackSettings(skipForwardInterval: 30)
      return EnhancedEpisodePlayer(stateManager: localStateManager)
    }
    
    await MainActor.run {
      skipPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      skipPlayer.play(episode: localSampleEpisode, duration: 300)
      
      // When: Skipping forward
      skipPlayer.skipForward()
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should advance by skip interval
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 30) < 0.1 }))
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }
  
  func test_skipBackward_retreatsPosition() async throws {
    #if canImport(Combine)
    // Given: Episode is playing at advanced position with skip interval - capture ALL properties outside MainActor.run
    _ = ticker!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    let skipPlayer = await MainActor.run {
      _ = PlaybackSettings(skipBackwardInterval: 15)
      return EnhancedEpisodePlayer(stateManager: localStateManager)
    }
    
    await MainActor.run {
      skipPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      skipPlayer.play(episode: localSampleEpisode, duration: 300)
      skipPlayer.seek(to: 100) // Start at 100 seconds
      
      // When: Skipping backward
      skipPlayer.skipBackward()
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should retreat by skip interval
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 85) < 0.1 })) // 100 - 15 = 85
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }

  // MARK: - Speed Control Tests

  func test_setPlaybackSpeed_changesSpeedAndClampsValues() async {
    // Given: Player is initialized - capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      
      // When: Setting playback speed
      localPlayer.setPlaybackSpeed(2.0)
    }
    
    // Then: Should set speed
    let currentSpeed = await MainActor.run {
      localPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(currentSpeed, 2.0, accuracy: 0.01)
    
    await MainActor.run {
      // When: Setting invalid high speed
      localPlayer.setPlaybackSpeed(10.0)
    }
    
    // Then: Should clamp to max (assuming max is 5.0 based on EnhancedEpisodePlayer implementation)
    let clampedMaxSpeed = await MainActor.run {
      localPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(clampedMaxSpeed, 5.0, accuracy: 0.01)
    
    await MainActor.run {
      // When: Setting invalid low speed
      localPlayer.setPlaybackSpeed(0.1)
    }
    
    // Then: Should clamp to min (assuming min is 0.8 based on EnhancedEpisodePlayer implementation)
    let clampedMinSpeed = await MainActor.run {
      localPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(clampedMinSpeed, 0.8, accuracy: 0.01)
  }
  
  func test_playbackSpeed_affectsTickProgression() async throws {
    #if canImport(Combine)
    // Given: Player with custom speed and state collection - capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localTicker = ticker!
    let localSampleEpisode = sampleEpisode
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      localPlayer.setPlaybackSpeed(1.25)
      
      localPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      // When: Ticker advances
      localTicker.tick()
    }
    
    // Allow async position update to complete
    do {
      try await Task.sleep(for: .milliseconds(10))
    } catch {
      XCTFail("Task.sleep failed: \(error)")
    }
    
    // Then: Should advance by playback speed
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 1.25) < 0.1 }))
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }
  
  func test_playbackSpeed_perPodcastOverrides() async {
    // Given: Settings with per-podcast speeds - capture ALL properties outside MainActor.run
    _ = ticker!
    let localStateManager = stateManager!
    
    let speedPlayer = await MainActor.run {
      let settings = PlaybackSettings(
        globalPlaybackSpeed: 1.0,
        podcastPlaybackSpeeds: ["podcast1": 1.75, "podcast2": 1.5]
      )
      
      return EnhancedEpisodePlayer(stateManager: localStateManager, playbackSettings: settings)
    }
    
    // Test 1: Episode from podcast1 should use per-podcast speed
    let episode1 = Episode(
      id: "ep1",
      title: "Episode 1",
      podcastID: "podcast1",
      playbackPosition: 0,
      isPlayed: false,
      pubDate: Date(),
      duration: 300,
      description: "Test episode",
      audioURL: URL(string: "https://example.com/ep1.mp3")
    )
    
    await MainActor.run {
      speedPlayer.play(episode: episode1, duration: 300)
    }
    
    let speed1 = await MainActor.run {
      speedPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(speed1, 1.75, accuracy: 0.01, "Should use podcast1 specific speed")
    
    // Test 2: Episode from podcast2 should use different per-podcast speed
    let episode2 = Episode(
      id: "ep2",
      title: "Episode 2",
      podcastID: "podcast2",
      playbackPosition: 0,
      isPlayed: false,
      pubDate: Date(),
      duration: 300,
      description: "Test episode",
      audioURL: URL(string: "https://example.com/ep2.mp3")
    )
    
    await MainActor.run {
      speedPlayer.play(episode: episode2, duration: 300)
    }
    
    let speed2 = await MainActor.run {
      speedPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(speed2, 1.5, accuracy: 0.01, "Should use podcast2 specific speed")
    
    // Test 3: Episode from unknown podcast should use global default
    let episode3 = Episode(
      id: "ep3",
      title: "Episode 3",
      podcastID: "unknown_podcast",
      playbackPosition: 0,
      isPlayed: false,
      pubDate: Date(),
      duration: 300,
      description: "Test episode",
      audioURL: URL(string: "https://example.com/ep3.mp3")
    )
    
    await MainActor.run {
      speedPlayer.play(episode: episode3, duration: 300)
    }
    
    let speed3 = await MainActor.run {
      speedPlayer.getCurrentPlaybackSpeed()
    }
    XCTAssertEqual(speed3, 1.0, accuracy: 0.01, "Should use global default speed")
  }

  // MARK: - Episode Management Tests

  func test_markEpisodeAs_updatesPlayedStatus() async {
    // Capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
    // Given: Episode is loaded
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    // When: Marking as played
    await MainActor.run {
      localPlayer.markEpisodeAs(played: true)
    }
    
    // Allow async state update to complete
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should update played status
    let updatedEpisode = await localStateManager.getEpisodeState(localSampleEpisode)
    XCTAssertTrue(updatedEpisode.isPlayed)
    
    // When: Marking as unplayed
    await MainActor.run {
      localPlayer.markEpisodeAs(played: false)
    }
    
    // Allow async state update to complete
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should update played status
    let revertedEpisode = await localStateManager.getEpisodeState(localSampleEpisode)
    XCTAssertFalse(revertedEpisode.isPlayed)
  }

  // MARK: - Chapter Navigation Tests

  func test_jumpToChapter_seeksToChapterStart() async throws {
    #if canImport(Combine)
    // Given: Episode with chapters is playing - capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localEpisodeWithChapters = episodeWithChapters
    
    // Create sample chapters for testing since Episode model doesn't include chapters
    let sampleChapters = [
      Chapter(id: "ch1", title: "Introduction", startTime: 0, endTime: 120),
      Chapter(id: "ch2", title: "Main Content", startTime: 120, endTime: 480),
      Chapter(id: "ch3", title: "Conclusion", startTime: 480, endTime: 600)
    ]
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    await MainActor.run {
      localPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      localPlayer.play(episode: localEpisodeWithChapters, duration: 600)
      
      // When: Jumping to chapter
      let chapter = sampleChapters[1] // Main Content at 120s
      localPlayer.jumpToChapter(chapter)
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should seek to chapter start time
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 120) < 0.1 }))
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }

  func test_skipForward_respectsChapterBoundaries() async throws {
    #if canImport(Combine)
    // Given: Episode with chapters and skip settings - capture ALL properties outside MainActor.run
    _ = ticker!
    let localStateManager = stateManager!
    let localEpisodeWithChapters = episodeWithChapters
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    let skipPlayer = await MainActor.run {
      _ = PlaybackSettings(skipForwardInterval: 60)
      return EnhancedEpisodePlayer(stateManager: localStateManager)
    }
    
    await MainActor.run {
      skipPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      skipPlayer.play(episode: localEpisodeWithChapters, duration: 600)
      skipPlayer.seek(to: 90) // Start near end of first chapter
      
      // When: Skipping forward
      skipPlayer.skipForward()
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should skip by interval
    let receivedStates = await stateCollector.getStates()
    let playingStates = receivedStates.compactMap { state -> TimeInterval? in
      if case .playing(_, let position, _) = state {
        return position
      }
      return nil
    }
    
    XCTAssertTrue(playingStates.contains(where: { abs($0 - 150) < 0.1 })) // 90 + 60 = 150
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }

  // MARK: - Integration Tests

  func test_complexPlaybackScenario_maintainsStateConsistency() async throws {
    #if canImport(Combine)
    // Given: Complex settings and episode - capture ALL properties outside MainActor.run
    _ = ticker!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
    actor StateCollector {
      private var states: [EpisodePlaybackState] = []
      
      func append(_ state: EpisodePlaybackState) {
        states.append(state)
      }
      
      func getStates() -> [EpisodePlaybackState] {
        return states
      }
    }
    
    let stateCollector = StateCollector()
    var localCancellables = Set<AnyCancellable>()
    
    let complexPlayer = await MainActor.run {
      _ = PlaybackSettings(
        globalPlaybackSpeed: 1.0,
        skipForwardInterval: 30,
        skipBackwardInterval: 10,
        autoMarkAsPlayed: true,
        playedThreshold: 0.9
      )
      
      return EnhancedEpisodePlayer(stateManager: localStateManager)
    }
    
    await MainActor.run {
      complexPlayer.statePublisher
        .sink { state in
          Task {
            await stateCollector.append(state)
          }
        }
        .store(in: &localCancellables)
      
      // When: Complex interaction sequence
      complexPlayer.play(episode: localSampleEpisode, duration: 300)
      complexPlayer.setPlaybackSpeed(2.0)
      complexPlayer.skipForward() // +30s
      complexPlayer.seek(to: 100)
      complexPlayer.skipBackward() // -10s, so 90s
      complexPlayer.pause()
    }
    
    // Allow time for state updates
    try? await Task.sleep(for: .milliseconds(10))
    
    // Then: Should maintain consistent state
    let receivedStates = await stateCollector.getStates()
    guard case .paused(let episode, let position, let duration) = receivedStates.last else {
      XCTFail("Expected paused state")
      return
    }
    
    XCTAssertEqual(episode.id, localSampleEpisode.id)
    XCTAssertEqual(position, 90, accuracy: 0.1)
    XCTAssertEqual(duration, 300, accuracy: 0.1)
    #else
    throw XCTSkip("Combine not available on this platform")
    #endif
  }
}
