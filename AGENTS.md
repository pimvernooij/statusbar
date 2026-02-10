# AGENTS.md - StatusApp Development Guide

## Project Overview

StatusApp is a macOS menu bar application (status bar app) that monitors cloud service status pages using the Atlassian StatusPage API v2. Built with SwiftUI, targeting macOS 14+ (Sonoma).

## Architecture

- **UI Framework**: SwiftUI with `MenuBarExtra` (`.window` style)
- **State Management**: Swift Observation framework (`@Observable` macro)
- **Networking**: Native `URLSession` with `async/await` and `TaskGroup`
- **Persistence**: `UserDefaults` with JSON-encoded configuration
- **Dependencies**: None - system frameworks only (SwiftUI, Foundation, AppKit)
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

### StatusPage API v2

The app consumes the Atlassian StatusPage API. Key details:

- Endpoint pattern: `https://{domain}/api/v2/summary.json`
- Component statuses: `operational`, `degraded_performance`, `partial_outage`, `major_outage`
- Page indicators: `none`, `minor`, `major`, `critical`
- Components may have `group: true` (container, not a real service) or `only_show_if_degraded: true` - filter these appropriately.
- Always use snake_case `CodingKeys` to map API field names to Swift's camelCase.

### Testing & Verification

- Build with `xcodebuild -scheme StatusApp -destination 'platform=macOS'`
- Verify menu bar icon appears and reflects correct status
- Test with live APIs: status.claude.com, www.githubstatus.com
- Verify Settings window opens and persists changes
- Test error states: disable network, use invalid domains

### Common Pitfalls

- Forgetting `isTemplate = false` on menu bar `NSImage` - icons will appear monochrome
- Using `.menu` style MenuBarExtra and wondering why custom views don't render
- Not filtering group components from the StatusPage API response
- Using `@ObservedObject`/`@StateObject` instead of the Observation framework on macOS 14+
- Force-unwrapping URLs - use `guard let` or provide fallback
- Not handling `Task.isCancelled` in polling loops
