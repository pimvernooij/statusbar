import SwiftUI

struct ServiceRowView: View {
    let result: ServiceResult
    @Binding var isExpanded: Bool

    /// Total height of the row, used to size the scrolling part of the dropdown.
    static func height(for result: ServiceResult, isExpanded: Bool) -> CGFloat {
        guard isExpanded else { return MenuMetrics.serviceRowHeight }
        return MenuMetrics.serviceRowHeight
            + CGFloat(result.incidents.count) * MenuMetrics.incidentRowHeight
            + listHeight(for: result)
            + (result.service.pageURL == nil ? 0 : MenuMetrics.linkRowHeight)
    }

    private static func listHeight(for result: ServiceResult) -> CGFloat {
        MenuMetrics.expandedListHeight(
            rowCount: max(result.visibleComponents.count, 1),
            rowHeight: MenuMetrics.componentRowHeight
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: MenuMetrics.serviceRowHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }

            if isExpanded {
                ForEach(result.incidents) { incident in
                    ServiceIncidentRowView(incident: incident)
                        .frame(height: MenuMetrics.incidentRowHeight, alignment: .top)
                }

                componentList
                    .frame(height: Self.listHeight(for: result))

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
                    .frame(height: MenuMetrics.linkRowHeight)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            StatusIndicatorView(status: result.status)
            Text(result.service.name)
                .font(.body.weight(.medium))
                .lineLimit(1)
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
            Image(systemName: "chevron.right")
                .font(.caption2)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var componentList: some View {
        let visible = result.visibleComponents
        if visible.isEmpty {
            Text("No component details available")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visible) { component in
                        ComponentRowView(component: component)
                            .frame(height: MenuMetrics.componentRowHeight)
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
    }
}
