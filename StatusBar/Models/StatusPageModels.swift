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

// MARK: - incident.io JSON Response Models

struct IncidentIOResponse: Codable, Sendable {
    let summary: IncidentIOSummary
}

struct IncidentIOSummary: Codable, Sendable {
    let name: String
    let components: [IncidentIOComponent]
    let affectedComponents: [IncidentIOAffectedComponent]
    let ongoingIncidents: [IncidentIOIncident]
    let structure: IncidentIOStructure?

    enum CodingKeys: String, CodingKey {
        case name, components, structure
        case affectedComponents = "affected_components"
        case ongoingIncidents = "ongoing_incidents"
    }
}

struct IncidentIOComponent: Codable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct IncidentIOAffectedComponent: Codable, Sendable {
    let componentId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case componentId = "component_id"
        case status
    }
}

struct IncidentIOIncident: Codable, Sendable {
    let id: String
    let name: String
}

struct IncidentIOStructure: Codable, Sendable {
    let id: String
    let items: [IncidentIOStructureItem]
}

struct IncidentIOStructureItem: Codable, Sendable {
    let group: IncidentIOGroup?
}

struct IncidentIOGroup: Codable, Sendable {
    let id: String
    let name: String
    let hidden: Bool
    let components: [IncidentIOGroupComponent]
}

struct IncidentIOGroupComponent: Codable, Sendable {
    let componentId: String
    let name: String
    let hidden: Bool

    enum CodingKeys: String, CodingKey {
        case name, hidden
        case componentId = "component_id"
    }
}

// MARK: - status.io Public API Response Models

struct StatusIOResponse: Codable, Sendable {
    let result: StatusIOResult
}

struct StatusIOResult: Codable, Sendable {
    let statusOverall: StatusIOOverall
    let status: [StatusIOComponent]
    let incidents: [StatusIOIncident]
    let maintenance: StatusIOMaintenance

    enum CodingKeys: String, CodingKey {
        case status, incidents, maintenance
        case statusOverall = "status_overall"
    }
}

struct StatusIOOverall: Codable, Sendable {
    let updated: String
    let status: String
    let statusCode: Int

    enum CodingKeys: String, CodingKey {
        case updated, status
        case statusCode = "status_code"
    }
}

struct StatusIOComponent: Codable, Sendable {
    let id: String
    let name: String
    let status: String
    let statusCode: Int
    let containers: [StatusIOContainer]

    enum CodingKeys: String, CodingKey {
        case id, name, status, containers
        case statusCode = "status_code"
    }
}

struct StatusIOContainer: Codable, Sendable {
    let id: String
    let name: String
    let status: String
    let statusCode: Int

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case statusCode = "status_code"
    }
}

struct StatusIOIncident: Codable, Sendable {
    let name: String

    enum CodingKeys: String, CodingKey {
        case name
    }
}

struct StatusIOMaintenance: Codable, Sendable {
    let active: [StatusIOMaintenanceEvent]
    let upcoming: [StatusIOMaintenanceEvent]
}

struct StatusIOMaintenanceEvent: Codable, Sendable {
    let name: String
}
