import Foundation

enum AdvisoryClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited(resetsAt: Date?)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid request URL"
        case .invalidResponse:
            "Invalid response"
        case .rateLimited(let resetsAt):
            if let resetsAt {
                "Rate limited until \(resetsAt.formatted(date: .omitted, time: .shortened))"
            } else {
                "Rate limited by GitHub"
            }
        case .http(let code):
            "HTTP \(code)"
        }
    }
}

/// Fetches reviewed high/critical advisories from the GitHub Advisory Database.
///
/// The endpoint is public; unauthenticated requests are limited to 60 per hour per IP,
/// and each topic costs one request per followed severity (the API accepts only one
/// severity per request).
actor AdvisoryClient {
    /// How far back advisories are listed.
    static let lookbackDays = 7

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchAdvisories(for topic: AdvisoryTopic) async -> AdvisoryTopicResult {
        do {
            let advisories = try await withThrowingTaskGroup(of: [Advisory].self) { group in
                for severity in topic.severities {
                    group.addTask { try await self.fetch(topic, severity: severity) }
                }
                return try await group.reduce(into: []) { $0 += $1 }
            }
            return AdvisoryTopicResult(
                id: topic.id,
                topic: topic,
                advisories: advisories.sorted { $0.publishedAt > $1.publishedAt },
                error: nil
            )
        } catch is CancellationError {
            return .error(topic: topic, message: "Request cancelled")
        } catch let error as DecodingError {
            return .error(topic: topic, message: "Failed to parse response: \(error.localizedDescription)")
        } catch {
            return .error(topic: topic, message: error.localizedDescription)
        }
    }

    private func fetch(_ topic: AdvisoryTopic, severity: AdvisorySeverity) async throws -> [Advisory] {
        guard let url = Self.url(for: topic, severity: severity) else {
            throw AdvisoryClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdvisoryClientError.invalidResponse
        }

        if [403, 429].contains(httpResponse.statusCode),
           httpResponse.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" {
            let reset = httpResponse.value(forHTTPHeaderField: "x-ratelimit-reset")
                .flatMap(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:))
            throw AdvisoryClientError.rateLimited(resetsAt: reset)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AdvisoryClientError.http(httpResponse.statusCode)
        }

        return try decoder.decode([GitHubAdvisory].self, from: data).compactMap(Advisory.init)
    }

    private static func url(for topic: AdvisoryTopic, severity: AdvisorySeverity) -> URL? {
        let since = Date.now.addingTimeInterval(-Double(lookbackDays) * 86_400)
        let sinceDay = since.formatted(.iso8601.year().month().day())

        var items = [
            URLQueryItem(name: "type", value: "reviewed"),
            URLQueryItem(name: "ecosystem", value: topic.ecosystem.rawValue),
            URLQueryItem(name: "severity", value: severity.rawValue),
            URLQueryItem(name: "published", value: ">=\(sinceDay)"),
            URLQueryItem(name: "sort", value: "published"),
            URLQueryItem(name: "direction", value: "desc"),
            URLQueryItem(name: "per_page", value: "100"),
        ]
        if !topic.packages.isEmpty {
            items.append(URLQueryItem(name: "affects", value: topic.packages.joined(separator: ",")))
        }

        var components = URLComponents(string: "https://api.github.com/advisories")
        components?.queryItems = items
        return components?.url
    }
}
