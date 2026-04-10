//
//  OPMLImportViewModelTests.swift
//  LibraryFeatureTests
//
//  Unit tests for OPMLImportViewModel (Issue #451).
//
//  These tests cover the error and success states that cannot be driven
//  through UI tests without mock injection hooks.
//
//  Spec coverage (Given/When/Then):
//    AC4 - "Import Error" alert appears when the selected file is not valid OPML
//    AC4 - "Import Error" alert appears when no podcast feeds are found
//    AC5 - Result sheet appears with correct counts on full success
//    AC5 - Result sheet appears with partial failure counts when subscriptions fail
//

import XCTest
@testable import LibraryFeature
import CoreModels
import FeedParsing

// MARK: - Mock OPMLParsing

private final class MockOPMLParser: OPMLParsing, @unchecked Sendable {
    enum Behavior {
        case returnDocument(OPMLDocument)
        case throwError
    }
    var behavior: Behavior

    init(behavior: Behavior) { self.behavior = behavior }

    func parseOPML(data: Data) throws -> OPMLDocument {
        switch behavior {
        case .returnDocument(let doc): return doc
        case .throwError: throw MockParseError.invalidXML
        }
    }

    private enum MockParseError: Error { case invalidXML }
}

// MARK: - Mock SubscriptionService

private final class MockSubscriptionService: SubscriptionService, @unchecked Sendable {
    var shouldThrow = false
    var subscribedURLs: [String] = []

    func subscribe(urlString: String) async throws {
        if shouldThrow { throw URLError(.badURL) }
        subscribedURLs.append(urlString)
    }
}

// MARK: - OPMLImportViewModelTests

/// Tests for OPMLImportViewModel error and success paths (AC4 / AC5).
///
/// **Issue**: #451 - OPML Import Feature
final class OPMLImportViewModelTests: XCTestCase {

    private var mockParser: MockOPMLParser!
    private var mockSubscriptionService: MockSubscriptionService!
    private var importService: OPMLImportService!
    nonisolated(unsafe) private var viewModel: OPMLImportViewModel!
    private var tempFiles: [URL] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        let parser = MockOPMLParser(behavior: .returnDocument(emptyDocument()))
        let subscriptionService = MockSubscriptionService()
        let service = OPMLImportService(opmlParser: parser, subscriptionService: subscriptionService)
        mockParser = parser
        mockSubscriptionService = subscriptionService
        importService = service
        viewModel = MainActor.assumeIsolated { OPMLImportViewModel(importService: service) }
    }

    override func tearDownWithError() throws {
        viewModel = nil
        importService = nil
        mockParser = nil
        mockSubscriptionService = nil
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles = []
    }

    // MARK: - AC4: Picker-level failure

    /// Given: The file picker itself reports an error (e.g. cancelled)
    /// When: handleFileSelection(.failure(error)) is called
    /// Then: errorMessage is set and no result item is produced
    ///
    /// **AC4**
    @MainActor
    func testHandleFileSelectionPickerFailureSetsErrorMessage() {
        let pickerError = URLError(.cancelled)

        // Failure is handled synchronously — no need to await a task.
        viewModel.handleFileSelection(.failure(pickerError))

        XCTAssertNotNil(viewModel.errorMessage, "errorMessage should be set on picker failure")
        XCTAssertFalse(viewModel.isImporting, "isImporting should remain false on picker failure")
        XCTAssertNil(viewModel.importResultItem, "importResultItem should remain nil on failure")
    }

    // MARK: - AC4: Unreadable file → invalidOPML error

    /// Given: File selection succeeds but the URL points to a non-existent file
    /// When: handleFileSelection(.success([badURL])) is called
    /// Then: errorMessage == "The selected file is not a valid OPML file."
    ///
    /// **AC4** — invalid OPML error path
    @MainActor
    func testHandleFileSelectionUnreadableFileSetsInvalidOPMLMessage() async {
        let badURL = URL(fileURLWithPath: "/tmp/does_not_exist_\(UUID().uuidString).opml")

        let task = viewModel.handleFileSelection(.success([badURL]))
        await task?.value

        XCTAssertEqual(
            viewModel.errorMessage,
            "The selected file is not a valid OPML file.",
            "Should report invalid OPML when the file cannot be read"
        )
        XCTAssertFalse(viewModel.isImporting)
        XCTAssertNil(viewModel.importResultItem)
    }

    // MARK: - AC4: Readable file with no feed URLs → noFeedsFound error

    /// Given: A readable OPML file whose parsed document contains no feed URLs
    /// When: handleFileSelection(.success([url])) is called
    /// Then: errorMessage == "No podcast feeds were found in the selected file."
    ///
    /// **AC4** — no feeds found error path
    @MainActor
    func testHandleFileSelectionEmptyOPMLSetsNoFeedsFoundMessage() async throws {
        let tempURL = try createTempOPMLFile()
        mockParser.behavior = .returnDocument(emptyDocument())

        let task = viewModel.handleFileSelection(.success([tempURL]))
        await task?.value

        XCTAssertEqual(
            viewModel.errorMessage,
            "No podcast feeds were found in the selected file.",
            "Should report no feeds found when OPML has no feed outlines"
        )
        XCTAssertFalse(viewModel.isImporting)
        XCTAssertNil(viewModel.importResultItem)
    }

    // MARK: - AC5: Full success populates result item

    /// Given: A readable OPML file with 2 feed URLs and a subscription service that succeeds
    /// When: handleFileSelection(.success([url])) is called
    /// Then: importResultItem is set with 2 successful feeds and 0 failures
    ///
    /// **AC5** — complete success path
    @MainActor
    func testHandleFileSelectionFullSuccessPopulatesResultItem() async throws {
        let tempURL = try createTempOPMLFile()
        let doc = documentWithFeeds(urls: ["https://feed1.example.com/rss", "https://feed2.example.com/rss"])
        mockParser.behavior = .returnDocument(doc)
        mockSubscriptionService.shouldThrow = false

        let task = viewModel.handleFileSelection(.success([tempURL]))
        await task?.value

        XCTAssertNil(viewModel.errorMessage, "No error on complete success")
        XCTAssertFalse(viewModel.isImporting)
        let item = try XCTUnwrap(viewModel.importResultItem, "importResultItem should be set on success")
        XCTAssertEqual(item.result.totalFeeds, 2, "totalFeeds should match the OPML document")
        XCTAssertEqual(item.result.successfulFeeds.count, 2)
        XCTAssertTrue(item.result.failedFeeds.isEmpty)
        XCTAssertTrue(item.result.isCompleteSuccess)
    }

    // MARK: - AC5: Partial failure shows failed feeds in result

    /// Given: A readable OPML file with 2 feeds and a subscription service that always throws
    /// When: handleFileSelection(.success([url])) is called
    /// Then: importResultItem is set with 0 successful feeds and 2 failed feeds
    ///       (the service returns a result rather than throwing allFeedsFailed)
    ///
    /// **AC5** — partial failure path
    @MainActor
    func testHandleFileSelectionAllFeedsFailShowsResultWithFailures() async throws {
        let tempURL = try createTempOPMLFile()
        let doc = documentWithFeeds(urls: ["https://feed1.example.com/rss", "https://feed2.example.com/rss"])
        mockParser.behavior = .returnDocument(doc)
        mockSubscriptionService.shouldThrow = true

        let task = viewModel.handleFileSelection(.success([tempURL]))
        await task?.value

        XCTAssertNil(viewModel.errorMessage, "Service returns result (not error) when all feeds fail")
        XCTAssertFalse(viewModel.isImporting)
        let item = try XCTUnwrap(viewModel.importResultItem, "importResultItem should be set even when all feeds fail")
        XCTAssertEqual(item.result.totalFeeds, 2)
        XCTAssertEqual(item.result.successfulFeeds.count, 0)
        XCTAssertEqual(item.result.failedFeeds.count, 2)
        XCTAssertFalse(item.result.isCompleteSuccess)
    }

    // MARK: - Reentrancy guard

    /// Given: An import is already in flight
    /// When: handleFileSelection is called a second time
    /// Then: The second call is a no-op (no crash, isImporting stays true until first finishes)
    ///
    /// **Concurrency safety**
    @MainActor
    func testHandleFileSelectionRejectsReentrantCall() async throws {
        let tempURL = try createTempOPMLFile()
        let doc = documentWithFeeds(urls: ["https://feed1.example.com/rss"])
        mockParser.behavior = .returnDocument(doc)
        mockSubscriptionService.shouldThrow = false

        let firstTask = viewModel.handleFileSelection(.success([tempURL]))
        // isImporting is now true; a second call should be ignored.
        let secondTask = viewModel.handleFileSelection(.success([tempURL]))

        XCTAssertNil(secondTask, "Second call while importing should return nil (no-op)")
        await firstTask?.value
        XCTAssertFalse(viewModel.isImporting)
    }

    // MARK: - Cancellation

    /// Given: An import is in flight
    /// When: cancelImport() is called
    /// Then: isImporting is reset to false and no result is set
    ///
    /// **Cancellation**
    @MainActor
    func testCancelImportResetsState() {
        // Put view model into importing state manually.
        viewModel.isImporting = true

        viewModel.cancelImport()

        XCTAssertFalse(viewModel.isImporting, "cancelImport should reset isImporting to false")
        XCTAssertNil(viewModel.importTask, "cancelImport should clear the stored task reference")
    }

    // MARK: - Helpers

    private func emptyDocument() -> OPMLDocument {
        OPMLDocument(
            head: OPMLHead(title: "Test"),
            body: OPMLBody(outlines: [])
        )
    }

    private func documentWithFeeds(urls: [String]) -> OPMLDocument {
        let outlines = urls.map { url in
            OPMLOutline(title: "Feed", xmlUrl: url, type: "rss")
        }
        return OPMLDocument(
            head: OPMLHead(title: "Test"),
            body: OPMLBody(outlines: outlines)
        )
    }

    /// Creates a temporary file with placeholder content so `Data(contentsOf:)` succeeds.
    /// The file is tracked in `tempFiles` and removed in `tearDownWithError()`.
    private func createTempOPMLFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".opml")
        try "placeholder".write(to: url, atomically: true, encoding: .utf8)
        tempFiles.append(url)
        return url
    }
}
