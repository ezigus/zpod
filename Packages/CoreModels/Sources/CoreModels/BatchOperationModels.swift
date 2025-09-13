@preconcurrency import Foundation

/// Represents different types of batch operations that can be performed on episodes
public enum BatchOperationType: String, Codable, Sendable, CaseIterable {
    case download = "download"
    case markAsPlayed = "mark_as_played"
    case markAsUnplayed = "mark_as_unplayed"
    case addToPlaylist = "add_to_playlist"
    case archive = "archive"
    case delete = "delete"
    case share = "share"
    case favorite = "favorite"
    case unfavorite = "unfavorite"
    case bookmark = "bookmark"
    case unbookmark = "unbookmark"
    
    public var displayName: String {
        switch self {
        case .download: return "Download"
        case .markAsPlayed: return "Mark as Played"
        case .markAsUnplayed: return "Mark as Unplayed"
        case .addToPlaylist: return "Add to Playlist"
        case .archive: return "Archive"
        case .delete: return "Delete"
        case .share: return "Share"
        case .favorite: return "Add to Favorites"
        case .unfavorite: return "Remove from Favorites"
        case .bookmark: return "Add Bookmark"
        case .unbookmark: return "Remove Bookmark"
        }
    }
    
    public var isReversible: Bool {
        switch self {
        case .delete: return false
        case .share: return false
        default: return true
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .download: return "arrow.down.circle"
        case .markAsPlayed: return "checkmark.circle"
        case .markAsUnplayed: return "circle"
        case .addToPlaylist: return "plus.rectangle.on.rectangle"
        case .archive: return "archivebox"
        case .delete: return "trash"
        case .share: return "square.and.arrow.up"
        case .favorite: return "heart"
        case .unfavorite: return "heart.slash"
        case .bookmark: return "bookmark"
        case .unbookmark: return "bookmark.slash"
        }
    }
}

/// Represents the status of a batch operation
public enum BatchOperationStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Represents a single episode operation within a batch
public struct EpisodeOperation: Codable, Sendable, Identifiable {
    public let id: String
    public let episodeID: String
    public let operationType: BatchOperationType
    public var status: BatchOperationStatus
    public var error: String?
    public var completedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        episodeID: String,
        operationType: BatchOperationType,
        status: BatchOperationStatus = .pending,
        error: String? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.episodeID = episodeID
        self.operationType = operationType
        self.status = status
        self.error = error
        self.completedAt = completedAt
    }
    
    public func withStatus(_ newStatus: BatchOperationStatus) -> EpisodeOperation {
        var copy = self
        copy.status = newStatus
        if newStatus == .completed || newStatus == .failed || newStatus == .cancelled {
            copy.completedAt = Date()
        }
        return copy
    }
    
    public func withError(_ error: String) -> EpisodeOperation {
        var copy = self
        copy.error = error
        copy.status = .failed
        copy.completedAt = Date()
        return copy
    }
}

/// Represents a complete batch operation containing multiple episode operations
public struct BatchOperation: Codable, Sendable, Identifiable {
    public let id: String
    public let operationType: BatchOperationType
    public var operations: [EpisodeOperation]
    public var status: BatchOperationStatus
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var totalCount: Int { operations.count }
    public var completedCount: Int { operations.filter { $0.status == .completed }.count }
    public var failedCount: Int { operations.filter { $0.status == .failed }.count }
    public var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount + failedCount) / Double(totalCount)
    }
    
    // Additional parameters for specific operations
    public var playlistID: String?
    public var shareMessage: String?
    
    public init(
        id: String = UUID().uuidString,
        operationType: BatchOperationType,
        episodeIDs: [String],
        playlistID: String? = nil,
        shareMessage: String? = nil
    ) {
        self.id = id
        self.operationType = operationType
        self.operations = episodeIDs.map { episodeID in
            EpisodeOperation(episodeID: episodeID, operationType: operationType)
        }
        self.status = .pending
        self.createdAt = Date()
        self.playlistID = playlistID
        self.shareMessage = shareMessage
    }
    
    public func withStatus(_ newStatus: BatchOperationStatus) -> BatchOperation {
        var copy = self
        copy.status = newStatus
        if newStatus == .running && copy.startedAt == nil {
            copy.startedAt = Date()
        }
        if newStatus == .completed || newStatus == .failed || newStatus == .cancelled {
            copy.completedAt = Date()
        }
        return copy
    }
    
    public func withUpdatedOperation(_ operation: EpisodeOperation) -> BatchOperation {
        var copy = self
        if let index = copy.operations.firstIndex(where: { $0.id == operation.id }) {
            copy.operations[index] = operation
        }
        
        // Update batch status based on operation statuses
        let allCompleted = copy.operations.allSatisfy { $0.status == .completed || $0.status == .failed }
        if allCompleted && copy.status == .running {
            copy.status = .completed
            copy.completedAt = Date()
        }
        
        return copy
    }
}

/// Represents the state of episode selection for batch operations
public struct EpisodeSelectionState: Sendable {
    public private(set) var selectedEpisodeIDs: Set<String>
    public private(set) var isMultiSelectMode: Bool
    public private(set) var lastSelectedEpisodeID: String?
    
    public init() {
        self.selectedEpisodeIDs = Set()
        self.isMultiSelectMode = false
        self.lastSelectedEpisodeID = nil
    }
    
    public var hasSelection: Bool {
        return !selectedEpisodeIDs.isEmpty
    }
    
    public var selectedCount: Int {
        return selectedEpisodeIDs.count
    }
    
    public mutating func enterMultiSelectMode() {
        isMultiSelectMode = true
    }
    
    public mutating func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedEpisodeIDs.removeAll()
        lastSelectedEpisodeID = nil
    }
    
    public mutating func toggleSelection(for episodeID: String) {
        if selectedEpisodeIDs.contains(episodeID) {
            selectedEpisodeIDs.remove(episodeID)
        } else {
            selectedEpisodeIDs.insert(episodeID)
        }
        lastSelectedEpisodeID = episodeID
    }
    
    public mutating func selectAll(episodeIDs: [String]) {
        selectedEpisodeIDs = Set(episodeIDs)
    }
    
    public mutating func selectNone() {
        selectedEpisodeIDs.removeAll()
        lastSelectedEpisodeID = nil
    }
    
    public mutating func invertSelection(allEpisodeIDs: [String]) {
        let allIDs = Set(allEpisodeIDs)
        selectedEpisodeIDs = allIDs.subtracting(selectedEpisodeIDs)
    }
    
    public func isSelected(_ episodeID: String) -> Bool {
        return selectedEpisodeIDs.contains(episodeID)
    }
}

/// Criteria for advanced episode selection
public struct EpisodeSelectionCriteria: Codable, Sendable {
    public var olderThanDays: Int?
    public var newerThanDays: Int?
    public var playStatus: PlayStatus?
    public var downloadStatus: EpisodeDownloadStatus?
    public var minimumDuration: TimeInterval?
    public var maximumDuration: TimeInterval?
    public var favoriteStatus: Bool?
    public var bookmarkStatus: Bool?
    public var archiveStatus: Bool?
    
    public enum PlayStatus: String, Codable, Sendable, CaseIterable {
        case played
        case unplayed
        case inProgress
        
        public var displayName: String {
            switch self {
            case .played: return "Played"
            case .unplayed: return "Unplayed"
            case .inProgress: return "In Progress"
            }
        }
    }
    
    public init() {}
    
    public func matches(episode: Episode) -> Bool {
        // Check date criteria
        if let olderThanDays = olderThanDays,
           let pubDate = episode.pubDate {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
            if pubDate > cutoffDate {
                return false
            }
        }
        
        if let newerThanDays = newerThanDays,
           let pubDate = episode.pubDate {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -newerThanDays, to: Date()) ?? Date()
            if pubDate < cutoffDate {
                return false
            }
        }
        
        // Check play status
        if let playStatus = playStatus {
            switch playStatus {
            case .played:
                if !episode.isPlayed { return false }
            case .unplayed:
                if episode.isPlayed || episode.isInProgress { return false }
            case .inProgress:
                if !episode.isInProgress { return false }
            }
        }
        
        // Check download status
        if let downloadStatus = downloadStatus {
            if episode.downloadStatus != downloadStatus { return false }
        }
        
        // Check duration criteria
        if let duration = episode.duration {
            if let minimumDuration = minimumDuration, duration < minimumDuration {
                return false
            }
            if let maximumDuration = maximumDuration, duration > maximumDuration {
                return false
            }
        }
        
        // Check status flags
        if let favoriteStatus = favoriteStatus, episode.isFavorited != favoriteStatus {
            return false
        }
        
        if let bookmarkStatus = bookmarkStatus, episode.isBookmarked != bookmarkStatus {
            return false
        }
        
        if let archiveStatus = archiveStatus, episode.isArchived != archiveStatus {
            return false
        }
        
        return true
    }
}