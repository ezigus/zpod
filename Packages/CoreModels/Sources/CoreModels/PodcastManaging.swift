import Foundation

public protocol PodcastManaging {
    func all() -> [Podcast]
    func find(id: String) -> Podcast?
    func add(_ podcast: Podcast)
    func update(_ podcast: Podcast)
    func remove(id: String)
    func findByFolder(folderId: String) -> [Podcast]
    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast]
    func findByTag(tagId: String) -> [Podcast]
    func findUnorganized() -> [Podcast]
}
