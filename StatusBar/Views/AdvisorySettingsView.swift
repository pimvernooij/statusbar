import SwiftUI

/// "Advisories" tab of the settings window.
struct AdvisorySettingsView: View {
    @Bindable var advisoryService: AdvisoryPollingService
    @Environment(\.colorScheme) private var colorScheme

    @State private var newEcosystem: AdvisoryEcosystem = .npm
    @State private var newPackages = ""

    private let intervalOptions: [(label: String, value: TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("1 hour", 3600),
    ]

    /// Adaptive overlay color: white in dark mode, black in light mode
    private var overlay: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Followed Topics")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(advisoryService.topics) { topic in
                        topicRow(topic)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            addTopicForm
            optionsSection
        }
    }

    // MARK: - Topic Row

    private func topicRow(_ topic: AdvisoryTopic) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.name)
                    .font(.body.weight(.medium))
                Text(topic.ecosystem.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(AdvisorySeverity.allCases.reversed(), id: \.self) { severity in
                severityToggle(severity, topic: topic)
            }
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    advisoryService.topics.removeAll { $0.id == topic.id }
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

    /// Chip that toggles a followed severity; the last enabled severity can't be turned off.
    private func severityToggle(_ severity: AdvisorySeverity, topic: AdvisoryTopic) -> some View {
        let isOn = topic.severities.contains(severity)
        let isLocked = isOn && topic.severities.count == 1
        return Button {
            guard let index = advisoryService.topics.firstIndex(where: { $0.id == topic.id }) else { return }
            if isOn {
                advisoryService.topics[index].severities.remove(severity)
            } else {
                advisoryService.topics[index].severities.insert(severity)
            }
        } label: {
            Text(severity.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isOn ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? AdvisoryStyle.color(for: severity) : overlay.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .help(isLocked ? "At least one severity must be followed" : "Follow \(severity.label.lowercased()) advisories")
    }

    // MARK: - Add Topic Form

    private var addTopicForm: some View {
        HStack(spacing: 8) {
            Picker("", selection: $newEcosystem) {
                ForEach(AdvisoryEcosystem.allCases, id: \.self) { ecosystem in
                    Text(ecosystem.displayName).tag(ecosystem)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            TextField("Packages, comma separated (empty = all)", text: $newPackages)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(overlay.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit(addTopic)

            Button(action: addTopic) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .frame(width: 30, height: 26)
                    .background(overlay.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(overlay.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Check every")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $advisoryService.refreshInterval) {
                    ForEach(intervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            HStack {
                Toggle("Prioritized notifications", isOn: $advisoryService.notificationsEnabled)
                    .font(.subheadline)
                Spacer()
                Button("Send Test") {
                    advisoryService.sendTestNotification()
                }
                .font(.caption)
            }

            Text("To receive these during Focus or Do Not Disturb, add StatusBar to the allowed apps of your Focus in System Settings › Focus.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func addTopic() {
        let packages = newPackages
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let topic = AdvisoryTopic(ecosystem: newEcosystem, packages: packages)
        guard !advisoryService.topics.contains(where: {
            $0.ecosystem == topic.ecosystem && Set($0.packages) == Set(topic.packages)
        }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            advisoryService.topics.append(topic)
            newPackages = ""
        }
    }
}
