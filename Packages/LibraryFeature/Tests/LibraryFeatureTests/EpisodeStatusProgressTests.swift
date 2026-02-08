#if os(iOS)
import XCTest
import CombineSupport
@testable import LibraryFeature
@testable import CoreModels
@testable import Persistence
@testable import PlaybackEngine

@MainActor
final class EpisodeStatusProgressTests: XCTestCase {
  private var cancellables: Set<AnyCancellable>!
  private var podcast: Podcast!
  private var downloadManager: MockDownloadManager!
  private var progressProvider: MockDownloadProgressProvider!
  private var playbackService: MockPlaybackService!
  private var episodeRepository: MockEpisodeRepository!
  private var batchOperationManager: MockBatchOperationManager!
  private var viewModel: EpisodeListViewModel!
    
  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    cancellables = Set<AnyCancellable>()
    podcast = Podcast(
      id: "pod-1",
      title: "Testing Podcast",
      author: "QA",
      description: "QA Episodes",
      feedURL: URL(string: "https://example.com/feed.xml")!,
      episodes: [
        Episode(
          id: "ep-1",
          title: "Download Fixture",
          podcastID: "pod-1",
          podcastTitle: "Testing Podcast",
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Date(),
          duration: 1800,
          description: "Episode used for download progress",
          audioURL: URL(string: "https://example.com/audio1.mp3"),
          downloadStatus: .notDownloaded
        ),
        Episode(
          id: "ep-2",
          title: "Playback Fixture",
          podcastID: "pod-1",
          podcastTitle: "Testing Podcast",
          playbackPosition: 300,
          isPlayed: false,
          pubDate: Date(),
          duration: 2400,
          description: "Episode used for playback",
          audioURL: URL(string: "https://example.com/audio2.mp3"),
          downloadStatus: .downloaded
        )
      ]
    )
        
    downloadManager = MockDownloadManager()
    progressProvider = MockDownloadProgressProvider()
    playbackService = MockPlaybackService()
    episodeRepository = MockEpisodeRepository()
    batchOperationManager = MockBatchOperationManager()
        
    viewModel = EpisodeListViewModel(
      podcast: podcast,
      filterService: DefaultEpisodeFilterService(),
      filterManager: nil,
      batchOperationManager: batchOperationManager,
      downloadProgressProvider: progressProvider,
      downloadManager: downloadManager,
      playbackService: playbackService,
      episodeRepository: episodeRepository
    )
  }
  override func tearDown() async throws {
    viewModel = nil
    batchOperationManager = nil
    episodeRepository = nil
    playbackService = nil
    progressProvider = nil
    downloadManager = nil
    podcast = nil
    cancellables = nil
    try await super.tearDown()
  }
  
  func testDownloadProgressUpdatesEpisodeStateAndPersistsOnCompletion() async throws {
        let progressExpectation = expectation(description: "Progress update applied")
        let completionExpectation = expectation(description: "Completion persisted")
        completionExpectation.expectedFulfillmentCount = 1
        
        viewModel.$downloadProgressByEpisodeID
            .dropFirst()
            .sink { mapping in
                if let progress = mapping["ep-1"], progress.fractionCompleted == 0.45 {
                    progressExpectation.fulfill()
                }
                if let progress = mapping["ep-1"], progress.fractionCompleted == 1.0, progress.status == .completed {
                    completionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        progressProvider.send(
            EpisodeDownloadProgressUpdate(
                episodeID: "ep-1",
                fractionCompleted: 0.45,
                status: .downloading,
                message: "Fetching bytes"
            )
        )
        
        progressProvider.send(
            EpisodeDownloadProgressUpdate(
                episodeID: "ep-1",
                fractionCompleted: 1.0,
                status: .completed,
                message: "Download complete"
            )
        )
        
        await fulfillment(of: [progressExpectation, completionExpectation], timeout: 1.0)
        
        guard let updatedEpisode = viewModel.filteredEpisodes.first(where: { $0.id == "ep-1" }) else {
            return XCTFail("Episode not found")
        }
        XCTAssertEqual(updatedEpisode.downloadStatus, .downloaded)
        XCTAssertEqual(viewModel.downloadProgress(for: "ep-1")?.fractionCompleted, 1.0)
        let savedIDs = await episodeRepository.storedEpisodeIDs()
        XCTAssertTrue(savedIDs.contains("ep-1"))
    }
    
    func testPauseAndResumeForwardToDownloadManager() async {
        guard let episode = viewModel.filteredEpisodes.first(where: { $0.id == "ep-1" }) else {
            return XCTFail("Episode missing")
        }
        
        await viewModel.pauseEpisodeDownload(episode)
        await viewModel.resumeEpisodeDownload(episode)
        
        XCTAssertEqual(downloadManager.pausedEpisodes, ["ep-1"])
        XCTAssertEqual(downloadManager.resumedEpisodes, ["ep-1"])
    }
    
    func testQuickPlayCompletionMarksEpisodeAsPlayedAndPersists() async throws {
        let completionExpectation = expectation(description: "Playback completion handled")
        playbackService.onPlay = { episode, _ in
            self.playbackService.emit(.playing(episode, position: TimeInterval(episode.playbackPosition), duration: 2400))
            self.playbackService.emit(.finished(episode, duration: 2400))
        }
        
        guard let episode = viewModel.filteredEpisodes.first(where: { $0.id == "ep-2" }) else {
            return XCTFail("Episode missing")
        }
        
        viewModel.$filteredEpisodes
            .sink { episodes in
                if let updated = episodes.first(where: { $0.id == "ep-2" }), updated.isPlayed {
                    completionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await viewModel.quickPlayEpisode(episode)
        
        await fulfillment(of: [completionExpectation], timeout: 1.0)
        let savedIDs = await episodeRepository.storedEpisodeIDs()
        XCTAssertTrue(savedIDs.contains("ep-2"))
    }

    @MainActor
    func testLoadsPersistedEpisodeStateOnInit() async throws {
        let persistedEpisode = podcast.episodes[1]
            .withPlayedStatus(true)
            .withPlaybackPosition(1200)
        await episodeRepository.seed([persistedEpisode])

        cancellables = Set<AnyCancellable>()
        downloadManager = MockDownloadManager()
        progressProvider = MockDownloadProgressProvider()
        playbackService = MockPlaybackService()
        batchOperationManager = MockBatchOperationManager()

    viewModel = EpisodeListViewModel(
            podcast: podcast,
            filterService: DefaultEpisodeFilterService(),
            filterManager: nil,
            batchOperationManager: batchOperationManager,
            downloadProgressProvider: progressProvider,
            downloadManager: downloadManager,
            playbackService: playbackService,
            episodeRepository: episodeRepository
        )

        let persistedExpectation = expectation(description: "Persisted episode applied")
        viewModel.$filteredEpisodes
            .sink { episodes in
                if let updated = episodes.first(where: { $0.id == persistedEpisode.id }),
                   updated.isPlayed,
                   updated.playbackPosition == persistedEpisode.playbackPosition {
                    persistedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await fulfillment(of: [persistedExpectation], timeout: 1.0)

        let refreshedEpisode = viewModel.filteredEpisodes.first(where: { $0.id == persistedEpisode.id })
        XCTAssertEqual(refreshedEpisode?.playbackPosition, persistedEpisode.playbackPosition)
        XCTAssertTrue(refreshedEpisode?.isPlayed ?? false)
    }
    
    func testBatchCompletionDisplaysFailureBannerWithRetry() async throws {
        let bannerExpectation = expectation(description: "Banner emitted")
        viewModel.$bannerState
            .dropFirst()
            .sink { banner in
                if let banner, banner.style == .failure {
                    bannerExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        var batch = BatchOperation(operationType: .download, episodeIDs: ["ep-1", "ep-2", "ep-3"])
        batch = batch.withStatus(.running)
        batch = batch.withUpdatedOperation(batch.operations[0].withStatus(.completed))
        batch = batch.withUpdatedOperation(batch.operations[1].withStatus(.failed))
        batch = batch.withUpdatedOperation(batch.operations[2].withStatus(.completed))
        batch = batch.withStatus(.completed)
        batchOperationManager.send(update: batch)
        
        await fulfillment(of: [bannerExpectation], timeout: 1.0)
        guard let bannerState = viewModel.bannerState else {
            return XCTFail("Banner missing")
        }
        XCTAssertEqual(bannerState.style, .failure)
        XCTAssertNotNil(bannerState.retry)
        XCTAssertEqual(bannerState.subtitle, "2 succeeded • 1 failed")
    }

    // MARK: - Delete Download Tests

    func testDeleteDownloadCallsManagerAndRevertsStatus() async throws {
        // Given: ep-2 is downloaded
        let episode = podcast.episodes[1]
        XCTAssertEqual(episode.downloadStatus, .downloaded)

        // When: delete download
        await viewModel.deleteDownloadForEpisode(episode)

        // Then: manager was called
        XCTAssertEqual(downloadManager.deletedDownloadEpisodes, ["ep-2"])

        // Then: episode status reverted
        let updated = viewModel.filteredEpisodes.first { $0.id == "ep-2" }
        XCTAssertEqual(updated?.downloadStatus, .notDownloaded)

        // Then: tracked in deletedDownloadEpisodeIDs
        XCTAssertTrue(viewModel.deletedDownloadEpisodeIDs.contains("ep-2"))
    }

    func testDeleteDownloadSkipsNonDownloadedEpisode() async throws {
        // Given: ep-1 is not downloaded
        let episode = podcast.episodes[0]
        XCTAssertEqual(episode.downloadStatus, .notDownloaded)

        // When: attempt delete download
        await viewModel.deleteDownloadForEpisode(episode)

        // Then: manager was NOT called
        XCTAssertTrue(downloadManager.deletedDownloadEpisodes.isEmpty)
        XCTAssertTrue(viewModel.deletedDownloadEpisodeIDs.isEmpty)
    }
}

// MARK: - Mocks

@MainActor
private final class MockDownloadManager: DownloadManaging {
    private(set) var pausedEpisodes: [String] = []
    private(set) var resumedEpisodes: [String] = []
    private(set) var downloadRequests: [String] = []
    private(set) var deletedDownloadEpisodes: [String] = []

    func downloadEpisode(_ episodeID: String) async throws {
        downloadRequests.append(episodeID)
    }

    func cancelDownload(_ episodeID: String) async {
        // no-op for test
    }

    func pauseDownload(_ episodeID: String) async {
        pausedEpisodes.append(episodeID)
    }

    func resumeDownload(_ episodeID: String) async {
        resumedEpisodes.append(episodeID)
    }

    func deleteDownloadedEpisode(episodeId: String) async throws {
        deletedDownloadEpisodes.append(episodeId)
    }
}

@MainActor
private final class MockDownloadProgressProvider: DownloadProgressProviding {
    private let subject = PassthroughSubject<EpisodeDownloadProgressUpdate, Never>()
    var progressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func send(_ update: EpisodeDownloadProgressUpdate) {
        subject.send(update)
    }
}

@MainActor
private final class MockPlaybackService: EpisodePlaybackService {
    #if canImport(Combine)
    private let subject = PassthroughSubject<EpisodePlaybackState, Never>()
    var statePublisher: AnyPublisher<EpisodePlaybackState, Never> { subject.eraseToAnyPublisher() }
    #endif
    var onPlay: ((Episode, TimeInterval?) -> Void)?
    
    func play(episode: Episode, duration: TimeInterval?) {
        onPlay?(episode, duration)
    }
    
    func pause() {}
    
    #if canImport(Combine)
    func emit(_ state: EpisodePlaybackState) {
        subject.send(state)
    }
    #endif
}

private actor MockEpisodeRepository: EpisodeRepository {
    private var storage: [String: Episode] = [:]
    
    func saveEpisode(_ episode: Episode) async throws {
        storage[episode.id] = episode
    }
    
    func loadEpisode(id: String) async throws -> Episode? {
        storage[id]
    }
    
    func storedEpisodeIDs() -> [String] {
        Array(storage.keys)
    }
    
    func seed(_ episodes: [Episode]) {
        for episode in episodes {
            storage[episode.id] = episode
        }
    }
}

@MainActor
private final class MockBatchOperationManager: BatchOperationManaging {
    private let subject = PassthroughSubject<BatchOperation, Never>()
    var batchOperationUpdates: AnyPublisher<BatchOperation, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func send(update: BatchOperation) {
        subject.send(update)
    }
    
    func executeBatchOperation(_ batchOperation: BatchOperation) async throws -> BatchOperation {
        batchOperation
    }
    
    func cancelBatchOperation(id: String) async {}
    
    func getBatchOperationStatus(id: String) async -> BatchOperation? { nil }
    
    func getActiveBatchOperations() async -> [BatchOperation] { [] }
}

#endif
