import Foundation

enum AppUpdaterError: LocalizedError {
    case invalidResponse
    case http(Int)
    case noDownload
    case extractionFailed
    case appNotFound
    case wrongApp(String)
    case wrongVersion(expected: AppVersion, found: String)
    case notWritable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from GitHub"
        case .http(let code):
            "HTTP \(code)"
        case .noDownload:
            "The release has no app download"
        case .extractionFailed:
            "Could not unpack the download"
        case .appNotFound:
            "The download doesn't contain StatusBar.app"
        case .wrongApp(let identifier):
            "The download contains a different app (\(identifier))"
        case .wrongVersion(let expected, let found):
            "Expected version \(expected), the download contains \(found)"
        case .notWritable(let path):
            "No permission to replace \(path)"
        }
    }
}

/// Checks GitHub Releases for a newer version and replaces the running app bundle.
///
/// The app is ad-hoc signed, so there is no signature to verify; the download is only
/// accepted when its bundle identifier and version match. Downloads made with
/// URLSession don't get the quarantine attribute, so the updated app launches
/// without a Gatekeeper prompt.
enum AppUpdater {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/pimvernooij/statusbar/releases/latest")

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    /// Returns the latest release when it is newer than `currentVersion`.
    static func fetchNewerRelease(than currentVersion: AppVersion) async throws -> AppRelease? {
        guard let url = latestReleaseURL else { throw AppUpdaterError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdaterError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppUpdaterError.http(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let version = AppVersion(release.tagName), version > currentVersion else { return nil }

        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let downloadURL = URL(string: asset.browserDownloadUrl),
              let notesURL = URL(string: release.htmlUrl)
        else {
            throw AppUpdaterError.noDownload
        }

        return AppRelease(version: version, notesURL: notesURL, downloadURL: downloadURL)
    }

    /// Downloads `release`, verifies it and replaces the app bundle at `appURL`.
    static func install(_ release: AppRelease, replacing appURL: URL, bundleIdentifier: String) async throws {
        let fileManager = FileManager.default
        guard fileManager.isWritableFile(atPath: appURL.deletingLastPathComponent().path),
              fileManager.isWritableFile(atPath: appURL.path)
        else {
            throw AppUpdaterError.notWritable(appURL.path)
        }

        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("StatusBarUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        let (downloadedURL, response) = try await session.download(from: release.downloadURL)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw AppUpdaterError.http(httpResponse.statusCode)
        }

        let zipURL = workDirectory.appendingPathComponent("update.zip")
        try fileManager.moveItem(at: downloadedURL, to: zipURL)

        let extractedURL = workDirectory.appendingPathComponent("extracted", isDirectory: true)
        guard try await run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractedURL.path]) == 0 else {
            throw AppUpdaterError.extractionFailed
        }

        let newAppURL = try verifiedApp(in: extractedURL, release: release, bundleIdentifier: bundleIdentifier)
        // Belt and braces: never carry a quarantine flag over to the installed app
        _ = try await run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newAppURL.path])

        _ = try fileManager.replaceItemAt(appURL, withItemAt: newAppURL)
    }

    /// Starts a fresh copy of the app at `appURL` once the current process has exited.
    static func relaunch(appURL: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
            appURL.path,
        ]
        try process.run()
    }

    private static func verifiedApp(in directory: URL, release: AppRelease, bundleIdentifier: String) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }),
              let bundle = Bundle(url: appURL)
        else {
            throw AppUpdaterError.appNotFound
        }

        guard bundle.bundleIdentifier == bundleIdentifier else {
            throw AppUpdaterError.wrongApp(bundle.bundleIdentifier ?? "unknown")
        }

        let foundVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        guard AppVersion(foundVersion) == release.version else {
            throw AppUpdaterError.wrongVersion(expected: release.version, found: foundVersion)
        }

        return appURL
    }

    private static func run(_ executable: String, _ arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
