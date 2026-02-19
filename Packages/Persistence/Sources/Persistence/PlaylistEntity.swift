import Foundation
import SwiftData
import CoreModels
import OSLog

/// SwiftData persistent model for `Playlist`.
@available(iOS 17, macOS 14, watchOS 10, *)
@Model
public final class PlaylistEntity {
    private static let logger = Logger(subsystem: "us.zig.zpod.persistence", category: "PlaylistEntity")
    @Attribute(.unique) public var id: String
    public var name: String
    /// Stored as `playlistDescription` to avoid collision with `NSObject.description`.
    public var playlistDescription: String
    public var episodeIds: [String]
    public var continuousPlayback: Bool
    public var shuffleAllowed: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        playlistDescription: String = "",
        episodeIds: [String] = [],
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.playlistDescription = playlistDescription
        self.episodeIds = episodeIds
        self.continuousPlayback = continuousPlayback
        self.shuffleAllowed = shuffleAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Domain Conversion

@available(iOS 17, macOS 14, watchOS 10, *)
extension PlaylistEntity {
    public func toDomain() -> Playlist {
        Playlist(
            id: id,
            name: name,
            description: playlistDescription,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func fromDomain(_ playlist: Playlist) -> PlaylistEntity {
        PlaylistEntity(
            id: playlist.id,
            name: playlist.name,
            playlistDescription: playlist.description,
            episodeIds: playlist.episodeIds,
            continuousPlayback: playlist.continuousPlayback,
            shuffleAllowed: playlist.shuffleAllowed,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt
        )
    }

    public func updateFrom(_ playlist: Playlist) {
        name = playlist.name
        playlistDescription = playlist.description
        episodeIds = playlist.episodeIds
        continuousPlayback = playlist.continuousPlayback
        shuffleAllowed = playlist.shuffleAllowed
        updatedAt = playlist.updatedAt
    }
}
