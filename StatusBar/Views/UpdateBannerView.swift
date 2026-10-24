import SwiftUI

/// Shown at the top of the dropdown when a newer release is available.
struct UpdateBannerView: View {
    let updateService: UpdateService
    let release: AppRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Text("Version \(release.version.description) available")
                    .font(.subheadline.weight(.medium))
                Spacer()
                actionButton
            }

            HStack(spacing: 8) {
                Button("Release notes") {
                    NSWorkspace.shared.open(release.notesURL)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)

                if case .failed(let message) = updateService.installState {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch updateService.installState {
        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failed:
            Button("Download") {
                NSWorkspace.shared.open(release.notesURL)
            }
            .controlSize(.small)
        case .idle:
            Button("Update") {
                Task { await updateService.installUpdate() }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        }
    }
}
