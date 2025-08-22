import Foundation
import CoreModels

public protocol FeedParsing {
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed
}

public struct ParsedFeed {
    public let title: String
    public let episodes: [Episode]
    // Add more properties as needed
}
