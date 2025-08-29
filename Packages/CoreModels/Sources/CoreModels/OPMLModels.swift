import Foundation

/// Represents an OPML document structure for podcast subscriptions
public struct OPMLDocument: Codable, Equatable, Sendable {
    /// Document version (usually "1.0" or "2.0")
    public let version: String
    /// Head section containing metadata
    public let head: OPMLHead
    /// Body containing the outline items
    public let body: OPMLBody
    public init(version: String = "2.0", head: OPMLHead, body: OPMLBody) {
        self.version = version
        self.head = head
        self.body = body
    }
}

/// OPML head section containing document metadata
public struct OPMLHead: Codable, Equatable, Sendable {
    /// Document title
    public let title: String
    /// Creation date
    public let dateCreated: Date?
    /// Last modification date
    public let dateModified: Date?
    /// Creator application
    public let ownerName: String?
    public init(title: String, dateCreated: Date? = nil, dateModified: Date? = nil, ownerName: String? = nil) {
        self.title = title
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.ownerName = ownerName
    }
}

/// OPML body containing outline items
public struct OPMLBody: Codable, Equatable, Sendable {
    /// List of outline items (feeds or folders)
    public let outlines: [OPMLOutline]
    public init(outlines: [OPMLOutline]) {
        self.outlines = outlines
    }
}

/// OPML outline representing a podcast feed or folder
public struct OPMLOutline: Codable, Equatable, Sendable {
    /// Outline title
    public let title: String
    /// Feed URL (for feeds)
    public let xmlUrl: String?
    /// Website URL
    public let htmlUrl: String?
    /// Outline type (usually "rss" for feeds)
    public let type: String?
    /// Outline text (alternative to title)
    public let text: String?
    /// Nested outlines (for folders)
    public let outlines: [OPMLOutline]?
    public init(
        title: String,
        xmlUrl: String? = nil,
        htmlUrl: String? = nil,
        type: String? = nil,
        text: String? = nil,
        outlines: [OPMLOutline]? = nil
    ) {
        self.title = title
        self.xmlUrl = xmlUrl
        self.htmlUrl = htmlUrl
        self.type = type
        self.text = text
        self.outlines = outlines
    }
    /// Returns true if this outline represents a feed (has xmlUrl)
    public var isFeed: Bool {
        return xmlUrl != nil && !xmlUrl!.isEmpty
    }
    /// Returns true if this outline represents a folder (has nested outlines)
    public var isFolder: Bool {
        return outlines != nil && !outlines!.isEmpty
    }
    /// Extracts all feed URLs from this outline and any nested outlines
    public func allFeedUrls() -> [String] {
        var urls: [String] = []
        // Add this outline's feed URL if it exists
        if let feedUrl = xmlUrl, !feedUrl.isEmpty {
            urls.append(feedUrl)
        }
        // Recursively add feed URLs from nested outlines
        if let nestedOutlines = outlines {
            for outline in nestedOutlines {
                urls.append(contentsOf: outline.allFeedUrls())
            }
        }
        return urls
    }
}

/// Represents a result from OPML import operation
public struct OPMLImportResult: Equatable, Sendable {
    /// Successfully imported podcast feed URLs
    public let successfulFeeds: [String]
    /// Failed feed URLs with their error descriptions
    public let failedFeeds: [(url: String, error: String)]
    /// Total number of feeds found in OPML
    public let totalFeeds: Int
    public init(successfulFeeds: [String], failedFeeds: [(url: String, error: String)], totalFeeds: Int) {
        self.successfulFeeds = successfulFeeds
        self.failedFeeds = failedFeeds
        self.totalFeeds = totalFeeds
    }
    /// Returns true if the import was completely successful
    public var isCompleteSuccess: Bool {
        return failedFeeds.isEmpty && totalFeeds > 0
    }
    /// Returns true if at least some feeds were imported successfully
    public var hasPartialSuccess: Bool {
        return !successfulFeeds.isEmpty
    }
    // MARK: - Equatable
    public static func == (lhs: OPMLImportResult, rhs: OPMLImportResult) -> Bool {
        return lhs.successfulFeeds == rhs.successfulFeeds &&
               lhs.totalFeeds == rhs.totalFeeds &&
               lhs.failedFeeds.count == rhs.failedFeeds.count &&
               zip(lhs.failedFeeds, rhs.failedFeeds).allSatisfy { left, right in
                   left.url == right.url && left.error == right.error
               }
    }
}
