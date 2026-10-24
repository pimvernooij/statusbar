import SwiftUI

struct AdvisoryTopicRowView: View {
    let result: AdvisoryTopicResult
    @State private var isExpanded = false

    /// Rows shown inline; a ScrollView collapses to zero height inside MenuBarExtra,
    /// so long lists are truncated instead.
    private static let maxVisibleAdvisories = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                advisoryList

                if let url = result.topic.webURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("All advisories on GitHub")
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

    private var header: some View {
        HStack {
            Image(systemName: result.error == nil
                  ? AdvisoryStyle.sfSymbolName(for: result.highestSeverity)
                  : "questionmark.circle")
                .foregroundStyle(result.error == nil ? AdvisoryStyle.color(for: result.highestSeverity) : .gray)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(result.topic.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(result.topic.ecosystem.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let error = result.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var advisoryList: some View {
        if result.advisories.isEmpty {
            Text("No \(result.topic.severityDescription) advisories in the last \(AdvisoryClient.lookbackDays) days")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(result.advisories.prefix(Self.maxVisibleAdvisories)) { advisory in
                    AdvisoryRowView(advisory: advisory)
                }
                let hidden = result.advisories.count - Self.maxVisibleAdvisories
                if hidden > 0 {
                    Text("+\(hidden) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 24)
        }
    }

    private var summaryText: String {
        let critical = result.count(of: .critical)
        let high = result.count(of: .high)
        switch (critical, high) {
        case (0, 0): return "None"
        case (_, 0): return "\(critical) critical"
        case (0, _): return "\(high) high"
        default: return "\(critical) critical · \(high) high"
        }
    }
}
