import SwiftUI

enum StatusColor {
    static func color(for status: OverallStatus) -> Color {
        switch status {
        case .operational: .green
        case .degradedPerformance: .yellow
        case .partialOutage: .orange
        case .majorOutage: .red
        case .unknown: .gray
        }
    }

    static func sfSymbolName(for status: OverallStatus) -> String {
        switch status {
        case .operational: "checkmark.circle.fill"
        case .degradedPerformance: "exclamationmark.triangle.fill"
        case .partialOutage: "exclamationmark.triangle.fill"
        case .majorOutage: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    static func label(for status: OverallStatus) -> String {
        switch status {
        case .operational: "Operational"
        case .degradedPerformance: "Degraded Performance"
        case .partialOutage: "Partial Outage"
        case .majorOutage: "Major Outage"
        case .unknown: "Unknown"
        }
    }
}
