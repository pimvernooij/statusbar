# StatusBar

A lightweight macOS menu bar app that keeps an eye on the services and packages you depend on: cloud service status pages and security advisories (CVEs) for the ecosystems you follow.

<img src="assets/screenshot.png" width="400" alt="StatusBar Screenshot">

StatusBar does two things:

- **Service status** — polls status page APIs from multiple providers and shows a colored icon in your menu bar reflecting the worst status across all monitored services. Click it to see per-service and per-component details. Just enter a status page URL; the provider is auto-detected.
- **Security advisories** — follows ecosystems or specific packages (for example `npm: next, react` or `pip: certifi`) in the [GitHub Advisory Database](https://github.com/advisories) and lists recent high and critical advisories, with a notification when a new one appears.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![No Dependencies](https://img.shields.io/badge/dependencies-none-green)

## Features

### Service status

- **Menu bar icon** that changes color based on overall status (green/yellow/orange/red/gray)
- **Five provider types** — auto-detected from URL (StatusPage, incident.io, status.io, Cachet, UptimeRobot)
- **Expandable service rows** with component-level breakdown
- **Quick links** to open status pages in your browser
- **Native notifications** when a service status changes (degradation or recovery)
- **Configurable polling interval** (30s to 10 minutes)
- **Add any supported status page** via Settings — just paste the URL

### Security advisories

- **Follow topics** — an ecosystem (npm, pip, Composer, Go, Maven, RubyGems, Rust, …), optionally narrowed to specific packages
- **High and critical advisories** from the last 7 days per topic, with CVE/GHSA ID, affected package and how long ago it was published; click one to open it on GitHub
- **Per-topic severity filter** — follow high, critical or both
- **Prioritized notifications** — delivered as Time Sensitive so they can break through Focus (see [Notifications during Focus](#notifications-during-focus))
- **No token needed** — uses the public GitHub Advisory Database API

### General

- **In-app updates** — checks GitHub Releases every 6 hours and shows an **Update** button in the dropdown that installs the new version and relaunches
- **Launch at Login** — optional, toggle in Settings
- **Test notification** buttons in Settings to verify notification permissions
- **Translucent settings panel** with vibrancy background, adapts to light/dark mode
- **Zero dependencies** — built entirely with system frameworks

## Default Services

| Service | Domain | Provider |
|---------|--------|----------|
| Claude | status.claude.com | StatusPage |
| GitHub | www.githubstatus.com | StatusPage |
| OpenAI | status.openai.com | incident.io |
| Vercel | www.vercel-status.com | StatusPage |

## Default Advisory Topics

| Ecosystem | Packages | Severities |
|-----------|----------|------------|
| npm | next, react | high, critical |

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (to build from source)

## Getting Started

```bash
git clone <repo-url>
cd StatusBar
open StatusBar.xcodeproj
```

Press **Cmd+R** in Xcode to build and run.

### Building from the command line

Using [Task](https://taskfile.dev) (`brew install go-task`):

```bash
task build     # debug build
task release   # release build
task run       # build and open the app
task zip       # build release + create distributable zip
task clean     # clean build artifacts
```

Or directly with xcodebuild:

```bash
xcodebuild -scheme StatusBar -destination 'platform=macOS' build
```

## Usage

1. After launching, look for the status icon in your **menu bar** (top-right of screen)
2. **Click** the icon to see service status and, below it, your security advisory topics
3. **Click** a service row to expand and see individual component statuses
4. **Click** an advisory topic to see its high and critical advisories; click an advisory to open it on GitHub
5. Open **Settings** to add/remove services (**Services**), follow advisory topics (**Advisories**), or change the refresh interval and check for updates (**General**)

The app runs as a menu-bar-only app — it won't appear in the Dock.

## Adding Services

1. Click the menu bar icon → **Settings...**
2. Enter the status page URL (e.g. `status.vercel.com`)
3. Click **+** — the provider and service name are auto-detected

### Supported Providers

| Provider | Example | Detection |
|----------|---------|-----------|
| [Atlassian StatusPage](https://www.atlassian.com/software/statuspage) | status.claude.com, www.githubstatus.com | `/api/v2/summary.json` |
| [incident.io](https://incident.io) | status.openai.com | `/proxy/{domain}` |
| [status.io](https://status.io) | status.commercetools.com | `statuspageId` in HTML |
| [Cachet](https://github.com/CachetHQ/Cachet) | status.bluestonepim.com | `/api/v1/components/groups` |
| [UptimeRobot](https://uptimerobot.com) | uptime.storyblok.com | `pspApiPath` in HTML |

## Security Advisories

The **Security Advisories** section of the dropdown lists your followed topics. Click a topic to see its high and critical advisories with how long ago they were published; click an advisory to open it on GitHub.

Manage topics in **Settings → Advisories**: pick an ecosystem and optionally enter package names (comma separated). Leaving packages empty follows the whole ecosystem, which can be noisy — pip and npm each see dozens of high/critical advisories per week. Use the **High** / **Critical** chips on each topic to choose which severities it follows (both by default).

- Data comes from the public `GET https://api.github.com/advisories` endpoint (reviewed advisories only), no token needed.
- Unauthenticated requests are limited to **60 per hour**, and each topic uses one request per followed severity per check. The check interval is 15 minutes to 1 hour (default 30 minutes).
- GitHub has no streaming or push API for advisories that a desktop app can use (the `security_advisory` webhook needs a publicly reachable server), so the app polls.
- When a topic is added or its severities change, its current advisories are recorded without notifying; only advisories published afterwards trigger a notification.

### Notifications during Focus

Advisory notifications use the Time Sensitive interruption level. macOS only honors that for apps signed with the `com.apple.developer.usernotifications.time-sensitive` entitlement, which requires an Apple Developer team. Release builds are ad-hoc signed, so to receive advisories during Focus or Do Not Disturb, add StatusBar to the allowed apps of your Focus in **System Settings → Focus**.

## Updates

StatusBar checks the [latest GitHub release](https://github.com/pimvernooij/statusbar/releases/latest) at launch and every 6 hours (or via **Settings → General → Check Now**). When a newer version exists, a banner at the top of the dropdown offers **Update**: the app downloads the release zip, checks that it contains StatusBar with the expected version, replaces itself and relaunches.

Release builds are not signed with a Developer ID. A copy downloaded with a browser is quarantined, so macOS asks you to allow it in **System Settings → Privacy & Security** — once per manually downloaded version. Updates installed with the Update button aren't quarantined and start without that prompt. If the app can't replace itself (for example when it lacks write permission to its folder), the banner links to the release for a manual download.

## Architecture

- **SwiftUI** with `MenuBarExtra` (`.window` style for rich rendering)
- **Swift Observation** (`@Observable`) for reactive state
- **Actor-based** API client for thread-safe networking
- **Structured concurrency** — `TaskGroup` for parallel fetching, `Task.sleep` for polling
- **NSVisualEffectView** for translucent settings window
- **UNUserNotificationCenter** for native macOS notifications on status changes and new advisories
- **SMAppService** for launch-at-login support
- **GitHub Releases API** + `ditto` for self-updating
- **UserDefaults** for persistence

## Project Structure

```
StatusBar/
  App/
    StatusBarApp.swift              — Entry point, MenuBarExtra + Settings scenes + AppDelegate
  Models/
    StatusPageModels.swift          — Codable structs for all provider APIs
    ServiceConfiguration.swift      — Service config, provider enum + defaults
    ServiceStatus.swift             — Status enums + result types
    AdvisoryTopic.swift             — Followed topic + ecosystem enum + defaults
    AdvisoryModels.swift            — Codable structs for the GitHub Advisory API
    AdvisoryResult.swift            — Advisory severity + result types
    AppVersion.swift                — Comparable app/release version
    ReleaseModels.swift             — Codable structs for the GitHub Releases API
  Services/
    StatusClient.swift              — Actor-based async API client + provider auto-detection
    StatusPollingService.swift      — Observable polling coordinator + notification dispatch
    AdvisoryClient.swift            — Actor-based GitHub Advisory Database client
    AdvisoryPollingService.swift    — Advisory polling, seen tracking + prioritized notifications
    AppUpdater.swift                — Release check, download, verification + bundle replacement
    UpdateService.swift             — Observable update state + periodic checks
  Views/
    StatusMenuView.swift            — Main dropdown content
    ServiceRowView.swift            — Expandable service row
    ComponentRowView.swift          — Component status line
    StatusIndicatorView.swift       — Reusable colored status dot
    AdvisoryTopicRowView.swift      — Expandable advisory topic row
    AdvisoryRowView.swift           — Single advisory line with relative timestamp
    SettingsView.swift              — Translucent settings window
    AdvisorySettingsView.swift      — Advisories settings tab
    UpdateBannerView.swift          — "Version x available" banner with Update button
  Utilities/
    MenuBarIconRenderer.swift       — Tinted SF Symbol for menu bar
    StatusColor.swift               — Status-to-color/label mapping
    AdvisoryStyle.swift             — Severity-to-color/symbol mapping
```

## License

MIT
