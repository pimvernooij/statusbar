import SwiftUI

struct StatusMenuView: View {
    let pollingService: StatusPollingService
    let advisoryService: AdvisoryPollingService
    let updateService: UpdateService
    @Environment(\.openWindow) private var openWindow
    /// IDs of the expanded service and advisory topic rows.
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let release = updateService.availableRelease {
                UpdateBannerView(updateService: updateService, release: release)
                Divider()
            }

            // Header
            HStack {
                Text("Service Status")
                    .font(.headline)
                Spacer()
                if pollingService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: MenuMetrics.headerHeight)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    serviceSection

                    if !advisoryService.topics.isEmpty {
                        Divider()
                        advisorySection
                    }
                }
            }
            // While the panel animates to a new height the content briefly overflows,
            // so base the indicator on the calculated height instead of the live one.
            // Expanded lists opt back in; this also applies to nested scroll views.
            .scrollIndicators(contentHeight > MenuMetrics.maxScrollHeight ? .automatic : .never)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(contentHeight, MenuMetrics.maxScrollHeight))

            Divider()

            // Footer
            HStack {
                if let lastUpdated = pollingService.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Refresh") {
                    Task { await pollingService.refresh() }
                    Task { await advisoryService.refresh() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .frame(height: MenuMetrics.footerRowHeight)

            Divider()

            HStack {
                Button("Settings...") {
                    openWindow(id: "settings")
                    // onAppear doesn't run when the window is already open, and a
                    // menu bar app isn't active by default, so bring it forward here
                    NSApp.activate()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.primary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .frame(height: MenuMetrics.footerRowHeight)
        }
        .frame(width: 340, height: panelHeight)
        .background(PanelHeightSetter(height: panelHeight))
    }

    /// Total height of the panel: the pinned rows plus the scrolling content.
    private var panelHeight: CGFloat {
        var height = MenuMetrics.headerHeight
            + MenuMetrics.footerRowHeight * 2
            + MenuMetrics.dividerHeight * 3
            + min(contentHeight, MenuMetrics.maxScrollHeight)
        if updateService.availableRelease != nil {
            height += MenuMetrics.updateBannerHeight + MenuMetrics.dividerHeight
        }
        return height
    }

    /// Height of the scrolling content, calculated from the fixed row heights.
    private var contentHeight: CGFloat {
        var height = serviceSectionHeight
        if !advisoryService.topics.isEmpty {
            height += MenuMetrics.dividerHeight + advisorySectionHeight
        }
        return height
    }

    private var serviceSectionHeight: CGFloat {
        let results = pollingService.results
        guard !results.isEmpty else { return Self.loadingHeight }
        let rows = results.reduce(0) { total, result in
            total + ServiceRowView.height(for: result, isExpanded: expandedIDs.contains(result.id))
        }
        return rows
            + CGFloat(results.count - 1) * MenuMetrics.dividerHeight
            + MenuMetrics.listVerticalPadding * 2
    }

    private var advisorySectionHeight: CGFloat {
        let results = advisoryService.results
        guard !results.isEmpty else { return MenuMetrics.sectionHeaderHeight + Self.loadingAdvisoriesHeight }
        let rows = results.reduce(0) { total, result in
            total + AdvisoryTopicRowView.height(for: result, isExpanded: expandedIDs.contains(result.id))
        }
        return MenuMetrics.sectionHeaderHeight
            + rows
            + CGFloat(results.count - 1) * MenuMetrics.dividerHeight
            + MenuMetrics.listVerticalPadding
    }

    private static let loadingHeight: CGFloat = 96
    private static let loadingAdvisoriesHeight: CGFloat = 40

    private func isExpanded(_ id: UUID) -> Binding<Bool> {
        Binding {
            expandedIDs.contains(id)
        } set: { expanded in
            if expanded {
                expandedIDs.insert(id)
            } else {
                expandedIDs.remove(id)
            }
        }
    }

    @ViewBuilder
    private var serviceSection: some View {
        if pollingService.results.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading status...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.loadingHeight)
        } else {
            VStack(spacing: 0) {
                ForEach(pollingService.results) { result in
                    ServiceRowView(result: result, isExpanded: isExpanded(result.id))
                    if result.id != pollingService.results.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, MenuMetrics.listVerticalPadding)
        }
    }

    private var advisorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Security Advisories")
                    .font(.headline)
                Spacer()
                if advisoryService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: MenuMetrics.sectionHeaderHeight)

            if advisoryService.results.isEmpty {
                Text("Loading advisories...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.loadingAdvisoriesHeight)
            } else {
                VStack(spacing: 0) {
                    ForEach(advisoryService.results) { result in
                        AdvisoryTopicRowView(result: result, isExpanded: isExpanded(result.id))
                        if result.id != advisoryService.results.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, MenuMetrics.listVerticalPadding)
            }
        }
    }
}
