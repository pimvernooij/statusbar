import SwiftUI

struct StatusMenuView: View {
    let pollingService: StatusPollingService

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
                }
                .frame(maxHeight: 400)
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
                SettingsLink {
                    Text("Settings...")
                        .font(.caption)
                }
                .buttonStyle(.plain)
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
