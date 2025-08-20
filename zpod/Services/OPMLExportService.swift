import Foundation
import CoreModels

/// Service for exporting podcast subscriptions to OPML format
public final class OPMLExportService {
    
    /// Errors that can occur during OPML export
    public enum Error: Swift.Error, Equatable {
        case noSubscriptions
        case exportFailed
    }
    
    private let podcastManager: PodcastManaging
    
    public init(podcastManager: PodcastManaging) {
        self.podcastManager = podcastManager
    }
    
    /// Exports all current subscriptions to OPML format
    /// - Returns: OPML document containing all subscribed podcasts
    /// - Throws: Error.noSubscriptions if no podcasts are subscribed
    public func exportSubscriptions() throws -> OPMLDocument {
        let allPodcasts = podcastManager.all()
        let subscribedPodcasts = allPodcasts.filter { $0.isSubscribed }
        
        guard !subscribedPodcasts.isEmpty else {
            throw Error.noSubscriptions
        }
        
        let head = OPMLHead(
            title: "zPodcastAddict Subscriptions",
            dateCreated: Date(),
            dateModified: Date(),
            ownerName: "zPodcastAddict"
        )
        
        // Ensure deterministic ordering in export. Sort by title ASC (case-insensitive), then by feed URL.
        let ordered = subscribedPodcasts.sorted { lhs, rhs in
            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return lhs.feedURL.absoluteString < rhs.feedURL.absoluteString
        }
        
        let outlines = ordered.map { podcast in
            OPMLOutline(
                title: podcast.title,
                xmlUrl: podcast.feedURL.absoluteString,
                htmlUrl: nil, // Could be website URL if available in future
                type: "rss",
                text: podcast.title,
                outlines: nil
            )
        }
        
        let body = OPMLBody(outlines: outlines)
        
        return OPMLDocument(version: "2.0", head: head, body: body)
    }
    
    /// Exports subscriptions to OPML XML data
    /// - Returns: UTF-8 encoded XML data
    /// - Throws: Error.noSubscriptions if no podcasts are subscribed, Error.exportFailed if XML generation fails
    public func exportSubscriptionsAsXML() throws -> Data {
        let document = try exportSubscriptions()
        return try generateXML(from: document)
    }
    
    /// Exports subscriptions to OPML XML string
    /// - Returns: XML string representation
    /// - Throws: Error.noSubscriptions if no podcasts are subscribed, Error.exportFailed if XML generation fails
    public func exportSubscriptionsAsXMLString() throws -> String {
        let data = try exportSubscriptionsAsXML()
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw Error.exportFailed
        }
        return xmlString
    }
    
    // MARK: - XML Generation
    private func generateXML(from document: OPMLDocument) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<opml version=\"\(document.version)\">\n"
        xml += generateHeadXML(from: document.head)
        xml += generateBodyXML(from: document.body)
        xml += "</opml>\n"
        
        guard let data = xml.data(using: .utf8) else {
            throw Error.exportFailed
        }
        
        return data
    }
    
    private func generateHeadXML(from head: OPMLHead) -> String {
        var xml = "  <head>\n"
        xml += "    <title>\(xmlEscape(head.title))</title>\n"
        
        if let dateCreated = head.dateCreated {
            xml += "    <dateCreated>\(formatDate(dateCreated))</dateCreated>\n"
        }
        
        if let dateModified = head.dateModified {
            xml += "    <dateModified>\(formatDate(dateModified))</dateModified>\n"
        }
        
        if let ownerName = head.ownerName {
            xml += "    <ownerName>\(xmlEscape(ownerName))</ownerName>\n"
        }
        
        xml += "  </head>\n"
        return xml
    }
    
    private func generateBodyXML(from body: OPMLBody) -> String {
        var xml = "  <body>\n"
        
        for outline in body.outlines {
            xml += generateOutlineXML(from: outline, indent: "    ")
        }
        
        xml += "  </body>\n"
        return xml
    }
    
    private func generateOutlineXML(from outline: OPMLOutline, indent: String) -> String {
        var xml = "\(indent)<outline"
        
        xml += " title=\"\(xmlEscape(outline.title))\""
        
        if let text = outline.text {
            xml += " text=\"\(xmlEscape(text))\""
        }
        
        if let type = outline.type {
            xml += " type=\"\(xmlEscape(type))\""
        }
        
        if let xmlUrl = outline.xmlUrl {
            xml += " xmlUrl=\"\(xmlEscape(xmlUrl))\""
        }
        
        if let htmlUrl = outline.htmlUrl {
            xml += " htmlUrl=\"\(xmlEscape(htmlUrl))\""
        }
        
        // Check if there are nested outlines
        if let nestedOutlines = outline.outlines, !nestedOutlines.isEmpty {
            xml += ">\n"
            
            for nestedOutline in nestedOutlines {
                xml += generateOutlineXML(from: nestedOutline, indent: indent + "  ")
            }
            
            xml += "\(indent)</outline>\n"
        } else {
            xml += " />\n"
        }
        
        return xml
    }
    
    // MARK: - Helper Methods
    private func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
