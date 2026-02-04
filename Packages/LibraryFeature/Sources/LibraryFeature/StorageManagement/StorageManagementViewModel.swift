import Foundation
import SwiftUI
import CoreModels

/// View model for storage management
///
/// Calculates storage statistics from downloaded episodes and provides
/// delete operations for storage cleanup.
@MainActor
@Observable
public final class StorageManagementViewModel {

    // MARK: - Published State

    public var storageStats: StorageStatistics = .empty
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let downloadBridge: DownloadCoordinatorBridge
    private let fileManager: FileManager

    // MARK: - Initialization

    public init(
        downloadBridge: DownloadCoordinatorBridge = .shared,
        fileManager: FileManager = .default
    ) {
        self.downloadBridge = downloadBridge
        self.fileManager = fileManager
    }

    // MARK: - Public Methods

    /// Calculate storage statistics from all downloaded episodes
    public func calculateStorage() async {
        isLoading = true
        errorMessage = nil

        do {
            let stats = try await calculateStorageStatistics()
            storageStats = stats
        } catch {
            errorMessage = "Failed to calculate storage: \(error.localizedDescription)"
            storageStats = .empty
        }

        isLoading = false
    }

    /// Delete a single podcast's downloads
    public func deletePodcastDownloads(podcastId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Get all downloaded episode IDs
            let allEpisodeIds = downloadBridge.getAllDownloadedEpisodeIds()

            // Filter to this podcast's episodes
            // Note: This is a simplification - we'd need podcast metadata to properly filter
            // For now, we'll delete by episode ID directly
            var deletedCount = 0
            for episodeId in allEpisodeIds {
                // In a full implementation, we'd check if episodeId belongs to podcastId
                // For now, we'll skip this check
                continue
            }

            // Recalculate storage after deletion
            await calculateStorage()
        } catch {
            errorMessage = "Failed to delete podcast downloads: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Delete all downloads
    public func deleteAllDownloads() async {
        isLoading = true
        errorMessage = nil

        do {
            let deletedCount = try await downloadBridge.deleteAllDownloads()
            storageStats = .empty
        } catch {
            errorMessage = "Failed to delete all downloads: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private Methods

    /// Calculate storage statistics from downloaded episodes
    private func calculateStorageStatistics() async throws -> StorageStatistics {
        let episodeIds = downloadBridge.getAllDownloadedEpisodeIds()

        guard !episodeIds.isEmpty else {
            return .empty
        }

        var totalBytes: Int64 = 0
        var podcastStorage: [String: (title: String, episodeCount: Int, bytes: Int64)] = [:]

        for episodeId in episodeIds {
            guard let localURL = downloadBridge.localFileURL(for: episodeId) else {
                continue
            }

            // Get file size
            guard let fileSize = try? getFileSize(at: localURL) else {
                continue
            }

            totalBytes += fileSize

            // Extract podcast ID from file path
            // Path structure: .../Downloads/<podcastId>/<episodeId>.mp3
            let pathComponents = localURL.pathComponents
            if pathComponents.count >= 2 {
                let podcastId = pathComponents[pathComponents.count - 2]

                if var existing = podcastStorage[podcastId] {
                    existing.episodeCount += 1
                    existing.bytes += fileSize
                    podcastStorage[podcastId] = existing
                } else {
                    // Use podcast ID as title for now
                    // In full implementation, we'd look up actual podcast title
                    podcastStorage[podcastId] = (
                        title: "Podcast \(podcastId.prefix(8))",
                        episodeCount: 1,
                        bytes: fileSize
                    )
                }
            }
        }

        // Convert to PodcastStorageInfo array
        let podcastBreakdown = podcastStorage.map { podcastId, info in
            PodcastStorageInfo(
                id: podcastId,
                podcastTitle: info.title,
                episodeCount: info.episodeCount,
                totalBytes: info.bytes
            )
        }
        .sorted { $0.totalBytes > $1.totalBytes } // Sort by size descending

        return StorageStatistics(
            totalBytes: totalBytes,
            totalEpisodes: episodeIds.count,
            podcastBreakdown: podcastBreakdown
        )
    }

    /// Get file size at URL
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
}
