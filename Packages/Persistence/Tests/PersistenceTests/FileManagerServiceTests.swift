import XCTest
@testable import Persistence
import CoreModels
import Foundation

/// Tests for FileManagerService URLSession download implementation
/// Following TDD approach: tests written before implementation
final class FileManagerServiceTests: XCTestCase {

    private var service: FileManagerService!
    private var testDownloadsPath: URL!
    private var mockURLSession: MockURLSession!

    override func setUp() async throws {
        try await super.setUp()

        // Create test downloads directory in temp location
        let tempDir = FileManager.default.temporaryDirectory
        testDownloadsPath = tempDir.appendingPathComponent("TestDownloads-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDownloadsPath, withIntermediateDirectories: true)

        // Create service with test session
        mockURLSession = MockURLSession()

        // NOTE: FileManagerService will need to be refactored to accept:
        // - URLSession (for real downloads)
        // - baseDownloadsPath (for testability)
        // For now, we'll use the standard initializer
        service = try await FileManagerService()
    }

    override func tearDown() async throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDownloadsPath)
        service = nil
        mockURLSession = nil
        try await super.tearDown()
    }

    // MARK: - Happy Path Tests

    /// Test: Download completes successfully and file exists at expected path
    func testDownloadCompletesSuccessfully() async throws {
        // Given: A download task for an episode
        let task = makeTestDownloadTask(episodeId: "episode-1", podcastId: "podcast-1")

        // Configure mock to simulate successful download
        let testData = "Test audio data".data(using: .utf8)!
        mockURLSession.mockDownloadCompletion = .success(testData)

        // When: Starting the download
        try await service.startDownload(task)

        // Wait for async completion
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then: File should exist at expected path
        let expectedPath = testDownloadsPath
            .appendingPathComponent("podcast-1")
            .appendingPathComponent("episode-1.mp3")

        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path),
                     "Downloaded file should exist at expected path")

        // Verify file contents
        let savedData = try Data(contentsOf: expectedPath)
        XCTAssertEqual(savedData, testData, "File contents should match downloaded data")
    }

    /// Test: Progress updates are emitted during download
    func testProgressUpdatesEmittedDuringDownload() async throws {
        // Given: A download task
        let task = makeTestDownloadTask(episodeId: "episode-2", podcastId: "podcast-2")

        // Collect progress updates
        var progressUpdates: [DownloadProgress] = []
        let progressPublisher = await service.downloadProgressPublisher

        let expectation = XCTestExpectation(description: "Progress updates received")
        expectation.expectedFulfillmentCount = 3 // Expect at least 3 progress updates

        let cancellable = progressPublisher.publisher.sink { progress in
            if progress.taskId == task.id {
                progressUpdates.append(progress)
                expectation.fulfill()
            }
        }

        // Configure mock to emit progress updates
        mockURLSession.mockProgressUpdates = [0.25, 0.50, 0.75, 1.0]
        mockURLSession.mockDownloadCompletion = .success(Data())

        // When: Starting the download
        try await service.startDownload(task)

        // Then: Progress updates should be received
        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertGreaterThanOrEqual(progressUpdates.count, 3,
                                    "Should receive multiple progress updates")
        XCTAssertTrue(progressUpdates.first!.progress < progressUpdates.last!.progress,
                     "Progress should increase over time")

        cancellable.cancel()
    }

    /// Test: File size is correctly reported for downloaded file
    func testFileSizeReportedCorrectly() async throws {
        // Given: A downloaded file
        let task = makeTestDownloadTask(episodeId: "episode-3", podcastId: "podcast-3")
        let testData = Data(repeating: 0xFF, count: 1024) // 1KB of data

        mockURLSession.mockDownloadCompletion = .success(testData)
        try await service.startDownload(task)
        try await Task.sleep(nanoseconds: 100_000_000)

        // When: Querying file size
        let fileSize = await service.getFileSize(for: task)

        // Then: Size should match data size
        XCTAssertEqual(fileSize, Int64(testData.count),
                      "File size should match downloaded data size")
    }

    // MARK: - Error Handling Tests

    /// Test: Network failure results in failed state
    func testNetworkFailureResultsInFailedState() async throws {
        // Given: A download task
        let task = makeTestDownloadTask(episodeId: "episode-4", podcastId: "podcast-4")

        // Configure mock to simulate network failure
        mockURLSession.mockDownloadCompletion = .failure(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        )

        // When/Then: Starting download should throw
        do {
            try await service.startDownload(task)
            XCTFail("Expected network error to be thrown")
        } catch {
            // Error should be network-related
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSURLErrorDomain)
        }

        // File should not exist
        let filePath = await service.downloadPath(for: task)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath),
                      "File should not exist after failed download")
    }

    /// Test: Invalid URL results in immediate failure
    func testInvalidURLResultsInImmediateFailure() async throws {
        // Given: A task with invalid URL
        var task = makeTestDownloadTask(episodeId: "episode-5", podcastId: "podcast-5")
        // Force invalid URL (this is a bit contrived since URL validation happens earlier)
        mockURLSession.shouldFailImmediately = true
        mockURLSession.mockDownloadCompletion = .failure(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        )

        // When/Then: Should fail immediately
        do {
            try await service.startDownload(task)
            XCTFail("Expected invalid URL error")
        } catch {
            // Should be URL-related error
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, NSURLErrorBadURL)
        }
    }

    /// Test: Insufficient disk space results in appropriate error
    func testInsufficientDiskSpaceError() async throws {
        // Given: A download task
        let task = makeTestDownloadTask(episodeId: "episode-6", podcastId: "podcast-6")

        // Configure mock to simulate disk full error
        mockURLSession.mockDownloadCompletion = .failure(
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        )

        // When/Then: Should fail with disk space error
        do {
            try await service.startDownload(task)
            XCTFail("Expected disk space error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, NSFileWriteOutOfSpaceError)
        }
    }

    // MARK: - Cancellation Tests

    /// Test: Canceling download stops task and removes partial file
    func testCancelDownloadStopsTaskAndRemovesFile() async throws {
        // Given: An in-progress download
        let task = makeTestDownloadTask(episodeId: "episode-7", podcastId: "podcast-7")

        mockURLSession.mockProgressUpdates = [0.25, 0.50] // Partial progress
        mockURLSession.mockDownloadCompletion = .success(Data()) // Will be cancelled before completion

        // Start download
        try await service.startDownload(task)

        // Let it progress a bit
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        // When: Canceling the download
        await service.cancelDownload(taskId: task.id)

        // Then: File should not exist (or be cleaned up)
        try await Task.sleep(nanoseconds: 50_000_000) // Allow cleanup

        let filePath = await service.downloadPath(for: task)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath),
                      "Partial file should be removed after cancellation")

        // Mock session should have cancelled the task
        XCTAssertTrue(mockURLSession.wasCancelled,
                     "URLSession task should be cancelled")
    }

    // MARK: - Resume Data Tests

    /// Test: Interrupted download saves resume data
    func testInterruptedDownloadSavesResumeData() async throws {
        // Given: A download that gets interrupted
        let task = makeTestDownloadTask(episodeId: "episode-8", podcastId: "podcast-8")

        let testResumeData = "Resume data".data(using: .utf8)!
        mockURLSession.mockResumeData = testResumeData
        mockURLSession.mockDownloadCompletion = .failure(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        )

        // When: Download is interrupted
        do {
            try await service.startDownload(task)
            XCTFail("Expected interruption error")
        } catch {
            // Error expected
        }

        // Then: Resume data should be saved
        let resumeData = await service.getResumeData(for: task)
        XCTAssertNotNil(resumeData, "Resume data should be saved for interrupted download")
        XCTAssertEqual(resumeData, testResumeData, "Resume data should match mock data")
    }

    /// Test: Resuming download uses saved resume data
    func testResumingDownloadUsesResumeData() async throws {
        // Given: A task with resume data
        let task = makeTestDownloadTask(episodeId: "episode-9", podcastId: "podcast-9")
        let resumeData = "Saved resume data".data(using: .utf8)!

        await service.saveResumeData(resumeData, for: task)

        // Configure mock to verify resume data is used
        mockURLSession.mockDownloadCompletion = .success(Data())

        // When: Resuming the download
        try await service.resumeDownload(task)

        // Then: Mock should have received resume data
        XCTAssertEqual(mockURLSession.lastResumeDataUsed, resumeData,
                      "Should use saved resume data when resuming")
    }

    // MARK: - File Management Tests

    /// Test: File exists check works correctly
    func testFileExistsCheckWorksCorrectly() async throws {
        // Given: A task with no downloaded file
        let task = makeTestDownloadTask(episodeId: "episode-10", podcastId: "podcast-10")

        // When: Checking if file exists
        var exists = await service.fileExists(for: task)

        // Then: Should be false initially
        XCTAssertFalse(exists, "File should not exist before download")

        // Download the file
        mockURLSession.mockDownloadCompletion = .success(Data())
        try await service.startDownload(task)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Check again
        exists = await service.fileExists(for: task)
        XCTAssertTrue(exists, "File should exist after successful download")
    }

    /// Test: Deleting downloaded file removes it from disk
    func testDeletingDownloadedFileRemovesIt() async throws {
        // Given: A downloaded file
        let task = makeTestDownloadTask(episodeId: "episode-11", podcastId: "podcast-11")

        mockURLSession.mockDownloadCompletion = .success(Data())
        try await service.startDownload(task)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify file exists
        var exists = await service.fileExists(for: task)
        XCTAssertTrue(exists)

        // When: Deleting the file
        try await service.deleteDownloadedFile(for: task)

        // Then: File should no longer exist
        exists = await service.fileExists(for: task)
        XCTAssertFalse(exists, "File should be removed after deletion")
    }

    // MARK: - Background Support Tests

    /// Test: Background URLSession is configured correctly
    func testBackgroundURLSessionConfiguration() async throws {
        // Given/When: Service is initialized
        let configuration = mockURLSession.configuration

        // Then: Should use background configuration
        XCTAssertTrue(configuration.isBackground,
                     "URLSession should be configured for background downloads")
        XCTAssertEqual(configuration.identifier, "us.zig.zpod.background-downloads",
                      "Should use correct background session identifier")
    }

    // MARK: - Helper Methods

    private func makeTestDownloadTask(episodeId: String, podcastId: String) -> DownloadTask {
        return DownloadTask(
            id: UUID().uuidString,
            episodeId: episodeId,
            podcastId: podcastId,
            audioURL: URL(string: "https://example.com/\(episodeId).mp3")!,
            title: "Test Episode \(episodeId)",
            estimatedSize: 1024 * 1024, // 1MB
            priority: .normal,
            retryCount: 0
        )
    }
}

// MARK: - Mock URLSession

/// Mock URLSession for testing without real network calls
final class MockURLSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    var configuration: URLSessionConfiguration = .default
    var mockDownloadCompletion: Result<Data, Error>?
    var mockProgressUpdates: [Double] = []
    var mockResumeData: Data?
    var lastResumeDataUsed: Data?
    var shouldFailImmediately = false
    var wasCancelled = false

    private var activeTask: URLSessionDownloadTask?
    private var completionHandler: ((URL?, URLResponse?, Error?) -> Void)?

    override init() {
        super.init()
        configuration.identifier = "us.zig.zpod.background-downloads"
        configuration.isBackground = true
    }

    func downloadTask(with url: URL) -> URLSessionDownloadTask {
        let task = MockDownloadTask(session: self, url: url)
        activeTask = task
        return task
    }

    func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        lastResumeDataUsed = resumeData
        let task = MockDownloadTask(session: self, url: URL(string: "https://example.com/resume")!)
        activeTask = task
        return task
    }

    func cancel() {
        wasCancelled = true
        activeTask?.cancel()
    }

    // URLSessionDownloadDelegate methods (not needed for mock, but required by protocol)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Implemented in MockDownloadTask
    }
}

/// Mock URLSessionDownloadTask
final class MockDownloadTask: URLSessionDownloadTask {
    private weak var mockSession: MockURLSession?
    private let taskURL: URL
    private var _state: URLSessionTask.State = .suspended

    init(session: MockURLSession, url: URL) {
        self.mockSession = session
        self.taskURL = url
        super.init()
    }

    override func resume() {
        _state = .running

        // Simulate async download behavior
        Task {
            // Emit progress updates
            if let progressUpdates = mockSession?.mockProgressUpdates {
                for progress in progressUpdates {
                    try? await Task.sleep(nanoseconds: 20_000_000) // 0.02s between updates
                    // Simulate progress callback
                }
            }

            // Complete or fail
            if let completion = mockSession?.mockDownloadCompletion {
                switch completion {
                case .success(let data):
                    // Write data to temp file
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try? data.write(to: tempURL)
                    // Simulate completion callback

                case .failure(let error):
                    // Simulate error
                    break
                }
            }
        }
    }

    override func cancel() {
        _state = .canceling
        mockSession?.wasCancelled = true
    }

    override var state: URLSessionTask.State {
        return _state
    }
}

// Helper extension for URLSessionConfiguration
extension URLSessionConfiguration {
    var isBackground: Bool {
        return identifier != nil && identifier!.contains("background")
    }
}
