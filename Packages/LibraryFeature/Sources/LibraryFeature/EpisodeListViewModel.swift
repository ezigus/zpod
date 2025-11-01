import Combine
import CoreModels
import Foundation
import OSLog
import Persistence
import PlaybackEngine
import SettingsDomain
import SharedUtilities
import SwiftUI

// MARK: - Episode List View Model

/// View model for episode list with filtering, sorting, and batch operations
@MainActor
public final class EpisodeListViewModel: ObservableObject {
  @Published public private(set) var filteredEpisodes: [Episode] = []
  @Published public private(set) var currentFilter: EpisodeFilter = EpisodeFilter()
  @Published public private(set) var isLoading = false
  @Published public private(set) var searchText = ""
  @Published public var showingFilterSheet = false
  @Published public var showingSwipeConfiguration = false
  @Published public private(set) var swipeConfiguration: SwipeConfiguration
  @Published public private(set) var noteCounts: [String: Int] = [:]

  public var leadingSwipeActions: [SwipeActionType] {
    swipeConfiguration.swipeActions.leadingActions
  }

  public var trailingSwipeActions: [SwipeActionType] {
    swipeConfiguration.swipeActions.trailingActions
  }

  public var allowsFullSwipeLeading: Bool {
    swipeConfiguration.swipeActions.allowFullSwipeLeading
  }

  public var allowsFullSwipeTrailing: Bool {
    swipeConfiguration.swipeActions.allowFullSwipeTrailing
  }

  public var isHapticFeedbackEnabled: Bool {
    swipeConfiguration.swipeActions.hapticFeedbackEnabled
  }

  public func refreshSwipeSettings() {
    let service = swipeConfigurationService
    Task { [weak self] in
      guard let self else { return }
      let configuration = await service.load()
      await MainActor.run { self.swipeConfiguration = configuration }
    }
  }

  public func updateSwipeConfiguration(_ configuration: SwipeConfiguration) {
    swipeConfiguration = configuration
  }

  public func makeSwipeConfigurationController() -> SwipeConfigurationController {
    let controller = SwipeConfigurationController(service: swipeConfigurationService)
    // Note: Controller will load baseline from service when view appears via .task block.
    // This avoids race conditions with async settings loading or seeded test configurations.
    return controller
  }

  public func performSwipeAction(_ action: SwipeActionType, for episode: Episode) {
    swipeActionHandler.triggerHapticIfNeeded(configuration: swipeConfiguration)
    
    let callbacks = SwipeActionCallbacks(
      quickPlay: { [weak self] episode in
        await self?.quickPlayEpisode(episode)
      },
      download: { [weak self] episode in
        self?.startEpisodeDownload(episode)
      },
      markPlayed: { [weak self] episode in
        self?.markEpisodeAsPlayed(episode)
      },
      markUnplayed: { [weak self] episode in
        self?.markEpisodeAsUnplayed(episode)
      },
      selectPlaylist: { [weak self] episode in
        self?.preparePlaylistSelection(for: episode)
      },
      toggleFavorite: { [weak self] episode in
        self?.toggleEpisodeFavorite(episode)
      },
      toggleArchive: { [weak self] episode in
        self?.toggleEpisodeArchiveStatus(episode)
      },
      deleteEpisode: { [weak self] episode in
        await self?.deleteEpisode(episode)
      },
      shareEpisode: { [weak self] episode in
        self?.prepareShare(for: episode)
      }
    )

    swipeActionHandler.performSwipeAction(action, for: episode, callbacks: callbacks)
  }

  public func addPendingEpisodeToPlaylist(_ playlistID: String) {
    guard let episode = pendingPlaylistEpisode else { return }
    showingPlaylistSelectionSheet = false
    pendingPlaylistEpisode = nil

    let batchOperation = BatchOperation(
      operationType: .addToPlaylist,
      episodeIDs: [episode.id],
      playlistID: playlistID
    )

    let _: Task<Void, Error> = launchTask { viewModel in
      do {
        let _ = try await viewModel.batchOperationManager.executeBatchOperation(batchOperation)
      } catch {
        Self.logger.error("Failed to add episode to playlist: \(error, privacy: .public)")
      }
    }
  }

  public func cancelPendingPlaylistSelection() {
    pendingPlaylistEpisode = nil
    showingPlaylistSelectionSheet = false
  }

  public func clearPendingShare() {
    pendingShareEpisode = nil
  }

  // Batch operation properties
  @Published public internal(set) var selectionState = EpisodeSelectionState()
  @Published public internal(set) var activeBatchOperations: [BatchOperation] = [] {
    didSet {
      #if DEBUG
        self.overlayLogger.debug(
          "[UITEST_OVERLAY] activeBatchOperations count: \(self.activeBatchOperations.count, privacy: .public)"
        )
      #endif
    }
  }
  @Published public var showingBatchOperationSheet = false
  @Published public var showingPlaylistSelectionSheet = false
  @Published public var showingSelectionCriteriaSheet = false
  @Published public var pendingPlaylistEpisode: Episode?
  @Published public var pendingShareEpisode: Episode?

  @Published public private(set) var downloadProgressByEpisodeID: [String: EpisodeDownloadProgressUpdate] = [:]
  @Published public private(set) var bannerState: EpisodeListBannerState?

  private let podcast: Podcast
  private let filterService: EpisodeFilterService
  private let filterManager: EpisodeFilterManager?
  internal let batchOperationManager: BatchOperationManaging
  internal let downloadManager: DownloadManaging?
  private let downloadProgressProvider: DownloadProgressProviding?
  private let playbackService: EpisodePlaybackService?
  private let episodeRepository: EpisodeRepository?
  private let annotationRepository: EpisodeAnnotationRepository?
  private let swipeConfigurationService: SwipeConfigurationServicing
  private var cancellables = Set<AnyCancellable>()
  internal var allEpisodes: [Episode] = []
  internal var hasSeededUITestOverlay = false
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "EpisodeListViewModel")
  internal let overlayLogger = Logger(subsystem: "us.zig.zpod", category: "UITestOverlay")
  
  // MARK: - Coordinators
  internal lazy var downloadProgressCoordinator: EpisodeDownloadProgressCoordinator = {
    EpisodeDownloadProgressCoordinator(
      downloadProgressProvider: self.downloadProgressProvider,
      episodeLookup: { [weak self] id in self?.episodeForID(id) },
      episodeUpdateHandler: { [weak self] episode in self?.updateEpisode(episode) }
    )
  }()
  internal lazy var bannerManager: BannerPresentationManager = {
    BannerPresentationManager(
      retryHandler: { [weak self] operationID in
        await self?.retryBatchOperation(operationID)
      },
      undoHandler: { [weak self] operationID in
        await self?.undoBatchOperation(operationID)
      }
    )
  }()
  private let swipeActionHandler: SwipeActionHandling
  private lazy var playbackCoordinator: EpisodePlaybackCoordinating = {
    EpisodePlaybackCoordinator(
      playbackService: self.playbackService,
      episodeLookup: { [weak self] id in self?.episodeForID(id) },
      episodeUpdateHandler: { [weak self] episode in self?.updateEpisode(episode) }
    )
  }()

  public init(
    podcast: Podcast,
    filterService: EpisodeFilterService = DefaultEpisodeFilterService(),
    filterManager: EpisodeFilterManager? = nil,
    batchOperationManager: BatchOperationManaging = InMemoryBatchOperationManager(),
    downloadProgressProvider: DownloadProgressProviding? = nil,
    downloadManager: DownloadManaging? = nil,
    playbackService: EpisodePlaybackService? = nil,
    episodeRepository: EpisodeRepository? = nil,
    swipeConfigurationService: SwipeConfigurationServicing =
      EpisodeListViewModel.makeDefaultSwipeConfigurationService(),
    hapticFeedbackService: HapticFeedbackServicing = HapticFeedbackService.shared,
    annotationRepository: EpisodeAnnotationRepository? = nil
  ) {
    self.podcast = podcast
    self.filterService = filterService
    self.filterManager = filterManager
    self.batchOperationManager = batchOperationManager
    self.downloadManager = downloadManager
    self.downloadProgressProvider = downloadProgressProvider
    self.playbackService = playbackService
    self.episodeRepository = episodeRepository
    self.swipeConfigurationService = swipeConfigurationService
    self.annotationRepository = annotationRepository
    self.allEpisodes = podcast.episodes
    self.swipeConfiguration = .default

    self.swipeActionHandler = SwipeActionHandler(
      hapticFeedbackService: hapticFeedbackService
    )

    bindCoordinatorPublishing()

    // Load saved filter for this podcast
    loadInitialFilter()
    applyCurrentFilter()

    // Subscribe to batch operation updates
    setupBatchOperationSubscription()
    downloadProgressCoordinator.startMonitoring()
    loadPersistedEpisodes()
    observeSwipeConfiguration()
    Task {
      try? await refreshNoteCounts()
    }

  }

  @usableFromInline static func makeDefaultSwipeConfigurationService()
    -> SwipeConfigurationServicing
  {
    SwipeConfigurationService(repository: UserDefaultsSettingsRepository())
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
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

    applyCurrentFilter()
  }

  public func toggleEpisodeFavorite(_ episode: Episode) {
    updateEpisode(episode.withFavoriteStatus(!episode.isFavorited))
  }

  public func toggleEpisodeBookmark(_ episode: Episode) {
    updateEpisode(episode.withBookmarkStatus(!episode.isBookmarked))
  }

  public func refreshNoteCounts() async throws {
    guard let annotationRepository else {
      noteCounts = [:]
      return
    }

    var updatedCounts: [String: Int] = [:]
    for episode in allEpisodes {
      let notes = try await annotationRepository.loadNotes(for: episode.id)
      if !notes.isEmpty {
        updatedCounts[episode.id] = notes.count
      }
    }

    noteCounts = updatedCounts
  }

  public func toggleEpisodeArchiveStatus(_ episode: Episode) {
    updateEpisode(episode.withArchivedStatus(!episode.isArchived))
  }

  public func markEpisodeAsPlayed(_ episode: Episode) {
    updateEpisode(episode.withPlayedStatus(true))
  }

  public func markEpisodeAsUnplayed(_ episode: Episode) {
    updateEpisode(episode.withPlayedStatus(false))
  }

  public func setEpisodeRating(_ episode: Episode, rating: Int?) {
    updateEpisode(episode.withRating(rating))
  }

  public func deleteEpisode(_ episode: Episode) async {
    // Perform single episode deletion via batch operation
    let batchOperation = BatchOperation(
      operationType: .delete,
      episodeIDs: [episode.id]
    )
    do {
      let _ = try await batchOperationManager.executeBatchOperation(batchOperation)
    } catch {
      Self.logger.error("Failed to delete episode: \(error, privacy: .public)")
    }
  }

  public func downloadProgress(for episodeID: String) -> EpisodeDownloadProgressUpdate? {
    downloadProgressCoordinator.downloadProgress(for: episodeID)
  }

  public func dismissBanner() {
    bannerManager.dismissBanner()
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
  internal func launchTask(
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

  private func bindCoordinatorPublishing() {
    downloadProgressCoordinator.objectWillChange
      .sink { [weak self] _ in
        guard let self else { return }
        self.downloadProgressByEpisodeID = self.downloadProgressCoordinator.downloadProgressByEpisodeID
      }
      .store(in: &cancellables)

    bannerManager.objectWillChange
      .sink { [weak self] _ in
        guard let self else { return }
        self.bannerState = self.bannerManager.bannerState
      }
      .store(in: &cancellables)

    downloadProgressByEpisodeID = downloadProgressCoordinator.downloadProgressByEpisodeID
    bannerState = bannerManager.bannerState
  }

  private func observeSwipeConfiguration() {
    let service = swipeConfigurationService

    Task { [weak self] in
      guard let self else { return }
      let baseline = await service.load()
      await MainActor.run { self.swipeConfiguration = baseline }
    }

    Task { [weak self] in
      guard let self else { return }
      var iterator = service.updatesStream().makeAsyncIterator()
      while let configuration = await iterator.next() {
        await MainActor.run { [weak self] in
          self?.swipeConfiguration = configuration
        }
      }
    }
  }

  private func preparePlaylistSelection(for episode: Episode) {
    pendingPlaylistEpisode = episode
    showingPlaylistSelectionSheet = true
  }

  private func prepareShare(for episode: Episode) {
    pendingShareEpisode = episode
  }

  private func updateBatchOperation(_ batchOperation: BatchOperation) {
    if let index = activeBatchOperations.firstIndex(where: { $0.id == batchOperation.id }) {
      activeBatchOperations[index] = batchOperation
    } else if batchOperation.status == .running {
      activeBatchOperations.append(batchOperation)
    }

    // Remove completed operations after a delay
    if batchOperation.status == .completed || batchOperation.status == .failed
      || batchOperation.status == .cancelled
    {
      launchTask { viewModel in
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        await MainActor.run {
          viewModel.activeBatchOperations.removeAll { $0.id == batchOperation.id }
        }
      }
    }

    if batchOperation.status == .completed || batchOperation.status == .failed {
      bannerManager.presentBanner(for: batchOperation)
    }
  }

  private func loadPersistedEpisodes() {
    guard episodeRepository != nil else { return }

    launchTask { viewModel in
      guard let repository = viewModel.episodeRepository else { return }

      for episode in viewModel.allEpisodes {
        do {
          if let persistedEpisode = try await repository.loadEpisode(id: episode.id) {
            await MainActor.run {
              viewModel.updateEpisode(persistedEpisode, persist: false)
            }
          }
        } catch {
          continue
        }
      }
    }
  }

  internal func episodeForID(_ id: String) -> Episode? {
    if let existing = allEpisodes.first(where: { $0.id == id }) {
      return existing
    }
    return filteredEpisodes.first(where: { $0.id == id })
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
          filter: nil,
          includeArchived: false
        )
      }

      // Apply filter and sort
      episodes = viewModel.filterService.filterAndSort(
        episodes: episodes, using: viewModel.currentFilter)

      viewModel.filteredEpisodes = episodes
    }
  }

  internal func updateEpisode(_ updatedEpisode: Episode, persist: Bool = true) {
    // Update in all episodes
    if let index = allEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
      allEpisodes[index] = updatedEpisode
    }

    // Update in filtered episodes
    if let index = filteredEpisodes.firstIndex(where: { $0.id == updatedEpisode.id }) {
      filteredEpisodes[index] = updatedEpisode
    }

    if persist, let episodeRepository {
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

  /// Quick play an episode that's in progress
  public func quickPlayEpisode(_ episode: Episode) async {
    await playbackCoordinator.quickPlayEpisode(episode)
  }
}
