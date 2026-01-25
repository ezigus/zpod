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

    // MARK: - Episode Builder

    /// Internal struct to accumulate episode data during parsing
    private struct EpisodeBuilder {
        var guid: String?
        var title: String = ""
        var audioURL: URL?
        var invalidAudioURLString: String?
        var pubDate: Date?
        var duration: TimeInterval?
        var description: String = ""
        var itunesSummary: String?
        var artworkURL: URL?
    }

    // MARK: - Parser State

    private let logWarning: @Sendable (String) -> Void

    private var elementStack: [String] = []
    private var textStack: [String] = []

    // MARK: - Podcast-level building

    private var podcastTitle: String = ""
    private var podcastDescription: String = ""
    private var podcastAuthor: String = ""
    private var podcastArtworkURL: URL?
    private var podcastCategories: [String] = []

    // MARK: - Episode building

    private var episodes: [EpisodeBuilder] = []
    private var currentEpisode: EpisodeBuilder?
    private var isInItem: Bool = false
    private var feedURL: URL?

    // MARK: - Public API

    public override convenience init() {
        self.init(logWarning: { @Sendable message in
            Logger.warning(message)
        })
    }

    public init(logWarning: @escaping @Sendable (String) -> Void) {
        self.logWarning = logWarning
        super.init()
    }

    /// Parse RSS feed from URL
    #if !os(Linux)
    @available(macOS 12.0, *)
    public static func parseFeed(from url: URL) async throws -> Podcast {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseFeed(from: data, feedURL: url)
    }
    #endif

    /// Parse RSS feed from data
    public static func parseFeed(from data: Data, feedURL: URL) throws -> Podcast {
        return try parseFeed(from: data, feedURL: feedURL, logWarning: { @Sendable message in
            Logger.warning(message)
        })
    }

    /// Parse RSS feed from data with a custom warning logger (testing)
    public static func parseFeed(from data: Data, feedURL: URL, logWarning: @escaping @Sendable (String) -> Void) throws -> Podcast {
        let parser = RSSFeedParser(logWarning: logWarning)
        parser.feedURL = feedURL

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        guard xmlParser.parse() else {
            throw RSSParsingError.invalidXML
        }

        let podcastID = feedURL.absoluteString.hash.description
        let episodes = parser.buildEpisodes(podcastID: podcastID, podcastTitle: parser.podcastTitle)

        return Podcast(
            id: podcastID,
            title: parser.podcastTitle.isEmpty ? "Unknown Podcast" : parser.podcastTitle,
            author: parser.podcastAuthor,
            description: parser.podcastDescription,
            artworkURL: parser.podcastArtworkURL,
            feedURL: feedURL,
            categories: parser.podcastCategories,
            episodes: episodes,
            isSubscribed: false,
            dateAdded: Date()
        )
    }

    // MARK: - Private Helpers

    /// Convert episode builders to Episode models
    private func buildEpisodes(podcastID: String, podcastTitle: String) -> [Episode] {
        return episodes.map { builder in
            let episodeTitle = builder.title.isEmpty ? "Untitled Episode" : builder.title
            let audioURL = builder.audioURL
            if audioURL == nil {
                if let invalidAudioURL = builder.invalidAudioURLString, !invalidAudioURL.isEmpty {
                    logWarning("Episode '\(episodeTitle)' has invalid audio URL: \(invalidAudioURL)")
                } else {
                    logWarning("Episode '\(episodeTitle)' missing audio URL")
                }
            }

            // Generate ID from guid or fallback
            let id = builder.guid ?? generateEpisodeID(title: builder.title, pubDate: builder.pubDate)

            // Use itunes:summary if available, fall back to description
            let description = builder.itunesSummary ?? builder.description

            return Episode(
                id: id,
                title: builder.title.isEmpty ? "Untitled Episode" : builder.title,
                podcastID: podcastID,
                podcastTitle: podcastTitle,
                pubDate: builder.pubDate,
                duration: builder.duration,
                description: description.isEmpty ? nil : description,
                audioURL: audioURL,
                artworkURL: builder.artworkURL
            )
        }
    }

    /// Generate episode ID from title and pubDate
    private func generateEpisodeID(title: String, pubDate: Date?) -> String {
        let feed = feedURL?.absoluteString ?? ""
        let dateString = pubDate?.timeIntervalSince1970.description ?? ""
        let base = "\(feed)|\(title)|\(dateString)"
        return StableHasher.hash(base)
    }

    /// Parse duration from string (supports both seconds and HH:MM:SS formats)
    private func parseDuration(_ string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Format 1: Plain seconds "3600"
        if let seconds = TimeInterval(trimmed) {
            return seconds
        }

        // Format 2: HH:MM:SS or MM:SS
        let parts = trimmed.split(separator: ":")
        let componentOptions = parts.map { Int($0) }
        guard componentOptions.allSatisfy({ $0 != nil }) else {
            return nil
        }
        let components = componentOptions.compactMap { $0 }

        switch components.count {
        case 3: // HH:MM:SS
            let hours = components[0]
            let minutes = components[1]
            let seconds = components[2]
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)

        case 2: // MM:SS
            let minutes = components[0]
            let seconds = components[1]
            return TimeInterval(minutes * 60 + seconds)

        default:
            return nil
        }
    }

    /// Parse date from string (supports RFC 822 and ISO 8601)
    private func parseDate(_ dateString: String) -> Date? {
        // RFC 822: "Wed, 02 Oct 2024 10:00:00 +0000"
        if let date = DateFormatter.rfc822.date(from: dateString) {
            return date
        }

        // ISO 8601: "2024-10-02T10:00:00Z"
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) {
            return date
        }

        return nil
    }
}

// MARK: - XMLParserDelegate

extension RSSFeedParser: XMLParserDelegate {

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        textStack.append("")

        switch elementName.lowercased() {
        case "item":
            // Starting a new episode
            isInItem = true
            currentEpisode = EpisodeBuilder()

        case "enclosure":
            // CRITICAL: Extract audio URL from attributes
            if isInItem, let urlString = attributeDict["url"] {
                if let url = URL(string: urlString) {
                    currentEpisode?.audioURL = url
                    currentEpisode?.invalidAudioURLString = nil
                } else {
                    currentEpisode?.audioURL = nil
                    currentEpisode?.invalidAudioURLString = urlString
                }
            }

        case "itunes:image":
            // Extract href attribute for artwork
            if let href = attributeDict["href"], let url = URL(string: href) {
                if isInItem {
                    currentEpisode?.artworkURL = url
                } else {
                    podcastArtworkURL = url
                }
            }

        case "category", "itunes:category":
            // Extract category text from attribute
            if let categoryText = attributeDict["text"], !isInItem {
                podcastCategories.append(categoryText)
            }

        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !textStack.isEmpty else { return }
        textStack[textStack.count - 1] += string
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {

        let collectedText = textStack.popLast() ?? ""
        elementStack.removeLast()
        let trimmedText = collectedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInItem {
            // Inside <item> - episode-level data
            switch elementName.lowercased() {
            case "item":
                // Finished episode - save it
                if let episode = currentEpisode {
                    episodes.append(episode)
                }
                currentEpisode = nil
                isInItem = false

            case "title":
                currentEpisode?.title = trimmedText

            case "guid":
                currentEpisode?.guid = trimmedText

            case "pubdate":
                currentEpisode?.pubDate = parseDate(trimmedText)

            case "description":
                currentEpisode?.description = trimmedText

            case "itunes:summary":
                currentEpisode?.itunesSummary = trimmedText

            case "itunes:duration":
                currentEpisode?.duration = parseDuration(trimmedText)

            default:
                break
            }
        } else {
            // Channel-level data (podcast)
            switch elementName.lowercased() {
            case "title":
                // Only capture channel title, not image title
                if elementStack.contains("channel") && !elementStack.contains("image") {
                    podcastTitle = trimmedText
                }

            case "description":
                if elementStack.contains("channel") {
                    podcastDescription = trimmedText
                }

            case "author", "itunes:author":
                podcastAuthor = trimmedText

            case "category":
                // Category as text content (not attribute)
                if !trimmedText.isEmpty {
                    podcastCategories.append(trimmedText)
                }

            default:
                break
            }
        }

        // Preserve mixed-content text by propagating to the parent element buffer
        if let lastIndex = textStack.indices.last {
            textStack[lastIndex] += collectedText
        }
    }
}

// MARK: - Date Formatter Extensions

private extension DateFormatter {
    static let rfc822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

}

// MARK: - Stable Hashing

private enum StableHasher {
    static func hash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325 // FNV-1a offset basis
        let prime: UInt64 = 0x00000100000001B3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return String(hash)
    }
}
