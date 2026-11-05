import SwiftUI

struct GlobalIncidentItemView: View {
    let incident: GlobalIncident

    var body: some View {
        Button {
            if let url = incident.url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(incident.needsAttention ? "ATTENTION" : incident.category.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(incident.needsAttention ? Color.orange : Color.gray, in: RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(incident.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    details
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(incident.summary)
    }

    private var details: some View {
        // Re-render every minute so "x days ago" stays current while the menu is open
        TimelineView(.everyMinute) { _ in
            Text("\(incident.action) · \(incident.publishedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}
