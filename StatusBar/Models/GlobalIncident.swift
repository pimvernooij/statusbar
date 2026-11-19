import Foundation

/// A briefing on a large, widespread incident from Cloudflare Radar's Zero Wire feed.
struct GlobalIncident: Identifiable, Sendable {
    /// The briefing's link. The feed's `guid` includes a date (`node2shell@2026-10-25`),
    /// so it might change when Cloudflare updates a briefing; the link doesn't.
    let id: String
    let title: String
    let summary: String
    /// Feed categories, such as affected technologies and vulnerability types.
    let tags: [String]
    let publishedAt: Date
    let url: URL?

    /// Briefings published within this many days count as recent.
    static let recentDays = 7

    /// The feed has no urgency field, so recency decides what is highlighted
    /// and notified: every briefing covers an urgent, widespread threat.
    var isRecent: Bool {
        publishedAt >= Date.now.addingTimeInterval(-Double(Self.recentDays) * 86_400)
    }

    /// The recommended action, which each summary starts with, e.g. "Prioritize patching."
    var action: String {
        guard let end = summary.firstIndex(of: ".") else { return summary }
        return String(summary[...end])
    }
}
