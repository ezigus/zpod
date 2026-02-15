//
//  DownloadStateSeeding.swift
//  LibraryFeature
//
//  Created for Issue 28.1.13 - Seed-first download state testing
//  Provides structured seeding of download states for deterministic UI testing
//

import Foundation

#if DEBUG

/// Represents a seeded download state for UI testing
public struct SeededDownloadState: Codable, Sendable {
    /// Download status
    public enum Status: String, Codable, Sendable {
        case downloaded
        case downloading
        case failed
        case paused
        case notDownloaded
    }

    /// Current download status
    public let status: Status

    /// Download progress (0.0 to 1.0) for downloading/paused states
    public let progress: Double?

    /// Error message for failed state
    public let errorMessage: String?

    /// File size in bytes for completed downloads
    public let fileSize: Int64?

    public init(
        status: Status,
        progress: Double? = nil,
        errorMessage: String? = nil,
        fileSize: Int64? = nil
    ) {
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
        self.fileSize = fileSize
    }
}

/// Manages download state seeding for UI tests
public enum DownloadStateSeeding {
    /// Environment variable key for structured download states
    public static let environmentKey = "UITEST_DOWNLOAD_STATES"

    /// Parse seeded download states from environment
    /// Format: JSON dictionary of episodeId -> SeededDownloadState
    /// Example: {"ep-1":{"status":"downloading","progress":0.45},"ep-2":{"status":"failed","errorMessage":"Network error"}}
    public static func parseSeededStates() -> [String: SeededDownloadState] {
        guard let envValue = ProcessInfo.processInfo.environment[environmentKey],
              !envValue.isEmpty else {
            print("🔍 [DownloadStateSeeding] No UITEST_DOWNLOAD_STATES environment variable")
            return [:]
        }

        print("🔍 [DownloadStateSeeding] Found UITEST_DOWNLOAD_STATES: \(envValue.prefix(100))...")

        guard let jsonData = envValue.data(using: .utf8) else {
            print("⚠️ Failed to parse UITEST_DOWNLOAD_STATES: invalid UTF-8")
            return [:]
        }

        do {
            let decoder = JSONDecoder()
            let states = try decoder.decode([String: SeededDownloadState].self, from: jsonData)
            print("🔍 [DownloadStateSeeding] Parsed \(states.count) states: \(states.keys.sorted())")
            return states
        } catch {
            print("⚠️ Failed to decode UITEST_DOWNLOAD_STATES: \(error)")
            return [:]
        }
    }

    /// Get seeded state for a specific episode ID
    public static func state(for episodeId: String) -> SeededDownloadState? {
        let states = parseSeededStates()

        print("🔍 [DownloadStateSeeding] Looking for episode ID: '\(episodeId)'")

        // Try exact match first
        if let state = states[episodeId] {
            print("🔍 [DownloadStateSeeding] ✅ Found exact match for '\(episodeId)': \(state.status)")
            return state
        }

        // Try normalized match (handle podcast:episode format)
        let normalized = normalizeEpisodeId(episodeId)
        print("🔍 [DownloadStateSeeding] Trying normalized: '\(normalized)'")
        for (key, value) in states {
            if normalizeEpisodeId(key) == normalized {
                print("🔍 [DownloadStateSeeding] ✅ Found normalized match: '\(key)' -> '\(normalized)'")
                return value
            }
        }

        print("🔍 [DownloadStateSeeding] ❌ No match found for '\(episodeId)' (normalized: '\(normalized)')")
        return nil
    }

    /// Normalize episode ID for matching (same logic as existing deletion code)
    private static func normalizeEpisodeId(_ id: String) -> String {
        let trimmed = id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let tokenParts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let episodePortion = tokenParts.count == 2 ? String(tokenParts[1]) : trimmed
        if episodePortion.hasPrefix("episode-") {
            return String(episodePortion.dropFirst("episode-".count))
        }
        return episodePortion
    }

    // MARK: - Convenience Constructors

    /// Create downloaded state
    public static func downloaded(fileSize: Int64 = 1024 * 1024) -> SeededDownloadState {
        SeededDownloadState(status: .downloaded, fileSize: fileSize)
    }

    /// Create downloading state with progress
    public static func downloading(progress: Double) -> SeededDownloadState {
        SeededDownloadState(status: .downloading, progress: max(0.0, min(1.0, progress)))
    }

    /// Create failed state with error message
    public static func failed(message: String = "Download failed") -> SeededDownloadState {
        SeededDownloadState(status: .failed, errorMessage: message)
    }

    /// Create paused state with progress
    public static func paused(progress: Double) -> SeededDownloadState {
        SeededDownloadState(status: .paused, progress: max(0.0, min(1.0, progress)))
    }

    /// Create not downloaded state
    public static func notDownloaded() -> SeededDownloadState {
        SeededDownloadState(status: .notDownloaded)
    }

    // MARK: - Test Helper: Encode States to JSON

    /// Encode states to JSON string for test environment variable
    public static func encodeStates(_ states: [String: SeededDownloadState]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let jsonData = try? encoder.encode(states),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }
}

#endif
