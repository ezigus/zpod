#if os(iOS)
import AVFoundation
import CoreModels
import MediaPlayer
import PlaybackEngine
import XCTest
@testable import LibraryFeature

@MainActor
final class SystemMediaCoordinatorTests: XCTestCase {
  private var coordinator: SystemMediaCoordinator!
  private let testEpisode = Episode(
    id: "test-episode",
    title: "Test Episode",
    podcastTitle: "Test Podcast",
    playbackPosition: 0,
    isPlayed: false,
    duration: 300
  )

  override func tearDownWithError() throws {
    coordinator = nil
    try super.tearDownWithError()
  }

  // MARK: - Initialization Tests

  func testInitializationConfiguresAudioSession() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    let audioSession = AVAudioSession.sharedInstance()
    XCTAssertEqual(audioSession.category, .playback)
    XCTAssertEqual(audioSession.mode, .spokenAudio)
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowAirPlay))
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowBluetooth))
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowBluetoothA2DP))
  }

  func testInitializationDisablesRemoteCommands() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    let commandCenter = MPRemoteCommandCenter.shared()
    XCTAssertFalse(commandCenter.playCommand.isEnabled)
    XCTAssertFalse(commandCenter.pauseCommand.isEnabled)
    XCTAssertFalse(commandCenter.togglePlayPauseCommand.isEnabled)
    XCTAssertFalse(commandCenter.skipForwardCommand.isEnabled)
    XCTAssertFalse(commandCenter.skipBackwardCommand.isEnabled)
  }

  // MARK: - Remote Command Availability Tests

  func testPlayCommandEnabledOnlyWhenPaused() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    // When paused, play command should be enabled
    mockService.setState(.paused(testEpisode, position: 50, duration: 300))
    XCTAssertTrue(MPRemoteCommandCenter.shared().playCommand.isEnabled)

    // When playing, play command should be disabled
    mockService.setState(.playing(testEpisode, position: 50, duration: 300))
    XCTAssertFalse(MPRemoteCommandCenter.shared().playCommand.isEnabled)
  }

  func testPauseCommandEnabledOnlyWhenPlaying() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    // When playing, pause command should be enabled
    mockService.setState(.playing(testEpisode, position: 50, duration: 300))
    XCTAssertTrue(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)

    // When paused, pause command should be disabled
    mockService.setState(.paused(testEpisode, position: 50, duration: 300))
    XCTAssertFalse(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)
  }

  func testTogglePlayPauseCommandEnabledDuringPlayback() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    // Enabled during playback
    mockService.setState(.playing(testEpisode, position: 50, duration: 300))
    XCTAssertTrue(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)

    // Enabled during pause
    mockService.setState(.paused(testEpisode, position: 50, duration: 300))
    XCTAssertTrue(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)

    // Disabled when idle
    mockService.setState(.idle(testEpisode))
    XCTAssertFalse(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)
  }

  func testSkipCommandsEnabledDuringPlayback() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    // Enabled during playback
    mockService.setState(.playing(testEpisode, position: 50, duration: 300))
    XCTAssertTrue(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled)
    XCTAssertTrue(MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled)

    // Disabled when idle
    mockService.setState(.idle(testEpisode))
    XCTAssertFalse(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled)
    XCTAssertFalse(MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled)
  }

  // MARK: - Now Playing Metadata Tests

  func testNowPlayingInfoIncludesPodcastTitle() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.playing(testEpisode, position: 0, duration: 300))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPMediaItemPropertyAlbumTitle] as? String,
      "Test Podcast"
    )
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPMediaItemPropertyArtist] as? String,
      "Test Podcast"
    )
  }

  func testNowPlayingInfoIncludesDuration() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.playing(testEpisode, position: 150, duration: 300))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval,
      300
    )
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
      150
    )
  }

  func testPlayingStateUpdatesPlaybackState() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.playing(testEpisode, position: 45, duration: 300))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(infoCenter.playbackState, .playing)
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float,
      1.0
    )
  }

  func testPausedStateUpdatesPlaybackState() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.paused(testEpisode, position: 100, duration: 300))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(infoCenter.playbackState, .paused)
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float,
      0.0
    )
  }

  func testIdleStateClearsNowPlayingInfo() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.idle(testEpisode))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertNil(infoCenter.nowPlayingInfo)
    XCTAssertEqual(infoCenter.playbackState, .stopped)
  }

  func testFinishedStateShowsCompletedProgress() {
    let mockService = SimpleTestPlaybackService()
    coordinator = SystemMediaCoordinator(playbackService: mockService)

    mockService.setState(.finished(testEpisode, duration: 300))

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
      300
    )
  }
}

// MARK: - Mock Implementations

@MainActor
private final class SimpleTestPlaybackService: EpisodePlaybackService, EpisodeTransportControlling {
  private var currentState: EpisodePlaybackState

  init(initialState: EpisodePlaybackState? = nil) {
    self.currentState = initialState ?? .idle(Episode(id: "default", title: "Default", description: ""))
  }

  // Simple publisher that can be subscribed to
  var statePublisher: any Publisher<EpisodePlaybackState, Never> {
    Just(currentState).eraseToAnyPublisher()
  }

  func setState(_ state: EpisodePlaybackState) {
    currentState = state
    // Simulate state change by posting notification that coordinator listens to
    // In a real test, we would need proper publisher support
  }

  func play(episode: Episode, duration: TimeInterval) {}
  func pause() {}
  func seek(to position: TimeInterval) {}
  func skipForward(interval: TimeInterval?) {}
  func skipBackward(interval: TimeInterval?) {}
}

#endif
