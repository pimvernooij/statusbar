import Foundation

enum OverallStatus: String, Comparable, Sendable {
    case operational
    case degradedPerformance
    case partialOutage
    case majorOutage
    case unknown

    var severity: Int {
        switch self {
        case .operational: 0
        case .degradedPerformance: 1
        case .partialOutage: 2
        case .majorOutage: 3
        case .unknown: 4
        }
    }

    static func < (lhs: OverallStatus, rhs: OverallStatus) -> Bool {
        lhs.severity < rhs.severity
    }

    init(indicator: String) {
        switch indicator {
        case "none": self = .operational
        case "minor": self = .degradedPerformance
        case "major": self = .partialOutage
        case "critical": self = .majorOutage
        default: self = .unknown
        }
    }

    init(componentStatus: String) {
        switch componentStatus {
        case "operational": self = .operational
        case "degraded_performance": self = .degradedPerformance
        case "partial_outage": self = .partialOutage
        case "major_outage": self = .majorOutage
        default: self = .unknown
        }
    }
}

struct ServiceResult: Identifiable, Sendable {
    let id: UUID
    let service: MonitoredService
    let status: OverallStatus
    let statusDescription: String
    let components: [ComponentResult]
    let error: String?

    var visibleComponents: [ComponentResult] {
        components.filter { component in
            !component.isGroup && (!component.onlyShowIfDegraded || component.status != .operational)
        }
    }

    static func error(service: MonitoredService, message: String) -> ServiceResult {
        ServiceResult(
            id: service.id,
            service: service,
            status: .unknown,
            statusDescription: "Unable to fetch status",
            components: [],
            error: message
        )
    }
}

struct ComponentResult: Identifiable, Sendable {
    let id: String
    let name: String
    let status: OverallStatus
    let isGroup: Bool
    let onlyShowIfDegraded: Bool
}
