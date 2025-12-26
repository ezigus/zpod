#if os(iOS)
import AVFoundation
import CombineSupport
import CoreModels
import MediaPlayer
import PlaybackEngine
import UIKit
import XCTest
@testable import LibraryFeature

final class SystemMediaCoordinatorTests: XCTestCase {
  private var coordinator: SystemMediaCoordinator!
  private var playbackService: RecordingPlaybackService!

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
    playbackService = nil
    try super.tearDownWithError()
  }

  // MARK: - Initialization Tests

  @MainActor
  func testInitializationConfiguresAudioSession() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    let audioSession = AVAudioSession.sharedInstance()
    XCTAssertEqual(audioSession.category, .playback)
    XCTAssertEqual(audioSession.mode, .spokenAudio)
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowAirPlay))
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowBluetoothHFP))
    XCTAssertTrue(audioSession.categoryOptions.contains(.allowBluetoothA2DP))
  }

  @MainActor
  func testInitializationDisablesRemoteCommands() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    let commandCenter = MPRemoteCommandCenter.shared()
    XCTAssertFalse(commandCenter.playCommand.isEnabled)
    XCTAssertFalse(commandCenter.pauseCommand.isEnabled)
    XCTAssertFalse(commandCenter.togglePlayPauseCommand.isEnabled)
    XCTAssertFalse(commandCenter.skipForwardCommand.isEnabled)
    XCTAssertFalse(commandCenter.skipBackwardCommand.isEnabled)
  }

  // MARK: - Remote Command Availability Tests

  @MainActor
  func testPlayCommandEnabledOnlyWhenPaused() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.paused(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertTrue(MPRemoteCommandCenter.shared().playCommand.isEnabled)

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertFalse(MPRemoteCommandCenter.shared().playCommand.isEnabled)
  }

  @MainActor
  func testPauseCommandEnabledOnlyWhenPlaying() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertTrue(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)

    playbackService.setState(.paused(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertFalse(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)
  }

  @MainActor
  func testTogglePlayPauseCommandEnabledDuringPlayback() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertTrue(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)

    playbackService.setState(.paused(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertTrue(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)

    playbackService.setState(.idle(testEpisode))
    advanceRunLoop()
    XCTAssertFalse(MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled)
  }

  @MainActor
  func testSkipCommandsEnabledDuringPlayback() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()
    XCTAssertTrue(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled)
    XCTAssertTrue(MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled)

    playbackService.setState(.idle(testEpisode))
    advanceRunLoop()
    XCTAssertFalse(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled)
    XCTAssertFalse(MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled)
  }

  // MARK: - Now Playing Metadata Tests

  @MainActor
  func testNowPlayingInfoIncludesPodcastTitle() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 0, duration: 300))
    advanceRunLoop()

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

  @MainActor
  func testNowPlayingInfoIncludesDuration() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 150, duration: 300))
    advanceRunLoop()

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

  @MainActor
  func testPlayingStateUpdatesPlaybackState() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 45, duration: 300))
    advanceRunLoop()

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(infoCenter.playbackState, .playing)
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float,
      1.0
    )
  }

  @MainActor
  func testPausedStateUpdatesPlaybackState() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.paused(testEpisode, position: 100, duration: 300))
    advanceRunLoop()

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(infoCenter.playbackState, .paused)
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Float,
      0.0
    )
  }

  @MainActor
  func testIdleStateClearsNowPlayingInfo() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.idle(testEpisode))
    advanceRunLoop()

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertNil(infoCenter.nowPlayingInfo)
    XCTAssertEqual(infoCenter.playbackState, .stopped)
  }

  @MainActor
  func testFinishedStateShowsCompletedProgress() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.finished(testEpisode, duration: 300))
    advanceRunLoop()

    let infoCenter = MPNowPlayingInfoCenter.default()
    XCTAssertEqual(
      infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
      300
    )
  }

  @MainActor
  func testNowPlayingInfoClearsArtworkWhenMissing() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    let infoCenter = MPNowPlayingInfoCenter.default()
    let image = UIImage(systemName: "music.note") ?? UIImage()
    infoCenter.nowPlayingInfo = [
      MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    ]

    playbackService.setState(.playing(testEpisode, position: 0, duration: 300))
    advanceRunLoop()

    XCTAssertNil(infoCenter.nowPlayingInfo?[MPMediaItemPropertyArtwork])
  }

  // MARK: - Helpers

  @MainActor
  private func advanceRunLoop() {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
  }

  @MainActor
  private func prepareCoordinator() {
    playbackService = RecordingPlaybackService(
      initialState: .idle(Episode(id: "idle", title: "Idle", description: ""))
    )
    coordinator = SystemMediaCoordinator(playbackService: playbackService)
  }

  @MainActor
  private func resetNowPlayingState() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.isEnabled = false
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.isEnabled = false

    let infoCenter = MPNowPlayingInfoCenter.default()
    infoCenter.nowPlayingInfo = nil
    infoCenter.playbackState = .stopped
  }

  // MARK: - Audio Interruption Tests

  @MainActor
  func testAudioInterruptionBegan_PausesPlayback() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    // Simulate phone call interruption
    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.pauseCallCount, 1, "Should pause on interruption began")
  }

  @MainActor
  func testAudioInterruptionEnded_ResumesIfWasPlaying() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    // Start playing, then interrupt
    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
      ]
    )
    advanceRunLoop()

    // Clear previous call counts
    playbackService.playCallCount = 0

    // Resume interruption with shouldResume=yes
    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
        AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.playCallCount, 1, "Should resume playback when shouldResume is set")
  }

  @MainActor
  func testAudioInterruptionEnded_DoesNotResumeIfShouldResumeNotSet() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
      ]
    )
    advanceRunLoop()

    playbackService.playCallCount = 0

    // Resume interruption without shouldResume
    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
        AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.init(rawValue: 0).rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.playCallCount, 0, "Should not resume if shouldResume not set")
  }

  @MainActor
  func testAudioInterruptionBeganWhilePaused_DoesNotChangeState() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.paused(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    playbackService.pauseCallCount = 0

    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.pauseCallCount, 0, "Should not pause when already paused")
  }

  // MARK: - Audio Route Change Tests

  @MainActor
  func testHeadphonesUnplug_PausesPlayback() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    // Simulate headphones being unplugged
    NotificationCenter.default.post(
      name: AVAudioSession.routeChangeNotification,
      object: nil,
      userInfo: [
        AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.pauseCallCount, 1, "Should pause when headphones unplugged")
  }

  @MainActor
  func testOtherRouteChanges_DoNotPausePlayback() {
    prepareCoordinator()
    defer { resetNowPlayingState() }

    playbackService.setState(.playing(testEpisode, position: 50, duration: 300))
    advanceRunLoop()

    playbackService.pauseCallCount = 0

    // Other route change reasons should not pause
    NotificationCenter.default.post(
      name: AVAudioSession.routeChangeNotification,
      object: nil,
      userInfo: [
        AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.categoryChange.rawValue
      ]
    )
    advanceRunLoop()

    XCTAssertEqual(playbackService.pauseCallCount, 0, "Should not pause on non-destructive route changes")
  }

}

@MainActor
private final class RecordingPlaybackService: EpisodePlaybackService, EpisodeTransportControlling {
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>

  // Invocation tracking for verification
  var playCallCount = 0
  var lastPlayedEpisode: Episode?
  var lastPlayDuration: TimeInterval?

  var pauseCallCount = 0

  var seekCallCount = 0
  var lastSeekPosition: TimeInterval?

  var skipForwardCallCount = 0
  var lastSkipForwardInterval: TimeInterval?

  var skipBackwardCallCount = 0
  var lastSkipBackwardInterval: TimeInterval?

  init(initialState: EpisodePlaybackState) {
    subject = CurrentValueSubject(initialState)
  }

  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }

  func setState(_ state: EpisodePlaybackState) {
    subject.send(state)
  }

  func play(episode: Episode, duration: TimeInterval?) {
    playCallCount += 1
    lastPlayedEpisode = episode
    lastPlayDuration = duration
  }

  func pause() {
    pauseCallCount += 1
  }

  func seek(to position: TimeInterval) {
    seekCallCount += 1
    lastSeekPosition = position
  }

  func skipForward(interval: TimeInterval?) {
    skipForwardCallCount += 1
    lastSkipForwardInterval = interval
  }

  func skipBackward(interval: TimeInterval?) {
    skipBackwardCallCount += 1
    lastSkipBackwardInterval = interval
  }
}

#endif
