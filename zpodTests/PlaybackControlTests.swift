import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import zpodLib

/// Tests for podcast playback controls and episode management functionality
/// 
/// **Specifications Covered**: `spec/playback.md`
/// - Playing an Episode with Custom Speed
/// - Skipping Silences and Boosting Volume  
/// - Manually Marking Episodes as Played/Unplayed
/// - Using Explicit Rewind/Fast-Forward Buttons
/// - Navigating Episode Chapters
final class PlaybackControlTests: XCTestCase {
  // MARK: - Test Fixtures
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
    // Simple manual ticker used only for protocol conformance in some tests.
    // No locking needed for these tests.
    private var _tickHandler: (@Sendable () -> Void)?
    private var _isScheduled = false
    
    var tickHandler: (@Sendable () -> Void)? { _tickHandler }
    var isScheduled: Bool { _isScheduled }
    
    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
      _tickHandler = tick
      _isScheduled = true
    }
    
    func cancel() {
      _tickHandler = nil
      _isScheduled = false
    }
    
    func tick() { _tickHandler?() }
  }

  private actor MockEpisodeStateManager: EpisodeStateManager {
    private var episodes: [String: Episode] = [:]
    
    func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
      let updated = Episode(
        id: episode.id,
        title: episode.title,
        podcastID: episode.podcastID,
        playbackPosition: episode.playbackPosition,
        isPlayed: isPlayed,
        pubDate: episode.pubDate,
        duration: episode.duration,
        description: episode.description,
        audioURL: episode.audioURL
      )
      episodes[episode.id] = updated
    }
    
    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
      let updated = Episode(
        id: episode.id,
        title: episode.title,
        podcastID: episode.podcastID,
        playbackPosition: Int(position),
        isPlayed: episode.isPlayed,
        pubDate: episode.pubDate,
        duration: episode.duration,
        description: episode.description,
        audioURL: episode.audioURL
      )
      episodes[episode.id] = updated
    }
    
    func getEpisodeState(_ episode: Episode) async -> Episode {
      episodes[episode.id] ?? episode
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

  // MARK: - Playback Position and Seeking Tests
  // Covers: "Using Explicit Rewind/Fast-Forward Buttons" from spec/playback.md

  func test_seekToPosition_updatesPosition() async throws {
    #if canImport(Combine)
    // Given: Episode is playing - capture ALL properties outside MainActor.run
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    let targetPosition: TimeInterval = 120
    
    // When: Seeking to specific position
    await MainActor.run {
      localPlayer.seek(to: targetPosition)
    }
    
    // Then: Position should be updated
    let currentPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertEqual(currentPosition, targetPosition, accuracy: 0.1)
    #endif
  }

  func test_skipForward_increasesPosition() async {
    // Given: Episode is playing at beginning
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      localPlayer.seek(to: 0)
    }
    
    // When: Skipping forward
    await MainActor.run {
      localPlayer.skipForward()
    }
    
    // Then: Position should increase by default skip interval
    let currentPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertGreaterThan(currentPosition, 0)
    XCTAssertLessThanOrEqual(currentPosition, 30) // Default skip interval
  }

  func test_skipBackward_decreasesPosition() async {
    // Given: Episode is playing at middle position
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      localPlayer.seek(to: 120)
    }
    
    let initialPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    
    // When: Skipping backward
    await MainActor.run {
      localPlayer.skipBackward()
    }
    
    // Then: Position should decrease by default skip interval
    let currentPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertLessThan(currentPosition, initialPosition)
  }

  // MARK: - Episode State Management Tests
  // Covers: "Manually Marking Episodes as Played/Unplayed" from spec/playback.md

  func test_markEpisodeAs_updatesPlayedStatus() async {
    // Given: Episode is loaded
    let localPlayer = player!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
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

  func test_automaticPlayedMarking_marksAsPlayedWhenComplete() async {
    // Given: Episode is near end
    let localPlayer = player!
    let localStateManager = stateManager!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      localPlayer.seek(to: 295) // Near end of 300 second episode
    }
    
    // When: Episode reaches end
    await MainActor.run {
      localPlayer.seek(to: 300)
    }
    
    // Allow async processing
    try? await Task.sleep(for: .milliseconds(100))
    
    // Then: Should automatically mark as played
    let updatedEpisode = await localStateManager.getEpisodeState(localSampleEpisode)
    XCTAssertTrue(updatedEpisode.isPlayed)
  }

  // MARK: - Playback Speed Tests
  // Covers: "Playing an Episode with Custom Speed" from spec/playback.md

  func test_playbackSpeed_validRange() async {
    // Given: Episode is playing
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    // When: Setting various playback speeds
    let testSpeeds: [Float] = [0.8, 1.0, 1.5, 2.0, 3.0, 5.0]
    
    for speed in testSpeeds {
      await MainActor.run {
        localPlayer.setPlaybackSpeed(speed)
      }
      
      // Then: Speed should be set correctly
      let currentSpeed = await MainActor.run {
        localPlayer.playbackSpeed
      }
      XCTAssertEqual(currentSpeed, speed, accuracy: 0.01)
    }
  }

  func test_playbackSpeed_boundsChecking() async {
    // Given: Episode is playing
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    // When: Setting speed below minimum
    await MainActor.run {
      localPlayer.setPlaybackSpeed(0.5) // Below minimum
    }
    
    // Then: Should clamp to minimum
    let minSpeed = await MainActor.run {
      localPlayer.playbackSpeed
    }
    XCTAssertGreaterThanOrEqual(minSpeed, 0.8)
    
    // When: Setting speed above maximum
    await MainActor.run {
      localPlayer.setPlaybackSpeed(6.0) // Above maximum
    }
    
    // Then: Should clamp to maximum
    let maxSpeed = await MainActor.run {
      localPlayer.playbackSpeed
    }
    XCTAssertLessThanOrEqual(maxSpeed, 5.0)
  }

  // MARK: - Audio Effects Tests
  // Covers: "Skipping Silences and Boosting Volume" from spec/playback.md

  func test_skipSilence_toggle() async {
    // Given: Episode is playing
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    // When: Enabling skip silence
    await MainActor.run {
      localPlayer.setSkipSilence(enabled: true)
    }
    
    // Then: Skip silence should be enabled
    let skipSilenceEnabled = await MainActor.run {
      localPlayer.isSkipSilenceEnabled
    }
    XCTAssertTrue(skipSilenceEnabled)
    
    // When: Disabling skip silence
    await MainActor.run {
      localPlayer.setSkipSilence(enabled: false)
    }
    
    // Then: Skip silence should be disabled
    let skipSilenceDisabled = await MainActor.run {
      localPlayer.isSkipSilenceEnabled
    }
    XCTAssertFalse(skipSilenceDisabled)
  }

  func test_volumeBoost_toggle() async {
    // Given: Episode is playing
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
    }
    
    // When: Enabling volume boost
    await MainActor.run {
      localPlayer.setVolumeBoost(enabled: true)
    }
    
    // Then: Volume boost should be enabled
    let volumeBoostEnabled = await MainActor.run {
      localPlayer.isVolumeBoostEnabled
    }
    XCTAssertTrue(volumeBoostEnabled)
    
    // When: Disabling volume boost
    await MainActor.run {
      localPlayer.setVolumeBoost(enabled: false)
    }
    
    // Then: Volume boost should be disabled
    let volumeBoostDisabled = await MainActor.run {
      localPlayer.isVolumeBoostEnabled
    }
    XCTAssertFalse(volumeBoostDisabled)
  }

  // MARK: - Chapter Navigation Tests
  // Covers: "Navigating Episode Chapters" from spec/playback.md

  func test_chapterNavigation_episodeWithChapters() async {
    // Given: Episode with chapters is playing
    let localPlayer = player!
    let localEpisodeWithChapters = episodeWithChapters
    
    await MainActor.run {
      localPlayer.play(episode: localEpisodeWithChapters, duration: 600)
    }
    
    // When: Navigating to next chapter
    await MainActor.run {
      localPlayer.nextChapter()
    }
    
    // Then: Position should advance to chapter boundary
    let position = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertGreaterThan(position, 0)
    
    // When: Navigating to previous chapter
    await MainActor.run {
      localPlayer.previousChapter()
    }
    
    // Then: Should return to beginning or previous chapter
    let newPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertLessThan(newPosition, position)
  }

  func test_chapterNavigation_episodeWithoutChapters() async {
    // Given: Episode without chapters is playing
    let localPlayer = player!
    let localSampleEpisode = sampleEpisode
    
    await MainActor.run {
      localPlayer.play(episode: localSampleEpisode, duration: 300)
      localPlayer.seek(to: 150)
    }
    
    let initialPosition = await MainActor.run {
      localPlayer.currentPosition
    }
    
    // When: Attempting to navigate chapters
    await MainActor.run {
      localPlayer.nextChapter()
    }
    
    // Then: Position should not change significantly
    let positionAfterNext = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertEqual(positionAfterNext, initialPosition, accuracy: 5.0)
    
    // When: Attempting previous chapter
    await MainActor.run {
      localPlayer.previousChapter()
    }
    
    // Then: Should go to beginning or not change much
    let positionAfterPrevious = await MainActor.run {
      localPlayer.currentPosition
    }
    XCTAssertLessThanOrEqual(positionAfterPrevious, initialPosition)
  }
}
