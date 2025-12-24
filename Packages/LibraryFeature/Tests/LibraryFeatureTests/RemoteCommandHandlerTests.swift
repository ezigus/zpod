import XCTest
@testable import LibraryFeature

final class RemoteCommandHandlerTests: XCTestCase {
  func testHandlePlayInvokesAction() {
    var playCount = 0
    let handler = RemoteCommandHandler(
      play: { playCount += 1 },
      pause: {},
      togglePlayPause: {},
      skipForward: { _ in },
      skipBackward: { _ in }
    )

    handler.handle(.play)

    XCTAssertEqual(playCount, 1)
  }

  func testHandleSkipForwardPassesInterval() {
    var receivedInterval: TimeInterval?
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: {},
      skipForward: { interval in receivedInterval = interval },
      skipBackward: { _ in }
    )

    handler.handle(.skipForward, interval: 42)

    XCTAssertEqual(receivedInterval, 42)
  }
}
