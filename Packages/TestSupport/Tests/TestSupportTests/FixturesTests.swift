import XCTest
@testable import TestSupport
import CoreModels

final class PodcastFixturesTests: XCTestCase {

    // MARK: - PodcastFixtures

    func testSwiftTalkFixture_HasExpectedID() {
        XCTAssertEqual(PodcastFixtures.swiftTalk.id, "swift-talk")
    }

    func testSwiftTalkFixture_HasExpectedTitle() {
        XCTAssertEqual(PodcastFixtures.swiftTalk.title, "Swift Talk")
    }

    func testSwiftTalkFixture_HasValidFeedURL() {
        XCTAssertEqual(PodcastFixtures.swiftTalk.feedURL.host, "example.com")
    }

    func testSwiftOverCoffeeFixture_HasExpectedID() {
        XCTAssertEqual(PodcastFixtures.swiftOverCoffee.id, "swift-over-coffee")
    }

    func testAccidentalTechPodcastFixture_HasExpectedID() {
        XCTAssertEqual(PodcastFixtures.accidentalTechPodcast.id, "accidental-tech-podcast")
    }

    func testAllFixtures_ContainsThreePodcasts() {
        XCTAssertEqual(PodcastFixtures.all.count, 3)
    }

    func testAllFixtures_AllHaveUniqueIDs() {
        let ids = PodcastFixtures.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "All fixture podcast IDs must be unique")
    }

    func testAllFixtures_AllHaveValidFeedURLs() {
        for podcast in PodcastFixtures.all {
            XCTAssertNotNil(podcast.feedURL.host, "Feed URL must have a host for \(podcast.id)")
        }
    }

    // MARK: - EpisodeFixtures

    func testSwiftConcurrencyEpisode_HasExpectedID() {
        XCTAssertEqual(EpisodeFixtures.swiftConcurrency.id, "swift-talk-001")
    }

    func testSwiftConcurrencyEpisode_BelongsToSwiftTalk() {
        XCTAssertEqual(EpisodeFixtures.swiftConcurrency.podcastID, PodcastFixtures.swiftTalk.id)
    }

    func testSwiftUILayoutsEpisode_HasExpectedID() {
        XCTAssertEqual(EpisodeFixtures.swiftUILayouts.id, "swift-talk-002")
    }

    func testSwiftTalkEpisodes_ContainsTwoEpisodes() {
        XCTAssertEqual(EpisodeFixtures.swiftTalkEpisodes.count, 2)
    }

    func testSwiftOverCoffeeEpisodes_ContainsOneEpisode() {
        XCTAssertEqual(EpisodeFixtures.swiftOverCoffeeEpisodes.count, 1)
    }

    func testAtpEpisodes_ContainsOneEpisode() {
        XCTAssertEqual(EpisodeFixtures.atpEpisodes.count, 1)
    }

    func testAllEpisodeFixtures_ContainsFourEpisodes() {
        XCTAssertEqual(EpisodeFixtures.all.count, 4)
    }

    func testAllEpisodeFixtures_AllHaveUniqueIDs() {
        let ids = EpisodeFixtures.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "All fixture episode IDs must be unique")
    }

    func testAllEpisodeFixtures_AllBelongToKnownPodcasts() {
        let podcastIDs = Set(PodcastFixtures.all.map(\.id))
        for episode in EpisodeFixtures.all {
            let podcastID = episode.podcastID ?? ""
            XCTAssertTrue(
                podcastIDs.contains(podcastID),
                "Episode \(episode.id) references unknown podcast \(podcastID)"
            )
        }
    }

    func testAllEpisodeFixtures_AllHavePositiveDuration() {
        for episode in EpisodeFixtures.all {
            let duration = episode.duration ?? 0
            XCTAssertGreaterThan(duration, 0, "Episode \(episode.id) must have positive duration")
        }
    }
}
