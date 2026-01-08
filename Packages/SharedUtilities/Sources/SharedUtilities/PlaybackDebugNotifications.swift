import Foundation

public enum PlaybackDebugInterruptionType: String, Sendable {
  case began
  case ended
}

public enum PlaybackDebugNotificationKey {
  public static let interruptionType = "PlaybackDebug.InterruptionType"
  public static let shouldResume = "PlaybackDebug.ShouldResume"
}

public extension Notification.Name {
  static let playbackDebugInterruption = Notification.Name("PlaybackDebug.Interruption")
}
