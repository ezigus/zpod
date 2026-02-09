import Foundation

public enum NetworkSimulationType: String, Sendable {
  case loss
  case recovery
  case poorQuality
}

public enum BufferSimulationType: String, Sendable {
  case empty
  case ready
}

public enum NetworkSimulationNotificationKey {
  public static let networkType = "NetworkSimulation.Type"
  public static let bufferType = "BufferSimulation.Type"
}

public extension Notification.Name {
  static let networkSimulation = Notification.Name("NetworkSimulation.StateChange")
  static let bufferSimulation = Notification.Name("BufferSimulation.StateChange")
}
