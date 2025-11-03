import XCTest
import PlaybackEngine
@testable import LibraryFeature

@MainActor
final class PlaybackEnvironmentTests: XCTestCase {

  override func setUp() {
    super.setUp()
    CarPlayDependencyRegistry.reset()
    PlaybackEnvironment.reset()
  }

  override func tearDown() {
    PlaybackEnvironment.reset()
    CarPlayDependencyRegistry.reset()
    super.tearDown()
  }

  func testPlaybackServiceIsSharedInstance() {
    let first = PlaybackEnvironment.playbackService
    let second = PlaybackEnvironment.playbackService
    XCTAssertTrue(first === second, "PlaybackEnvironment should return the cached playback service instance")
  }

  func testQueueManagerIsSharedWithPlaybackService() {
    let dependencies = PlaybackEnvironment.dependencies
    XCTAssertTrue(
      dependencies.playbackService === PlaybackEnvironment.playbackService,
      "Dependencies bundle should expose the same playback service instance"
    )
    XCTAssertTrue(
      dependencies.queueManager === PlaybackEnvironment.queueManager,
      "Dependencies bundle should expose the same queue manager instance"
    )
  }
}
