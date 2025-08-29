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
    
    public static func createWithFolder(id: String = "pod-1", title: String = "Sample Podcast", folderId: String) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: "Sample Author",
            description: "Sample podcast description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            folderId: folderId
        )
    }
    
    public static func createWithTags(id: String = "pod-1", title: String = "Sample Podcast", tagIds: [String]) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: "Sample Author",
            description: "Sample podcast description",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            tagIds: tagIds
        )
    }
    
    public static func createUnicode(id: String = "pod-unicode", title: String = "🎧 Programação em Swift 📱") -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: "João da Silva 🇧🇷",
            description: "Podcast sobre programação Swift em português with émojis 🚀",
            artworkURL: URL(string: "https://example.com/artwork-unicode.jpg"),
            feedURL: URL(string: "https://example.com/feed-unicode.xml")!
        )
    }
}

public enum MockEpisode {
    public static func createSample(id: String = "ep-1", title: String = "Sample Episode", podcastID: String? = nil, playbackPosition: Int = 0, isPlayed: Bool = false) -> Episode {
        Episode(id: id, title: title, podcastID: podcastID, playbackPosition: playbackPosition, isPlayed: isPlayed)
    }
    
    public static func createWithDuration(id: String = "ep-1", title: String = "Sample Episode", duration: TimeInterval = 3600.0) -> Episode {
        Episode(id: id, title: title, duration: duration)
    }
    
    public static func createUnicode(id: String = "ep-unicode", title: String = "🎵 Episódio especial", podcastID: String? = nil) -> Episode {
        Episode(
            id: id,
            title: title,
            podcastID: podcastID,
            duration: 2400.0,
            description: "Descrição com acentos and émojis 🎙️"
        )
    }
}

public enum MockFolder {
    public static func createSample(id: String = "folder-1", name: String = "Sample Folder", parentId: String? = nil) -> Folder {
        Folder(id: id, name: name, parentId: parentId)
    }
    
    public static func createRoot(id: String = "root-folder", name: String = "Root Folder") -> Folder {
        Folder(id: id, name: name, parentId: nil)
    }
    
    public static func createChild(id: String = "child-folder", name: String = "Child Folder", parentId: String) -> Folder {
        Folder(id: id, name: name, parentId: parentId)
    }
    
    public static func createUnicode(id: String = "folder-unicode", name: String = "📁 Pasta Especial", parentId: String? = nil) -> Folder {
        Folder(id: id, name: name, parentId: parentId)
    }
}

public enum MockPlaylist {
    public static func createManual(id: String = "playlist-1", name: String = "Sample Playlist", episodeIds: [String] = []) -> Playlist {
        Playlist(id: id, name: name, episodeIds: episodeIds)
    }
    
    public static func createSmart(id: String = "smart-1", name: String = "Smart Playlist") -> SmartPlaylist {
        SmartPlaylist(id: id, name: name)
    }
}

public enum MockDownloadTask {
    public static func createSample(
        id: String = "download-1",
        episodeId: String = "ep-1",
        podcastId: String = "pod-1",
        audioURL: URL = URL(string: "https://example.com/episode.mp3")!,
        title: String = "Sample Episode Download",
        priority: DownloadPriority = .normal
    ) -> DownloadTask {
        DownloadTask(
            id: id, 
            episodeId: episodeId, 
            podcastId: podcastId, 
            audioURL: audioURL, 
            title: title, 
            priority: priority
        )
    }
    
    public static func createWithProgress(
        id: String = "download-progress",
        episodeId: String = "ep-1",
        podcastId: String = "pod-1",
        title: String = "Download with Progress"
    ) -> DownloadTask {
        DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            audioURL: URL(string: "https://example.com/episode.mp3")!,
            title: title,
            priority: .normal
        )
    }
}