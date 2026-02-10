import SwiftUI

struct ComponentRowView: View {
    let component: ComponentResult

    var body: some View {
        HStack {
            StatusIndicatorView(status: component.status, size: 10)
            Text(component.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(StatusColor.label(for: component.status))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 24)
    }
}
