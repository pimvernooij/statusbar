import Foundation
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class GlobalIncidentService {
    /// Identifies the Global incidents row in the dropdown's expansion state.
    static let rowID = UUID()

    private(set) var incidents: [GlobalIncident] = []
    private(set) var error: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsEnabledKey) }
    }

    var attentionCount: Int {
        incidents.filter(\.needsAttention).count
    }

    private let client = GlobalIncidentClient()
    private var pollingTask: Task<Void, Never>?
    /// Briefing IDs already seen, with their publish date for pruning. The first
    /// successful fetch only records them, so existing briefings don't notify.
    private var seenIncidents: [String: Date]
    private var isSeeded: Bool

    private static let notificationsEnabledKey = "globalIncidentNotificationsEnabled"
    private static let seenIncidentsKey = "seenGlobalIncidents"
    private static let isSeededKey = "globalIncidentsSeeded"
    private static let checkInterval: TimeInterval = 1800
    private static let seenRetention: TimeInterval = 90 * 86_400

    init() {
        let defaults = UserDefaults.standard
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
        self.seenIncidents = defaults.data(forKey: Self.seenIncidentsKey)
            .flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
        self.isSeeded = defaults.bool(forKey: Self.isSeededKey)
        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                do {
                    try await Task.sleep(for: .seconds(Self.checkInterval))
                } catch {
                    break
                }
            }
        }
    }

    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let fetched = try await client.fetchIncidents()
            processNew(fetched)
            incidents = fetched
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Notifications

    private func processNew(_ fetched: [GlobalIncident]) {
        let unseen = fetched.filter { seenIncidents[$0.id] == nil }
        for incident in fetched {
            seenIncidents[incident.id] = incident.publishedAt
        }

        if isSeeded && notificationsEnabled {
            unseen.filter(\.needsAttention).forEach(notify)
        }
        isSeeded = true

        let cutoff = Date.now.addingTimeInterval(-Self.seenRetention)
        seenIncidents = seenIncidents.filter { $0.value > cutoff }
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(seenIncidents) {
            defaults.set(data, forKey: Self.seenIncidentsKey)
        }
        defaults.set(true, forKey: Self.isSeededKey)
    }

    /// Delivered as Time Sensitive, like advisories, so it can break through Focus.
    private func notify(_ incident: GlobalIncident) {
        let content = UNMutableNotificationContent()
        content.title = incident.title
        content.subtitle = "Global incident · \(incident.category)"
        content.body = incident.summary
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.threadIdentifier = "global-incidents"
        if let url = incident.url {
            content.userInfo = ["url": url.absoluteString]
        }

        let request = UNNotificationRequest(identifier: incident.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
