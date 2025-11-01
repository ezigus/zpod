import Foundation
import CoreModels

// MARK: - Podcast Extensions for Testing

extension Podcast {
    /// Creates a copy of the podcast with updated subscription status
    ///
    /// - Parameter isSubscribed: The new subscription status
    /// - Returns: A new podcast instance with the updated subscription status
    public func withSubscriptionStatus(_ isSubscribed: Bool) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            description: self.description,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: self.episodes,
            isSubscribed: isSubscribed,
            dateAdded: self.dateAdded,
            folderId: self.folderId,
            tagIds: self.tagIds
        )
    }

    /// Creates a copy of the podcast with updated organizational metadata
    ///
    /// - Parameters:
    ///   - folderId: The folder identifier to assign
    ///   - tagIds: Tags that should be associated with the podcast
    /// - Returns: A new podcast instance with the updated organization values
    public func withOrganization(folderId: String?, tagIds: [String]) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            author: self.author,
            description: self.description,
            artworkURL: self.artworkURL,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: self.episodes,
            isSubscribed: self.isSubscribed,
            dateAdded: self.dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
    }
}

// MARK: - InMemoryPodcastManager Extensions for Testing

extension InMemoryPodcastManager {
    /// Returns all podcasts that are subscribed
    ///
    /// - Returns: Array of subscribed podcasts
    public func getSubscribedPodcasts() -> [Podcast] {
        return all().filter { $0.isSubscribed }
    }
}
