import Foundation

public protocol FolderManaging: Sendable {
    func all() -> [Folder]
    func find(id: String) -> Folder?
    func add(_ folder: Folder) throws
    func update(_ folder: Folder) throws
    func remove(id: String) throws
    func getChildren(of folderId: String) -> [Folder]
    func getDescendants(of folderId: String) -> [Folder]
    func getRootFolders() -> [Folder]
}
