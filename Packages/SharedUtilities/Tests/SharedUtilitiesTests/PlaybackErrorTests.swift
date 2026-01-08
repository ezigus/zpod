//
//  PlaybackErrorTests.swift
//  SharedUtilitiesTests
//
//  Tests for PlaybackError enum properties and behavior.
//  Issue 03.3.4.1: Extend PlaybackError with network/missing URL cases
//

import XCTest
@testable import SharedUtilities

final class PlaybackErrorTests: XCTestCase {

  // MARK: - Recoverability Tests

  func testNetworkErrorIsRecoverable() {
    // Given: A network error
    let error = PlaybackError.networkError

    // When/Then: Network errors should be recoverable (user can retry)
    XCTAssertTrue(error.isRecoverable, "Network errors should be recoverable")
  }

  func testTimeoutErrorIsRecoverable() {
    // Given: A timeout error
    let error = PlaybackError.timeout

    // When/Then: Timeout errors should be recoverable (user can retry)
    XCTAssertTrue(error.isRecoverable, "Timeout errors should be recoverable")
  }

  func testMissingAudioURLIsNotRecoverable() {
    // Given: A missing audio URL error
    let error = PlaybackError.missingAudioURL

    // When/Then: Missing URL errors cannot be recovered from
    XCTAssertFalse(error.isRecoverable, "Missing audio URL errors are not recoverable")
  }

  func testExistingErrorsRecoverability() {
    // Given: Existing error cases
    let episodeUnavailable = PlaybackError.episodeUnavailable
    let resumeExpired = PlaybackError.resumeStateExpired
    let persistenceCorrupted = PlaybackError.persistenceCorrupted
    let streamFailed = PlaybackError.streamFailed
    let unknown = PlaybackError.unknown(message: "test")

    // When/Then: Existing errors should not be recoverable
    XCTAssertFalse(episodeUnavailable.isRecoverable, "Episode unavailable is not recoverable")
    XCTAssertFalse(resumeExpired.isRecoverable, "Resume state expired is not recoverable")
    XCTAssertFalse(persistenceCorrupted.isRecoverable, "Persistence corrupted is not recoverable")
    XCTAssertFalse(streamFailed.isRecoverable, "Stream failed is not recoverable")
    XCTAssertFalse(unknown.isRecoverable, "Unknown errors are not recoverable")
  }

  // MARK: - User Message Tests

  func testMissingAudioURLUserMessage() {
    // Given: A missing audio URL error
    let error = PlaybackError.missingAudioURL

    // When: Getting user message
    let message = error.userMessage

    // Then: Should have appropriate user-facing message
    XCTAssertEqual(
      message,
      "This episode doesn't have audio available.",
      "Missing URL should have clear user message"
    )
  }

  func testNetworkErrorUserMessage() {
    // Given: A network error
    let error = PlaybackError.networkError

    // When: Getting user message
    let message = error.userMessage

    // Then: Should have appropriate user-facing message
    XCTAssertEqual(
      message,
      "Unable to load episode. Check your connection.",
      "Network error should have clear user message"
    )
  }

  func testTimeoutErrorUserMessage() {
    // Given: A timeout error
    let error = PlaybackError.timeout

    // When: Getting user message
    let message = error.userMessage

    // Then: Should have appropriate user-facing message
    XCTAssertEqual(
      message,
      "Loading timed out. Tap to retry.",
      "Timeout should have clear user message with retry hint"
    )
  }

  func testExistingErrorsUserMessages() {
    // Given/When/Then: Existing errors should have user messages
    XCTAssertEqual(
      PlaybackError.episodeUnavailable.userMessage,
      "The episode you were listening to is no longer available."
    )
    XCTAssertEqual(
      PlaybackError.resumeStateExpired.userMessage,
      "Your previous listening session expired."
    )
    XCTAssertEqual(
      PlaybackError.persistenceCorrupted.userMessage,
      "We couldn't access your last listening position."
    )
    XCTAssertEqual(
      PlaybackError.streamFailed.userMessage,
      "Playback failed. Please try again."
    )
  }

  func testUnknownErrorUserMessage() {
    // Given: Unknown error with custom message
    let errorWithMessage = PlaybackError.unknown(message: "Custom error")
    let errorWithoutMessage = PlaybackError.unknown(message: nil)

    // When/Then: Should use custom message or fallback
    XCTAssertEqual(errorWithMessage.userMessage, "Custom error")
    XCTAssertEqual(errorWithoutMessage.userMessage, "An unknown error occurred")
  }

  // MARK: - Descriptor Tests

  func testMissingAudioURLDescriptor() {
    // Given: A missing audio URL error
    let error = PlaybackError.missingAudioURL

    // When: Getting descriptor
    let descriptor = error.descriptor()

    // Then: Should have appropriate descriptor
    XCTAssertEqual(descriptor.title, "Audio Not Available")
    XCTAssertEqual(descriptor.message, error.userMessage)
    XCTAssertEqual(descriptor.style, .error)
  }

  func testNetworkErrorDescriptor() {
    // Given: A network error
    let error = PlaybackError.networkError

    // When: Getting descriptor
    let descriptor = error.descriptor()

    // Then: Should have appropriate descriptor
    XCTAssertEqual(descriptor.title, "Connection Error")
    XCTAssertEqual(descriptor.message, error.userMessage)
    XCTAssertEqual(descriptor.style, .error)
  }

  func testTimeoutErrorDescriptor() {
    // Given: A timeout error
    let error = PlaybackError.timeout

    // When: Getting descriptor
    let descriptor = error.descriptor()

    // Then: Should have appropriate descriptor
    XCTAssertEqual(descriptor.title, "Request Timed Out")
    XCTAssertEqual(descriptor.message, error.userMessage)
    XCTAssertEqual(descriptor.style, .error)
  }

  // MARK: - Equatable Tests

  func testNewErrorsAreEquatable() {
    // Given: Same error types
    let error1 = PlaybackError.missingAudioURL
    let error2 = PlaybackError.missingAudioURL
    let error3 = PlaybackError.networkError
    let error4 = PlaybackError.timeout

    // When/Then: Should be equatable
    XCTAssertEqual(error1, error2, "Same error types should be equal")
    XCTAssertNotEqual(error1, error3, "Different error types should not be equal")
    XCTAssertNotEqual(error3, error4, "Different error types should not be equal")
  }

  // MARK: - Sendable Compliance Tests

  func testErrorsAreSendable() {
    // Given: Various error types
    let errors: [PlaybackError] = [
      .missingAudioURL,
      .networkError,
      .timeout,
      .episodeUnavailable,
      .streamFailed
    ]

    // When/Then: Should compile as Sendable (compile-time test)
    // This test verifies the enum conforms to Sendable protocol
    let _: [any Sendable] = errors
  }
}
