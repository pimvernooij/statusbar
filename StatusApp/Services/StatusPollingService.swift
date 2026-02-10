import Foundation
import SwiftUI

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

    var worstStatus: OverallStatus {
        guard !results.isEmpty else { return .unknown }
        return results.map(\.status).max() ?? .unknown
    }

    private let client = StatusPageClient()
    private var pollingTask: Task<Void, Never>?

    private static let servicesKey = "monitoredServices"
    private static let intervalKey = "refreshInterval"
    private static let defaultInterval: TimeInterval = 120

    init() {
        self.services = Self.loadServices()
        self.refreshInterval = Self.loadRefreshInterval()
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
            results = fetchedResults
            lastUpdated = Date()
        }
        isLoading = false
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
}
