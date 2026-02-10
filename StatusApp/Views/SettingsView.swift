import SwiftUI

struct SettingsView: View {
    @Bindable var pollingService: StatusPollingService

    @State private var newServiceName = ""
    @State private var newServiceDomain = ""

    private let intervalOptions: [(label: String, value: TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
    ]

    var body: some View {
        TabView {
            servicesTab
                .tabItem {
                    Label("Services", systemImage: "list.bullet")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 480, height: 360)
    }

    // MARK: - Services Tab

    private var servicesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitored Services")
                .font(.headline)

            List {
                ForEach(pollingService.services) { service in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .font(.body.weight(.medium))
                            Text(service.domain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            pollingService.services.removeAll { $0.id == service.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.bordered)

            // Add new service form
            GroupBox("Add Service") {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Name", text: $newServiceName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Domain (e.g. status.example.com)", text: $newServiceDomain)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Spacer()
                        Button("Add") {
                            addService()
                        }
                        .disabled(newServiceName.isEmpty || newServiceDomain.isEmpty)
                    }
                }
                .padding(4)
            }
        }
        .padding()
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Refresh Interval")
                .font(.headline)

            Picker("Check status every:", selection: $pollingService.refreshInterval) {
                ForEach(intervalOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.radioGroup)

            Spacer()
        }
        .padding()
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
            domain: domain
        )
        pollingService.services.append(service)
        newServiceName = ""
        newServiceDomain = ""
    }
}
