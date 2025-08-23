import XCTest
@testable import CoreModels

/// Comprehensive unit tests for DownloadTask model based on spec requirements
final class ComprehensiveDownloadTaskTests: XCTestCase {
    
    // MARK: - Test Data
    private var sampleDownloadTask: DownloadTask!
    private let testAudioURL = URL(string: "https://example.com/episode1.mp3")!
    
    override func setUp() async throws {
        try await super.setUp()
        sampleDownloadTask = DownloadTask(
            id: "test-download-id",
            episodeId: "episode-123",
            podcastId: "podcast-456",
            audioURL: testAudioURL,
            title: "Introduction to Swift Concurrency",
            estimatedSize: 52428800, // 50 MB
            priority: .high,
            retryCount: 0
        )
    }
    
    // MARK: - Basic Model Tests
    
    func testDownloadTaskInitialization_WithAllProperties() {
        // Given: All download task properties
        // When: Creating a download task with all properties
        // Then: All properties should be correctly set
        XCTAssertEqual(sampleDownloadTask.id, "test-download-id")
        XCTAssertEqual(sampleDownloadTask.episodeId, "episode-123")
        XCTAssertEqual(sampleDownloadTask.podcastId, "podcast-456")
        XCTAssertEqual(sampleDownloadTask.audioURL, testAudioURL)
        XCTAssertEqual(sampleDownloadTask.title, "Introduction to Swift Concurrency")
        XCTAssertEqual(sampleDownloadTask.estimatedSize, 52428800)
        XCTAssertEqual(sampleDownloadTask.priority, .high)
        XCTAssertEqual(sampleDownloadTask.retryCount, 0)
    }
    
    func testDownloadTaskInitialization_WithDefaults() {
        // Given: Creating a download task with default values
        // When: Using minimal required parameters
        let defaultTask = DownloadTask(
            episodeId: "episode-789",
            podcastId: "podcast-101",
            audioURL: testAudioURL,
            title: "Default Task"
        )
        
        // Then: Default values should be applied correctly
        XCTAssertFalse(defaultTask.id.isEmpty) // Should generate UUID
        XCTAssertEqual(defaultTask.episodeId, "episode-789")
        XCTAssertEqual(defaultTask.podcastId, "podcast-101")
        XCTAssertEqual(defaultTask.audioURL, testAudioURL)
        XCTAssertEqual(defaultTask.title, "Default Task")
        XCTAssertNil(defaultTask.estimatedSize) // Default should be nil
        XCTAssertEqual(defaultTask.priority, .normal) // Default should be normal
        XCTAssertEqual(defaultTask.retryCount, 0) // Default should be 0
    }
    
    // MARK: - Download Priority Tests (Based on Spec)
    
    func testDownloadPriority_HighPriority() {
        // Given: A high priority download task
        let highPriorityTask = DownloadTask(
            episodeId: "urgent-episode",
            podcastId: "urgent-podcast",
            audioURL: testAudioURL,
            title: "Urgent Download",
            priority: .high
        )
        
        // When: Checking priority
        // Then: Should be high priority
        XCTAssertEqual(highPriorityTask.priority, .high)
    }
    
    func testDownloadPriority_NormalPriority() {
        // Given: A normal priority download task
        let normalPriorityTask = DownloadTask(
            episodeId: "normal-episode",
            podcastId: "normal-podcast",
            audioURL: testAudioURL,
            title: "Normal Download",
            priority: .normal
        )
        
        // When: Checking priority
        // Then: Should be normal priority
        XCTAssertEqual(normalPriorityTask.priority, .normal)
    }
    
    func testDownloadPriority_LowPriority() {
        // Given: A low priority download task
        let lowPriorityTask = DownloadTask(
            episodeId: "background-episode",
            podcastId: "background-podcast",
            audioURL: testAudioURL,
            title: "Background Download",
            priority: .low
        )
        
        // When: Checking priority
        // Then: Should be low priority
        XCTAssertEqual(lowPriorityTask.priority, .low)
    }
    
    func testDownloadPriority_ComparableOrdering() {
        // Given: Different priority levels
        let highPriority = DownloadPriority.high
        let normalPriority = DownloadPriority.normal
        let lowPriority = DownloadPriority.low
        
        // When: Comparing priorities
        // Then: Should have correct ordering for download queue management
        XCTAssertTrue(highPriority > normalPriority)
        XCTAssertTrue(normalPriority > lowPriority)
        XCTAssertTrue(highPriority > lowPriority)
        
        // Test equality
        XCTAssertEqual(highPriority, .high)
        XCTAssertEqual(normalPriority, .normal)
        XCTAssertEqual(lowPriority, .low)
    }
    
    // MARK: - Download State Management Tests (Based on Spec)
    
    func testWithState_PendingState() {
        // Given: A download task
        // When: Setting state to pending
        let downloadInfo = sampleDownloadTask.withState(.pending)
        
        // Then: Should create DownloadInfo with pending state
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .pending)
        XCTAssertNil(downloadInfo.error)
    }
    
    func testWithState_DownloadingState() {
        // Given: A download task
        // When: Setting state to downloading
        let downloadInfo = sampleDownloadTask.withState(.downloading)
        
        // Then: Should create DownloadInfo with downloading state
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .downloading)
    }
    
    func testWithState_CompletedState() {
        // Given: A download task
        // When: Setting state to completed
        let downloadInfo = sampleDownloadTask.withState(.completed)
        
        // Then: Should create DownloadInfo with completed state
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .completed)
    }
    
    func testWithState_FailedState() {
        // Given: A download task
        // When: Setting state to failed
        let downloadInfo = sampleDownloadTask.withState(.failed)
        
        // Then: Should create DownloadInfo with failed state
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .failed)
    }
    
    // MARK: - Error Handling Tests (Based on Spec)
    
    func testWithError_NetworkError() {
        // Given: A download task
        // When: Setting network error
        let downloadInfo = sampleDownloadTask.withError(.networkUnavailable)
        
        // Then: Should create DownloadInfo with failed state and error message
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .failed)
        XCTAssertNotNil(downloadInfo.error)
        XCTAssertTrue(downloadInfo.error!.contains("Network") || downloadInfo.error!.contains("network"))
    }
    
    func testWithError_InsufficientStorage() {
        // Given: A download task
        // When: Setting insufficient storage error
        let downloadInfo = sampleDownloadTask.withError(.insufficientStorage)
        
        // Then: Should create DownloadInfo with failed state and storage error
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .failed)
        XCTAssertNotNil(downloadInfo.error)
        XCTAssertTrue(downloadInfo.error!.contains("storage") || downloadInfo.error!.contains("Storage"))
    }
    
    func testWithError_InvalidURL() {
        // Given: A download task
        // When: Setting invalid URL error
        let downloadInfo = sampleDownloadTask.withError(.invalidURL)
        
        // Then: Should create DownloadInfo with failed state and URL error
        XCTAssertEqual(downloadInfo.task.id, sampleDownloadTask.id)
        XCTAssertEqual(downloadInfo.state, .failed)
        XCTAssertNotNil(downloadInfo.error)
        XCTAssertTrue(downloadInfo.error!.contains("URL") || downloadInfo.error!.contains("url"))
    }
    
    // MARK: - Retry Logic Tests (Based on Spec)
    
    func testWithRetry_IncrementsRetryCount() {
        // Given: A download task with 0 retry count
        // When: Creating retry task
        let retryTask = sampleDownloadTask.withRetry()
        
        // Then: Retry count should be incremented
        XCTAssertEqual(retryTask.retryCount, 1)
        XCTAssertEqual(retryTask.id, sampleDownloadTask.id) // Same task ID
        XCTAssertEqual(retryTask.episodeId, sampleDownloadTask.episodeId)
        XCTAssertEqual(retryTask.audioURL, sampleDownloadTask.audioURL)
        
        // Original task should remain unchanged
        XCTAssertEqual(sampleDownloadTask.retryCount, 0)
    }
    
    func testWithRetry_MultipleRetries() {
        // Given: A download task
        // When: Multiple retries
        let firstRetry = sampleDownloadTask.withRetry()
        let secondRetry = firstRetry.withRetry()
        let thirdRetry = secondRetry.withRetry()
        
        // Then: Retry count should increment each time
        XCTAssertEqual(firstRetry.retryCount, 1)
        XCTAssertEqual(secondRetry.retryCount, 2)
        XCTAssertEqual(thirdRetry.retryCount, 3)
        
        // All other properties should remain the same
        XCTAssertEqual(thirdRetry.episodeId, sampleDownloadTask.episodeId)
        XCTAssertEqual(thirdRetry.audioURL, sampleDownloadTask.audioURL)
        XCTAssertEqual(thirdRetry.priority, sampleDownloadTask.priority)
    }
    
    func testRetryCount_InitialValue() {
        // Given: A new download task
        // When: Checking initial retry count
        // Then: Should start at 0
        XCTAssertEqual(sampleDownloadTask.retryCount, 0)
    }
    
    func testRetryCount_Mutable() {
        // Given: A download task
        // When: Modifying retry count directly (for service layer updates)
        var mutableTask = sampleDownloadTask!
        mutableTask.retryCount = 5
        
        // Then: Should allow direct modification
        XCTAssertEqual(mutableTask.retryCount, 5)
    }
    
    // MARK: - File Size Management Tests
    
    func testEstimatedSize_WithSize() {
        // Given: A download task with estimated size
        // When: Checking estimated size
        // Then: Should return the estimated size in bytes
        XCTAssertEqual(sampleDownloadTask.estimatedSize, 52428800) // 50 MB
    }
    
    func testEstimatedSize_WithNilSize() {
        // Given: A download task without estimated size
        let noSizeTask = DownloadTask(
            episodeId: "no-size",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: "Unknown Size"
        )
        
        // When: Checking estimated size
        // Then: Should handle nil size gracefully
        XCTAssertNil(noSizeTask.estimatedSize)
    }
    
    func testEstimatedSize_LargeFiles() {
        // Given: A download task with large file size
        let largeFileTask = DownloadTask(
            episodeId: "large-episode",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: "Large Episode",
            estimatedSize: 1073741824 // 1 GB
        )
        
        // When: Checking estimated size
        // Then: Should handle large file sizes
        XCTAssertEqual(largeFileTask.estimatedSize, 1073741824)
    }
    
    func testEstimatedSize_ZeroSize() {
        // Given: A download task with zero size
        let zeroSizeTask = DownloadTask(
            episodeId: "zero-size",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: "Zero Size",
            estimatedSize: 0
        )
        
        // When: Checking estimated size
        // Then: Should handle zero size
        XCTAssertEqual(zeroSizeTask.estimatedSize, 0)
    }
    
    // MARK: - URL Validation Tests
    
    func testAudioURL_HTTPSScheme() {
        // Given: A download task with HTTPS URL
        let httpsURL = URL(string: "https://secure.example.com/episode.mp3")!
        let httpsTask = DownloadTask(
            episodeId: "https-episode",
            podcastId: "podcast",
            audioURL: httpsURL,
            title: "HTTPS Episode"
        )
        
        // When: Checking audio URL
        // Then: Should accept HTTPS URLs
        XCTAssertEqual(httpsTask.audioURL, httpsURL)
        XCTAssertEqual(httpsTask.audioURL.scheme, "https")
    }
    
    func testAudioURL_HTTPScheme() {
        // Given: A download task with HTTP URL
        let httpURL = URL(string: "http://example.com/episode.mp3")!
        let httpTask = DownloadTask(
            episodeId: "http-episode",
            podcastId: "podcast",
            audioURL: httpURL,
            title: "HTTP Episode"
        )
        
        // When: Checking audio URL
        // Then: Should accept HTTP URLs
        XCTAssertEqual(httpTask.audioURL, httpURL)
        XCTAssertEqual(httpTask.audioURL.scheme, "http")
    }
    
    func testAudioURL_DifferentFileTypes() {
        // Given: Different audio file types
        let mp3URL = URL(string: "https://example.com/episode.mp3")!
        let aacURL = URL(string: "https://example.com/episode.aac")!
        let m4aURL = URL(string: "https://example.com/episode.m4a")!
        
        // When: Creating tasks with different file types
        let mp3Task = DownloadTask(episodeId: "mp3", podcastId: "p", audioURL: mp3URL, title: "MP3")
        let aacTask = DownloadTask(episodeId: "aac", podcastId: "p", audioURL: aacURL, title: "AAC")
        let m4aTask = DownloadTask(episodeId: "m4a", podcastId: "p", audioURL: m4aURL, title: "M4A")
        
        // Then: Should handle different audio formats
        XCTAssertTrue(mp3Task.audioURL.absoluteString.hasSuffix(".mp3"))
        XCTAssertTrue(aacTask.audioURL.absoluteString.hasSuffix(".aac"))
        XCTAssertTrue(m4aTask.audioURL.absoluteString.hasSuffix(".m4a"))
    }
    
    // MARK: - Codable Tests
    
    func testDownloadTaskCodable_FullData() throws {
        // Given: A download task with all properties set
        // When: Encoding and decoding the task
        let encoder = JSONEncoder()
        let data = try encoder.encode(sampleDownloadTask)
        
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(DownloadTask.self, from: data)
        
        // Then: All properties should be preserved
        XCTAssertEqual(sampleDownloadTask, decodedTask)
    }
    
    func testDownloadTaskCodable_WithNilEstimatedSize() throws {
        // Given: A download task with nil estimated size
        let taskWithNilSize = DownloadTask(
            episodeId: "nil-size",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: "Nil Size Task"
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(taskWithNilSize)
        
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(DownloadTask.self, from: data)
        
        // Then: Nil values should be preserved
        XCTAssertEqual(taskWithNilSize, decodedTask)
        XCTAssertNil(decodedTask.estimatedSize)
    }
    
    // MARK: - Equatable Tests
    
    func testDownloadTaskEquatable_SameContent() {
        // Given: Two download tasks with identical content
        let task1 = sampleDownloadTask!
        let task2 = DownloadTask(
            id: sampleDownloadTask.id,
            episodeId: sampleDownloadTask.episodeId,
            podcastId: sampleDownloadTask.podcastId,
            audioURL: sampleDownloadTask.audioURL,
            title: sampleDownloadTask.title,
            estimatedSize: sampleDownloadTask.estimatedSize,
            priority: sampleDownloadTask.priority,
            retryCount: sampleDownloadTask.retryCount
        )
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(task1, task2)
    }
    
    func testDownloadTaskEquatable_DifferentId() {
        // Given: Two download tasks with different IDs
        let task1 = sampleDownloadTask!
        let task2 = DownloadTask(
            id: "different-id",
            episodeId: sampleDownloadTask.episodeId,
            podcastId: sampleDownloadTask.podcastId,
            audioURL: sampleDownloadTask.audioURL,
            title: sampleDownloadTask.title,
            estimatedSize: sampleDownloadTask.estimatedSize,
            priority: sampleDownloadTask.priority,
            retryCount: sampleDownloadTask.retryCount
        )
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(task1, task2)
    }
    
    func testDownloadTaskEquatable_DifferentRetryCount() {
        // Given: Two download tasks with different retry counts
        let task1 = sampleDownloadTask!
        let task2 = sampleDownloadTask.withRetry()
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(task1, task2)
    }
    
    // MARK: - Identifiable Protocol Tests
    
    func testDownloadTaskIdentifiable() {
        // Given: A download task implementing Identifiable
        // When: Accessing id property
        // Then: Should conform to Identifiable protocol
        let taskId: String = sampleDownloadTask.id
        XCTAssertFalse(taskId.isEmpty)
        XCTAssertEqual(taskId, sampleDownloadTask.id)
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testDownloadTaskSendableCompliance() {
        // Given: DownloadTask model should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let _: Sendable = sampleDownloadTask
        XCTAssertNotNil(sampleDownloadTask)
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testEmptyTitle() {
        // Given: A download task with empty title
        let emptyTitleTask = DownloadTask(
            episodeId: "empty-title",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: ""
        )
        
        // When: Checking title
        // Then: Should handle empty string gracefully
        XCTAssertEqual(emptyTitleTask.title, "")
        XCTAssertTrue(emptyTitleTask.title.isEmpty)
    }
    
    func testVeryLongTitle() {
        // Given: A download task with very long title
        let longTitle = String(repeating: "Very Long Episode Title ", count: 100)
        let longTitleTask = DownloadTask(
            episodeId: "long-title",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: longTitle
        )
        
        // When: Checking title
        // Then: Should handle long titles
        XCTAssertEqual(longTitleTask.title, longTitle)
        XCTAssertTrue(longTitleTask.title.count > 1000)
    }
    
    func testUnicodeTitle() {
        // Given: A download task with Unicode characters in title
        let unicodeTitle = "🎧 Episódio sobre Programação 📱"
        let unicodeTask = DownloadTask(
            episodeId: "unicode",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: unicodeTitle
        )
        
        // When: Checking title
        // Then: Should handle Unicode properly
        XCTAssertEqual(unicodeTask.title, unicodeTitle)
        XCTAssertTrue(unicodeTask.title.contains("🎧"))
        XCTAssertTrue(unicodeTask.title.contains("Programação"))
    }
    
    func testNegativeRetryCount() {
        // Given: A download task
        // When: Setting negative retry count
        var negativeRetryTask = sampleDownloadTask!
        negativeRetryTask.retryCount = -1
        
        // Then: Should allow negative values (for edge cases or reset scenarios)
        XCTAssertEqual(negativeRetryTask.retryCount, -1)
    }
    
    func testVeryHighRetryCount() {
        // Given: A download task
        // When: Setting very high retry count
        var highRetryTask = sampleDownloadTask!
        highRetryTask.retryCount = 9999
        
        // Then: Should handle high retry counts
        XCTAssertEqual(highRetryTask.retryCount, 9999)
    }
    
    func testNegativeFileSize() {
        // Given: A download task with negative file size
        let negativeSize = DownloadTask(
            episodeId: "negative",
            podcastId: "podcast",
            audioURL: testAudioURL,
            title: "Negative Size",
            estimatedSize: -1
        )
        
        // When: Checking estimated size
        // Then: Should allow negative values (for unknown/error states)
        XCTAssertEqual(negativeSize.estimatedSize, -1)
    }
}