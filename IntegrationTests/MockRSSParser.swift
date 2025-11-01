import Foundation
import CoreModels
import DiscoverFeature

/// Mock RSS parser for testing discovery workflows
///
/// This mock allows tests to control RSS feed parsing behavior without network calls.
/// Tests can configure the mock to return specific podcasts or throw errors.
///
/// @unchecked Sendable: This test-only implementation uses mutable state for configuration
/// but is designed for single-threaded test scenarios where the mock is configured once
/// before use.
final class MockRSSParser: RSSFeedParsing, @unchecked Sendable {
    /// The podcast to return when parseFeed is called
    var mockPodcast: Podcast?
    
    /// If true, parseFeed will throw an error instead of returning a podcast
    var shouldThrowError = false
    
    func parseFeed(from url: URL) async throws -> Podcast {
        if shouldThrowError {
            throw NSError(
                domain: "MockRSSError", 
                code: 1, 
                userInfo: [NSLocalizedDescriptionKey: "Mock RSS parsing error"]
            )
        }
        
        return mockPodcast ?? Podcast(
            id: "mock-podcast",
            title: "Mock Podcast",
            feedURL: url
        )
    }
}
