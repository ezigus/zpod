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
  @testable import PlaybackEngine
  @testable import SharedUtilities
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
    // MARK: - Fallback-to-Streaming Behavioral Tests

    /// Test: EnhancedEpisodePlayer falls back to audioURL when localFileProvider returns nil
    ///
    /// **Spec**: offline-playback.md - "Fallback to streaming when local file unavailable"
    ///
    /// **Given**: EnhancedEpisodePlayer with mock audio engine, localFileProvider returns nil
    /// **When**: play() is called for an episode with an audioURL
    /// **Then**: Audio engine receives the streaming URL (not a local file URL)
    @MainActor
    func testLocalFileProviderFallbackToStreamingURL() async {
      // Given: Player with mock audio engine and localFileProvider that returns nil
      let mockEngine = URLCapturingAudioEngine()
      let streamingURL = URL(string: "https://example.com/stream.mp3")!

      let player = EnhancedEpisodePlayer(
        audioEngine: mockEngine,
        localFileProvider: { _ in nil }
      )

      let episode = Episode(
        id: "fallback-test-ep",
        title: "Fallback Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 300,
        audioURL: streamingURL,
        downloadStatus: .notDownloaded
      )

      // When: Play the episode
      player.play(episode: episode, duration: 300)

      // Then: Audio engine should receive the streaming URL (fallback path)
      XCTAssertEqual(mockEngine.playCallCount, 1, "Audio engine should be called exactly once")
      XCTAssertEqual(
        mockEngine.lastPlayedURL, streamingURL,
        "Audio engine should receive streaming URL when local file is unavailable"
      )
      XCTAssertTrue(player.isPlaying, "Player should be playing")
    }

    /// Test: EnhancedEpisodePlayer uses local file when localFileProvider returns a URL
    ///
    /// **Spec**: offline-playback.md - "Downloaded episode uses local file for playback"
    ///
    /// **Given**: EnhancedEpisodePlayer with mock audio engine, localFileProvider returns file URL
    /// **When**: play() is called for an episode
    /// **Then**: Audio engine receives the local file URL (not the streaming URL)
    @MainActor
    func testDownloadedEpisodeUsesLocalFile() async {
      // Given: Player with mock audio engine and localFileProvider that returns a local URL
      let mockEngine = URLCapturingAudioEngine()
      let localURL = URL(fileURLWithPath: "/tmp/test-episode.mp3")
      let streamingURL = URL(string: "https://example.com/stream.mp3")!

      let player = EnhancedEpisodePlayer(
        audioEngine: mockEngine,
        localFileProvider: { episodeId in
          episodeId == "local-test-ep" ? localURL : nil
        }
      )

      let episode = Episode(
        id: "local-test-ep",
        title: "Local File Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 300,
        audioURL: streamingURL,
        downloadStatus: .downloaded
      )

      // When: Play the episode
      player.play(episode: episode, duration: 300)

      // Then: Audio engine should receive the local file URL (preferred over streaming)
      XCTAssertEqual(mockEngine.playCallCount, 1, "Audio engine should be called exactly once")
      XCTAssertEqual(
        mockEngine.lastPlayedURL, localURL,
        "Audio engine should receive local file URL when available, not streaming URL"
      )
      XCTAssertNotEqual(
        mockEngine.lastPlayedURL, streamingURL,
        "Audio engine should NOT receive streaming URL when local file is available"
      )
      XCTAssertTrue(player.isPlaying, "Player should be playing from local file")
    }

    /// Test: Episode without audioURL and without local file fails with .missingAudioURL
    ///
    /// **Spec**: offline-playback.md - "Error when both offline and streaming unavailable"
    ///
    /// **Given**: Episode has no audioURL and localFileProvider returns nil, audio engine provided
    /// **When**: play() is called
    /// **Then**: Player enters failed state with .missingAudioURL, audio engine is NOT called
    @MainActor
    func testMissingBothSourcesHandledGracefully() async {
      // Given: Player with mock audio engine, localFileProvider returning nil, no audioURL
      let mockEngine = URLCapturingAudioEngine()

      let player = EnhancedEpisodePlayer(
        audioEngine: mockEngine,
        localFileProvider: { _ in nil }
      )

      let episode = Episode(
        id: "no-source-ep",
        title: "No Source Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 300,
        audioURL: nil,
        downloadStatus: .notDownloaded
      )

      // When: Play the episode
      player.play(episode: episode, duration: 300)

      // Then: Player should fail — audio engine never called, player not playing
      XCTAssertEqual(
        mockEngine.playCallCount, 0,
        "Audio engine should NOT be called when episode has no audioURL"
      )
      XCTAssertFalse(
        player.isPlaying,
        "Player should NOT be playing when both sources are missing"
      )
    }
  }

  // MARK: - Test Double

  /// Mock audio engine that records the URL passed to `play(from:)`.
  /// Enables verification of the local-file-vs-streaming URL selection logic
  /// in EnhancedEpisodePlayer without requiring AVFoundation.
  @MainActor
  private final class URLCapturingAudioEngine: AudioEngineProtocol {
    var onPositionUpdate: ((TimeInterval) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onError: ((PlaybackError) -> Void)?

    private(set) var isPlaying: Bool = false
    private(set) var lastPlayedURL: URL?
    private(set) var playCallCount: Int = 0

    func play(from url: URL, startPosition: TimeInterval, rate: Float) {
      lastPlayedURL = url
      playCallCount += 1
      isPlaying = true
    }

    func pause() {
      isPlaying = false
    }

    func seek(to position: TimeInterval) {}

    func setRate(_ rate: Float) {}

    func stop() {
      isPlaying = false
    }
  }
#endif
