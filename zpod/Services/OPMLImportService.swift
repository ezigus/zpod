import Foundation

/// Service for importing podcast subscriptions from OPML format
public final class OPMLImportService {
    
    /// Errors that can occur during OPML import
    public enum Error: Swift.Error, Equatable {
        case invalidOPML
        case noFeedsFound
        case allFeedsFailed
    }
    
    private let opmlParser: OPMLParsing
    private let subscriptionService: SubscriptionService
    
    public init(opmlParser: OPMLParsing, subscriptionService: SubscriptionService) {
        self.opmlParser = opmlParser
        self.subscriptionService = subscriptionService
    }
    
    /// Imports podcast subscriptions from OPML data
    /// - Parameter data: OPML XML data
    /// - Returns: Import result with success/failure details
    /// - Throws: Error.invalidOPML if OPML cannot be parsed, Error.noFeedsFound if no valid feeds found
    public func importSubscriptions(from data: Data) async throws -> OPMLImportResult {
        // Parse OPML document
        let document: OPMLDocument
        do {
            document = try opmlParser.parseOPML(data: data)
        } catch {
            throw Error.invalidOPML
        }
        
        // Extract all feed URLs from the document
        let feedUrls = extractFeedUrls(from: document.body.outlines)
        
        guard !feedUrls.isEmpty else {
            throw Error.noFeedsFound
        }
        
        // Attempt to subscribe to each feed
        var successfulFeeds: [String] = []
        var failedFeeds: [(url: String, error: String)] = []
        
        for feedUrl in feedUrls {
            do {
                _ = try await subscriptionService.subscribe(urlString: feedUrl)
                successfulFeeds.append(feedUrl)
            } catch {
                let errorDescription = describeSubscriptionError(error)
                failedFeeds.append((url: feedUrl, error: errorDescription))
            }
        }
        
        let result = OPMLImportResult(
            successfulFeeds: successfulFeeds,
            failedFeeds: failedFeeds,
            totalFeeds: feedUrls.count
        )
        
        // Return result even if all feeds failed (e.g., duplicates). Consumers/tests inspect failures.
        return result
    }
    
    /// Imports podcast subscriptions from OPML file URL
    /// - Parameter fileURL: Local file URL to OPML file
    /// - Returns: Import result with success/failure details
    /// - Throws: Error.invalidOPML if file cannot be read or parsed
    public func importSubscriptions(from fileURL: URL) async throws -> OPMLImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw Error.invalidOPML
        }
        
        return try await importSubscriptions(from: data)
    }
    
    /// Imports podcast subscriptions from OPML XML string
    /// - Parameter xmlString: OPML XML as string
    /// - Returns: Import result with success/failure details
    /// - Throws: Error.invalidOPML if string cannot be converted to data or parsed
    public func importSubscriptions(from xmlString: String) async throws -> OPMLImportResult {
        guard let data = xmlString.data(using: .utf8) else {
            throw Error.invalidOPML
        }
        
        return try await importSubscriptions(from: data)
    }
    
    // MARK: - Helper Methods
    
    /// Recursively extracts all feed URLs from OPML outlines
    private func extractFeedUrls(from outlines: [OPMLOutline]) -> [String] {
        var urls: [String] = []
        
        for outline in outlines {
            urls.append(contentsOf: outline.allFeedUrls())
        }
        
        // Remove duplicates while preserving order
        return (Array(NSOrderedSet(array: urls)) as NSArray).compactMap { $0 as? String }
    }
    
    /// Converts subscription service errors to human-readable descriptions
    private func describeSubscriptionError(_ error: Swift.Error) -> String {
        if let subscriptionError = error as? SubscriptionService.Error {
            switch subscriptionError {
            case .invalidURL:
                return "Invalid feed URL"
            case .dataLoadFailed:
                return "Failed to load feed data"
            case .parseFailed:
                return "Failed to parse feed"
            case .duplicateSubscription:
                return "Already subscribed"
            }
        }
        
        return "Unknown error: \(error.localizedDescription)"
    }
}
