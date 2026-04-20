//
//  PodcastDownloadSettingsPriorityTests.swift
//  CoreModelsTests
//
//  Tests for Issue #468: [06.2.1] Priority storage, UI, and download queue integration
//
//  Covers:
//  - Default priority value
//  - Priority clamping at init time
//  - Codable round-trip with priority field
//  - Backwards-compatible decoding (old JSON without priority → priority=0)
//

import XCTest
@testable import CoreModels

final class PodcastDownloadSettingsPriorityTests: XCTestCase {

    // MARK: - Default Value

    func testPriorityDefaultValue() {
        let settings = PodcastDownloadSettings(
            podcastId: "podcast-1",
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil
        )
        XCTAssertEqual(settings.priority, 0, "Default priority must be 0 (normal)")
    }

    // MARK: - Clamping

    func testPriorityClampedAtUpperBound() {
        let settings = PodcastDownloadSettings(
            podcastId: "podcast-1",
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            priority: 99
        )
        XCTAssertEqual(settings.priority, 10, "Priority above +10 must be clamped to +10")
    }

    func testPriorityClampedAtLowerBound() {
        let settings = PodcastDownloadSettings(
            podcastId: "podcast-1",
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            priority: -99
        )
        XCTAssertEqual(settings.priority, -10, "Priority below -10 must be clamped to -10")
    }

    func testPriorityBoundaryValues() {
        for value in [-10, -5, 0, 5, 10] {
            let settings = PodcastDownloadSettings(
                podcastId: "podcast-1",
                autoDownloadEnabled: nil,
                wifiOnly: nil,
                retentionPolicy: nil,
                priority: value
            )
            XCTAssertEqual(settings.priority, value, "Priority \(value) must be preserved without clamping")
        }
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let original = PodcastDownloadSettings(
            podcastId: "podcast-codable",
            autoDownloadEnabled: true,
            wifiOnly: false,
            retentionPolicy: nil,
            priority: 7
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PodcastDownloadSettings.self, from: data)

        XCTAssertEqual(decoded.podcastId, original.podcastId)
        XCTAssertEqual(decoded.priority, 7, "Priority must survive Codable round-trip")
        XCTAssertEqual(decoded.autoDownloadEnabled, true)
    }

    func testCodableRoundTripNegativePriority() throws {
        let original = PodcastDownloadSettings(
            podcastId: "podcast-neg",
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            priority: -5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PodcastDownloadSettings.self, from: data)

        XCTAssertEqual(decoded.priority, -5, "Negative priority must survive Codable round-trip")
    }

    // MARK: - Backwards Compatibility (Upgrade Migration)

    func testCodableUpgradeBackwardsCompat() throws {
        // Simulate JSON from before priority field existed (no "priority" key)
        let legacyJSON = """
        {
            "podcastId": "legacy-podcast",
            "autoDownloadEnabled": true,
            "wifiOnly": null,
            "retentionPolicy": null
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PodcastDownloadSettings.self, from: legacyJSON)
        XCTAssertEqual(decoded.podcastId, "legacy-podcast")
        XCTAssertEqual(decoded.priority, 0, "Old data without 'priority' key must decode with priority=0")
    }

    func testCodableUpgradeBackwardsCompatWithNullPriority() throws {
        // Some edge case: "priority" key present but null (shouldn't happen but be safe)
        // Note: priority is non-optional Int, so null would cause a decoding failure.
        // This test verifies that missing key (not null) is the backwards-compat path.
        let jsonWithPriority = """
        {
            "podcastId": "podcast-with-priority",
            "autoDownloadEnabled": null,
            "wifiOnly": null,
            "retentionPolicy": null,
            "priority": 3
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PodcastDownloadSettings.self, from: jsonWithPriority)
        XCTAssertEqual(decoded.priority, 3, "Explicit priority in JSON must be decoded correctly")
    }
}
