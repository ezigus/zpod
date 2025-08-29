import Foundation

/// Represents a tag for flat organization of podcasts
public struct Tag: Codable, Equatable, Sendable {
  /// Unique identifier for the tag
  public let id: String
  /// Display name of the tag
  public let name: String
  /// When the tag was created
  public let dateCreated: Date
  public init(
    id: String,
    name: String,
    dateCreated: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.dateCreated = dateCreated
  }
}
