import Foundation

// MARK: - StatusPage API v2 Response Models

struct StatusPageSummary: Codable, Sendable {
    let page: StatusPageInfo
    let status: StatusPageStatus
    let components: [StatusPageComponent]
}

struct StatusPageInfo: Codable, Sendable {
    let id: String
    let name: String
    let url: String
}

struct StatusPageStatus: Codable, Sendable {
    let indicator: String
    let description: String
}

struct StatusPageComponent: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let status: String
    let description: String?
    let group: Bool
    let onlyShowIfDegraded: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, status, description, group
        case onlyShowIfDegraded = "only_show_if_degraded"
    }
}
