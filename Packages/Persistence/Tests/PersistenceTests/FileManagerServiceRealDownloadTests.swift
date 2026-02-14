import XCTest
@testable import Persistence
import CoreModels
import Foundation
import Combine

private final class ChunkedURLProtocol: URLProtocol {
  nonisolated(unsafe) static var chunks: [Data] = []
  nonisolated(unsafe) static var statusCode: Int = 200
  nonisolated(unsafe) static var error: Error?

  // swiftlint:disable:next static_over_final_class
  override class func canInit(with request: URLRequest) -> Bool { true }
  // swiftlint:disable:next static_over_final_class
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    if let error = Self.error {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    let totalLength = Self.chunks.reduce(0) { $0 + $1.count }
    let response = HTTPURLResponse(
      url: request.url ?? URL(string: "https://example.com")!,
      statusCode: Self.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Length": "\(totalLength)"]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

    for chunk in Self.chunks {
      client?.urlProtocol(self, didLoad: chunk)
    }
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() { /* no-op */ }

  static func reset() {
    chunks = []
    statusCode = 200
    error = nil
  }
}

final class FileManagerServiceRealDownloadTests: XCTestCase {

  private var service: FileManagerService!
  private var downloadsRoot: URL!
  private var cancellables = Set<AnyCancellable>()

  override func setUp() async throws {
    try await super.setUp()
    downloadsRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("RealDownload-\(UUID().uuidString)", isDirectory: true)
    ChunkedURLProtocol.reset()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ChunkedURLProtocol.self]
    service = try FileManagerService(
      baseDownloadsPath: downloadsRoot,
      configuration: config
    )
  }

  override func tearDown() async throws {
    cancellables.removeAll()
    try? FileManager.default.removeItem(at: downloadsRoot)
    service = nil
    ChunkedURLProtocol.reset()
    try await super.tearDown()
  }

  // MARK: - Basic File Management

  func testDownloadPathFormat() async throws {
    let task = makeTestTask(episodeId: "ep-1", podcastId: "pod-1")
    let path = await service.downloadPath(for: task)
    XCTAssertTrue(path.contains("Downloads/pod-1/ep-1.mp3"))
  }

  func testFileExistsReturnsFalseForNonExistent() async throws {
    let task = makeTestTask(episodeId: "ep-2", podcastId: "pod-2")
    let exists = await service.fileExists(for: task)
    XCTAssertFalse(exists)
  }

  func testCreateDownloadDirectoryCreatesStructure() async throws {
    let task = makeTestTask(episodeId: "ep-3", podcastId: "pod-3")
    try await service.createDownloadDirectory(for: task)
    let path = await service.downloadPath(for: task)
    let dirPath = (path as NSString).deletingLastPathComponent
    XCTAssertTrue(FileManager.default.fileExists(atPath: dirPath))
    try? FileManager.default.removeItem(atPath: dirPath)
  }

  // MARK: - URLSession-backed behavior

  func testStartDownloadWithRealURLSession() async throws {
    let fixture = try makeLocalFileTask(
      episodeId: "real-ep-1",
      podcastId: "real-pod-1",
      size: 1024
    )

    let completion = expectation(description: "download completes")
    (await service.downloadProgressPublisher).publisher
      .sink { progress in
        if progress.taskId == fixture.task.id, progress.state == .completed {
          completion.fulfill()
        }
      }
      .store(in: &cancellables)

    try await service.startDownload(fixture.task)
    await fulfillment(of: [completion], timeout: 2.0)

    let finalPath = await service.downloadPath(for: fixture.task)
    XCTAssertTrue(FileManager.default.fileExists(atPath: finalPath))
    let data = try Data(contentsOf: URL(fileURLWithPath: finalPath))
    XCTAssertEqual(data, fixture.data)
    try? FileManager.default.removeItem(at: fixture.sourceURL)
  }

  func testDownloadProgressPublisherEmitsRealProgress() async throws {
    let fixture = try makeLocalFileTask(
      episodeId: "progress-ep",
      podcastId: "progress-pod",
      size: 600
    )

    let expectation = expectation(description: "completion progress")
    var observed: [Double] = []

    (await service.downloadProgressPublisher).publisher
      .sink { progress in
        guard progress.taskId == fixture.task.id else { return }
        observed.append(progress.progress)
        if progress.state == .completed {
          expectation.fulfill()
        }
      }
      .store(in: &cancellables)

    try await service.startDownload(fixture.task)
    await fulfillment(of: [expectation], timeout: 2.0)

    XCTAssertGreaterThanOrEqual(observed.max() ?? 0, 1.0)
    let finalPath = await service.downloadPath(for: fixture.task)
    let data = try Data(contentsOf: URL(fileURLWithPath: finalPath))
    XCTAssertEqual(data, fixture.data)
    try? FileManager.default.removeItem(at: fixture.sourceURL)
  }

  func testCancelDownloadStopsURLSessionTask() async throws {
    ChunkedURLProtocol.chunks = [Data(repeating: 0xAA, count: 1024)]
    let task = makeTestTask(
      episodeId: "cancel-ep",
      podcastId: "cancel-pod",
      audioURL: URL(string: "https://example.com/cancel.mp3")!
    )

    let cancelled = expectation(description: "cancelled")
    (await service.downloadProgressPublisher).publisher
      .sink { progress in
        if progress.taskId == task.id, progress.state == .cancelled {
          cancelled.fulfill()
        }
      }
      .store(in: &cancellables)

    try await service.startDownload(task)
    await service.cancelDownload(taskId: task.id)
    await fulfillment(of: [cancelled], timeout: 1.0)
  }

  func testFileSizeMatchesDownloadedContent() async throws {
    let fixture = try makeLocalFileTask(
      episodeId: "size-ep",
      podcastId: "size-pod",
      size: 2048
    )

    try await service.startDownload(fixture.task)
    let size = await service.getFileSize(for: fixture.task)
    XCTAssertEqual(size, Int64(fixture.data.count))
    try? FileManager.default.removeItem(at: fixture.sourceURL)
  }

  func testNetworkErrorResultsInFailedState() async throws {
    let missingURL = URL(string: "file:///tmp/nonexistent-\(UUID().uuidString).mp3")!
    let task = makeTestTask(
      episodeId: "error-ep",
      podcastId: "error-pod",
      audioURL: missingURL
    )

    await XCTAssertThrowsErrorAsync(try await service.startDownload(task))
  }

  // MARK: - Helpers

  private func makeTestTask(
    episodeId: String,
    podcastId: String,
    audioURL: URL = URL(string: "https://example.com/test.mp3")!
  ) -> DownloadTask {
    DownloadTask(
      episodeId: episodeId,
      podcastId: podcastId,
      audioURL: audioURL,
      title: "Test Episode"
    )
  }

  private struct LocalFileTaskFixture {
    let task: DownloadTask
    let sourceURL: URL
    let data: Data
  }

  private func makeLocalFileTask(
    episodeId: String,
    podcastId: String,
    size: Int
  ) throws -> LocalFileTaskFixture {
    let data = Data(repeating: 0x5A, count: size)
    let sourceURL = downloadsRoot.appendingPathComponent("\(episodeId)-source.mp3")
    try data.write(to: sourceURL)
    let task = makeTestTask(
      episodeId: episodeId,
      podcastId: podcastId,
      audioURL: sourceURL
    )
    return LocalFileTaskFixture(task: task, sourceURL: sourceURL, data: data)
  }

  /// Minimal async variant of XCTAssertThrowsError for compatibility with Swift 6 async tests.
  private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
  ) async {
    do {
      _ = try await expression()
      XCTFail(message(), file: file, line: line)
    } catch {
      errorHandler(error)
    }
  }
}
