import XCTest
@testable import CoreModels
@testable import Persistence

@available(iOS 17, macOS 14, watchOS 10, *)
final class EpisodeEntityTests: XCTestCase {

    // MARK: - Domain Conversion Tests

    func testDomainConversionRoundTrip() {
        let episode = makeEpisode(
            id: "ep-1",
            title: "Test Episode",
            playbackPosition: 1234,
            downloadStatus: .downloaded,
            isFavorited: true
        )

        let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
        let converted = entity.toDomain()

        XCTAssertEqual(converted.id, episode.id)
        XCTAssertEqual(converted.title, episode.title)
        XCTAssertEqual(converted.playbackPosition, episode.playbackPosition)
        XCTAssertEqual(converted.downloadStatus, episode.downloadStatus)
        XCTAssertEqual(converted.isFavorited, episode.isFavorited)
        XCTAssertEqual(converted.podcastTitle, episode.podcastTitle)
    }

    func testDomainConversionPreservesAllFields() {
        let episode = makeEpisode(
            id: "ep-full",
            title: "Full Episode",
            podcastTitle: "Test Podcast",
            playbackPosition: 5000,
            isPlayed: true,
            pubDate: Date(timeIntervalSince1970: 1234567890),
            duration: 3600,
            description: "Episode description",
            audioURL: URL(string: "https://example.com/audio.mp3"),
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            downloadStatus: .downloaded,
            isFavorited: true,
            isBookmarked: true,
            isArchived: false,
            rating: 5,
            dateAdded: Date(timeIntervalSince1970: 9876543210)
        )

        let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
        let converted = entity.toDomain()

        XCTAssertEqual(converted.id, episode.id)
        XCTAssertEqual(converted.title, episode.title)
        XCTAssertEqual(converted.podcastTitle, episode.podcastTitle)
        XCTAssertEqual(converted.playbackPosition, episode.playbackPosition)
        XCTAssertEqual(converted.isPlayed, episode.isPlayed)
        XCTAssertEqual(converted.pubDate?.timeIntervalSince1970, episode.pubDate?.timeIntervalSince1970)
        XCTAssertEqual(converted.duration, episode.duration)
        XCTAssertEqual(converted.description, episode.description)
        XCTAssertEqual(converted.audioURL, episode.audioURL)
        XCTAssertEqual(converted.artworkURL, episode.artworkURL)
        XCTAssertEqual(converted.downloadStatus, episode.downloadStatus)
        XCTAssertEqual(converted.isFavorited, episode.isFavorited)
        XCTAssertEqual(converted.isBookmarked, episode.isBookmarked)
        XCTAssertEqual(converted.isArchived, episode.isArchived)
        XCTAssertEqual(converted.rating, episode.rating)
        XCTAssertEqual(converted.dateAdded.timeIntervalSince1970, episode.dateAdded.timeIntervalSince1970, accuracy: 1.0)
    }

    func testUpdateFromPreservesDateAdded() {
        let originalDate = Date(timeIntervalSince1970: 1000000)
        let entity = EpisodeEntity(
            id: "ep-1",
            podcastId: "podcast-1",
            title: "Original",
            podcastTitle: "Podcast",
            dateAdded: originalDate
        )

        let updated = makeEpisode(
            id: "ep-1",
            title: "Updated Title",
            playbackPosition: 999,
            dateAdded: Date()  // Different date
        )

        entity.updateFrom(updated)

        XCTAssertEqual(entity.title, "Updated Title")
        XCTAssertEqual(entity.playbackPosition, 999)
        XCTAssertEqual(entity.dateAdded, originalDate, "dateAdded should not change on update")
    }

    func testToDomainSafeLogsInvalidValuesButReturnsEpisode() {
        // Invalid downloadStatus and URLs should not crash and should log
        let entity = EpisodeEntity(
            id: "bad-episode",
            podcastId: "pod-1",
            title: "Bad",
            podcastTitle: "Pod",
            episodeDescription: nil,
            audioURLString: "not a url",
            artworkURLString: "also bad",
            pubDate: nil,
            duration: nil,
            playbackPosition: 0,
            isPlayed: false,
            downloadStatus: "nonsense",
            isFavorited: false,
            isBookmarked: false,
            isArchived: false,
            rating: nil,
            dateAdded: Date(timeIntervalSince1970: 1)
        )

        let episode = entity.toDomainSafe()

        XCTAssertEqual(episode.downloadStatus, .notDownloaded, "Invalid raw value should default safely")
        XCTAssertNil(episode.audioURL)
        XCTAssertNil(episode.artworkURL)
    }

    func testUpdateMetadataOnlyPreservesUserState() {
        let entity = EpisodeEntity(
            id: "ep-1",
            podcastId: "podcast-1",
            title: "Original",
            podcastTitle: "Podcast",
            playbackPosition: 1234,
            isPlayed: true,
            downloadStatus: "downloaded",
            isFavorited: true
        )

        let updated = makeEpisode(
            id: "ep-1",
            title: "Updated Title",
            playbackPosition: 0,  // Should NOT be updated
            isPlayed: false,  // Should NOT be updated
            description: "New description",
            isFavorited: false  // Should NOT be updated
        )

        entity.updateMetadataFrom(updated)

        // Metadata should update
        XCTAssertEqual(entity.title, "Updated Title")
        XCTAssertEqual(entity.episodeDescription, "New description")

        // User state should be preserved
        XCTAssertEqual(entity.playbackPosition, 1234, "Playback position should not change")
        XCTAssertEqual(entity.isPlayed, true, "Played status should not change")
        XCTAssertEqual(entity.downloadStatus, "downloaded", "Download status should not change")
        XCTAssertEqual(entity.isFavorited, true, "Favorited status should not change")
    }

    func testDownloadStatusConversion() {
        for status in EpisodeDownloadStatus.allCases {
            let episode = makeEpisode(id: "ep-\(status)", downloadStatus: status)
            let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
            let converted = entity.toDomain()

            XCTAssertEqual(converted.downloadStatus, status,
                           "Download status \(status) should round-trip correctly")
        }
    }

    func testNilOptionalFields() {
        let episode = makeEpisode(
            id: "ep-minimal",
            title: "Minimal Episode",
            pubDate: nil,
            duration: nil,
            description: nil,
            audioURL: nil,
            artworkURL: nil,
            rating: nil
        )

        let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
        let converted = entity.toDomain()

        XCTAssertNil(converted.description)
        XCTAssertNil(converted.audioURL)
        XCTAssertNil(converted.artworkURL)
        XCTAssertNil(converted.pubDate)
        XCTAssertNil(converted.duration)
        XCTAssertNil(converted.rating)
    }

    // MARK: - Helpers

    private func makeEpisode(
        id: String,
        title: String = "Test Episode",
        podcastTitle: String = "Test Podcast",
        playbackPosition: Int = 0,
        isPlayed: Bool = false,
        pubDate: Date? = nil,
        duration: TimeInterval? = nil,
        description: String? = nil,
        audioURL: URL? = nil,
        artworkURL: URL? = nil,
        downloadStatus: EpisodeDownloadStatus = .notDownloaded,
        isFavorited: Bool = false,
        isBookmarked: Bool = false,
        isArchived: Bool = false,
        rating: Int? = nil,
        dateAdded: Date = Date()
    ) -> Episode {
        Episode(
            id: id,
            title: title,
            podcastID: "podcast-1",
            podcastTitle: podcastTitle,
            playbackPosition: playbackPosition,
            isPlayed: isPlayed,
            pubDate: pubDate,
            duration: duration,
            description: description,
            audioURL: audioURL,
            artworkURL: artworkURL,
            downloadStatus: downloadStatus,
            isFavorited: isFavorited,
            isBookmarked: isBookmarked,
            isArchived: isArchived,
            rating: rating,
            dateAdded: dateAdded
        )
    }
}
