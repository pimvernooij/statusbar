import Foundation

// MARK: - GitHub Advisory Database API Models

/// An entry from `GET https://api.github.com/advisories`.
struct GitHubAdvisory: Codable, Sendable {
    let ghsaId: String
    let cveId: String?
    let htmlUrl: String
    let summary: String
    let severity: String
    let publishedAt: Date
    let withdrawnAt: Date?
    let vulnerabilities: [GitHubAdvisoryVulnerability]?

    enum CodingKeys: String, CodingKey {
        case ghsaId = "ghsa_id"
        case cveId = "cve_id"
        case htmlUrl = "html_url"
        case summary
        case severity
        case publishedAt = "published_at"
        case withdrawnAt = "withdrawn_at"
        case vulnerabilities
    }
}

struct GitHubAdvisoryVulnerability: Codable, Sendable {
    let package: GitHubAdvisoryPackage?
}

struct GitHubAdvisoryPackage: Codable, Sendable {
    let ecosystem: String
    let name: String
}
