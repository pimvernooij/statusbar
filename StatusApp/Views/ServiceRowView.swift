import SwiftUI

struct ServiceRowView: View {
    let result: ServiceResult
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusIndicatorView(status: result.status)
                Text(result.service.name)
                    .font(.body.weight(.medium))
                Spacer()
                if let error = result.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text(StatusColor.label(for: result.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                let visible = result.visibleComponents
                if visible.isEmpty {
                    Text("No component details available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 24)
                } else {
                    ForEach(visible) { component in
                        ComponentRowView(component: component)
                    }
                }

                if let url = result.service.pageURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open Status Page")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 24)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
