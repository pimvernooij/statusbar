import Foundation

/// Package ecosystems supported by the GitHub Advisory Database.
/// Raw values match the `ecosystem` query parameter of the REST API.
enum AdvisoryEcosystem: String, Codable, CaseIterable, Sendable {
    case npm
    case pip
    case composer
    case go
    case maven
    case nuget
    case rubygems
    case rust
    case pub
    case swift
    case erlang
    case actions
    case other

    var displayName: String {
        switch self {
        case .npm: "npm"
        case .pip: "pip"
        case .composer: "Composer"
        case .go: "Go"
        case .maven: "Maven"
        case .nuget: "NuGet"
        case .rubygems: "RubyGems"
        case .rust: "Rust"
        case .pub: "Pub"
        case .swift: "Swift"
        case .erlang: "Erlang"
        case .actions: "GitHub Actions"
        case .other: "Other"
        }
    }
}

/// A followed topic: an ecosystem, optionally narrowed to specific packages,
/// filtered to the severities the user follows.
struct AdvisoryTopic: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var ecosystem: AdvisoryEcosystem
    var packages: [String]
    var severities: Set<AdvisorySeverity>

    init(
        id: UUID = UUID(),
        ecosystem: AdvisoryEcosystem,
        packages: [String] = [],
        severities: Set<AdvisorySeverity> = Set(AdvisorySeverity.allCases)
    ) {
        self.id = id
        self.ecosystem = ecosystem
        self.packages = packages
        self.severities = severities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.ecosystem = try container.decode(AdvisoryEcosystem.self, forKey: .ecosystem)
        self.packages = try container.decode([String].self, forKey: .packages)
        // Topics saved before severities were configurable follow all of them
        self.severities = try container.decodeIfPresent(Set<AdvisorySeverity>.self, forKey: .severities)
            ?? Set(AdvisorySeverity.allCases)
    }

    var name: String {
        packages.isEmpty ? "All \(ecosystem.displayName) packages" : packages.joined(separator: ", ")
    }

    /// Followed severities, e.g. "high or critical".
    var severityDescription: String {
        severities.sorted().map { $0.label.lowercased() }.joined(separator: " or ")
    }

    /// Advisory search on github.com for this topic.
    var webURL: URL? {
        var terms = ["type:reviewed", "ecosystem:\(ecosystem.rawValue)"]
        terms += packages.map { "affects:\($0)" }
        var components = URLComponents(string: "https://github.com/advisories")
        components?.queryItems = [URLQueryItem(name: "query", value: terms.joined(separator: " "))]
        return components?.url
    }

    static let defaults: [AdvisoryTopic] = [
        AdvisoryTopic(ecosystem: .npm, packages: ["next", "react"]),
    ]
}
