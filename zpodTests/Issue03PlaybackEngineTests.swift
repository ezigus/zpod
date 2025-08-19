import XCTest
@preconcurrency import Combine
@testable import zpod

@MainActor
final class Issue03BasicPlaybackTests: XCTestCase {
  // MARK: - Fixtures
  private let sampleEpisode = Episode(
    id: "ep1",
    title: "Test Episode",
    description: "A test episode",
    mediaURL: URL(string: "https://example.com/ep1.mp3"),
    duration: 300,
    pubDate: Date(),
    isPlayed: false,
    playbackPosition: 0,
    chapters: [],
    podcastId: "podcast1"
  )
  
  private let sampleEpisodeWithPosition = Episode(
    id: "ep2",
    title: "Episode with Position",
    description: "Episode with existing position",
    mediaURL: URL(string: "https://example.com/ep2.mp3"),
    duration: 600,
    pubDate: Date(),
    isPlayed: false,
    playbackPosition: 150,
    chapters: [],
    podcastId: "podcast1"
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
    
    func advance(by seconds: Int) {
      for _ in 0..<seconds {
        tick()
      }
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
      let position = await actor.getPlaybackPosition(episode.id, defaultValue: episode.playbackPosition)
      let isPlayed = await actor.getPlayedStatus(episode.id, defaultValue: episode.isPlayed)
      
      return Episode(
        id: episode.id,
        title: episode.title,
        description: episode.description,
        mediaURL: episode.mediaURL,
        duration: episode.duration,
        pubDate: episode.pubDate,
        isPlayed: isPlayed,
        playbackPosition: position,
        chapters: episode.chapters,
        podcastId: episode.podcastId
      )
    }
  }

  // MARK: - System Under Test
  private var ticker: ManualTicker!
  private var stateManager: MockEpisodeStateManager!
  private var player: EnhancedEpisodePlayer!
  private var cancellables: Set<AnyCancellable>!

  override func setUp() async throws {
    // Remove super.setUp() call to avoid Sendable violations in Swift 6
    await MainActor.run {
      ticker = ManualTicker()
      stateManager = MockEpisodeStateManager()
      player = EnhancedEpisodePlayer(
        ticker: ticker,
        settings: PlaybackSettings(), // Use default settings
        episodeStateManager: stateManager
      )
      cancellables = Set<AnyCancellable>()
    }
  }

  override func tearDown() async throws {
    await MainActor.run {
      cancellables = nil
      player = nil
      stateManager = nil
      ticker = nil
    }
    // Remove super.tearDown() call to avoid Sendable violations in Swift 6
  }

  // MARK: - Basic Playback Tests

  func test_initialState_isIdleWithInitialEpisode() async {
    await MainActor.run {
      // Given: EnhancedEpisodePlayer is initialized
      var receivedState: EpisodePlaybackState?
      
      player.statePublisher
        .sink { state in receivedState = state }
        .store(in: &cancellables)
      
      // Then: Initial state should be idle
      guard case .idle(let episode) = receivedState else {
        XCTFail("Expected idle state, got \(String(describing: receivedState))")
        return
      }
      XCTAssertEqual(episode.title, "No Episode")
    }
  }
  
  func test_playEpisode_emitsPlayingState() async {
    await MainActor.run {
      // Given: Player is initialized
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      // When: Playing an episode
      player.play(episode: sampleEpisode, duration: 300)
      
      // Then: Should emit playing state
      XCTAssertEqual(receivedStates.count, 2) // Initial idle + playing
      
      guard case .playing(let episode, let position, let duration) = receivedStates[1] else {
        XCTFail("Expected playing state")
        return
      }
      
      XCTAssertEqual(episode.id, sampleEpisode.id)
      XCTAssertEqual(position, 0, accuracy: 0.1)
      XCTAssertEqual(duration, 300, accuracy: 0.1)
    }
  }
  
  func test_playEpisodeWithExistingPosition_startsFromPosition() async {
    await MainActor.run {
      // Given: Episode with existing playback position
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      // When: Playing episode with position
      player.play(episode: sampleEpisodeWithPosition, duration: 600)
      
      // Then: Should start from existing position
      guard case .playing(_, let position, _) = receivedStates[1] else {
        XCTFail("Expected playing state")
        return
      }
      
      XCTAssertEqual(position, 150, accuracy: 0.1)
    }
  }
  
  func test_pauseEpisode_emitsPausedState() async {
    await MainActor.run {
      // Given: Episode is playing
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      player.play(episode: sampleEpisode, duration: 300)
      
      // When: Pausing the episode
      player.pause()
      
      // Then: Should emit paused state
      XCTAssertEqual(receivedStates.count, 3) // Initial idle + playing + paused
      
      guard case .paused(let episode, let position, let duration) = receivedStates[2] else {
        XCTFail("Expected paused state")
        return
      }
      
      XCTAssertEqual(episode.id, sampleEpisode.id)
      XCTAssertEqual(position, 0, accuracy: 0.1)
      XCTAssertEqual(duration, 300, accuracy: 0.1)
    }
  }
  
  func test_playbackProgression_advancesPosition() async throws {
    await MainActor.run {
      // Given: Episode is playing
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      player.play(episode: sampleEpisode, duration: 300)
      
      // When: Ticker advances time
      ticker.tick()
      
      // Allow a brief moment for the state to be updated
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        // Then: Position should advance by playback speed (1.0)
        let playingStates = receivedStates.compactMap { state -> (TimeInterval, TimeInterval)? in
          if case .playing(_, let position, let duration) = state {
            return (position, duration)
          }
          return nil
        }
        
        XCTAssertGreaterThanOrEqual(playingStates.count, 2)
        XCTAssertEqual(playingStates.last?.0 ?? 0, 1.0, accuracy: 0.1) // Advanced by 1 second
      }
    }
    
    // Allow async position update to complete
    try await Task.sleep(for: .milliseconds(20))
  }
  
  func test_playbackAtEnd_emitsFinishedState() async throws {
    let autoMarkSettings = PlaybackSettings(autoMarkAsPlayed: true)
    var autoMarkPlayer: EnhancedEpisodePlayer!
    var receivedStates: [EpisodePlaybackState] = []
    
    await MainActor.run {
      // Given: Episode playing near the end with auto-mark enabled
      autoMarkPlayer = EnhancedEpisodePlayer(
        ticker: ticker,
        settings: autoMarkSettings,
        episodeStateManager: stateManager
      )
      
      autoMarkPlayer.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      let shortEpisode = Episode(
        id: "short",
        title: "Short Episode",
        mediaURL: URL(string: "https://example.com/short.mp3"),
        duration: 2,
        pubDate: Date(),
        isPlayed: false,
        playbackPosition: 1.5,
        chapters: [],
        podcastId: "podcast1"
      )
      
      autoMarkPlayer.play(episode: shortEpisode, duration: 2)
      
      // When: Ticker advances past end
      ticker.tick() // Should reach end
    }
    
    // Allow async completion to process
    try await Task.sleep(for: .milliseconds(50))
    
    await MainActor.run {
      // Then: Should emit finished state and mark as played
      let finishedStates = receivedStates.compactMap { state -> Episode? in
        if case .finished(let episode, _) = state {
          return episode
        }
        return nil
      }
      
      XCTAssertEqual(finishedStates.count, 1)
      XCTAssertEqual(finishedStates.first?.id, "short")
    }
    
    // Verify episode was marked as played
    let shortEpisode = Episode(
      id: "short",
      title: "Short Episode",
      mediaURL: URL(string: "https://example.com/short.mp3"),
      duration: 2,
      pubDate: Date(),
      isPlayed: false,
      playbackPosition: 1.5,
      chapters: [],
      podcastId: "podcast1"
    )
    let updatedEpisode = await stateManager.getEpisodeState(shortEpisode)
    XCTAssertTrue(updatedEpisode.isPlayed)
  }
  
  func test_switchEpisodes_stopsCurrentAndStartsNew() async {
    await MainActor.run {
      // Given: Episode is playing
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      player.play(episode: sampleEpisode, duration: 300)
      
      // When: Playing a different episode
      player.play(episode: sampleEpisodeWithPosition, duration: 600)
      
      // Then: Should transition to new episode
      XCTAssertEqual(receivedStates.count, 3) // Initial idle + first playing + second playing
      
      guard case .playing(let newEpisode, let position, let duration) = receivedStates[2] else {
        XCTFail("Expected playing state for new episode")
        return
      }
      
      XCTAssertEqual(newEpisode.id, sampleEpisodeWithPosition.id)
      XCTAssertEqual(position, 150, accuracy: 0.1) // Should start from saved position
      XCTAssertEqual(duration, 600, accuracy: 0.1)
    }
  }
  
  func test_playbackSpeed_affectsProgression() async throws {
    let fastSettings = PlaybackSettings(
      globalPlaybackSpeed: 2.0,
      podcastPlaybackSpeeds: ["podcast1": 1.5],
      skipForwardInterval: 30,
      skipBackwardInterval: 15,
      introSkipDurations: [:],
      outroSkipDurations: [:],
      autoMarkAsPlayed: false,
      playedThreshold: 0.9
    )
    var fastPlayer: EnhancedEpisodePlayer!
    var receivedStates: [EpisodePlaybackState] = []
    
    await MainActor.run {
      // Given: Player with custom speed settings
      fastPlayer = EnhancedEpisodePlayer(
        ticker: ticker,
        settings: fastSettings,
        episodeStateManager: stateManager
      )
      
      fastPlayer.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      fastPlayer.play(episode: sampleEpisode, duration: 300)
      
      // When: Ticker advances time
      ticker.tick()
    }
    
    // Allow async position update to complete
    try await Task.sleep(for: .milliseconds(10))
    
    await MainActor.run {
      // Then: Position should advance by podcast-specific speed (1.5)
      let playingStates = receivedStates.compactMap { state -> TimeInterval? in
        if case .playing(_, let position, _) = state {
          return position
        }
        return nil
      }
      
      XCTAssertGreaterThanOrEqual(playingStates.count, 2)
      XCTAssertEqual(playingStates.last ?? 0, 1.5, accuracy: 0.1) // Advanced by 1.5 seconds
    }
  }
  
  func test_tickerScheduling_startsAndStopsWithPlayback() async {
    await MainActor.run {
      // Given: Player is initialized
      XCTAssertFalse(ticker.isScheduled)
      
      // When: Playing an episode
      player.play(episode: sampleEpisode, duration: 300)
      
      // Then: Ticker should be scheduled
      XCTAssertTrue(ticker.isScheduled)
      
      // When: Pausing the episode
      player.pause()
      
      // Then: Ticker should be cancelled
      XCTAssertFalse(ticker.isScheduled)
    }
  }
  
  func test_statePublisher_providesStateAccess() async {
    await MainActor.run {
      // Given: Player is initialized and subscribed to state
      var receivedStates: [EpisodePlaybackState] = []
      
      player.statePublisher
        .sink { state in receivedStates.append(state) }
        .store(in: &cancellables)
      
      // Then: Should provide initial idle state
      guard case .idle = receivedStates.first else {
        XCTFail("Expected idle state initially")
        return
      }
      
      // When: Playing an episode
      player.play(episode: sampleEpisode, duration: 300)
      
      // Then: Should emit playing state
      guard case .playing(let episode, _, _) = receivedStates.last else {
        XCTFail("Expected playing state")
        return
      }
      
      XCTAssertEqual(episode.id, sampleEpisode.id)
    }
  }
}
