import Foundation
import SwiftUI
import CoreModels
import Persistence
import Combine
import PlaybackEngine

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
    @Published public private(set) var downloadProgressByEpisodeID: [String: EpisodeDownloadProgressUpdate] = [:]
    @Published public private(set) var bannerState: EpisodeListBannerState?

    private let podcast: Podcast
    private let filterService: EpisodeFilterService
    private let filterManager: EpisodeFilterManager?
    private let batchOperationManager: BatchOperationManaging
    private let downloadProgressProvider: DownloadProgressProviding?
    private let downloadManager: DownloadManaging?
    private let playbackService: EpisodePlaybackService?
    private let episodeRepository: EpisodeRepository?
    private var cancellables = Set<AnyCancellable>()
    private var playbackStateCancellable: AnyCancellable?
    private var bannerDismissTask: Task<Void, Never>?
    private var allEpisodes: [Episode] = []
    
    public init(
        podcast: Podcast,
        filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
        filterManager: EpisodeFilterManager? = nil,
        batchOperationManager: BatchOperationManaging = InMemoryBatchOperationManager(),
        downloadProgressProvider: DownloadProgressProviding? = nil,
        downloadManager: DownloadManaging? = nil,
        playbackService: EpisodePlaybackService? = nil,
        episodeRepository: EpisodeRepository? = nil
    ) {
        self.podcast = podcast
        self.filterService = filterService
        self.filterManager = filterManager
        self.batchOperationManager = batchOperationManager
        self.downloadProgressProvider = downloadProgressProvider
        self.downloadManager = downloadManager
        self.playbackService = playbackService
        self.episodeRepository = episodeRepository
        self.allEpisodes = podcast.episodes

        // Load saved filter for this podcast
        loadInitialFilter()
        applyCurrentFilter()

        // Subscribe to batch operation updates
        setupBatchOperationSubscription()
        setupDownloadProgressSubscription()
    }
    
    // MARK: - Public Methods
    
    public func setFilter(_ filter: EpisodeFilter) {
        currentFilter = filter
        applyCurrentFilter()
        
        // Save filter preference for this podcast
        launchMainActorTask { viewModel in
            await viewModel.filterManager?.setCurrentFilter(filter, forPodcast: viewModel.podcast.id)
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

    public func downloadProgress(for episodeID: String) -> EpisodeDownloadProgressUpdate? {
        downloadProgressByEpisodeID[episodeID]
    }

    public func dismissBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        bannerState = nil
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
    private func launchMainActorTask(
        priority: TaskPriority? = nil,
        _ operation: @escaping (EpisodeListViewModel) async -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) { @MainActor [weak self] in
            guard let self else { return }
            await operation(self)
        }
    }

    @discardableResult
    private func launchTask(
        priority: TaskPriority? = nil,
        _ operation: @escaping (EpisodeListViewModel) async throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) { [weak self] in
            guard let self else { return }
            try await operation(self)
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
            launchTask { viewModel in
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    viewModel.activeBatchOperations.removeAll { $0.id == batchOperation.id }
                }
            }
        }

        if batchOperation.status == .completed || batchOperation.status == .failed {
            presentBanner(for: batchOperation)
        }
    }

    private func setupDownloadProgressSubscription() {
        guard let downloadProgressProvider else { return }

        downloadProgressProvider.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.applyDownloadProgressUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func applyDownloadProgressUpdate(_ update: EpisodeDownloadProgressUpdate) {
        downloadProgressByEpisodeID[update.episodeID] = update

        guard var episode = episodeForID(update.episodeID) else { return }

        switch update.status {
        case .queued, .downloading:
            episode = episode.withDownloadStatus(.downloading)
        case .paused:
            episode = episode.withDownloadStatus(.paused)
        case .completed:
            episode = episode.withDownloadStatus(.downloaded)
        case .failed:
            episode = episode.withDownloadStatus(.failed)
        }

        updateEpisode(episode)

        if update.status == .completed || update.status == .failed {
            scheduleProgressClear(for: update.episodeID)
        }
    }

    private func episodeForID(_ id: String) -> Episode? {
        if let existing = allEpisodes.first(where: { $0.id == id }) {
            return existing
        }
        return filteredEpisodes.first(where: { $0.id == id })
    }

    private func scheduleProgressClear(for episodeID: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                guard let self else { return }
                guard let progress = self.downloadProgressByEpisodeID[episodeID] else { return }
                switch progress.status {
                case .completed, .failed:
                    self.downloadProgressByEpisodeID.removeValue(forKey: episodeID)
                default:
                    break
                }
            }
        }
    }

    private func presentBanner(for batchOperation: BatchOperation) {
        guard let banner = makeBannerState(for: batchOperation) else { return }

        bannerState = banner
        bannerDismissTask?.cancel()
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                guard let self else { return }
                if self.bannerState?.title == banner.title && self.bannerState?.subtitle == banner.subtitle {
                    self.bannerState = nil
                }
            }
        }
    }

    private func makeBannerState(for batchOperation: BatchOperation) -> EpisodeListBannerState? {
        let succeeded = batchOperation.completedCount
        let failed = batchOperation.failedCount
        let total = batchOperation.totalCount

        if total == 0 {
            return nil
        }

        let title: String
        switch batchOperation.status {
        case .failed:
            title = "\(batchOperation.operationType.displayName) Failed"
        default:
            title = "\(batchOperation.operationType.displayName) Complete"
        }

        var subtitleParts: [String] = []
        if succeeded > 0 {
            subtitleParts.append("\(succeeded) succeeded")
        }
        if failed > 0 {
            subtitleParts.append("\(failed) failed")
        }
        if subtitleParts.isEmpty {
            subtitleParts.append("No changes applied")
        }
        let subtitle = subtitleParts.joined(separator: " • ")

        let style: EpisodeListBannerState.Style = (failed > 0 || batchOperation.status == .failed) ? .failure : .success
        let operationID = batchOperation.id

        let retryAction: (() -> Void)? = failed > 0 ? { [weak self] in
            guard let self else { return }
            Task { await self.retryBatchOperation(operationID) }
        } : nil

        let undoAction: (() -> Void)? = batchOperation.operationType.isReversible ? { [weak self] in
            guard let self else { return }
            Task { await self.undoBatchOperation(operationID) }
        } : nil

        return EpisodeListBannerState(
            title: title,
            subtitle: subtitle,
            style: style,
            retry: retryAction,
            undo: undoAction
        )
    }
    
    private func loadInitialFilter() {
        if let filterManager = filterManager {
            currentFilter = filterManager.filterForPodcast(podcast.id)
        }
    }
    
    private func applyCurrentFilter() {
        launchMainActorTask { viewModel in
            var episodes = viewModel.allEpisodes

            // Apply search if present
            if !viewModel.searchText.isEmpty {
                episodes = viewModel.filterService.searchEpisodes(
                    episodes,
                    query: viewModel.searchText,
                    filter: nil
                )
            }

            // Apply filter and sort
            episodes = viewModel.filterService.filterAndSort(episodes: episodes, using: viewModel.currentFilter)

            viewModel.filteredEpisodes = episodes
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

        if let episodeRepository {
            Task {
                try? await episodeRepository.saveEpisode(updatedEpisode)
            }
        }
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
        
        if let enqueuer = downloadManager as? EpisodeDownloadEnqueuing {
            enqueuer.enqueueEpisode(updatedEpisode)
            return
        }

        // Fallback simulation when no download manager is provided
        launchTask { viewModel in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                let completedEpisode = updatedEpisode.withDownloadStatus(.downloaded)
                viewModel.updateEpisode(completedEpisode)
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
    public func pauseEpisodeDownload(_ episode: Episode) async {
        guard let downloadManager else { return }
        await downloadManager.pauseDownload(episode.id)
        if var storedEpisode = episodeForID(episode.id) {
            storedEpisode = storedEpisode.withDownloadStatus(.paused)
            updateEpisode(storedEpisode)
        }
        if var progress = downloadProgressByEpisodeID[episode.id] {
            downloadProgressByEpisodeID[episode.id] = EpisodeDownloadProgressUpdate(
                episodeID: progress.episodeID,
                fractionCompleted: progress.fractionCompleted,
                status: .paused,
                message: progress.message
            )
        }
    }

    public func resumeEpisodeDownload(_ episode: Episode) async {
        guard let downloadManager else { return }
        await downloadManager.resumeDownload(episode.id)
        if var storedEpisode = episodeForID(episode.id) {
            storedEpisode = storedEpisode.withDownloadStatus(.downloading)
            updateEpisode(storedEpisode)
        }
        if var progress = downloadProgressByEpisodeID[episode.id] {
            downloadProgressByEpisodeID[episode.id] = EpisodeDownloadProgressUpdate(
                episodeID: progress.episodeID,
                fractionCompleted: progress.fractionCompleted,
                status: .downloading,
                message: progress.message
            )
        }
    }

    /// Quick play an episode that's in progress
    public func quickPlayEpisode(_ episode: Episode) async {
        guard let playbackService else {
            return
        }

        #if canImport(Combine)
        playbackStateCancellable?.cancel()
        playbackStateCancellable = playbackService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handlePlaybackState(state)
            }
        #endif

        playbackService.play(episode: episode, duration: episode.duration)
    }
}

// MARK: - Private Helpers (Playback)

extension EpisodeListViewModel {
    private func handlePlaybackState(_ state: EpisodePlaybackState) {
        switch state {
        case .idle(let episode):
            updateEpisodePlayback(for: episode, position: 0, markPlayed: false)
        case .playing(let episode, position: let position, duration: _):
            updateEpisodePlayback(for: episode, position: position, markPlayed: false)
        case .paused(let episode, position: let position, duration: _):
            updateEpisodePlayback(for: episode, position: position, markPlayed: false)
        case .finished(let episode, duration: let duration):
            updateEpisodePlayback(for: episode, position: duration, markPlayed: true)
        }
    }

    private func updateEpisodePlayback(for episode: Episode, position: TimeInterval, markPlayed: Bool) {
        guard var storedEpisode = episodeForID(episode.id) else { return }
        storedEpisode = storedEpisode.withPlaybackPosition(Int(position))
        if markPlayed {
            storedEpisode = storedEpisode.withPlayedStatus(true)
        }
        updateEpisode(storedEpisode)
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
    private func launchMainActorTask(
        priority: TaskPriority? = nil,
        _ operation: @escaping (SmartEpisodeListViewModel) async -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) { @MainActor [weak self] in
            guard let self else { return }
            await operation(self)
        }
    }

    private func updateEpisodes() {
        launchMainActorTask { viewModel in
            let filteredEpisodes = viewModel.filterService.updateSmartList(
                viewModel.smartList,
                allEpisodes: viewModel.allEpisodes
            )
            viewModel.episodes = filteredEpisodes
        }
    }
    
    private func scheduleAutoRefresh() {
        // TODO: Implement background refresh scheduling
        // This would typically use a timer or background task
    }
}
