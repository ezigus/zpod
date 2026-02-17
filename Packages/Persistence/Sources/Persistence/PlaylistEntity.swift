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
    public var episodeIds: [String]
    public var continuousPlayback: Bool
    public var shuffleAllowed: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        episodeIds: [String] = [],
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
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
            episodeIds: playlist.episodeIds,
            continuousPlayback: playlist.continuousPlayback,
            shuffleAllowed: playlist.shuffleAllowed,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt
        )
    }

    public func updateFrom(_ playlist: Playlist) {
        name = playlist.name
        episodeIds = playlist.episodeIds
        continuousPlayback = playlist.continuousPlayback
        shuffleAllowed = playlist.shuffleAllowed
        updatedAt = playlist.updatedAt
    }
}
