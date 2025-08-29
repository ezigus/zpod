import Foundation
import CoreModels

/// Re-export CoreModels' FolderManaging to avoid duplication and ambiguity across modules.
public typealias FolderManaging = CoreModels.FolderManaging

/// Folder management errors.
public enum FolderError: Error, Equatable {
  case parentNotFound(String)
  case circularReference(String)
  case hasChildren(String)
  case containsPodcasts(String)
}

// InMemoryFolderManager implementation moved to TestSupport package to avoid duplication

/// Protocol defining tag management responsibilities for flat organization.
public protocol TagManaging {
  /// Returns all stored tags.
  func all() -> [Tag]
  /// Finds a tag by id.
  func find(id: String) -> Tag?
  /// Adds a new tag if it does not already exist (id uniqueness enforced).
  func add(_ tag: Tag)
  /// Updates an existing tag (matched by id); no-op if not present.
  func update(_ tag: Tag)
  /// Removes a tag by id; no-op if absent.
  func remove(id: String)
}

/// In-memory implementation suitable for early development & unit testing.
public final class InMemoryTagManager: TagManaging {
  private var storage: [String: Tag] = [:]
  
  public init(initial: [Tag] = []) {
    for tag in initial { 
      storage[tag.id] = tag 
    }
  }
  
  public func all() -> [Tag] { 
    Array(storage.values) 
  }
  
  public func find(id: String) -> Tag? { 
    storage[id] 
  }
  
  public func add(_ tag: Tag) {
    // Enforce id uniqueness; ignore if already present
    guard storage[tag.id] == nil else { return }
    storage[tag.id] = tag
  }
  
  public func update(_ tag: Tag) {
    guard storage[tag.id] != nil else { return }
    storage[tag.id] = tag
  }
  
  public func remove(id: String) { 
    storage.removeValue(forKey: id) 
  }
}
