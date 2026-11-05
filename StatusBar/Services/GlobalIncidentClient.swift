import Foundation

enum GlobalIncidentClientError: LocalizedError {
    case invalidResponse
    case http(Int)
    case invalidFeed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response"
        case .http(let code): "HTTP \(code)"
        case .invalidFeed: "Could not read the feed"
        }
    }
}

/// Reads Cloudflare Radar's Zero Wire RSS feed of urgent, widespread incidents.
/// The feed is public and cached for 5 minutes by Cloudflare.
actor GlobalIncidentClient {
    static let feedURL = URL(string: "https://radar.cloudflare.com/security/zero-wire/rss")
    static let pageURL = URL(string: "https://radar.cloudflare.com/security/zero-wire")
    /// How far back briefings are listed.
    static let lookbackDays = 30

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Recent briefings: items that need attention first, newest first within each group.
    func fetchIncidents() async throws -> [GlobalIncident] {
        guard let url = Self.feedURL else { throw GlobalIncidentClientError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalIncidentClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GlobalIncidentClientError.http(httpResponse.statusCode)
        }
        guard let items = RSSFeedParser.parse(data) else {
            throw GlobalIncidentClientError.invalidFeed
        }

        let cutoff = Date.now.addingTimeInterval(-Double(Self.lookbackDays) * 86_400)
        return items
            .compactMap(Self.incident)
            .filter { $0.publishedAt >= cutoff }
            .sorted {
                $0.needsAttention != $1.needsAttention ? $0.needsAttention : $0.publishedAt > $1.publishedAt
            }
    }

    private static func incident(from item: RSSItem) -> GlobalIncident? {
        let id = item.link.isEmpty ? item.guid : item.link
        guard !id.isEmpty, !item.title.isEmpty, let date = parseDate(item.pubDate) else { return nil }
        // The first category is the briefing's status; the rest are tags
        return GlobalIncident(
            id: id,
            title: item.title,
            summary: item.description,
            category: item.categories.first ?? "",
            tags: Array(item.categories.dropFirst()),
            publishedAt: date,
            url: URL(string: item.link)
        )
    }

    /// RFC 822 dates as used by RSS, e.g. "Sun, 01 Nov 2026 00:00:00 GMT".
    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
