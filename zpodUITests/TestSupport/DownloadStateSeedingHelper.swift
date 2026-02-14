//
//  DownloadStateSeedingHelper.swift
//  zpodUITests
//
//  Created for Issue 28.1.13 - Seed-first download state testing
//  Provides convenient test helpers for seeding download states
//

import Foundation

/// Helper for creating download state seeding environment variables in UI tests
enum DownloadStateSeedingHelper {
    /// Encode download states to JSON environment variable value
    static func encodeStates(_ states: [String: DownloadState]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        guard let jsonData = try? encoder.encode(states),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            fatalError("Failed to encode download states")
        }

        return jsonString
    }

    /// Download state for seeding
    struct DownloadState: Codable {
        let status: Status
        let progress: Double?
        let errorMessage: String?
        let fileSize: Int64?

        enum Status: String, Codable {
            case downloaded
            case downloading
            case failed
            case paused
            case notDownloaded
        }
    }

    // MARK: - Convenience Constructors

    /// Create downloaded state
    static func downloaded(fileSize: Int64 = 1024 * 1024) -> DownloadState {
        DownloadState(status: .downloaded, progress: nil, errorMessage: nil, fileSize: fileSize)
    }

    /// Create downloading state with progress
    static func downloading(progress: Double) -> DownloadState {
        DownloadState(status: .downloading, progress: max(0.0, min(1.0, progress)), errorMessage: nil, fileSize: nil)
    }

    /// Create failed state with error message
    static func failed(message: String = "Download failed") -> DownloadState {
        DownloadState(status: .failed, progress: nil, errorMessage: message, fileSize: nil)
    }

    /// Create paused state with progress
    static func paused(progress: Double) -> DownloadState {
        DownloadState(status: .paused, progress: max(0.0, min(1.0, progress)), errorMessage: nil, fileSize: nil)
    }

    /// Create not downloaded state
    static func notDownloaded() -> DownloadState {
        DownloadState(status: .notDownloaded, progress: nil, errorMessage: nil, fileSize: nil)
    }

    // MARK: - Common Test Scenarios

    /// Single episode downloading at 45%
    static var singleDownloading: [String: String] {
        [
            "UITEST_DOWNLOAD_STATES": encodeStates([
                "st-001": downloading(progress: 0.45)
            ])
        ]
    }

    /// Single episode failed
    static var singleFailed: [String: String] {
        [
            "UITEST_DOWNLOAD_STATES": encodeStates([
                "st-001": failed(message: "Network error")
            ])
        ]
    }

    /// Single episode paused at 30%
    static var singlePaused: [String: String] {
        [
            "UITEST_DOWNLOAD_STATES": encodeStates([
                "st-001": paused(progress: 0.30)
            ])
        ]
    }

    /// Single episode downloaded
    static var singleDownloaded: [String: String] {
        [
            "UITEST_DOWNLOAD_STATES": encodeStates([
                "st-001": downloaded()
            ])
        ]
    }

    /// Multiple episodes in various states
    static var mixedStates: [String: String] {
        [
            "UITEST_DOWNLOAD_STATES": encodeStates([
                "st-001": downloaded(),
                "st-002": downloading(progress: 0.65),
                "st-003": failed(message: "Server error"),
                "st-004": paused(progress: 0.20)
            ])
        ]
    }
}
