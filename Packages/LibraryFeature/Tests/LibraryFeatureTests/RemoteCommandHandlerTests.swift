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

  func testHandlePauseInvokesAction() {
    var pauseCount = 0
    let handler = RemoteCommandHandler(
      play: {},
      pause: { pauseCount += 1 },
      togglePlayPause: {},
      skipForward: { _ in },
      skipBackward: { _ in }
    )

    handler.handle(.pause)

    XCTAssertEqual(pauseCount, 1)
  }

  func testHandleTogglePlayPauseInvokesAction() {
    var toggleCount = 0
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: { toggleCount += 1 },
      skipForward: { _ in },
      skipBackward: { _ in }
    )

    handler.handle(.togglePlayPause)

    XCTAssertEqual(toggleCount, 1)
  }

  func testHandleSkipBackwardPassesInterval() {
    var receivedInterval: TimeInterval?
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: {},
      skipForward: { _ in },
      skipBackward: { interval in receivedInterval = interval }
    )

    handler.handle(.skipBackward, interval: 15)

    XCTAssertEqual(receivedInterval, 15)
  }

  func testHandleSkipForwardWithNilInterval() {
    var receivedInterval: TimeInterval? = 1
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: {},
      skipForward: { interval in receivedInterval = interval },
      skipBackward: { _ in }
    )

    handler.handle(.skipForward, interval: nil)

    XCTAssertNil(receivedInterval)
  }

  func testHandleSkipBackwardWithNilInterval() {
    var receivedInterval: TimeInterval? = 1
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: {},
      skipForward: { _ in },
      skipBackward: { interval in receivedInterval = interval }
    )

    handler.handle(.skipBackward, interval: nil)

    XCTAssertNil(receivedInterval)
  }

  func testHandleSkipForwardAcceptsZeroAndNegativeIntervals() {
    var receivedIntervals: [TimeInterval?] = []
    let handler = RemoteCommandHandler(
      play: {},
      pause: {},
      togglePlayPause: {},
      skipForward: { interval in receivedIntervals.append(interval) },
      skipBackward: { _ in }
    )

    handler.handle(.skipForward, interval: 0)
    handler.handle(.skipForward, interval: -15)

    XCTAssertEqual(receivedIntervals.count, 2)
    XCTAssertEqual(receivedIntervals[0], 0)
    XCTAssertEqual(receivedIntervals[1], -15)
  }
}
