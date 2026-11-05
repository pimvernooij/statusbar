import Foundation

/// A raw RSS `<item>`, with only the fields the app uses.
struct RSSItem: Sendable {
    var title = ""
    var link = ""
    var guid = ""
    var pubDate = ""
    /// All `<category>` values in feed order.
    var categories: [String] = []
    var description = ""
}

/// Minimal RSS 2.0 parser built on Foundation's `XMLParser`.
final class RSSFeedParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []
    private var current: RSSItem?
    private var text = ""

    static func parse(_ data: Data) -> [RSSItem]? {
        let delegate = RSSFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        return parser.parse() ? delegate.items : nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "item" {
            current = RSSItem()
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "item":
            if let current { items.append(current) }
            current = nil
        case "title": current?.title = value
        case "link": current?.link = value
        case "guid": current?.guid = value
        case "pubDate": current?.pubDate = value
        case "category": current?.categories.append(value)
        case "description": current?.description = value
        default: break
        }
        text = ""
    }
}
