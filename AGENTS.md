# AGENTS.md - StatusBar Development Guide

## Project Overview

StatusBar is a macOS menu bar application with two functions: it monitors cloud service status pages (Atlassian StatusPage, incident.io, status.io, Cachet and UptimeRobot), and it follows security advisories for chosen ecosystems and packages via the GitHub Advisory Database. Both send native macOS notifications on changes. The app also updates itself from GitHub Releases. Built with SwiftUI, targeting macOS 14+ (Sonoma).

## Architecture

- **UI Framework**: SwiftUI with `MenuBarExtra` (`.window` style)
- **State Management**: Swift Observation framework (`@Observable` macro)
- **Networking**: Native `URLSession` with `async/await` and `TaskGroup`
- **Persistence**: `UserDefaults` with JSON-encoded configuration
- **Notifications**: `UNUserNotificationCenter` for native alerts on status changes
- **Dependencies**: None - system frameworks only (SwiftUI, Foundation, AppKit, UserNotifications)
- **App Type**: LSUIElement (menu-bar-only, no Dock icon)

## Swift & SwiftUI Best Practices

### General Swift

- Use Swift's strict concurrency model. Mark classes as `@MainActor` when they drive UI. Use `actor` for shared mutable state accessed from multiple tasks.
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless you need identity or `@Observable`.
- Use `async/await` and structured concurrency (`TaskGroup`, `withThrowingTaskGroup`) over callbacks or Combine.
- Use `Codable` with `CodingKeys` for JSON mapping. Never force-unwrap decoded data.
- Prefer `guard` for early exits and precondition checks over nested `if let`.
- Use `let` over `var` whenever possible. Minimize mutable state.
- Use access control: `private` by default, only expose what's needed.
- Prefer `final class` when a class shouldn't be subclassed.
- Error handling: define domain-specific error enums conforming to `LocalizedError`. Never use `try!` in production code.

### SwiftUI Specific

- Use `@Observable` (macOS 14+) instead of `ObservableObject`/`@Published`. It provides fine-grained view invalidation.
- Keep views small and composable. Extract subviews when a view body exceeds ~30 lines.
- Use `@State` for view-local state, pass `@Observable` objects directly (no `@ObservedObject` needed with Observation framework).
- Prefer `.task { }` modifier for async work tied to view lifecycle over `onAppear` + `Task { }`.
- Use `SettingsLink` (macOS 14+) to open the Settings scene.
- For MenuBarExtra with rich content, always use `.menuBarExtraStyle(.window)`.

### macOS Menu Bar App Specifics

- Set `LSUIElement = true` in Info.plist to prevent Dock icon appearance.
- Menu bar icons: use `NSImage` with `isTemplate = false` for colored icons. macOS renders template images as monochrome.
- Create tinted SF Symbol images programmatically via `NSImage(systemSymbolName:)` with compositing.
- The `.window` MenuBarExtra style gives full SwiftUI rendering; the `.menu` style is limited to basic items.
- Use `NSWorkspace.shared.open(url)` to open URLs in the default browser.
- Use `NSApplication.shared.terminate(nil)` for the Quit action.

### Networking

- Use `actor` for the API client to ensure thread safety.
- Set reasonable timeouts: 15s for request, 30s for resource.
- Always check HTTP status codes before decoding responses.
- Use `TaskGroup` to fetch multiple services concurrently.
- For polling: prefer `Task.sleep(for:)` over `Timer` - it integrates with structured concurrency and respects task cancellation.

### Project Conventions

- File organization: group by feature layer (App, Models, Services, Views, Utilities).
- One primary type per file. File name matches the type name.
- Use `enum` with no cases for namespacing static utilities (e.g., `enum MenuBarIconRenderer`).
- SwiftUI previews: keep mock data in a dedicated `PreviewData.swift` file.
- No third-party dependencies unless absolutely necessary.
- Minimum deployment target: macOS 14.0 (Sonoma).

### Status Provider APIs

The app supports two provider types, both JSON-based:

**Atlassian StatusPage:**
- Endpoint: `https://{domain}/api/v2/summary.json`
- Component statuses: `operational`, `degraded_performance`, `partial_outage`, `major_outage`
- Page indicators: `none`, `minor`, `major`, `critical`
- Components may have `group: true` (container, not a real service) or `only_show_if_degraded: true` — filter these appropriately.
- Always use snake_case `CodingKeys` to map API field names to Swift's camelCase.

**incident.io:**
- Endpoint: `https://{domain}/proxy/{domain}`
- Uses a structure-based component model with groups, affected components, and ongoing incidents.
- Component statuses: `operational`, `degraded_performance`, `partial_outage`, `full_outage`
- Groups can be `hidden` — skip these. Components within groups can also be `hidden`.

### Security Advisories (GitHub Advisory Database)

- Endpoint: `https://api.github.com/advisories?type=reviewed&ecosystem={eco}&severity={sev}&affects={pkgs}&published=>={date}`
- Public, no auth; limited to 60 requests/hour per IP. Conditional (`If-None-Match`) 304 responses still count against this limit.
- `severity` accepts a single value, so each followed severity of a topic is a separate request. Don't drop the severity filter and filter client-side: npm and pip exceed 100 reviewed advisories per week.
- Skip advisories with a non-null `withdrawn_at`. `cve_id` is often null at publish time; fall back to `ghsa_id`.
- Advisory notifications use `interruptionLevel = .timeSensitive`. Builds are ad-hoc signed without the time-sensitive entitlement, so macOS downgrades them to regular notifications unless the app is allowed in the user's Focus.

### Self-Update

- `AppUpdater` reads `https://api.github.com/repos/pimvernooij/statusbar/releases/latest`, compares `tag_name` (`v1.4.0`) with `CFBundleShortVersionString`, and installs the first `.zip` asset. The release workflow must keep publishing `StatusBar-{version}.zip` containing `StatusBar.app`.
- Builds are ad-hoc signed, so the download is verified by bundle identifier and version only. Keep `CFBundleShortVersionString` in sync with the release tag (`scripts/sync-version.sh`), or the update is rejected.
- Downloads go through URLSession, which doesn't set `com.apple.quarantine`; the updater also strips it. Don't download updates via a browser or `NSWorkspace`, or Gatekeeper will block the relaunch.

### Testing & Verification

- Build with `xcodebuild -scheme StatusBar -destination 'platform=macOS'`
- Verify menu bar icon appears and reflects correct status
- Test with live APIs: status.claude.com (StatusPage), www.githubstatus.com (StatusPage), status.openai.com (incident.io)
- Verify Settings window opens and persists changes
- Test error states: disable network, use invalid domains

### CI & Supply Chain

- Pin GitHub Actions to a full commit SHA with the version as a comment (`uses: actions/checkout@<sha> # v7.0.1`). Dependabot (`.github/dependabot.yml`) keeps the pins current.
- `pnpm-workspace.yaml` sets `minimumReleaseAge` to 7 days: pnpm refuses package versions younger than that, also when they are already in the lockfile. Dependabot uses the same 7-day `cooldown`.
- Changesets/release tooling is the only npm dependency; the app itself has none.

### Documentation

- Always update `README.md` when making significant changes (new features, renamed files, architecture changes). Keep the Features list, Architecture section, and Project Structure tree in sync with the codebase.

### Common Pitfalls

- Forgetting `isTemplate = false` on menu bar `NSImage` - icons will appear monochrome
- Using `.menu` style MenuBarExtra and wondering why custom views don't render
- Not filtering group components from the StatusPage API response
- Using `@ObservedObject`/`@StateObject` instead of the Observation framework on macOS 14+
- Force-unwrapping URLs - use `guard let` or provide fallback
- Not handling `Task.isCancelled` in polling loops
