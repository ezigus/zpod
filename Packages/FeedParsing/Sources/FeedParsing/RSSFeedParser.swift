import Foundation
import CoreModels
import SharedUtilities

/// RSS Feed parsing errors
public enum RSSParsingError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidXML
    case missingRequiredFields
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feed URL"
        case .noData:
            return "No data received from feed"
        case .invalidXML:
            return "Invalid XML format"
        case .missingRequiredFields:
            return "Missing required podcast fields"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        }
    }
}

/// RSS Feed parser for podcast feeds
public final class RSSFeedParser: NSObject, @unchecked Sendable {
    
    /// Parse RSS feed from URL
    #if !os(Linux)
    public static func parseFeed(from url: URL) async throws -> Podcast {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseFeed(from: data, feedURL: url)
    }
    #endif
    
    /// Parse RSS feed from data
    public static func parseFeed(from data: Data, feedURL: URL) throws -> Podcast {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw RSSParsingError.noData
        }
        
        // Basic XML parsing - in a real implementation you'd use XMLParser
        // For now, create a basic podcast structure
        let podcastId = feedURL.absoluteString.hash.description
        
        // Extract basic information (simplified parsing)
        let title = extractValue(from: xmlString, tag: "title") ?? "Unknown Podcast"
        let description = extractValue(from: xmlString, tag: "description") ?? ""
        let author = extractValue(from: xmlString, tag: "author") ?? ""
        
        return Podcast(
            id: podcastId,
            title: title,
            author: author,
            description: description,
            artworkURL: extractURL(from: xmlString, tag: "image"),
            feedURL: feedURL,
            categories: extractCategories(from: xmlString),
            episodes: [],  // Episodes would be parsed separately
            isSubscribed: false,
            dateAdded: Date()
        )
    }
    
    /// Extract value between XML tags (simplified)
    private static func extractValue(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let range = NSRange(xml.startIndex..., in: xml)
        
        if let match = regex?.firstMatch(in: xml, options: [], range: range) {
            if let matchRange = Range(match.range(at: 1), in: xml) {
                return String(xml[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    /// Extract URL from XML (simplified)
    private static func extractURL(from xml: String, tag: String) -> URL? {
        if let urlString = extractValue(from: xml, tag: tag) {
            return URL(string: urlString)
        }
        return nil
    }
    
    /// Extract categories from XML (simplified)
    private static func extractCategories(from xml: String) -> [String] {
        // Simplified category extraction
        return []
    }
}