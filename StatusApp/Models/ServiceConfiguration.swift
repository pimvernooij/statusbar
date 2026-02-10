import Foundation

struct MonitoredService: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var domain: String

    var apiURL: URL? {
        URL(string: "https://\(domain)/api/v2/summary.json")
    }

    var pageURL: URL? {
        URL(string: "https://\(domain)")
    }

    static let defaults: [MonitoredService] = [
        MonitoredService(id: UUID(), name: "Claude", domain: "status.claude.com"),
        MonitoredService(id: UUID(), name: "GitHub", domain: "eu.githubstatus.com"),
    ]
}
