import AppKit
import Foundation

@MainActor
@Observable
final class UpdateService {
    enum InstallState: Equatable {
        case idle
        case installing
        case failed(String)
    }

    private(set) var availableRelease: AppRelease?
    private(set) var installState: InstallState = .idle
    private(set) var isChecking = false
    private(set) var lastChecked: Date?
    private(set) var checkError: String?

    let currentVersion = AppVersion.current

    private var pollingTask: Task<Void, Never>?

    private static let checkInterval: TimeInterval = 6 * 3600

    init() {
        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await checkForUpdates()
                do {
                    try await Task.sleep(for: .seconds(Self.checkInterval))
                } catch {
                    break
                }
            }
        }
    }

    func checkForUpdates() async {
        guard let currentVersion, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            availableRelease = try await AppUpdater.fetchNewerRelease(than: currentVersion)
            checkError = nil
        } catch {
            checkError = error.localizedDescription
        }
        lastChecked = Date()
    }

    func installUpdate() async {
        guard let release = availableRelease, installState != .installing,
              let bundleIdentifier = Bundle.main.bundleIdentifier
        else { return }

        installState = .installing
        let appURL = Bundle.main.bundleURL
        do {
            try await AppUpdater.install(release, replacing: appURL, bundleIdentifier: bundleIdentifier)
            try AppUpdater.relaunch(appURL: appURL)
            NSApplication.shared.terminate(nil)
        } catch {
            installState = .failed(error.localizedDescription)
        }
    }
}
