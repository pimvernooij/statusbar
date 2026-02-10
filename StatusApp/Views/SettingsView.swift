import SwiftUI
import AppKit

// MARK: - Translucent Background

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Settings View

struct SettingsView: View {
    @Bindable var pollingService: StatusPollingService
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0
    @State private var newServiceName = ""
    @State private var newServiceDomain = ""
    @State private var newServiceProvider: ServiceProvider = .statusPage

    private let intervalOptions: [(label: String, value: TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
    ]

    /// Adaptive overlay color: white in dark mode, black in light mode
    private var overlay: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 2) {
                tabButton("Services", icon: "list.bullet", index: 0)
                tabButton("General", icon: "gear", index: 1)
            }
            .padding(3)
            .background(overlay.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tab content
            Group {
                if selectedTab == 0 {
                    servicesTab
                } else {
                    generalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(width: 500, height: 400)
        .background(VisualEffectBackground())
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(selectedTab == index ? overlay.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == index ? .primary : .secondary)
    }

    // MARK: - Services Tab

    private var servicesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitored Services")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Service list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(pollingService.services) { service in
                        serviceRow(service)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            addServiceForm
        }
    }

    // MARK: - Add Service Form

    private var addServiceForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Service")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                // Row 1: Name + Provider
                HStack(spacing: 8) {
                    formField("Name", text: $newServiceName)
                        .frame(maxWidth: .infinity)

                    Picker("", selection: $newServiceProvider) {
                        Text("StatusPage").tag(ServiceProvider.statusPage)
                        Text("incident.io").tag(ServiceProvider.incidentIO)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                // Row 2: Domain + Add button
                HStack(spacing: 8) {
                    formField("Domain (e.g. status.example.com)", text: $newServiceDomain)

                    Button {
                        addService()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.medium))
                            .frame(width: 30, height: 26)
                            .background(overlay.opacity(newServiceName.isEmpty || newServiceDomain.isEmpty ? 0.04 : 0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(newServiceName.isEmpty || newServiceDomain.isEmpty)
                    .opacity(newServiceName.isEmpty || newServiceDomain.isEmpty ? 0.35 : 1)
                }
            }
            .padding(10)
            .background(overlay.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(overlay.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Service Row

    private func serviceRow(_ service: MonitoredService) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(service.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(service.provider == .statusPage ? "StatusPage" : "incident.io")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pollingService.services.removeAll { $0.id == service.id }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(6)
                    .background(overlay.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(overlay.opacity(0.05))
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refresh Interval")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                ForEach(intervalOptions, id: \.value) { option in
                    intervalRow(option)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
    }

    private func intervalRow(_ option: (label: String, value: TimeInterval)) -> some View {
        Button {
            pollingService.refreshInterval = option.value
        } label: {
            HStack {
                Text(option.label)
                    .font(.body)
                Spacer()
                if pollingService.refreshInterval == option.value {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(pollingService.refreshInterval == option.value ? overlay.opacity(0.08) : overlay.opacity(0.04))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addService() {
        let domain = newServiceDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let service = MonitoredService(
            id: UUID(),
            name: newServiceName.trimmingCharacters(in: .whitespaces),
            domain: domain,
            provider: newServiceProvider
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            pollingService.services.append(service)
        }
        newServiceName = ""
        newServiceDomain = ""
        newServiceProvider = .statusPage
    }
}
