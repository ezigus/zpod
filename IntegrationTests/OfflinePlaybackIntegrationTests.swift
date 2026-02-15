//
//  OfflinePlaybackIntegrationTests.swift
//  IntegrationTests
//
//  Created for Issue 28.1.13: Offline and Streaming Playback Infrastructure
//  Integration tests for offline playback fallback scenarios
//

#if os(iOS)
  import XCTest
  @testable import CoreModels
  @testable import LibraryFeature
  @testable import TestSupport

  /// Integration tests for offline playback and fallback-to-streaming scenarios
  ///
  /// **Specifications Covered**: spec/offline-playback.md
  /// - Episode model supports both offline (local file) and streaming (audioURL) playback
  /// - Fallback mechanism enabled through downloadStatus and audioURL properties
  final class OfflinePlaybackIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var podcastManager: InMemoryPodcastManager!
    private var testEpisode: Episode!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
      try await super.setUp()
      continueAfterFailure = false

      // Create test episode with audio URL for streaming fallback
      testEpisode = Episode(
        id: "test-episode-fallback",
        title: "Test Episode with Streaming Fallback",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 3600,
        audioURL: URL(string: "https://example.com/test-stream.mp3")!,
        downloadStatus: .notDownloaded  // Not downloaded initially
      )

      // Setup podcast manager
      podcastManager = InMemoryPodcastManager()
      let podcast = Podcast(
        id: "test-podcast",
        title: "Test Podcast",
        feedURL: URL(string: "https://example.com/feed.xml")!,
        episodes: [testEpisode]
      )
      podcastManager.add(podcast)
    }

    override func tearDown() async throws {
      podcastManager = nil
      testEpisode = nil
      try await super.tearDown()
    }

    // MARK: - Fallback Data Model Tests

    /// Test: Episode model supports both offline and streaming playback sources
    ///
    /// **Spec**: offline-playback.md - "Fallback to streaming when download unavailable"
    ///
    /// **Given**: Episode has both downloadStatus and audioURL properties
    /// **When**: Episode is not downloaded
    /// **Then**: audioURL is available for streaming fallback
    func testEpisodeModelSupportsStreamingFallback() {
      // Given: Episode is not downloaded but has audioURL
      XCTAssertEqual(testEpisode.downloadStatus, .notDownloaded, "Episode should not be downloaded")
      XCTAssertNotNil(testEpisode.audioURL, "Episode should have streaming URL for fallback")
      XCTAssertEqual(
        testEpisode.audioURL?.absoluteString,
        "https://example.com/test-stream.mp3",
        "Streaming URL should be preserved"
      )

      // Then: Episode supports fallback by having both properties
      XCTAssertTrue(
        testEpisode.audioURL != nil && testEpisode.downloadStatus == .notDownloaded,
        "Episode model supports streaming fallback when not downloaded"
      )
    }

    /// Test: Episode with failed download still has audioURL for fallback
    ///
    /// **Spec**: offline-playback.md - "Fallback to streaming when download failed"
    ///
    /// **Given**: Episode download has failed
    /// **When**: Checking episode properties
    /// **Then**: audioURL is still available for streaming fallback
    func testFailedDownloadPreservesStreamingURL() {
      // Given: Episode download has failed
      let failedEpisode = testEpisode.withDownloadStatus(.failed)
      XCTAssertEqual(failedEpisode.downloadStatus, .failed, "Episode download should be failed")

      // Then: Streaming URL is still available for fallback
      XCTAssertNotNil(failedEpisode.audioURL, "Failed episode should still have streaming URL")
      XCTAssertEqual(
        failedEpisode.audioURL,
        testEpisode.audioURL,
        "Streaming URL should be preserved after download failure"
      )
    }

    /// Test: Episode with in-progress download has audioURL for immediate streaming
    ///
    /// **Spec**: offline-playback.md - "Streaming available while download in progress"
    ///
    /// **Given**: Episode download is in progress
    /// **When**: Checking episode properties
    /// **Then**: audioURL is available for immediate streaming (don't wait for download)
    func testDownloadingEpisodeHasStreamingURL() {
      // Given: Episode is actively downloading
      let downloadingEpisode = testEpisode.withDownloadStatus(.downloading)
      XCTAssertEqual(downloadingEpisode.downloadStatus, .downloading, "Episode should be downloading")

      // Then: Streaming URL is available for immediate playback
      XCTAssertNotNil(
        downloadingEpisode.audioURL,
        "Downloading episode should have streaming URL for immediate playback"
      )
      XCTAssertEqual(
        downloadingEpisode.audioURL,
        testEpisode.audioURL,
        "Streaming URL should be preserved during download"
      )
    }

    /// Test: Episodes can exist without streaming URL (offline-only)
    ///
    /// **Spec**: offline-playback.md - "Error when both offline and streaming unavailable"
    ///
    /// **Given**: Episode has no audioURL
    /// **When**: Episode is also not downloaded
    /// **Then**: Episode model allows this state (playback layer must handle error)
    func testEpisodeCanExistWithoutStreamingURL() {
      // Given: Episode with no audioURL
      let noURLEpisode = Episode(
        id: "test-episode-no-url",
        title: "Episode Without Streaming URL",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 3600,
        audioURL: nil,  // No streaming URL available
        downloadStatus: .notDownloaded
      )

      // Then: Episode model allows this state
      XCTAssertNil(noURLEpisode.audioURL, "Episode can have no streaming URL")
      XCTAssertEqual(
        noURLEpisode.downloadStatus,
        .notDownloaded,
        "Episode can be both not-downloaded and have no URL"
      )

      // Note: Playback layer must check audioURL and show error when both sources unavailable
    }

    /// Test: Podcast manager preserves episode audioURL across operations
    ///
    /// **Spec**: offline-playback.md - "Streaming fallback relies on persisted audioURL"
    ///
    /// **Given**: Episode added to podcast manager
    /// **When**: Retrieving episode
    /// **Then**: audioURL is preserved for streaming fallback
    func testPodcastManagerPreservesStreamingURL() async {
      // Given: Episode in podcast manager
      let retrieved = podcastManager.all().first?.episodes.first { $0.id == testEpisode.id }

      // Then: audioURL is preserved
      XCTAssertNotNil(retrieved, "Should retrieve episode from manager")
      XCTAssertEqual(
        retrieved?.audioURL,
        testEpisode.audioURL,
        "Podcast manager should preserve streaming URL"
      )
      XCTAssertEqual(
        retrieved?.downloadStatus,
        testEpisode.downloadStatus,
        "Podcast manager should preserve download status"
      )
    }
  }
#endif
