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
