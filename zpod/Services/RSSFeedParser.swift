import Foundation
import CoreModels

public final class RSSFeedParser: NSObject, FeedParsing, XMLParserDelegate {
  private var currentElement: String = ""
  private var currentText: String = ""

  private var channelTitle: String = ""
  private var channelDescription: String = ""
  private var channelAuthor: String?
  private var channelImageURL: URL?
  private var categories: [String] = []

  private struct TempEpisode {
    var guid: String?
    var title: String = ""
    var enclosureURL: URL?
  }
  private var currentEpisode: TempEpisode?
  private var episodes: [Episode] = []

  private var sourceURL: URL?

  public override init() {}

  public func parse(data: Data, sourceURL: URL) throws -> ParsedFeed {
    // Reset all state variables before parsing to ensure clean state
    resetState()
    self.sourceURL = sourceURL
    let parser = XMLParser(data: data)
    parser.delegate = self
    guard parser.parse() else { throw SubscriptionService.Error.parseFailed }
    let podcast = Podcast(
      id: sourceURL.absoluteString,
      title: channelTitle.trimmingCharacters(in: .whitespacesAndNewlines),
      author: channelAuthor?.trimmingCharacters(in: .whitespacesAndNewlines),
      description: channelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? nil : channelDescription,
      artworkURL: channelImageURL,
      feedURL: sourceURL,
      categories: categories,
      episodes: episodes,
      isSubscribed: false,
      dateAdded: Date()
    )
    return ParsedFeed(podcast: podcast)
  }

  // MARK: - State Management
  private func resetState() {
    currentElement = ""
    currentText = ""
    channelTitle = ""
    channelDescription = ""
    channelAuthor = nil
    channelImageURL = nil
    categories = []
    currentEpisode = nil
    episodes = []
  }

  // MARK: - XMLParserDelegate
  public func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
  ) {
    currentElement = elementName
    currentText = ""
    switch elementName.lowercased() {
    case "item": currentEpisode = TempEpisode()
    case "enclosure":
      if let urlStr = attributeDict["url"], let u = URL(string: urlStr) {
        currentEpisode?.enclosureURL = u
      }
    case "itunes:image":
      if let href = attributeDict["href"], let u = URL(string: href) { channelImageURL = u }
    case "category", "itunes:category":
      if let text = attributeDict["text"], !text.isEmpty { categories.append(text) }
    default: break
    }
  }

  public func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentText += string
  }

  public func parser(
    _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    switch elementName.lowercased() {
    case "title":
      if currentEpisode != nil { currentEpisode?.title += trimmed } else { channelTitle += trimmed }
    case "description":
      if currentEpisode == nil { channelDescription += trimmed }
    case "itunes:author": channelAuthor = (channelAuthor ?? "") + trimmed
    case "guid": currentEpisode?.guid = trimmed
    case "category": if !trimmed.isEmpty { categories.append(trimmed) }
    case "item":
      if let temp = currentEpisode {
        let id = temp.guid ?? temp.enclosureURL?.absoluteString ?? UUID().uuidString
        let ep = Episode(
          id: id, title: temp.title.isEmpty ? id : temp.title, mediaURL: temp.enclosureURL)
        episodes.append(ep)
        currentEpisode = nil
      }
    default: break
    }
  }
}
