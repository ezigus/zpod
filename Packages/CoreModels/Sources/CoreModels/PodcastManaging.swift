import Foundation

public protocol PodcastManaging: Sendable {
    func all() -> [Podcast]
    func find(id: String) -> Podcast?
    func add(_ podcast: Podcast)
    func update(_ podcast: Podcast)
    func remove(id: String)
    func findByFolder(folderId: String) -> [Podcast]
    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast]
    func findByTag(tagId: String) -> [Podcast]
    func findUnorganized() -> [Podcast]
    func fetchOrphanedEpisodes() -> [Episode]
    func deleteOrphanedEpisode(id: String) -> Bool
    @discardableResult func deleteAllOrphanedEpisodes() -> Int
}

// MARK: - Podcast Library Change Notification

public extension Notification.Name {
    /// Posted by PodcastManaging implementations after add/update/remove mutations.
    /// Observers can reload their podcast list without polling or tab-switch triggers.
    static let podcastLibraryDidChange = Notification.Name("us.zig.zpod.podcastLibraryDidChange")
}
