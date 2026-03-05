# StatusBar

A lightweight macOS menu bar app that monitors cloud service status pages at a glance.

StatusBar polls status page APIs from multiple providers, showing a colored icon in your menu bar reflecting the worst status across all monitored services. Click it to see per-service and per-component details. Just enter a status page URL — the provider is auto-detected.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![No Dependencies](https://img.shields.io/badge/dependencies-none-green)

## Features

- **Menu bar icon** that changes color based on overall status (green/yellow/orange/red/gray)
- **Five provider types** — auto-detected from URL (StatusPage, incident.io, status.io, Cachet, UptimeRobot)
- **Expandable service rows** with component-level breakdown
- **Quick links** to open status pages in your browser
- **Native notifications** when a service status changes (degradation or recovery)
- **Configurable polling interval** (30s to 10 minutes)
- **Add any supported status page** via Settings — just paste the URL
- **Launch at Login** — optional, toggle in Settings
- **Test notification** button in Settings to verify notification permissions
- **Translucent settings panel** with vibrancy background, adapts to light/dark mode
- **Zero dependencies** — built entirely with system frameworks

## Default Services

| Service | Domain | Provider |
|---------|--------|----------|
| Claude | status.claude.com | StatusPage |
| GitHub | eu.githubstatus.com | StatusPage |
| OpenAI | status.openai.com | incident.io |
| Vercel | www.vercel-status.com | StatusPage |

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
2. **Click** the icon to see service details
3. **Click** a service row to expand and see individual component statuses
4. Open **Settings** to add/remove services or change the refresh interval

The app runs as a menu-bar-only app — it won't appear in the Dock.

## Adding Services

1. Click the menu bar icon → **Settings...**
2. Enter the status page URL (e.g. `status.vercel.com`)
3. Click **+** — the provider and service name are auto-detected

### Supported Providers

| Provider | Example | Detection |
|----------|---------|-----------|
| [Atlassian StatusPage](https://www.atlassian.com/software/statuspage) | status.claude.com, eu.githubstatus.com | `/api/v2/summary.json` |
| [incident.io](https://incident.io) | status.openai.com | `/proxy/{domain}` |
| [status.io](https://status.io) | status.commercetools.com | `statuspageId` in HTML |
| [Cachet](https://github.com/CachetHQ/Cachet) | status.bluestonepim.com | `/api/v1/components/groups` |
| [UptimeRobot](https://uptimerobot.com) | uptime.storyblok.com | `pspApiPath` in HTML |

## Architecture

- **SwiftUI** with `MenuBarExtra` (`.window` style for rich rendering)
- **Swift Observation** (`@Observable`) for reactive state
- **Actor-based** API client for thread-safe networking
- **Structured concurrency** — `TaskGroup` for parallel fetching, `Task.sleep` for polling
- **NSVisualEffectView** for translucent settings window
- **UNUserNotificationCenter** for native macOS notifications on status changes
- **SMAppService** for launch-at-login support
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
  Services/
    StatusClient.swift              — Actor-based async API client + provider auto-detection
    StatusPollingService.swift      — Observable polling coordinator + notification dispatch
  Views/
    StatusMenuView.swift            — Main dropdown content
    ServiceRowView.swift            — Expandable service row
    ComponentRowView.swift          — Component status line
    StatusIndicatorView.swift       — Reusable colored status dot
    SettingsView.swift              — Translucent settings window
  Utilities/
    MenuBarIconRenderer.swift       — Tinted SF Symbol for menu bar
    StatusColor.swift               — Status-to-color/label mapping
```

## License

MIT
