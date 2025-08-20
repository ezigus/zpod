import CoreModels

public enum MockPodcast {
    public static func createSample(id: String = "pod-1", title: String = "Sample Podcast") -> Podcast {
        Podcast(id: id, title: title)
        
    }
}

public enum MockEpisode {
    public static func createSample(id: String = "ep-1", title: String = "Sample Episode", podcastID: String? = nil, playbackPosition: Int = 0, isPlayed: Bool = false) -> Episode {
        Episode(id: id, title: title, podcastID: podcastID, playbackPosition: playbackPosition, isPlayed: isPlayed)
    }
}