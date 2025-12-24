import Foundation

public enum RemoteCommandAction: Sendable {
  case play
  case pause
  case togglePlayPause
  case skipForward
  case skipBackward
}

public struct RemoteCommandHandler {
  private let playAction: () -> Void
  private let pauseAction: () -> Void
  private let togglePlayPauseAction: () -> Void
  private let skipForwardAction: (TimeInterval?) -> Void
  private let skipBackwardAction: (TimeInterval?) -> Void

  public init(
    play: @escaping () -> Void,
    pause: @escaping () -> Void,
    togglePlayPause: @escaping () -> Void,
    skipForward: @escaping (TimeInterval?) -> Void,
    skipBackward: @escaping (TimeInterval?) -> Void
  ) {
    self.playAction = play
    self.pauseAction = pause
    self.togglePlayPauseAction = togglePlayPause
    self.skipForwardAction = skipForward
    self.skipBackwardAction = skipBackward
  }

  public func handle(_ action: RemoteCommandAction, interval: TimeInterval? = nil) {
    switch action {
    case .play:
      playAction()
    case .pause:
      pauseAction()
    case .togglePlayPause:
      togglePlayPauseAction()
    case .skipForward:
      skipForwardAction(interval)
    case .skipBackward:
      skipBackwardAction(interval)
    }
  }
}
