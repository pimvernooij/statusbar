import Foundation

// MARK: - GitHub Releases API Models

/// Response of `GET https://api.github.com/repos/{owner}/{repo}/releases/latest`.
struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let htmlUrl: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Codable, Sendable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

/// A published release newer than the running app.
struct AppRelease: Equatable, Sendable {
    let version: AppVersion
    let notesURL: URL
    let downloadURL: URL
}
