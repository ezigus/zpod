import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import CoreModels

/// Protocol for parsing OPML documents
public protocol OPMLParsing {
    /// Parse OPML data into an OPMLDocument
    func parseOPML(data: Data) throws -> OPMLDocument
}

/// XML-based OPML parser implementation
public final class XMLOPMLParser: NSObject, OPMLParsing, @unchecked Sendable {
    
    /// Errors that can occur during OPML parsing
    public enum Error: Swift.Error, Equatable {
        case invalidXML
        case missingRequiredElements
        case unsupportedVersion
    }
    
    // MARK: - Parser State
    private var currentElement: String = ""
    private var currentText: String = ""
    private var elementStack: [String] = []
    
    // MARK: - Document Building State
    private var version: String = "2.0"
    private var title: String = ""
    private var dateCreated: Date?
    private var dateModified: Date?
    private var ownerName: String?
    private var outlines: [OPMLOutline] = []
    private var outlineStack: [OPMLOutline] = []
    
    public override init() {}
    
    public func parseOPML(data: Data) throws -> OPMLDocument {
        // Reset parser state
        resetState()
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw Error.invalidXML
        }
        
        // Validate required elements
        guard !title.isEmpty else {
            throw Error.missingRequiredElements
        }
        
        let head = OPMLHead(
            title: title,
            dateCreated: dateCreated,
            dateModified: dateModified,
            ownerName: ownerName
        )
        
        let body = OPMLBody(outlines: outlines)
        
        return OPMLDocument(version: version, head: head, body: body)
    }
    
    // MARK: - State Management
    private func resetState() {
        currentElement = ""
        currentText = ""
        elementStack = []
        version = "2.0"
        title = ""
        dateCreated = nil
        dateModified = nil
        ownerName = nil
        outlines = []
        outlineStack = []
    }
}

// MARK: - XMLParserDelegate
extension XMLOPMLParser: XMLParserDelegate {
    
    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        elementStack.append(elementName)
        
        switch elementName.lowercased() {
        case "opml":
            if let versionAttr = attributeDict["version"] {
                version = versionAttr
            }
            
        case "outline":
            let outline = parseOutlineAttributes(attributeDict)
            
            // If we're inside another outline, this is a nested outline
            if !outlineStack.isEmpty {
                // We'll handle nesting when we close the parent outline
                outlineStack.append(outline)
            } else {
                // This is a top-level outline
                outlineStack.append(outline)
            }
            
        default:
            break
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        elementStack.removeLast()
        
        switch elementName.lowercased() {
        case "title":
            if isInHead() {
                title = currentText
            }
            
        case "datecreated":
            if isInHead() {
                dateCreated = parseDate(currentText)
            }
            
        case "datemodified":
            if isInHead() {
                dateModified = parseDate(currentText)
            }
            
        case "ownername":
            if isInHead() {
                ownerName = currentText
            }
            
        case "outline":
            guard let completedOutline = outlineStack.popLast() else { break }
            
            if outlineStack.isEmpty {
                // This was a top-level outline
                outlines.append(completedOutline)
            } else {
                // This was a nested outline - add it to its parent
                if var parentOutline = outlineStack.popLast() {
                    var nestedOutlines = parentOutline.outlines ?? []
                    nestedOutlines.append(completedOutline)
                    
                    // Create updated parent with nested outline
                    parentOutline = OPMLOutline(
                        title: parentOutline.title,
                        xmlUrl: parentOutline.xmlUrl,
                        htmlUrl: parentOutline.htmlUrl,
                        type: parentOutline.type,
                        text: parentOutline.text,
                        outlines: nestedOutlines
                    )
                    
                    outlineStack.append(parentOutline)
                }
            }
            
        default:
            break
        }
        
        currentText = ""
        currentElement = ""
    }
    
    // MARK: - Helper Methods
    private func isInHead() -> Bool {
        return elementStack.contains("head")
    }
    
    private func parseOutlineAttributes(_ attributes: [String: String]) -> OPMLOutline {
        let title = attributes["title"] ?? attributes["text"] ?? ""
        let xmlUrl = attributes["xmlUrl"]
        let htmlUrl = attributes["htmlUrl"]
        let type = attributes["type"]
        let text = attributes["text"]
        
        return OPMLOutline(
            title: title,
            xmlUrl: xmlUrl,
            htmlUrl: htmlUrl,
            type: type,
            text: text,
            outlines: nil // Will be populated if this has nested outlines
        )
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try common OPML date formats
        
        // RFC 822 format: "Wed, 02 Oct 2002 15:00:00 +0000"
        if let date = DateFormatter.rfc822.date(from: dateString) {
            return date
        }
        
        // ISO 8601 format: "2002-10-02T15:00:00Z"
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Simple date format: "2002-10-02"
        if let date = DateFormatter.simpleDateFormat.date(from: dateString) {
            return date
        }
        
        return nil
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
    
    static let simpleDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
