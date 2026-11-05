import SwiftUI

/// Expandable "Global incidents" row at the top of the Security Advisories section.
struct GlobalIncidentRowView: View {
    let service: GlobalIncidentService
    @Binding var isExpanded: Bool

    /// Total height of the row, used to size the scrolling part of the dropdown.
    static func height(for service: GlobalIncidentService, isExpanded: Bool) -> CGFloat {
        guard isExpanded else { return MenuMetrics.topicRowHeight }
        return MenuMetrics.topicRowHeight + listHeight(for: service) + MenuMetrics.linkRowHeight
    }

    private static func listHeight(for service: GlobalIncidentService) -> CGFloat {
        guard !service.incidents.isEmpty else { return MenuMetrics.componentRowHeight }
        return MenuMetrics.expandedListHeight(
            rowCount: service.incidents.count,
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
                incidentList
                    .frame(height: Self.listHeight(for: service))

                if let url = GlobalIncidentClient.pageURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("All briefings on Cloudflare Radar")
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
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text("Global incidents")
                    .font(.body.weight(.medium))
                Text("powered by Cloudflare")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let error = service.error {
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
    private var incidentList: some View {
        if service.incidents.isEmpty {
            Text(service.hasLoaded
                 ? "No briefings in the last \(GlobalIncidentClient.lookbackDays) days"
                 : "Loading...")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(service.incidents) { incident in
                        GlobalIncidentItemView(incident: incident)
                            .frame(height: MenuMetrics.advisoryRowHeight, alignment: .top)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .padding(.leading, 24)
        }
    }

    private var summaryText: String {
        guard service.hasLoaded else { return "" }
        let count = service.attentionCount
        return count == 0 ? "None urgent" : "\(count) need\(count == 1 ? "s" : "") attention"
    }

    private var iconName: String {
        if service.error != nil { return "questionmark.circle" }
        return service.attentionCount > 0 ? "exclamationmark.triangle.fill" : "globe"
    }

    private var iconColor: Color {
        if service.error != nil { return .gray }
        return service.attentionCount > 0 ? .orange : .green
    }
}
