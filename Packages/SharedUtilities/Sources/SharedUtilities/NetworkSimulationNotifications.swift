import Foundation

public enum NetworkSimulationType: String, Sendable {
  case loss
  case recovery
  case poorQuality
  case wifiToCellular
}

public enum BufferSimulationType: String, Sendable {
  case empty
  case ready
  case seekWithinBuffer
  case seekOutsideBuffer
}

public enum PlaybackErrorSimulationType: String, Sendable {
  case recoverableNetworkError
  case serverError
  case notFound
  case timeout
}

public enum NetworkSimulationNotificationKey {
  public static let networkType = "NetworkSimulation.Type"
  public static let bufferType = "BufferSimulation.Type"
  public static let playbackErrorType = "PlaybackErrorSimulation.Type"
}

public extension Notification.Name {
  static let networkSimulation = Notification.Name("NetworkSimulation.StateChange")
  static let bufferSimulation = Notification.Name("BufferSimulation.StateChange")
  static let playbackErrorSimulation = Notification.Name("PlaybackErrorSimulation.StateChange")
}
