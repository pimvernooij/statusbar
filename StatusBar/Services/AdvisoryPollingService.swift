import Foundation
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class AdvisoryPollingService {
    private(set) var results: [AdvisoryTopicResult] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?

    var topics: [AdvisoryTopic] {
        didSet { saveTopics(oldValue: oldValue) }
    }

    var refreshInterval: TimeInterval {
        didSet { saveRefreshInterval() }
    }

    var notificationsEnabled: Bool {
        didSet { saveNotificationsEnabled() }
    }

    private let client = AdvisoryClient()
    private var pollingTask: Task<Void, Never>?

    /// Advisory IDs already shown to the user, with their publish date for pruning.
    private var seenAdvisories: [String: Date]
    /// Topics whose current advisories have been recorded as seen. The first successful
    /// fetch of a topic seeds the seen set without notifying, so adding a topic doesn't
    /// flood the user with a week of history.
    private var seededTopicIDs: Set<UUID>

    private static let topicsKey = "advisoryTopics"
    private static let intervalKey = "advisoryRefreshInterval"
    private static let notificationsEnabledKey = "advisoryNotificationsEnabled"
    private static let seenAdvisoriesKey = "seenAdvisories"
    private static let seededTopicIDsKey = "seededAdvisoryTopicIDs"
    private static let defaultInterval: TimeInterval = 1800
    /// Seen IDs older than this are dropped; they can no longer appear in the lookback window.
    private static let seenRetention: TimeInterval = 30 * 86_400
    /// Above this many new advisories for one topic, send a single summary notification.
    private static let maxIndividualNotifications = 3

    init() {
        let topics = Self.loadTopics()
        self.topics = topics
        self.refreshInterval = Self.loadRefreshInterval()
        self.notificationsEnabled = Self.loadNotificationsEnabled()
        self.seenAdvisories = Self.loadSeenAdvisories()
        self.seededTopicIDs = Self.loadSeededTopicIDs().intersection(topics.map(\.id))
        // Persist the defaults on first launch so topic IDs stay stable across
        // launches; seeding is tracked per topic ID.
        if UserDefaults.standard.data(forKey: Self.topicsKey) == nil,
           let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: Self.topicsKey)
        }
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
        let currentTopics = topics
        var partials: [UUID: AdvisoryTopicResult] = [:]

        await withTaskGroup(of: AdvisoryTopicResult.self) { group in
            for topic in currentTopics {
                group.addTask { [client] in
                    await client.fetchAdvisories(for: topic)
                }
            }

            for await result in group {
                partials[result.id] = result
                results = currentTopics.compactMap { partials[$0.id] }
            }
        }

        let fetchedResults = currentTopics.compactMap { partials[$0.id] }
        processNewAdvisories(in: fetchedResults)
        results = fetchedResults
        lastUpdated = Date()
        isLoading = false
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Critical · npm: next"
        content.subtitle = "Test advisory"
        content.body = "Prioritized advisory notifications are working."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1

        let request = UNNotificationRequest(
            identifier: "test-advisory-notification",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Notifications

    private func processNewAdvisories(in results: [AdvisoryTopicResult]) {
        for result in results where result.error == nil {
            let unseen = result.advisories.filter { seenAdvisories[$0.id] == nil }
            for advisory in result.advisories {
                seenAdvisories[advisory.id] = advisory.publishedAt
            }

            guard seededTopicIDs.contains(result.topic.id) else {
                seededTopicIDs.insert(result.topic.id)
                continue
            }

            if notificationsEnabled && !unseen.isEmpty {
                notify(unseen, topic: result.topic)
            }
        }

        let cutoff = Date.now.addingTimeInterval(-Self.seenRetention)
        seenAdvisories = seenAdvisories.filter { $0.value > cutoff }
        saveSeenState()
    }

    private func notify(_ advisories: [Advisory], topic: AdvisoryTopic) {
        if advisories.count > Self.maxIndividualNotifications {
            let critical = advisories.filter { $0.severity == .critical }.count
            let content = Self.prioritizedContent(severity: critical > 0 ? .critical : .high)
            content.title = "\(advisories.count) new advisories · \(topic.ecosystem.displayName)"
            content.subtitle = topic.name
            content.body = critical > 0
                ? "\(critical) critical, \(advisories.count - critical) high"
                : "\(advisories.count) high severity"
            if let url = topic.webURL {
                content.userInfo = ["url": url.absoluteString]
            }
            add(content, identifier: "advisories-\(topic.id.uuidString)")
            return
        }

        for advisory in advisories {
            let content = Self.prioritizedContent(severity: advisory.severity)
            let packages = advisory.packages.isEmpty ? topic.name : advisory.packages.joined(separator: ", ")
            content.title = "\(advisory.severity.label) · \(topic.ecosystem.displayName): \(packages)"
            content.subtitle = advisory.displayID
            content.body = advisory.summary
            if let url = advisory.url {
                content.userInfo = ["url": url.absoluteString]
            }
            add(content, identifier: advisory.id)
        }
    }

    /// High and critical advisories are delivered as Time Sensitive so they can break
    /// through Focus. This needs the time-sensitive entitlement; without it macOS
    /// delivers them as regular notifications unless the app is allowed in the Focus.
    private static func prioritizedContent(severity: AdvisorySeverity) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = severity == .critical ? 1 : 0.8
        content.threadIdentifier = "advisories"
        return content
    }

    private func add(_ content: UNNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private func saveTopics(oldValue: [AdvisoryTopic]) {
        guard let data = try? JSONEncoder().encode(topics) else { return }
        UserDefaults.standard.set(data, forKey: Self.topicsKey)
        let topicIDs = Set(topics.map(\.id))
        seededTopicIDs.formIntersection(topicIDs)
        // A topic whose filter changed (e.g. a severity was enabled) is seeded again,
        // so advisories that newly match aren't reported as new.
        let previous = Dictionary(uniqueKeysWithValues: oldValue.map { ($0.id, $0) })
        for topic in topics where previous[topic.id].map({ $0 != topic }) ?? false {
            seededTopicIDs.remove(topic.id)
        }
        results.removeAll { !topicIDs.contains($0.id) }
        saveSeenState()
        // Re-fetch when topics change
        Task { await refresh() }
    }

    private func saveRefreshInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: Self.intervalKey)
        startPolling()
    }

    private func saveNotificationsEnabled() {
        UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
    }

    private func saveSeenState() {
        if let data = try? JSONEncoder().encode(seenAdvisories) {
            UserDefaults.standard.set(data, forKey: Self.seenAdvisoriesKey)
        }
        UserDefaults.standard.set(seededTopicIDs.map(\.uuidString), forKey: Self.seededTopicIDsKey)
    }

    private static func loadTopics() -> [AdvisoryTopic] {
        guard let data = UserDefaults.standard.data(forKey: topicsKey),
              let topics = try? JSONDecoder().decode([AdvisoryTopic].self, from: data)
        else {
            return AdvisoryTopic.defaults
        }
        return topics
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

    private static func loadSeenAdvisories() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: seenAdvisoriesKey),
              let seen = try? JSONDecoder().decode([String: Date].self, from: data)
        else {
            return [:]
        }
        return seen
    }

    private static func loadSeededTopicIDs() -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: seededTopicIDsKey) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }
}
