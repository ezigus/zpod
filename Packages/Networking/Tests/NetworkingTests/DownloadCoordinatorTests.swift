import XCTest
import Combine
@testable import Networking
import CoreModels
import Persistence

private actor StubFileManagerService: FileManagerServicing {
  #if canImport(Combine)
  private let subject = PassthroughSubject<DownloadProgress, Never>()
  #endif

  private var paths: [String: String] = [:]

  #if canImport(Combine)
  var downloadProgressPublisher: DownloadProgressPublisher {
    get async { DownloadProgressPublisher(publisher: subject.eraseToAnyPublisher()) }
  }
  #endif

  func downloadPath(for task: DownloadTask) async -> String {
    if let existing = paths[task.id] { return existing }
    let path = "/tmp/\(task.podcastId)/\(task.episodeId).mp3"
    paths[task.id] = path
    return path
  }

  func createDownloadDirectory(for task: DownloadTask) async throws {
    // no-op
  }

  func startDownload(_ task: DownloadTask) async throws {
    let path = await downloadPath(for: task)
    #if canImport(Combine)
      subject.send(
        DownloadProgress(
          taskId: task.id,
          progress: 1.0,
          state: .completed,
          localFileURL: URL(fileURLWithPath: path)
        )
      )
    #endif
  }

  func cancelDownload(taskId: String) async {}

  func deleteDownloadedFile(for task: DownloadTask) async throws {
    paths.removeValue(forKey: task.id)
  }

  func fileExists(for task: DownloadTask) async -> Bool {
    paths[task.id] != nil
  }

  func getFileSize(for task: DownloadTask) async -> Int64? {
    0
  }
}

@MainActor
final class DownloadCoordinatorTests: XCTestCase {
  private var cancellables: Set<AnyCancellable> = []

  func testCachesLocalFileURLOnCompletion() async throws {
    let stubFileManager = StubFileManagerService()
    let coordinator = DownloadCoordinator(
      fileManagerService: stubFileManager,
      autoProcessingEnabled: true
    )

    let episode = Episode(
      id: "episode-123",
      title: "Test Episode",
      podcastID: "podcast-abc",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      downloadStatus: .notDownloaded,
      isFavorited: false,
      isBookmarked: false,
      isArchived: false,
      dateAdded: Date(),
      isOrphaned: false
    )

    let expectation = expectation(description: "download completes")
    var fulfilled = false
    coordinator.episodeProgressPublisher
      .sink { update in
        guard !fulfilled else { return }
        if update.episodeID == episode.id, update.status == .completed {
          fulfilled = true
          expectation.fulfill()
        }
      }
      .store(in: &cancellables)

    coordinator.addDownload(for: episode)
    await fulfillment(of: [expectation], timeout: 1.0)

    let localURL = coordinator.localFileURL(for: episode.id)
    XCTAssertNotNil(localURL)
    XCTAssertTrue(localURL?.path.contains("podcast-abc") == true)
  }
}
