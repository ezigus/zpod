import Foundation

/// Represents a folder for hierarchical organization of podcasts
public struct Folder: Codable, Equatable {
  /// Unique identifier for the folder
  public let id: String
  /// Display name of the folder
  public let name: String
  /// Parent folder ID for hierarchical organization (nil for root folders)
  public let parentId: String?
  /// When the folder was created
  public let dateCreated: Date
  
  public init(
    id: String,
    name: String,
    parentId: String? = nil,
    dateCreated: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.parentId = parentId
    self.dateCreated = dateCreated
  }
  
  /// Returns true if this is a root-level folder (no parent)
  public var isRoot: Bool {
    return parentId == nil
  }
}

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