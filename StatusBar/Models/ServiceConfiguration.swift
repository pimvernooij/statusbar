import Foundation

enum ServiceProvider: String, Codable, CaseIterable, Sendable {
    case statusPage
    case incidentIO
}

struct MonitoredService: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var domain: String
    var provider: ServiceProvider

    init(id: UUID, name: String, domain: String, provider: ServiceProvider = .statusPage) {
        self.id = id
        self.name = name
        self.domain = domain
        self.provider = provider
    }

    var apiURL: URL? {
        switch provider {
        case .statusPage:
            URL(string: "https://\(domain)/api/v2/summary.json")
        case .incidentIO:
            URL(string: "https://\(domain)/feed.rss")
        }
    }

    var pageURL: URL? {
        URL(string: "https://\(domain)")
    }

    static let defaults: [MonitoredService] = [
        MonitoredService(id: UUID(), name: "Claude", domain: "status.claude.com"),
        MonitoredService(id: UUID(), name: "GitHub", domain: "eu.githubstatus.com"),
        MonitoredService(id: UUID(), name: "OpenAI", domain: "status.openai.com", provider: .incidentIO),
        MonitoredService(id: UUID(), name: "Vercel", domain: "www.vercel-status.com"),
    ]
}
