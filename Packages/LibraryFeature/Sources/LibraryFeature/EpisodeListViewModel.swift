import Foundation
import SwiftUI
import CoreModels
import Persistence
import Combine

// MARK: - Episode List View Model

/// View model for episode list with filtering, sorting, and batch operations
@MainActor
public final class EpisodeListViewModel: ObservableObject {
    @Published public private(set) var filteredEpisodes: [Episode] = []
    @Published public private(set) var currentFilter: EpisodeFilter = EpisodeFilter()
    @Published public private(set) var isLoading = false
    @Published public private(set) var searchText = ""
    @Published public var showingFilterSheet = false
    
    // Batch operation properties
    @Published public private(set) var selectionState = EpisodeSelectionState()
    @Published public private(set) var activeBatchOperations: [BatchOperation] = []
    @Published public var showingBatchOperationSheet = false
    @Published public var showingPlaylistSelectionSheet = false
    @Published public var showingSelectionCriteriaSheet = false
    
    private let podcast: Podcast
    private let filterService: EpisodeFilterService
    private let filterManager: EpisodeFilterManager?
    private let batchOperationManager: BatchOperationManaging
    private var cancellables = Set<AnyCancellable>()
    private var allEpisodes: [Episode] = []
    
    public init(
        podcast: Podcast,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
        filterManager: EpisodeFilterManager? = nil,
        batchOperationManager: BatchOperationManaging = InMemoryBatchOperationManager()
    ) {
        self.podcast = podcast
        self.filterService = filterService
        self.filterManager = filterManager
        self.batchOperationManager = batchOperationManager
        self.allEpisodes = podcast.episodes
        
        // Load saved filter for this podcast
        loadInitialFilter()
        applyCurrentFilter()
        
        // Subscribe to batch operation updates
        setupBatchOperationSubscription()
    }
    
    // MARK: - Public Methods
    
    public func setFilter(_ filter: EpisodeFilter) {
        currentFilter = filter
        applyCurrentFilter()
        
        // Save filter preference for this podcast
        launchMainActorTask {
            await filterManager?.setCurrentFilter(filter, forPodcast: podcast.id)
        }
    }
    
    public func clearFilter() {
        setFilter(EpisodeFilter())
    }
    
    public func updateSearchText(_ text: String) {
        searchText = text
        applyCurrentFilter()
    }
    
    public func refreshEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: In a real implementation, this would fetch fresh episodes
        // For now, simulate a refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        applyCurrentFilter()
    }
    
    public func toggleEpisodeFavorite(_ episode: Episode) {
        updateEpisode(episode.withFavoriteStatus(!episode.isFavorited))
    }
    
    public func toggleEpisodeBookmark(_ episode: Episode) {
        updateEpisode(episode.withBookmarkStatus(!episode.isBookmarked))
    }
    
    public func markEpisodeAsPlayed(_ episode: Episode) {
        updateEpisode(episode.withPlayedStatus(true))
    }
    
    public func setEpisodeRating(_ episode: Episode, rating: Int?) {
        updateEpisode(episode.withRating(rating))
    }
    
    // MARK: - Batch Operation Methods
    
    public func enterMultiSelectMode() {
        selectionState.enterMultiSelectMode()
    }
    
    public func exitMultiSelectMode() {
        selectionState.exitMultiSelectMode()
    }
    
    public func toggleEpisodeSelection(_ episode: Episode) {
        selectionState.toggleSelection(for: episode.id)
    }
    
    public func selectAllEpisodes() {
        let episodeIDs = filteredEpisodes.map { $0.id }
        selectionState.selectAll(episodeIDs: episodeIDs)
    }
    
    public func selectNone() {
        selectionState.selectNone()
    }
    
    public func invertSelection() {
        let allEpisodeIDs = filteredEpisodes.map { $0.id }
        selectionState.invertSelection(allEpisodeIDs: allEpisodeIDs)
    }
    
    public func selectEpisodesByCriteria(_ criteria: EpisodeSelectionCriteria) {
        let matchingEpisodes = filteredEpisodes.filter { criteria.matches(episode: $0) }
        let episodeIDs = matchingEpisodes.map { $0.id }
        selectionState.selectAll(episodeIDs: episodeIDs)
    }
    
    public func executeBatchOperation(_ operationType: BatchOperationType, playlistID: String? = nil) async {
        guard selectionState.hasSelection else { return }
        
        let selectedEpisodeIDs = Array(selectionState.selectedEpisodeIDs)
        let batchOperation = BatchOperation(
            operationType: operationType,
            episodeIDs: selectedEpisodeIDs,
            playlistID: playlistID
        )
        
        do {
            let _ = try await batchOperationManager.executeBatchOperation(batchOperation)
            // Operation completed successfully
            exitMultiSelectMode()
        } catch {
            // Handle error - in a real implementation, this would show an error message
            print("Batch operation failed: \(error)")
        }
    }
    
    public func cancelBatchOperation(_ operationID: String) async {
        await batchOperationManager.cancelBatchOperation(id: operationID)
    }
    
    public var selectedEpisodes: [Episode] {
        return filteredEpisodes.filter { selectionState.isSelected($0.id) }
    }
    
    public var isEpisodeSelected: (String) -> Bool {
        return { [weak self] episodeID in
            self?.selectionState.isSelected(episodeID) ?? false
        }
    }
    
    public var hasActiveSelection: Bool {
        return selectionState.hasSelection
    }
    
    public var selectedCount: Int {
        return selectionState.selectedCount
    }
    
    public var isInMultiSelectMode: Bool {
        return selectionState.isMultiSelectMode
    }
    
    
    public var availableBatchOperations: [BatchOperationType] {
        return [
            .download,
            .markAsPlayed,
            .markAsUnplayed,
            .addToPlaylist,
            .favorite,
            .unfavorite,
            .bookmark,
            .unbookmark,
            .archive,
            .share,
            .delete
        ]
    }
    
    // MARK: - Episode Status Helpers
    
    public var hasActiveFilters: Bool {
        return !currentFilter.isEmpty || !searchText.isEmpty
    }
    
    public var filterSummary: String {
        if currentFilter.isEmpty && searchText.isEmpty {
            return "All Episodes (\(allEpisodes.count))"
        }
        
        var parts: [String] = []
        
        if !currentFilter.isEmpty {
            parts.append(currentFilter.displayName)
        }
        
        if !searchText.isEmpty {
            parts.append("Search: \"\(searchText)\"")
        }
        
        let summary = parts.joined(separator: " • ")
        return "\(summary) (\(filteredEpisodes.count))"
    }
    
    // MARK: - Private Methods

    @discardableResult
    private func launchMainActorTask(priority: TaskPriority? = nil, _ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task(priority: priority) { @MainActor in
            await operation()
        }
    }

    @discardableResult
    private func launchTask(priority: TaskPriority? = nil, _ operation: @escaping @Sendable () async throws -> Void) -> Task<Void, Error> {
        Task(priority: priority) {
            try await operation()
        }
    }


    private func setupBatchOperationSubscription() {
        batchOperationManager.batchOperationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] batchOperation in
                self?.updateBatchOperation(batchOperation)
            }
            .store(in: &cancellables)
    }
    
    private func updateBatchOperation(_ batchOperation: BatchOperation) {
        if let index = activeBatchOperations.firstIndex(where: { $0.id == batchOperation.id }) {
            activeBatchOperations[index] = batchOperation
        } else if batchOperation.status == .running {
            activeBatchOperations.append(batchOperation)
        }
        
        // Remove completed operations after a delay
        if batchOperation.status == .completed || batchOperation.status == .failed || batchOperation.status == .cancelled {
            launchTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    activeBatchOperations.removeAll { $0.id == batchOperation.id }
                }
            }
        }
    }
    
    private func loadInitialFilter() {
        if let filterManager = filterManager {
            currentFilter = filterManager.filterForPodcast(podcast.id)
        }
    }
    
    private func applyCurrentFilter() {
        launchMainActorTask {
            var episodes = allEpisodes
            
            // Apply search if present
            if !searchText.isEmpty {
                episodes = filterService.searchEpisodes(episodes, query: searchText, filter: nil)
            }
            
            // Apply filter and sort
            episodes = filterService.filterAndSort(episodes: episodes, using: currentFilter)
            
            filteredEpisodes = episodes
        }
    }
    
    private func updateEpisode(_ updatedEpisode: Episode) {
        // Update in all episodes
        if let index = allEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
            allEpisodes[index] = updatedEpisode
        }
        
        // Update in filtered episodes
        if let index = filteredEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
            filteredEpisodes[index] = updatedEpisode
        }
        
        // TODO: In a real implementation, this would save to persistence
    }
    
    // MARK: - Enhanced Episode Status Management
    
    /// Toggle the played status of an episode with immediate UI feedback
    public func toggleEpisodePlayedStatus(_ episode: Episode) {
        let updatedEpisode = episode.withPlayedStatus(!episode.isPlayed)
        updateEpisode(updatedEpisode)
    }
    
    /// Retry failed download for an episode
    public func retryEpisodeDownload(_ episode: Episode) {
        guard episode.downloadStatus == .failed else { return }
        
        // Update status to downloading
        let updatedEpisode = episode.withDownloadStatus(.downloading)
        updateEpisode(updatedEpisode)
        
        // TODO: In a real implementation, this would trigger actual download retry
        // For now, simulate successful download after delay
        launchTask {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                let completedEpisode = updatedEpisode.withDownloadStatus(.downloaded)
                updateEpisode(completedEpisode)
            }
        }
    }
    
    /// Retry a failed batch operation
    public func retryBatchOperation(_ batchOperationId: String) async {
        // TODO: In a real implementation, this would retry the specific failed operations
        // For now, find the batch operation and restart failed operations
        if let batchIndex = activeBatchOperations.firstIndex(where: { $0.id == batchOperationId }) {
            let batchOperation = activeBatchOperations[batchIndex]
            let failedOperations = batchOperation.operations.filter { $0.status == .failed }
            
            if !failedOperations.isEmpty {
                // Restart the batch operation with only failed episodes
                let retryBatch = BatchOperation(
                    operationType: batchOperation.operationType,
                    episodeIDs: failedOperations.map { $0.episodeID },
                    playlistID: batchOperation.playlistID
                )
                
                do {
                    let _ = try await batchOperationManager.executeBatchOperation(retryBatch)
                } catch {
                    print("Retry batch operation failed: \(error)")
                }
            }
        }
    }
    
    /// Undo a completed batch operation if it's reversible
    public func undoBatchOperation(_ batchOperationId: String) async {
        // TODO: In a real implementation, this would reverse the effects of the batch operation
        // For now, simulate the undo operation
        if let batchIndex = activeBatchOperations.firstIndex(where: { $0.id == batchOperationId }) {
            let batchOperation = activeBatchOperations[batchIndex]
            
            guard batchOperation.operationType.isReversible else { return }
            
            // Create reverse operation
            let reverseOperationType: BatchOperationType
            switch batchOperation.operationType {
            case .markAsPlayed:
                reverseOperationType = .markAsUnplayed
            case .markAsUnplayed:
                reverseOperationType = .markAsPlayed
            case .favorite:
                reverseOperationType = .unfavorite
            case .unfavorite:
                reverseOperationType = .favorite
            case .bookmark:
                reverseOperationType = .unbookmark
            case .unbookmark:
                reverseOperationType = .bookmark
            case .archive:
                // Unarchive episodes by updating them directly
                let episodeIDs = batchOperation.operations.map { $0.episodeID }
                for episodeID in episodeIDs {
                    if let episode = allEpisodes.first(where: { $0.id == episodeID }) {
                        let updatedEpisode = episode.withArchivedStatus(false)
                        updateEpisode(updatedEpisode)
                    }
                }
                return
            default:
                return // Non-reversible operations
            }
            
            // Execute reverse batch operation
            let undoBatch = BatchOperation(
                operationType: reverseOperationType,
                episodeIDs: batchOperation.operations.map { $0.episodeID },
                playlistID: batchOperation.playlistID
            )
            
            do {
                let _ = try await batchOperationManager.executeBatchOperation(undoBatch)
            } catch {
                print("Undo batch operation failed: \(error)")
            }
        }
    }
    
    /// Pause/resume episode download
    public func pauseEpisodeDownload(_ episode: Episode) {
        guard episode.downloadStatus == .downloading else { return }
        
        // TODO: In a real implementation, this would pause the actual download
        // For now, simulate pausing by changing status
        let pausedEpisode = episode.withDownloadStatus(.notDownloaded)
        updateEpisode(pausedEpisode)
    }
    
    /// Quick play an episode that's in progress
    public func quickPlayEpisode(_ episode: Episode) {
        // TODO: In a real implementation, this would start playback from current position
        // For now, just mark as played after a short delay to simulate playing
        launchTask {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                let playedEpisode = episode.withPlayedStatus(true)
                updateEpisode(playedEpisode)
            }
        }
    }
}

// MARK: - Smart List View Model

/// View model for smart episode lists
@MainActor
public final class SmartEpisodeListViewModel: ObservableObject {
    @Published public private(set) var episodes: [Episode] = []
    @Published public private(set) var smartList: SmartEpisodeList
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastRefresh: Date?
    
    private let filterService: EpisodeFilterService
    private let filterManager: EpisodeFilterManager
    private var allEpisodes: [Episode] = [] // Would come from all podcasts
    
    public init(
        smartList: SmartEpisodeList,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
        filterManager: EpisodeFilterManager
    ) {
        self.smartList = smartList
        self.filterService = filterService
        self.filterManager = filterManager
        
        updateEpisodes()
        
        // Set up auto-refresh if enabled
        if smartList.autoUpdate {
            scheduleAutoRefresh()
        }
    }
    
    // MARK: - Public Methods
    
    public func refreshNow() async {
        isLoading = true
        defer { isLoading = false }
        
        updateEpisodes()
        
        // Update the smart list's last updated time
        let updatedSmartList = smartList.withLastUpdated(Date())
        smartList = updatedSmartList
        await filterManager.updateSmartList(updatedSmartList)
        
        lastRefresh = Date()
    }
    
    public var needsRefresh: Bool {
        return filterService.smartListNeedsUpdate(smartList)
    }
    
    public var refreshIntervalText: String {
        let minutes = Int(smartList.refreshInterval / 60)
        return "\(minutes) min"
    }
    
    // MARK: - Private Methods

    @discardableResult
    private func launchMainActorTask(priority: TaskPriority? = nil, _ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task(priority: priority) { @MainActor in
            await operation()
        }
    }

    private func updateEpisodes() {
        launchMainActorTask {
            let filteredEpisodes = filterService.updateSmartList(smartList, allEpisodes: allEpisodes)
            episodes = filteredEpisodes
        }
    }
    
    private func scheduleAutoRefresh() {
        // TODO: Implement background refresh scheduling
        // This would typically use a timer or background task
    }
}
