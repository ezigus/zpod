@preconcurrency import Foundation

public struct Episode: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var podcastID: String?
    public var playbackPosition: Int
    public var isPlayed: Bool
    public var pubDate: Date?
    public var duration: TimeInterval?
    public var description: String?
    public var audioURL: URL?

    public init(
        id: String, 
        title: String, 
        podcastID: String? = nil, 
        playbackPosition: Int = 0, 
        isPlayed: Bool = false,
        pubDate: Date? = nil,
        duration: TimeInterval? = nil,
        description: String? = nil,
        audioURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.podcastID = podcastID
        self.playbackPosition = playbackPosition
        self.isPlayed = isPlayed
        self.pubDate = pubDate
        self.duration = duration
        self.description = description
        self.audioURL = audioURL
    }

    public func withPlaybackPosition(_ position: Int) -> Episode {
        var copy = self
        copy.playbackPosition = position
        return copy
    }

    public func withPlayedStatus(_ played: Bool) -> Episode {
        var copy = self
        copy.isPlayed = played
        return copy
    }
}
