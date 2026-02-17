import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StatusMenuView: View {
    let pollingService: StatusPollingService
    @Environment(\.openWindow) private var openWindow
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Service list
            if pollingService.results.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading status...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                let maxHeight = (NSScreen.main?.visibleFrame.height ?? 800) - 120
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(pollingService.results) { result in
                            ServiceRowView(result: result)
                            if result.id != pollingService.results.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    })
                }
                .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            }

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
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            HStack {
                Button("Settings...") {
                    openWindow(id: "settings")
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
            .padding(.vertical, 8)
        }
        .frame(width: 340)
    }
}
