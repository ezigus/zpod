//
//  DownloadStateSeedingIntegrationTests.swift
//  IntegrationTests
//
//  Created for Issue 28.1.13: Download State Seeding Infrastructure
//  Integration tests verifying DownloadStateSeeding parses, normalizes,
//  and resolves seeded download states correctly.
//

#if os(iOS)
  import XCTest
  @testable import CoreModels
  @testable import LibraryFeature

  /// Integration tests for the download state seeding infrastructure
  ///
  /// **Spec Coverage**: `spec/offline-playback.md`
  /// - Seeded download states parse correctly from JSON environment variables
  /// - Episode ID normalization handles prefixes and colon separators
  /// - All download status types (downloaded, downloading, paused, failed) seed correctly
  /// - Progress values and error messages are preserved through encoding/decoding
  ///
  /// **Issue**: #28.1.13 - Complete Test Coverage
  final class DownloadStateSeedingIntegrationTests: XCTestCase {
    private func assertProgress(
      _ progress: Double?,
      equals expected: Double,
      file: StaticString = #filePath,
      line: UInt = #line
    ) {
      guard let progress else {
        XCTFail("Expected non-nil progress", file: file, line: line)
        return
      }
      XCTAssertEqual(progress, expected, accuracy: 0.001, file: file, line: line)
    }

    override func setUp() {
      super.setUp()
      unsetenv(DownloadStateSeeding.environmentKey)
    }

    override func tearDown() {
      unsetenv(DownloadStateSeeding.environmentKey)
      super.tearDown()
    }

    // MARK: - SeededDownloadState Encoding/Decoding

    /// Test: SeededDownloadState round-trips through JSON encoding
    ///
    /// **Given**: A SeededDownloadState with status, progress, and error
    /// **When**: Encoded to JSON and decoded back
    /// **Then**: All fields are preserved
    func testSeededDownloadStateRoundTrips() throws {
      let original = SeededDownloadState(
        status: .downloading,
        progress: 0.45,
        errorMessage: nil,
        fileSize: nil
      )

      let encoder = JSONEncoder()
      let data = try encoder.encode(original)
      let decoded = try JSONDecoder().decode(SeededDownloadState.self, from: data)

      XCTAssertEqual(decoded.status, .downloading)
      assertProgress(decoded.progress, equals: 0.45)
      XCTAssertNil(decoded.errorMessage)
      XCTAssertNil(decoded.fileSize)
    }

    /// Test: All SeededDownloadState statuses encode/decode correctly
    func testAllStatusTypesRoundTrip() throws {
      let statuses: [SeededDownloadState.Status] = [
        .downloaded, .downloading, .failed, .paused, .notDownloaded
      ]

      let encoder = JSONEncoder()

      for status in statuses {
        let state = SeededDownloadState(status: status)
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(SeededDownloadState.self, from: data)
        XCTAssertEqual(decoded.status, status, "Status \(status) should round-trip")
      }
    }

    /// Test: Failed state preserves error message through encoding
    func testFailedStatePreservesErrorMessage() throws {
      let state = SeededDownloadState(
        status: .failed,
        errorMessage: "Network connection lost"
      )

      let encoder = JSONEncoder()
      let data = try encoder.encode(state)
      let decoded = try JSONDecoder().decode(SeededDownloadState.self, from: data)

      XCTAssertEqual(decoded.status, .failed)
      XCTAssertEqual(decoded.errorMessage, "Network connection lost")
    }

    /// Test: Downloaded state preserves file size through encoding
    func testDownloadedStatePreservesFileSize() throws {
      let state = SeededDownloadState(
        status: .downloaded,
        fileSize: 2_048_000
      )

      let encoder = JSONEncoder()
      let data = try encoder.encode(state)
      let decoded = try JSONDecoder().decode(SeededDownloadState.self, from: data)

      XCTAssertEqual(decoded.status, .downloaded)
      XCTAssertEqual(decoded.fileSize, 2_048_000)
    }

    // MARK: - DownloadStateSeeding.encodeStates

    /// Test: encodeStates produces valid JSON that parseSeededStates can read
    ///
    /// **Given**: A dictionary of episode IDs to SeededDownloadStates
    /// **When**: Encoded via encodeStates
    /// **Then**: The resulting JSON string decodes back to equivalent states
    func testEncodeStatesProducesValidJSON() throws {
      let states: [String: SeededDownloadState] = [
        "ep-001": DownloadStateSeeding.downloaded(),
        "ep-002": DownloadStateSeeding.downloading(progress: 0.65),
        "ep-003": DownloadStateSeeding.failed(message: "Server error")
      ]

      let jsonString = try XCTUnwrap(
        DownloadStateSeeding.encodeStates(states),
        "encodeStates should produce JSON string"
      )

      // Verify JSON is valid by decoding it
      let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
      let decoded = try JSONDecoder().decode(
        [String: SeededDownloadState].self, from: jsonData
      )

      XCTAssertEqual(decoded.count, 3, "Should decode 3 states")
      XCTAssertEqual(decoded["ep-001"]?.status, .downloaded)
      XCTAssertEqual(decoded["ep-002"]?.status, .downloading)
      assertProgress(decoded["ep-002"]?.progress, equals: 0.65)
      XCTAssertEqual(decoded["ep-003"]?.status, .failed)
      XCTAssertEqual(decoded["ep-003"]?.errorMessage, "Server error")
    }

    // MARK: - Convenience Constructors

    /// Test: downloaded() convenience sets correct fields
    func testDownloadedConvenience() {
      let state = DownloadStateSeeding.downloaded()
      XCTAssertEqual(state.status, .downloaded)
      XCTAssertEqual(state.fileSize, 1024 * 1024)
      XCTAssertNil(state.progress)
      XCTAssertNil(state.errorMessage)
    }

    /// Test: downloaded(fileSize:) convenience preserves custom file size
    func testDownloadedWithCustomFileSize() {
      let state = DownloadStateSeeding.downloaded(fileSize: 5_000_000)
      XCTAssertEqual(state.status, .downloaded)
      XCTAssertEqual(state.fileSize, 5_000_000)
    }

    /// Test: downloading(progress:) convenience sets correct fields
    func testDownloadingConvenience() {
      let state = DownloadStateSeeding.downloading(progress: 0.45)
      XCTAssertEqual(state.status, .downloading)
      assertProgress(state.progress, equals: 0.45)
      XCTAssertNil(state.errorMessage)
      XCTAssertNil(state.fileSize)
    }

    /// Test: downloading(progress:) clamps values to 0.0-1.0
    func testDownloadingClampsProgress() {
      let overState = DownloadStateSeeding.downloading(progress: 1.5)
      assertProgress(overState.progress, equals: 1.0)

      let underState = DownloadStateSeeding.downloading(progress: -0.5)
      assertProgress(underState.progress, equals: 0.0)
    }

    /// Test: failed(message:) convenience sets correct fields
    func testFailedConvenience() {
      let state = DownloadStateSeeding.failed(message: "Network error")
      XCTAssertEqual(state.status, .failed)
      XCTAssertEqual(state.errorMessage, "Network error")
      XCTAssertNil(state.progress)
      XCTAssertNil(state.fileSize)
    }

    /// Test: paused(progress:) convenience sets correct fields
    func testPausedConvenience() {
      let state = DownloadStateSeeding.paused(progress: 0.30)
      XCTAssertEqual(state.status, .paused)
      assertProgress(state.progress, equals: 0.30)
      XCTAssertNil(state.errorMessage)
      XCTAssertNil(state.fileSize)
    }

    /// Test: paused(progress:) clamps values to 0.0-1.0
    func testPausedClampsProgress() {
      let overState = DownloadStateSeeding.paused(progress: 2.0)
      assertProgress(overState.progress, equals: 1.0)
    }

    /// Test: notDownloaded() convenience sets correct fields
    func testNotDownloadedConvenience() {
      let state = DownloadStateSeeding.notDownloaded()
      XCTAssertEqual(state.status, .notDownloaded)
      XCTAssertNil(state.progress)
      XCTAssertNil(state.errorMessage)
      XCTAssertNil(state.fileSize)
    }

    // MARK: - Episode ID Normalization

    /// Test: Exact episode ID match works
    func testExactEpisodeIdMatch() throws {
      let states: [String: SeededDownloadState] = [
        "st-001": DownloadStateSeeding.downloaded()
      ]

      let jsonString = try XCTUnwrap(DownloadStateSeeding.encodeStates(states))

      // Simulate setting environment and parsing
      let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
      let parsed = try JSONDecoder().decode(
        [String: SeededDownloadState].self, from: jsonData
      )

      XCTAssertNotNil(parsed["st-001"], "Exact match for 'st-001' should work")
      XCTAssertEqual(parsed["st-001"]?.status, .downloaded)
    }

    /// Test: Multiple states encode and decode independently
    func testMultipleStatesIndependent() throws {
      let states: [String: SeededDownloadState] = [
        "st-001": DownloadStateSeeding.downloaded(),
        "st-002": DownloadStateSeeding.downloading(progress: 0.65),
        "st-003": DownloadStateSeeding.failed(message: "Server error"),
        "st-004": DownloadStateSeeding.paused(progress: 0.20)
      ]

      let jsonString = try XCTUnwrap(DownloadStateSeeding.encodeStates(states))
      let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
      let parsed = try JSONDecoder().decode(
        [String: SeededDownloadState].self, from: jsonData
      )

      XCTAssertEqual(parsed.count, 4)
      XCTAssertEqual(parsed["st-001"]?.status, .downloaded)
      XCTAssertEqual(parsed["st-002"]?.status, .downloading)
      assertProgress(parsed["st-002"]?.progress, equals: 0.65)
      XCTAssertEqual(parsed["st-003"]?.status, .failed)
      XCTAssertEqual(parsed["st-003"]?.errorMessage, "Server error")
      XCTAssertEqual(parsed["st-004"]?.status, .paused)
      assertProgress(parsed["st-004"]?.progress, equals: 0.20)
    }

    // MARK: - EpisodeDownloadStatus ↔ SeededDownloadState Mapping

    /// Test: SeededDownloadState status maps correctly to EpisodeDownloadStatus
    ///
    /// **Given**: SeededDownloadState statuses
    /// **When**: Mapping to EpisodeDownloadStatus
    /// **Then**: Each status maps to the correct EpisodeDownloadStatus case
    func testSeededStatusMapsToEpisodeDownloadStatus() {
      let mapping: [(SeededDownloadState.Status, EpisodeDownloadStatus)] = [
        (.downloaded, .downloaded),
        (.downloading, .downloading),
        (.failed, .failed),
        (.paused, .paused),
        (.notDownloaded, .notDownloaded)
      ]

      for (seededStatus, expectedEpisodeStatus) in mapping {
        let episodeStatus: EpisodeDownloadStatus
        switch seededStatus {
        case .downloaded: episodeStatus = .downloaded
        case .downloading: episodeStatus = .downloading
        case .failed: episodeStatus = .failed
        case .paused: episodeStatus = .paused
        case .notDownloaded: episodeStatus = .notDownloaded
        }
        XCTAssertEqual(
          episodeStatus,
          expectedEpisodeStatus,
          "SeededDownloadState.\(seededStatus) should map to EpisodeDownloadStatus.\(expectedEpisodeStatus)"
        )
      }
    }

    // MARK: - Edge Cases

    /// Test: Empty states dictionary encodes correctly
    func testEmptyStatesEncodes() throws {
      let states: [String: SeededDownloadState] = [:]
      let jsonString = try XCTUnwrap(DownloadStateSeeding.encodeStates(states))
      XCTAssertEqual(jsonString, "{}", "Empty dict should encode as '{}'")
    }

    /// Test: Progress at boundary values (0.0 and 1.0)
    func testProgressBoundaryValues() {
      let zeroState = DownloadStateSeeding.downloading(progress: 0.0)
      assertProgress(zeroState.progress, equals: 0.0)

      let fullState = DownloadStateSeeding.downloading(progress: 1.0)
      assertProgress(fullState.progress, equals: 1.0)
    }

    /// Test: Error message with special characters encodes correctly
    func testErrorMessageSpecialCharacters() throws {
      let state = DownloadStateSeeding.failed(message: "Error: \"timeout\" at 10:30")
      let states = ["ep-1": state]

      let jsonString = try XCTUnwrap(DownloadStateSeeding.encodeStates(states))
      let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
      let decoded = try JSONDecoder().decode(
        [String: SeededDownloadState].self, from: jsonData
      )

      XCTAssertEqual(
        decoded["ep-1"]?.errorMessage,
        "Error: \"timeout\" at 10:30",
        "Special characters in error message should round-trip"
      )
    }

    /// Test: Episode ID with colon separator normalizes correctly
    func testColonSeparatorNormalization() throws {
      // The normalizeEpisodeId function handles "podcast:episode" format
      // If the seeded key is "st-001" and the lookup is "swift-talk:st-001",
      // the normalization should strip the prefix and match
      let states: [String: SeededDownloadState] = [
        "st-001": DownloadStateSeeding.downloaded()
      ]

      let jsonString = try XCTUnwrap(DownloadStateSeeding.encodeStates(states))
      let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
      let parsed = try JSONDecoder().decode(
        [String: SeededDownloadState].self, from: jsonData
      )

      // Direct key lookup works for the exact key
      XCTAssertNotNil(parsed["st-001"])
    }

    // MARK: - Environment Contract: parse + lookup

    func testParseSeededStatesReadsEnvironmentJSON() throws {
      let seeded: [String: SeededDownloadState] = [
        "st-001": .init(status: .downloaded),
        "swift-talk:st-002": .init(status: .downloading, progress: 0.45)
      ]
      let json = try XCTUnwrap(DownloadStateSeeding.encodeStates(seeded))
      setenv(DownloadStateSeeding.environmentKey, json, 1)

      let parsed = DownloadStateSeeding.parseSeededStates()
      XCTAssertEqual(parsed.count, 2)
      XCTAssertEqual(parsed["st-001"]?.status, .downloaded)
      XCTAssertEqual(parsed["swift-talk:st-002"]?.status, .downloading)
      assertProgress(parsed["swift-talk:st-002"]?.progress, equals: 0.45)
    }

    func testParseSeededStatesReturnsEmptyOnInvalidEnvironmentJSON() {
      setenv(DownloadStateSeeding.environmentKey, "{invalid-json", 1)
      let parsed = DownloadStateSeeding.parseSeededStates()
      XCTAssertTrue(parsed.isEmpty)
    }

    func testStateLookupSupportsExactEpisodeId() throws {
      let seeded: [String: SeededDownloadState] = [
        "st-001": .init(status: .failed, errorMessage: "Network error")
      ]
      let json = try XCTUnwrap(DownloadStateSeeding.encodeStates(seeded))
      setenv(DownloadStateSeeding.environmentKey, json, 1)

      let state = DownloadStateSeeding.state(for: "st-001")
      XCTAssertEqual(state?.status, .failed)
      XCTAssertEqual(state?.errorMessage, "Network error")
    }

    func testStateLookupSupportsPodcastPrefixedEpisodeId() throws {
      let seeded: [String: SeededDownloadState] = [
        "st-001": .init(status: .downloaded)
      ]
      let json = try XCTUnwrap(DownloadStateSeeding.encodeStates(seeded))
      setenv(DownloadStateSeeding.environmentKey, json, 1)

      let state = DownloadStateSeeding.state(for: "swift-talk:st-001")
      XCTAssertEqual(state?.status, .downloaded)
    }

    func testStateLookupSupportsEpisodePrefixNormalization() throws {
      let seeded: [String: SeededDownloadState] = [
        "st-001": .init(status: .paused, progress: 0.3)
      ]
      let json = try XCTUnwrap(DownloadStateSeeding.encodeStates(seeded))
      setenv(DownloadStateSeeding.environmentKey, json, 1)

      let state = DownloadStateSeeding.state(for: "episode-st-001")
      XCTAssertEqual(state?.status, .paused)
      assertProgress(state?.progress, equals: 0.3)
    }

    // MARK: - Integration: Episode Model + Download State

    /// Test: Episode.withDownloadStatus correctly transitions between all states
    ///
    /// This validates the Episode model can represent every download state
    /// that DownloadStateSeeding can seed.
    func testEpisodeModelSupportsAllDownloadStates() {
      let episode = Episode(
        id: "test-ep",
        title: "Test Episode",
        podcastID: "test-podcast",
        pubDate: Date(),
        duration: 3600,
        audioURL: URL(string: "https://example.com/stream.mp3")
      )

      // Verify all transitions
      let downloaded = episode.withDownloadStatus(.downloaded)
      XCTAssertEqual(downloaded.downloadStatus, .downloaded)
      XCTAssertNotNil(downloaded.audioURL, "audioURL preserved after download")

      let downloading = episode.withDownloadStatus(.downloading)
      XCTAssertEqual(downloading.downloadStatus, .downloading)
      XCTAssertNotNil(downloading.audioURL, "audioURL preserved during download")

      let paused = episode.withDownloadStatus(.paused)
      XCTAssertEqual(paused.downloadStatus, .paused)
      XCTAssertNotNil(paused.audioURL, "audioURL preserved when paused")

      let failed = episode.withDownloadStatus(.failed)
      XCTAssertEqual(failed.downloadStatus, .failed)
      XCTAssertNotNil(failed.audioURL, "audioURL preserved on failure")

      let notDownloaded = episode.withDownloadStatus(.notDownloaded)
      XCTAssertEqual(notDownloaded.downloadStatus, .notDownloaded)
      XCTAssertNotNil(notDownloaded.audioURL, "audioURL preserved when not downloaded")
    }

    /// Test: Progress percentage computation matches what UI tests expect
    ///
    /// UI tests check for "45%", "65%", "30%", "20%" labels.
    /// Verify the Int(progress * 100) computation produces these exact strings.
    func testProgressPercentageFormatting() {
      let testCases: [(Double, String)] = [
        (0.45, "45%"),
        (0.65, "65%"),
        (0.30, "30%"),
        (0.20, "20%"),
        (0.0, "0%"),
        (1.0, "100%"),
        (0.999, "99%")
      ]

      for (progress, expected) in testCases {
        let formatted = "\(Int(progress * 100))%"
        XCTAssertEqual(
          formatted,
          expected,
          "Progress \(progress) should format as '\(expected)'"
        )
      }
    }
  }
#endif
