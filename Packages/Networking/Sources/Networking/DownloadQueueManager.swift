#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import CoreModels

/// Protocol for managing download queue operations
@MainActor
public protocol DownloadQueueManaging {
    #if canImport(Combine)
    /// Publisher for queue state changes
    var queuePublisher: AnyPublisher<[DownloadTask], Never> { get }
    #endif
    
    /// Add a task to the download queue
    func addToQueue(_ task: DownloadTask)
    
    /// Remove a task from the queue
    func removeFromQueue(taskId: String)
    
    /// Reorder tasks in the queue based on provided task IDs
    func reorderQueue(taskIds: [String])
    
    /// Pause a downloading task
    func pauseDownload(taskId: String)
    
    /// Resume a paused task
    func resumeDownload(taskId: String)
    
    /// Cancel a task
    func cancelDownload(taskId: String)
    
    /// Retry a failed download
    func retryFailedDownload(taskId: String)
    
    /// Get current queue state
    func getCurrentQueue() -> [DownloadTask]
    
    /// Get a specific task by ID
    func getTask(id: String) -> DownloadInfo?
}

/// In-memory implementation of download queue manager
@MainActor
public final class InMemoryDownloadQueueManager: DownloadQueueManaging {
    private var tasks: [String: DownloadInfo] = [:]
    private var queueOrder: [String] = []
    
    #if canImport(Combine)
    private let queueSubject = CurrentValueSubject<[DownloadTask], Never>([])
    
    public var queuePublisher: AnyPublisher<[DownloadTask], Never> {
        queueSubject.eraseToAnyPublisher()
    }
    #endif
    
    public init() {}
    
    public func addToQueue(_ task: DownloadTask) {
        let downloadInfo = DownloadInfo(task: task, state: .pending)
        tasks[task.id] = downloadInfo
        
        // Insert based on priority (higher priority first)
        if let insertIndex = queueOrder.firstIndex(where: { taskId in
            guard let existingTask = tasks[taskId] else { return false }
            return existingTask.task.priority < task.priority
        }) {
            queueOrder.insert(task.id, at: insertIndex)
        } else {
            queueOrder.append(task.id)
        }
        
        publishQueueUpdate()
    }
    
    public func removeFromQueue(taskId: String) {
        tasks.removeValue(forKey: taskId)
        queueOrder.removeAll { $0 == taskId }
        publishQueueUpdate()
    }
    
    public func reorderQueue(taskIds: [String]) {
        // Validate all task IDs exist
        let validTaskIds = taskIds.filter { tasks[$0] != nil }
        
        // Update queue order
        queueOrder = validTaskIds
        
        publishQueueUpdate()
    }
    
    public func pauseDownload(taskId: String) {
        guard var task = tasks[taskId], task.state == .downloading else { return }
        task = task.withState(.paused)
        tasks[taskId] = task
        publishQueueUpdate()
    }
    
    public func resumeDownload(taskId: String) {
        guard var task = tasks[taskId], task.state == .paused else { return }
        task = task.withState(.downloading)
        tasks[taskId] = task
        publishQueueUpdate()
    }
    
    public func cancelDownload(taskId: String) {
        guard var task = tasks[taskId] else { return }
        task = task.withState(.cancelled)
        tasks[taskId] = task
        publishQueueUpdate()
    }
    
    public func retryFailedDownload(taskId: String) {
        guard var downloadInfo = tasks[taskId], downloadInfo.state == .failed else { return }
        let retryTask = downloadInfo.task.withRetry()
        downloadInfo = DownloadInfo(task: retryTask, state: .pending)
        tasks[taskId] = downloadInfo
        publishQueueUpdate()
    }
    
    public func getCurrentQueue() -> [DownloadTask] {
        return queueOrder.compactMap { tasks[$0]?.task }
    }
    
    public func getTask(id: String) -> DownloadInfo? {
        return tasks[id]
    }
    
    // MARK: - Private Methods
    
    private func publishQueueUpdate() {
        let currentQueue = getCurrentQueue()
        #if canImport(Combine)
        queueSubject.send(currentQueue)
        #endif
    }
}
