import Foundation

/// A briefing on a large, widespread incident from Cloudflare Radar's Zero Wire feed.
struct GlobalIncident: Identifiable, Sendable {
    /// The briefing's link. The feed's `guid` includes a date (`node2shell@2026-10-25`),
    /// so it might change when Cloudflare updates a briefing; the link doesn't.
    let id: String
    let title: String
    let summary: String
    /// Status of the briefing: "Needs attention" or "Reference".
    let category: String
    /// Remaining feed categories, such as CVE IDs and affected technologies.
    let tags: [String]
    let publishedAt: Date
    let url: URL?

    var needsAttention: Bool {
        category.caseInsensitiveCompare("Needs attention") == .orderedSame
    }

    /// The recommended action, which each summary starts with, e.g. "Prioritize patching."
    var action: String {
        guard let end = summary.firstIndex(of: ".") else { return summary }
        return String(summary[...end])
    }
}
