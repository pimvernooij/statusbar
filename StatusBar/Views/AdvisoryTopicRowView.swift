import SwiftUI

struct AdvisoryTopicRowView: View {
    let result: AdvisoryTopicResult
    @Binding var isExpanded: Bool

    /// Total height of the row, used to size the scrolling part of the dropdown.
    static func height(for result: AdvisoryTopicResult, isExpanded: Bool) -> CGFloat {
        guard isExpanded else { return MenuMetrics.topicRowHeight }
        return MenuMetrics.topicRowHeight
            + listHeight(for: result)
            + (result.topic.webURL == nil ? 0 : MenuMetrics.linkRowHeight)
    }

    private static func listHeight(for result: AdvisoryTopicResult) -> CGFloat {
        guard !result.advisories.isEmpty else { return MenuMetrics.componentRowHeight }
        return MenuMetrics.expandedListHeight(
            rowCount: result.advisories.count,
            rowHeight: MenuMetrics.advisoryRowHeight
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: MenuMetrics.topicRowHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }

            if isExpanded {
                advisoryList
                    .frame(height: Self.listHeight(for: result))

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
                    .frame(height: MenuMetrics.linkRowHeight)
                }
            }
        }
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
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(result.advisories) { advisory in
                        AdvisoryRowView(advisory: advisory)
                            .frame(height: MenuMetrics.advisoryRowHeight, alignment: .top)
                    }
                }
            }
            .scrollIndicators(.automatic)
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
