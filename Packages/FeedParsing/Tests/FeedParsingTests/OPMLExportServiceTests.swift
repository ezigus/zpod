//
//  OPMLExportServiceTests.swift
//  FeedParsingTests
//
//  Unit tests for OPMLExportService (Issue #450).
//
//  Spec coverage (Given/When/Then):
//    AC1 - Export button calls OPMLExportService and produces valid OPML data
//    AC2 - "No subscriptions" error is surfaced when library is empty
//    AC2 - "No subscriptions" error is surfaced when all podcasts are unsubscribed
//    AC3 - OPML output contains correct titles and feed URLs
//    AC3 - Podcast list is sorted alphabetically by title (case-insensitive)
//    AC3 - Special characters in podcast titles are XML-escaped

import XCTest
@testable import FeedParsing
import CoreModels

// MARK: - Mock PodcastManaging

private final class MockPodcastManager: PodcastManaging, @unchecked Sendable {
    var podcasts: [Podcast]

    init(podcasts: [Podcast] = []) {
        self.podcasts = podcasts
    }

    func all() -> [Podcast] { podcasts }
    func find(id: String) -> Podcast? { podcasts.first { $0.id == id } }
    func add(_ podcast: Podcast) { podcasts.append(podcast) }
    func update(_ podcast: Podcast) {}
    func remove(id: String) { podcasts.removeAll { $0.id == id } }
    func findByFolder(folderId: String) -> [Podcast] { [] }
    func findByFolderRecursive(folderId: String, folderManager: any FolderManaging) -> [Podcast] { [] }
    func findByTag(tagId: String) -> [Podcast] { [] }
    func findUnorganized() -> [Podcast] { [] }
    func fetchOrphanedEpisodes() -> [Episode] { [] }
    func deleteOrphanedEpisode(id: String) -> Bool { false }
    @discardableResult func deleteAllOrphanedEpisodes() -> Int { 0 }
}

// MARK: - Helpers

private func makePodcast(
    id: String = UUID().uuidString,
    title: String,
    feedURL: String,
    isSubscribed: Bool = true
) -> Podcast {
    Podcast(
        id: id,
        title: title,
        feedURL: URL(string: feedURL)!,
        isSubscribed: isSubscribed
    )
}

// MARK: - OPMLExportServiceTests

/// Unit tests for OPMLExportService.
///
/// **Test Pyramid Breakdown**:
/// - 7 unit tests covering all `OPMLExportService` code paths
/// - 0 integration / E2E tests (file-picker system sheet is outside unit scope)
///
/// **Coverage Targets**:
/// - Unit layer: 100% branch coverage of exportSubscriptions(), exportSubscriptionsAsXML(), and exportSubscriptionsAsXMLString()
///
/// **Critical Paths**:
/// - Happy path: subscribed podcasts → valid OPML document and XML data
/// - Error: no podcasts at all → `.noSubscriptions`
/// - Error: all podcasts unsubscribed → `.noSubscriptions`
/// - Edge case: XML special characters are escaped in output
/// - Edge case: deterministic alphabetical ordering of podcasts in output
final class OPMLExportServiceTests: XCTestCase {

    // MARK: - AC2: No subscriptions — empty library

    /// Given: The podcast manager has no podcasts at all
    /// When: exportSubscriptions() is called
    /// Then: OPMLExportService.Error.noSubscriptions is thrown
    ///
    /// **AC2** — empty library error path
    func testExportSubscriptions_emptyLibrary_throwsNoSubscriptions() {
        let manager = MockPodcastManager(podcasts: [])
        let service = OPMLExportService(podcastManager: manager)

        XCTAssertThrowsError(try service.exportSubscriptions()) { error in
            XCTAssertEqual(error as? OPMLExportService.Error, .noSubscriptions,
                "Should throw .noSubscriptions when the library is empty")
        }
    }

    // MARK: - AC2: No subscriptions — all unsubscribed

    /// Given: The podcast manager has podcasts but none are subscribed
    /// When: exportSubscriptions() is called
    /// Then: OPMLExportService.Error.noSubscriptions is thrown
    ///
    /// **AC2** — all-unsubscribed error path
    func testExportSubscriptions_allUnsubscribed_throwsNoSubscriptions() {
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "Pod A", feedURL: "https://a.example.com/rss", isSubscribed: false),
            makePodcast(title: "Pod B", feedURL: "https://b.example.com/rss", isSubscribed: false),
        ])
        let service = OPMLExportService(podcastManager: manager)

        XCTAssertThrowsError(try service.exportSubscriptions()) { error in
            XCTAssertEqual(error as? OPMLExportService.Error, .noSubscriptions,
                "Should throw .noSubscriptions when all podcasts are unsubscribed")
        }
    }

    // MARK: - AC1: Happy path — returns OPML document

    /// Given: The podcast manager has subscribed podcasts
    /// When: exportSubscriptions() is called
    /// Then: A valid OPMLDocument is returned containing the subscribed podcasts
    ///
    /// **AC1** — happy path
    func testExportSubscriptions_withSubscribedPodcasts_returnsDocument() throws {
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "Podcast Alpha", feedURL: "https://alpha.example.com/rss"),
            makePodcast(title: "Podcast Beta", feedURL: "https://beta.example.com/rss"),
        ])
        let service = OPMLExportService(podcastManager: manager)

        let document = try service.exportSubscriptions()

        XCTAssertEqual(document.body.outlines.count, 2, "Document should contain 2 outline entries")
    }

    // MARK: - AC1: Happy path — only subscribed podcasts exported

    /// Given: A mix of subscribed and unsubscribed podcasts
    /// When: exportSubscriptions() is called
    /// Then: Only subscribed podcasts appear in the OPML output
    ///
    /// **AC1** — filtering: unsubscribed omitted
    func testExportSubscriptions_mixedSubscriptions_onlyIncludesSubscribed() throws {
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "Subscribed", feedURL: "https://sub.example.com/rss", isSubscribed: true),
            makePodcast(title: "Unsubscribed", feedURL: "https://unsub.example.com/rss", isSubscribed: false),
        ])
        let service = OPMLExportService(podcastManager: manager)

        let document = try service.exportSubscriptions()

        XCTAssertEqual(document.body.outlines.count, 1)
        XCTAssertEqual(document.body.outlines[0].title, "Subscribed")
    }

    // MARK: - AC3: Output contains correct URLs

    /// Given: Subscribed podcasts with known feed URLs
    /// When: exportSubscriptionsAsXML() is called (the method used by SettingsHomeView)
    /// Then: The returned Data contains each feed URL and podcast title
    ///
    /// **AC3** — feed URL correctness; directly exercises the production code path
    func testExportSubscriptionsAsXML_containsFeedURLs() throws {
        let feedURL = "https://podcast.example.com/rss"
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "My Show", feedURL: feedURL),
        ])
        let service = OPMLExportService(podcastManager: manager)

        let data = try service.exportSubscriptionsAsXML()
        let xml = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(data.isEmpty, "exportSubscriptionsAsXML() should return non-empty Data")
        XCTAssertTrue(xml.contains(feedURL), "XML output should contain the podcast feed URL")
        XCTAssertTrue(xml.contains("My Show"), "XML output should contain the podcast title")
    }

    // MARK: - AC3: Alphabetical ordering

    /// Given: Podcasts with titles in non-alphabetical order
    /// When: exportSubscriptions() is called
    /// Then: The outlines are sorted case-insensitively by title ascending
    ///
    /// **AC3** — deterministic sort order
    func testExportSubscriptions_sortsAlphabeticallyByTitle() throws {
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "Zeta Cast", feedURL: "https://z.example.com/rss"),
            makePodcast(title: "alpha cast", feedURL: "https://a.example.com/rss"),
            makePodcast(title: "Middle Show", feedURL: "https://m.example.com/rss"),
        ])
        let service = OPMLExportService(podcastManager: manager)

        let document = try service.exportSubscriptions()
        let titles = document.body.outlines.map { $0.title }

        XCTAssertEqual(titles, ["alpha cast", "Middle Show", "Zeta Cast"],
            "Outlines should be sorted case-insensitively ascending by title")
    }

    // MARK: - AC3: XML escaping of special characters

    /// Given: A podcast with special characters in its title
    /// When: exportSubscriptionsAsXMLString() is called
    /// Then: The special characters are properly XML-escaped in the output
    ///
    /// **AC3** — XML escape edge case
    func testExportSubscriptionsAsXMLString_escapesSpecialCharactersInTitle() throws {
        let manager = MockPodcastManager(podcasts: [
            makePodcast(title: "Rock & Roll <Podcast>", feedURL: "https://rock.example.com/rss"),
        ])
        let service = OPMLExportService(podcastManager: manager)

        let xml = try service.exportSubscriptionsAsXMLString()

        XCTAssertTrue(xml.contains("Rock &amp; Roll &lt;Podcast&gt;"),
            "Special characters in podcast titles must be XML-escaped")
        XCTAssertFalse(xml.contains("Rock & Roll <Podcast>"),
            "Unescaped special characters must not appear in the XML output")
    }
}
