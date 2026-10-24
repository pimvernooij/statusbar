import Foundation

enum AdvisorySeverity: String, Codable, CaseIterable, Comparable, Sendable {
    case high
    case critical

    var label: String {
        switch self {
        case .high: "High"
        case .critical: "Critical"
        }
    }

    private var rank: Int {
        switch self {
        case .high: 0
        case .critical: 1
        }
    }

    static func < (lhs: AdvisorySeverity, rhs: AdvisorySeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct Advisory: Identifiable, Sendable {
    /// GHSA identifier, e.g. `GHSA-673q-mjm6-r5xr`.
    let id: String
    let cveID: String?
    let summary: String
    let severity: AdvisorySeverity
    let packages: [String]
    let publishedAt: Date
    let url: URL?

    /// CVE identifier when assigned, otherwise the GHSA identifier.
    var displayID: String {
        cveID ?? id
    }

    init?(_ advisory: GitHubAdvisory) {
        guard advisory.withdrawnAt == nil,
              let severity = AdvisorySeverity(rawValue: advisory.severity)
        else { return nil }

        let names = (advisory.vulnerabilities ?? []).compactMap { $0.package?.name }
        var seen = Set<String>()

        self.id = advisory.ghsaId
        self.cveID = advisory.cveId
        self.summary = advisory.summary
        self.severity = severity
        self.packages = names.filter { seen.insert($0).inserted }
        self.publishedAt = advisory.publishedAt
        self.url = URL(string: advisory.htmlUrl)
    }
}

struct AdvisoryTopicResult: Identifiable, Sendable {
    let id: UUID
    let topic: AdvisoryTopic
    /// High and critical advisories, newest first.
    let advisories: [Advisory]
    let error: String?

    var highestSeverity: AdvisorySeverity? {
        advisories.map(\.severity).max()
    }

    func count(of severity: AdvisorySeverity) -> Int {
        advisories.filter { $0.severity == severity }.count
    }

    static func error(topic: AdvisoryTopic, message: String) -> AdvisoryTopicResult {
        AdvisoryTopicResult(id: topic.id, topic: topic, advisories: [], error: message)
    }
}
