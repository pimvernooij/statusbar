import SwiftUI

struct AdvisoryRowView: View {
    let advisory: Advisory

    var body: some View {
        Button {
            if let url = advisory.url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(advisory.severity.label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AdvisoryStyle.color(for: advisory.severity), in: RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(advisory.summary)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    details
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(advisory.summary)
    }

    private var details: some View {
        // Re-render every minute so "x minutes ago" stays current while the menu is open
        TimelineView(.everyMinute) { _ in
            Text([
                advisory.packages.joined(separator: ", "),
                advisory.displayID,
                advisory.publishedAt.formatted(.relative(presentation: .named)),
            ].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}
