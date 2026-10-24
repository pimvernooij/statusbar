import SwiftUI

enum AdvisoryStyle {
    static func color(for severity: AdvisorySeverity?) -> Color {
        switch severity {
        case .critical: .red
        case .high: .orange
        case nil: .green
        }
    }

    static func sfSymbolName(for severity: AdvisorySeverity?) -> String {
        switch severity {
        case .critical, .high: "exclamationmark.shield.fill"
        case nil: "checkmark.shield.fill"
        }
    }
}
