import XCTest
@testable import CoreModels
@testable import Persistence
@testable import TestSupport

@available(iOS 17, macOS 14, watchOS 10, *)
final class EpisodeEntityTests: XCTestCase {

    // MARK: - Domain Conversion Tests

    func testDomainConversionRoundTrip() {
        let episode = MockEpisode.create(
            id: "ep-1",
            title: "Test Episode",
            podcastID: "podcast-1",
            playbackPosition: 1234,
            downloadStatus: .downloaded,
            isFavorited: true
        )

        let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
        let converted = entity.toDomain()

        XCTAssertEqual(converted.id, episode.id)
        XCTAssertEqual(converted.title, episode.title)
        XCTAssertEqual(converted.podcastID, episode.podcastID)
        XCTAssertEqual(converted.playbackPosition, episode.playbackPosition)
        XCTAssertEqual(converted.downloadStatus, episode.downloadStatus)
        XCTAssertEqual(converted.isFavorited, episode.isFavorited)
        XCTAssertEqual(converted.podcastTitle, episode.podcastTitle)
    }

    func testDomainConversionPreservesAllFields() {
        let episode = MockEpisode.create(
            id: "ep-full",
            title: "Full Episode",
            podcastID: "podcast-1",
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
        XCTAssertEqual(converted.podcastID, episode.podcastID)
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

        let updated = MockEpisode.create(
            id: "ep-1",
            title: "Updated Title",
            podcastID: "podcast-1",
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
            audioURLString: "http:// bad.com",
            artworkURLString: "ht!tp://bad url",
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
        XCTAssertEqual(episode.id, "bad-episode")
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

        let updated = MockEpisode.create(
            id: "ep-1",
            title: "Updated Title",
            podcastID: "podcast-1",
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
            let episode = MockEpisode.create(id: "ep-\(status)", podcastID: "podcast-1", downloadStatus: status)
            let entity = EpisodeEntity.fromDomain(episode, podcastId: "podcast-1")
            let converted = entity.toDomain()

            XCTAssertEqual(converted.downloadStatus, status,
                           "Download status \(status) should round-trip correctly")
        }
    }

    func testNilOptionalFields() {
        let episode = MockEpisode.create(
            id: "ep-minimal",
            title: "Minimal Episode",
            podcastID: "podcast-1",
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

    func testHasUserStateCoversAllStatefulFlags() {
        let entity = EpisodeEntity(
            id: "ep-state",
            podcastId: "pod-1",
            title: "Stateful",
            podcastTitle: "Podcast",
            playbackPosition: 0,
            isPlayed: false,
            downloadStatus: EpisodeDownloadStatus.downloaded.rawValue,
            isFavorited: false,
            isBookmarked: false,
            isArchived: false,
            rating: nil,
            dateAdded: Date()
        )

        XCTAssertTrue(entity.hasUserState, "Downloaded episodes should be treated as having user state")

        entity.downloadStatus = EpisodeDownloadStatus.notDownloaded.rawValue
        entity.playbackPosition = 10
        XCTAssertTrue(entity.hasUserState, "Playback position > 0 is user state")

        entity.playbackPosition = 0
        entity.downloadStatus = EpisodeDownloadStatus.downloading.rawValue
        XCTAssertTrue(entity.hasUserState, "Downloading should be treated as user state")

        entity.downloadStatus = EpisodeDownloadStatus.paused.rawValue
        XCTAssertTrue(entity.hasUserState, "Paused download should be treated as user state")

        entity.downloadStatus = EpisodeDownloadStatus.failed.rawValue
        XCTAssertTrue(entity.hasUserState, "Failed download still reflects user intent")

        entity.playbackPosition = 0
        entity.isPlayed = true
        XCTAssertTrue(entity.hasUserState, "Played flag counts as user state")

        entity.isPlayed = false
        entity.isFavorited = true
        XCTAssertTrue(entity.hasUserState, "Favorited counts as user state")

        entity.isFavorited = false
        entity.isBookmarked = true
        XCTAssertTrue(entity.hasUserState, "Bookmarked counts as user state")

        entity.isBookmarked = false
        entity.isArchived = true
        XCTAssertTrue(entity.hasUserState, "Archived counts as user state")

        entity.isArchived = false
        entity.rating = 4
        XCTAssertTrue(entity.hasUserState, "Rating counts as user state")

        entity.rating = nil
        entity.downloadStatus = EpisodeDownloadStatus.notDownloaded.rawValue
        XCTAssertFalse(entity.hasUserState, "Stateless episodes should return false")
    }

    func testOrphanedDefaultsFalseAndDateNil() {
        let entity = EpisodeEntity(
            id: "orphan-default",
            podcastId: "pod",
            title: "Title",
            podcastTitle: "Pod"
        )

        XCTAssertFalse(entity.isOrphaned)
        XCTAssertNil(entity.dateOrphaned)
    }

    func testOrphanedFlagRoundTripsToDomain() {
        let entity = EpisodeEntity(
            id: "orphaned",
            podcastId: "pod",
            title: "Title",
            podcastTitle: "Pod",
            isOrphaned: true,
            dateOrphaned: Date(timeIntervalSince1970: 123)
        )

        let episode = entity.toDomain()
        XCTAssertTrue(episode.isOrphaned)
        XCTAssertEqual(episode.dateOrphaned?.timeIntervalSince1970 ?? -1, 123, accuracy: 0.5)
    }
}
