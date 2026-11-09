import SwiftUI

/// An open incident of a monitored service, shown above its components.
struct ServiceIncidentRowView: View {
    let incident: ServiceIncident

    var body: some View {
        Button {
            if let url = incident.url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(StatusColor.color(for: incident.status))
                    .padding(.top, 2)
                Text(incident.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if incident.url != nil {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                }
            }
            .padding(.leading, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(incident.url == nil)
        .help(incident.name)
    }
}
