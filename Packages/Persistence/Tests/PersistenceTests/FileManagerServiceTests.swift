import XCTest
@testable import Persistence
import CoreModels
import Foundation
import Combine

final class FileManagerServiceTests: XCTestCase {
  private var service: FileManagerService!
  private var downloadsRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    downloadsRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("Downloads-\(UUID().uuidString)", isDirectory: true)

    service = try FileManagerService(baseDownloadsPath: downloadsRoot)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: downloadsRoot)
    service = nil
    try super.tearDownWithError()
  }

  func testDownloadCompletesAndPersistsFile() async throws {
    let data = "hello world".data(using: .utf8)!
    let sourceURL = downloadsRoot.appendingPathComponent("source.mp3")
    try data.write(to: sourceURL)

    let task = DownloadTask(
      episodeId: "episode-1",
      podcastId: "pod-1",
      audioURL: sourceURL,
      title: "Test Episode"
    )

    let progressPublisher = await service.downloadProgressPublisher
    let expectation = expectation(description: "download completes")
    var completionUpdate: DownloadProgress?

    let cancellable = progressPublisher.publisher.sink { update in
      if update.taskId == task.id, update.state == .completed {
        completionUpdate = update
        expectation.fulfill()
      }
    }

    try await service.startDownload(task)
    await fulfillment(of: [expectation], timeout: 3.0)
    cancellable.cancel()

    let finalPath = await service.downloadPath(for: task)
    XCTAssertTrue(FileManager.default.fileExists(atPath: finalPath))
    let savedData = try Data(contentsOf: URL(fileURLWithPath: finalPath))
    XCTAssertEqual(savedData, data)
    XCTAssertEqual(completionUpdate?.localFileURL?.path, finalPath)
  }

  func testDownloadFailureEmitsFailedProgress() async throws {
    let missingURL = downloadsRoot.appendingPathComponent("missing.mp3")
    let task = DownloadTask(
      episodeId: "episode-2",
      podcastId: "pod-2",
      audioURL: missingURL,
      title: "Failing Episode"
    )

    do {
      try await service.startDownload(task)
      XCTFail("Expected startDownload to throw for missing file URL")
    } catch {
      // expected
    }
  }
}
