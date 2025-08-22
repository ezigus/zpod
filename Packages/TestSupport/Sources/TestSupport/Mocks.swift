import Foundation
import CoreModels

public enum MockPodcast {
    public static func createSample(id: String = "pod-1", title: String = "Sample Podcast") -> Podcast {
        Podcast(
            id: id, 
            title: title,
            author: "Sample Author",
            description: "Sample podcast description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!
        )
    }
}

public enum MockEpisode {
    public static func createSample(id: String = "ep-1", title: String = "Sample Episode", podcastID: String? = nil, playbackPosition: Int = 0, isPlayed: Bool = false) -> Episode {
        Episode(id: id, title: title, podcastID: podcastID, playbackPosition: playbackPosition, isPlayed: isPlayed)
    }
}