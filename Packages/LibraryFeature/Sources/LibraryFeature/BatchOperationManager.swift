@preconcurrency import Foundation
import CoreModels
import CombineSupport
import PlaybackEngine

/// Error types for batch operations
public enum BatchOperationError: Error, LocalizedError, Sendable {
    case operationNotSupported(BatchOperationType)
    case episodeNotFound(String)
    case playlistNotFound(String)
    case networkError(String)
    case operationCancelled
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .operationNotSupported(let type):
            return "Operation '\(type.displayName)' is not supported"
        case .episodeNotFound(let id):
            return "Episode with ID '\(id)' not found"
        case .playlistNotFound(let id):
            return "Playlist with ID '\(id)' not found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// Protocol for managing batch operations on episodes
@MainActor
public protocol BatchOperationManaging: Sendable {
    /// Execute a batch operation
    func executeBatchOperation(_ batchOperation: BatchOperation) async throws -> BatchOperation
    
    /// Cancel a running batch operation
    func cancelBatchOperation(id: String) async
    
    /// Get the current status of a batch operation
    func getBatchOperationStatus(id: String) async -> BatchOperation?
    
    /// Get all active batch operations
    func getActiveBatchOperations() async -> [BatchOperation]
    
    /// Subscribe to batch operation progress updates
    var batchOperationUpdates: AnyPublisher<BatchOperation, Never> { get }
}

/// Concrete implementation of batch operation management
@MainActor
public final class BatchOperationManager: BatchOperationManaging, ObservableObject {
    @Published public private(set) var activeBatchOperations: [BatchOperation] = []
    @Published public private(set) var completedBatchOperations: [BatchOperation] = []
    
    private var runningTasks: [String: Task<BatchOperation, Error>] = [:]
    private let batchOperationSubject = LockIsolated<PassthroughSubject<BatchOperation, Never>>(PassthroughSubject())
    
    // Dependencies
    private let episodeStateManager: EpisodeStateManager
    private let downloadManager: DownloadManaging?
    private let playlistManager: BatchPlaylistManaging?

    public init(
        episodeStateManager: EpisodeStateManager,
        downloadManager: DownloadManaging? = nil,
        playlistManager: BatchPlaylistManaging? = nil
    ) {
        self.episodeStateManager = episodeStateManager
        self.downloadManager = downloadManager
        self.playlistManager = playlistManager
    }
    
    nonisolated public var batchOperationUpdates: AnyPublisher<BatchOperation, Never> {
        batchOperationSubject.withValue { $0.eraseToAnyPublisher() }
    }
    
    public func executeBatchOperation(_ batchOperation: BatchOperation) async throws -> BatchOperation {
        var updatedBatch = batchOperation.withStatus(.running)
        
        // Add to active operations
        activeBatchOperations.append(updatedBatch)
        batchOperationSubject.withValue { $0.send(updatedBatch) }
        
        // Create and store task for cancellation
        let task = Task<BatchOperation, Error> {
            return try await performBatchOperation(updatedBatch)
        }
        runningTasks[batchOperation.id] = task
        
        do {
            updatedBatch = try await task.value
            
            // Move from active to completed
            activeBatchOperations.removeAll { $0.id == updatedBatch.id }
            completedBatchOperations.append(updatedBatch)
            
            // Clean up task
            runningTasks.removeValue(forKey: updatedBatch.id)
            
            batchOperationSubject.withValue { $0.send(updatedBatch) }
            return updatedBatch
        } catch {
            // Handle cancellation and errors
            updatedBatch = updatedBatch.withStatus(.failed)
            activeBatchOperations.removeAll { $0.id == updatedBatch.id }
            completedBatchOperations.append(updatedBatch)
            runningTasks.removeValue(forKey: updatedBatch.id)
            
            batchOperationSubject.withValue { $0.send(updatedBatch) }
            throw error
        }
    }
    
    public func cancelBatchOperation(id: String) async {
        guard let task = runningTasks[id] else { return }
        
        task.cancel()
        runningTasks.removeValue(forKey: id)
        
        // Update batch status
        if let index = activeBatchOperations.firstIndex(where: { $0.id == id }) {
            var batch = activeBatchOperations[index]
            batch = batch.withStatus(.cancelled)
            activeBatchOperations.remove(at: index)
            completedBatchOperations.append(batch)
            batchOperationSubject.withValue { $0.send(batch) }
        }
    }
    
    public func getBatchOperationStatus(id: String) async -> BatchOperation? {
        if let active = activeBatchOperations.first(where: { $0.id == id }) {
            return active
        }
        return completedBatchOperations.first { $0.id == id }
    }
    
    public func getActiveBatchOperations() async -> [BatchOperation] {
        return activeBatchOperations
    }
    
    // MARK: - Private Implementation
    
    private func performBatchOperation(_ batchOperation: BatchOperation) async throws -> BatchOperation {
        var updatedBatch = batchOperation
        
        for operation in batchOperation.operations {
            // Check for cancellation
            try Task.checkCancellation()
            
            do {
                let updatedOperation = try await performSingleOperation(operation, batchContext: batchOperation)
                updatedBatch = updatedBatch.withUpdatedOperation(updatedOperation)
                
                // Send progress update
                await MainActor.run {
                    if let index = activeBatchOperations.firstIndex(where: { $0.id == batchOperation.id }) {
                        activeBatchOperations[index] = updatedBatch
                    }
                    batchOperationSubject.withValue { $0.send(updatedBatch) }
                }
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                
            } catch {
                let failedOperation = operation.withError(error.localizedDescription)
                updatedBatch = updatedBatch.withUpdatedOperation(failedOperation)
                
                // Continue with other operations even if one fails
                await MainActor.run {
                    if let index = activeBatchOperations.firstIndex(where: { $0.id == batchOperation.id }) {
                        activeBatchOperations[index] = updatedBatch
                    }
                    batchOperationSubject.withValue { $0.send(updatedBatch) }
                }
            }
        }
        
        return updatedBatch.withStatus(.completed)
    }
    
    private func performSingleOperation(_ operation: EpisodeOperation, batchContext: BatchOperation) async throws -> EpisodeOperation {
        switch operation.operationType {
        case .markAsPlayed:
            return try await markAsPlayed(operation)
        case .markAsUnplayed:
            return try await markAsUnplayed(operation)
        case .download:
            return try await downloadEpisode(operation)
        case .addToPlaylist:
            return try await addToPlaylist(operation, playlistID: batchContext.playlistID)
        case .archive:
            return try await archiveEpisode(operation)
        case .unarchive:
            return try await unarchiveEpisode(operation)
        case .delete:
            return try await deleteEpisode(operation)
        case .favorite:
            return try await favoriteEpisode(operation)
        case .unfavorite:
            return try await unfavoriteEpisode(operation)
        case .bookmark:
            return try await bookmarkEpisode(operation)
        case .unbookmark:
            return try await unbookmarkEpisode(operation)
        case .share:
            // Share operations are handled differently (typically in UI)
            return operation.withStatus(.completed)
        }
    }
    
    // MARK: - Individual Operation Implementations
    
    private func markAsPlayed(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        // In a real implementation, this would fetch the episode and update its status
        // For now, simulate the operation
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms simulation
        return operation.withStatus(.completed)
    }
    
    private func markAsUnplayed(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func downloadEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        guard let downloadManager else {
            throw BatchOperationError.operationNotSupported(.download)
        }

        // Initiate actual download via download manager
        try await downloadManager.downloadEpisode(operation.episodeID)
        return operation.withStatus(.completed)
    }
    
    private func addToPlaylist(_ operation: EpisodeOperation, playlistID: String?) async throws -> EpisodeOperation {
        guard playlistID != nil else {
            throw BatchOperationError.playlistNotFound("No playlist specified")
        }
        
        guard playlistManager != nil else {
            throw BatchOperationError.operationNotSupported(.addToPlaylist)
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms simulation
        return operation.withStatus(.completed)
    }
    
    private func archiveEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func unarchiveEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func deleteEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms simulation for delete
        return operation.withStatus(.completed)
    }
    
    private func favoriteEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func unfavoriteEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func bookmarkEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
    
    private func unbookmarkEpisode(_ operation: EpisodeOperation) async throws -> EpisodeOperation {
        try await Task.sleep(nanoseconds: 100_000_000)
        return operation.withStatus(.completed)
    }
}

/// Protocol for download management (to be used when download manager is available)
@MainActor
public protocol DownloadManaging {
    func downloadEpisode(_ episodeID: String) async throws
    func cancelDownload(_ episodeID: String) async
    func pauseDownload(_ episodeID: String) async
    func resumeDownload(_ episodeID: String) async
    func deleteDownloadedEpisode(episodeId: String) async throws
}

public extension DownloadManaging {
    func pauseDownload(_ episodeID: String) async {}
    func resumeDownload(_ episodeID: String) async {}
    func deleteDownloadedEpisode(episodeId: String) async throws {}
}

@MainActor
public protocol EpisodeDownloadEnqueuing: DownloadManaging {
    func enqueueEpisode(_ episode: Episode)
}

/// Protocol for batch playlist management operations (distinct from CoreModels.PlaylistManaging).
public protocol BatchPlaylistManaging: Sendable {
    func addEpisodesToPlaylist(_ episodeIDs: [String], playlistID: String) async throws
    func removeEpisodesFromPlaylist(_ episodeIDs: [String], playlistID: String) async throws
}

/// Simple in-memory implementation for testing and development
public final class InMemoryBatchOperationManager: BatchOperationManaging {
    private let batchOperations = LockIsolated<[String: BatchOperation]>([:])
    private let batchOperationSubject = LockIsolated<PassthroughSubject<BatchOperation, Never>>(PassthroughSubject())
    
    public init() {}
    
    public var batchOperationUpdates: AnyPublisher<BatchOperation, Never> {
        batchOperationSubject.withValue { $0.eraseToAnyPublisher() }
    }
    
    public func executeBatchOperation(_ batchOperation: BatchOperation) async throws -> BatchOperation {
        var updatedBatch = batchOperation.withStatus(.running)
        batchOperations.withValue { $0[updatedBatch.id] = updatedBatch }
        batchOperationSubject.withValue { $0.send(updatedBatch) }
        
        // Simulate batch operation execution
        for operation in updatedBatch.operations {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms per operation
            let completedOperation = operation.withStatus(.completed)
            updatedBatch = updatedBatch.withUpdatedOperation(completedOperation)
            batchOperations.withValue { $0[updatedBatch.id] = updatedBatch }
            batchOperationSubject.withValue { $0.send(updatedBatch) }
        }
        
        updatedBatch = updatedBatch.withStatus(.completed)
        batchOperations.withValue { $0[updatedBatch.id] = updatedBatch }
        batchOperationSubject.withValue { $0.send(updatedBatch) }
        
        return updatedBatch
    }
    
    public func cancelBatchOperation(id: String) async {
        batchOperations.withValue { operations in
            if var batch = operations[id] {
                batch = batch.withStatus(.cancelled)
                operations[id] = batch
                batchOperationSubject.withValue { $0.send(batch) }
            }
        }
    }
    
    public func getBatchOperationStatus(id: String) async -> BatchOperation? {
        return batchOperations.withValue { $0[id] }
    }
    
    public func getActiveBatchOperations() async -> [BatchOperation] {
        return batchOperations.withValue { operations in
            operations.values.filter { $0.status == .running || $0.status == .pending }
        }
    }
}

/// Thread-safe container for mutable state in Sendable classes
private final class LockIsolated<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    
    init(_ value: Value) {
        self._value = value
    }
    
    func withValue<T>(_ operation: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(&_value)
    }
}
