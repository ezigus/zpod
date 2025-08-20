public struct OPMLDocument {
    public let version: String
    public let head: OPMLHead
    public let body: OPMLBody
}

public struct OPMLHead {
    public let title: String
    public let dateCreated: Date?
    public let dateModified: Date?
    public let ownerName: String?
}

public struct OPMLBody {
    public let outlines: [OPMLOutline]
}

public struct OPMLOutline {
    public let title: String
    public let xmlUrl: String?
    public let htmlUrl: String?
    public let type: String?
    public let text: String?
    public let outlines: [OPMLOutline]?
    public func allFeedUrls() -> [String] {
        var urls: [String] = []
        if let xmlUrl = xmlUrl { urls.append(xmlUrl) }
        if let nested = outlines {
            for outline in nested { urls.append(contentsOf: outline.allFeedUrls()) }
        }
        return urls
    }
}

public struct OPMLImportResult {
    public let successfulFeeds: [String]
    public let failedFeeds: [(url: String, error: String)]
    public let totalFeeds: Int
}
