import Foundation
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class StatusPollingService {
    private(set) var results: [ServiceResult] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?

    var services: [MonitoredService] {
        didSet { saveServices() }
    }

    var refreshInterval: TimeInterval {
        didSet { saveRefreshInterval() }
    }

    var notificationsEnabled: Bool {
        didSet { saveNotificationsEnabled() }
    }

    var worstStatus: OverallStatus {
        guard !results.isEmpty else { return .unknown }
        return results.map(\.status).max() ?? .unknown
    }

    private let client = StatusClient()
    private var pollingTask: Task<Void, Never>?

    private static let servicesKey = "monitoredServices"
    private static let intervalKey = "refreshInterval"
    private static let notificationsEnabledKey = "notificationsEnabled"
    private static let defaultInterval: TimeInterval = 120

    init() {
        self.services = Self.loadServices()
        self.refreshInterval = Self.loadRefreshInterval()
        self.notificationsEnabled = Self.loadNotificationsEnabled()
        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                do {
                    try await Task.sleep(for: .seconds(refreshInterval))
                } catch {
                    break
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        isLoading = true
        let fetchedResults = await client.fetchAll(services: services)
        if !Task.isCancelled {
            notifyStatusChanges(old: results, new: fetchedResults)
            results = fetchedResults
            lastUpdated = Date()
        }
        isLoading = false
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "StatusBar"
        content.body = "Notifications are working!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notifyStatusChanges(old: [ServiceResult], new: [ServiceResult]) {
        guard notificationsEnabled else { return }
        guard !old.isEmpty else { return }

        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.service.id, $0) })

        for result in new {
            guard let previous = oldByID[result.service.id] else { continue }
            guard result.status != previous.status else { continue }

            let content = UNMutableNotificationContent()
            content.title = result.service.name
            content.sound = .default

            if result.status == .operational {
                content.body = "All Systems Operational"
            } else {
                let affected = result.visibleComponents
                    .filter { $0.status != .operational }
                    .map { "\($0.name): \($0.status.description)" }
                content.body = affected.isEmpty
                    ? result.statusDescription
                    : affected.joined(separator: ", ")
            }

            let request = UNNotificationRequest(
                identifier: result.service.id.uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Persistence

    private func saveServices() {
        guard let data = try? JSONEncoder().encode(services) else { return }
        UserDefaults.standard.set(data, forKey: Self.servicesKey)
        // Re-fetch when services change
        Task { await refresh() }
    }

    private func saveRefreshInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: Self.intervalKey)
        startPolling()
    }

    private func saveNotificationsEnabled() {
        UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
    }

    private static func loadServices() -> [MonitoredService] {
        guard let data = UserDefaults.standard.data(forKey: servicesKey),
              let services = try? JSONDecoder().decode([MonitoredService].self, from: data),
              !services.isEmpty
        else {
            return MonitoredService.defaults
        }
        return services
    }

    private static func loadRefreshInterval() -> TimeInterval {
        let interval = UserDefaults.standard.double(forKey: intervalKey)
        return interval > 0 ? interval : defaultInterval
    }

    private static func loadNotificationsEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: notificationsEnabledKey)
    }
}
