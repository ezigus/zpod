import Foundation
import CoreModels

/// In-memory implementation of FolderManaging suitable for testing and early development.
/// Thread-safety: Not yet synchronized; assume single-threaded access for initial phase.
public final class InMemoryFolderManager: FolderManaging {
    private var storage: [String: Folder] = [:]
    
    public init(initial: [Folder] = []) {
        for folder in initial { storage[folder.id] = folder }
    }
    
    public func all() -> [Folder] { 
        Array(storage.values) 
    }
    
    public func find(id: String) -> Folder? { 
        storage[id] 
    }
    
    public func add(_ folder: Folder) throws {
        // Enforce id uniqueness; allow idempotent re-add of identical value
        if let existing = storage[folder.id] {
            if existing == folder { return } // idempotent no-op
            throw TestSupportError.duplicateId("Folder with id '\(folder.id)' already exists")
        }
        
        // Validate parent exists if specified
        if let parentId = folder.parentId {
            guard storage[parentId] != nil else {
                throw TestSupportError.invalidParent("Parent folder '\(parentId)' does not exist")
            }
        }
        
        storage[folder.id] = folder
    }
    
    public func update(_ folder: Folder) throws {
        guard storage[folder.id] != nil else { 
            throw TestSupportError.notFound("Folder with id '\(folder.id)' not found")
        }
        
        // Validate parent exists if specified
        if let parentId = folder.parentId {
            guard storage[parentId] != nil else {
                throw TestSupportError.invalidParent("Parent folder '\(parentId)' does not exist")
            }
            
            // Check for circular reference by traversing up the parent chain
            if wouldCreateCircularReference(folderId: folder.id, proposedParentId: parentId) {
                throw TestSupportError.circularReference("Updating folder '\(folder.id)' would create a circular reference")
            }
        }
        
        storage[folder.id] = folder
    }
    
    private func wouldCreateCircularReference(folderId: String, proposedParentId: String) -> Bool {
        var currentId: String? = proposedParentId
        
        while let current = currentId {
            if current == folderId {
                return true // Found a cycle
            }
            currentId = storage[current]?.parentId
        }
        
        return false
    }
    
    public func remove(id: String) throws {
        guard storage[id] != nil else { 
            throw TestSupportError.notFound("Folder with id '\(id)' not found")
        }
        
        // Check if folder has children
        let children = getChildren(of: id)
        guard children.isEmpty else {
            throw TestSupportError.hasChildren("Cannot remove folder '\(id)' that has children")
        }
        
        storage.removeValue(forKey: id)
    }
    
    public func getChildren(of folderId: String) -> [Folder] {
        storage.values.filter { $0.parentId == folderId }
    }
    
    public func getDescendants(of folderId: String) -> [Folder] {
        var descendants: [Folder] = []
        let children = getChildren(of: folderId)
        
        for child in children {
            descendants.append(child)
            descendants.append(contentsOf: getDescendants(of: child.id))
        }
        
        return descendants
    }
    
    public func getRootFolders() -> [Folder] {
        storage.values.filter { $0.parentId == nil }
    }
}

public enum TestSupportError: Error, LocalizedError, Sendable, Equatable {
    case duplicateId(String)
    case notFound(String)
    case invalidParent(String)
    case hasChildren(String)
    case circularReference(String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateId(let message):
            return "Duplicate ID: \(message)"
        case .notFound(let message):
            return "Not Found: \(message)"
        case .invalidParent(let message):
            return "Invalid Parent: \(message)"
        case .hasChildren(let message):
            return "Has Children: \(message)"
        case .circularReference(let message):
            return "Circular Reference: \(message)"
        }
    }
}
