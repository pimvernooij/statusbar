# StatusApp

A lightweight macOS menu bar app that monitors cloud service status pages at a glance.

StatusApp polls [Atlassian StatusPage](https://www.atlassian.com/software/statuspage) APIs and shows a colored icon in your menu bar reflecting the worst status across all monitored services. Click it to see per-service and per-component details.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![No Dependencies](https://img.shields.io/badge/dependencies-none-green)

## Features

- **Menu bar icon** that changes color based on overall status (green/yellow/orange/red/gray)
- **Expandable service rows** with component-level breakdown
- **Quick links** to open status pages in your browser
- **Configurable polling interval** (30s to 10 minutes)
- **Add any StatusPage-based service** — works with hundreds of services out of the box
- **Zero dependencies** — built entirely with system frameworks

## Default Services

| Service | Status Page |
|---------|-------------|
| Claude | status.claude.com |
| GitHub | eu.githubstatus.com |

You can add any service that uses the Atlassian StatusPage platform (Vercel, Cloudflare, OpenAI, Datadog, Twilio, and many more) via Settings.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)

## Getting Started

```bash
git clone <repo-url>
cd StatusApp
open StatusApp.xcodeproj
```

Press **Cmd+R** in Xcode to build and run.

### Building from the command line

```bash
xcodebuild -scheme StatusApp -destination 'platform=macOS' build
```

## Usage

1. After launching, look for the status icon in your **menu bar** (top-right of screen)
2. **Click** the icon to see service details
3. **Expand** a service row to see individual component statuses
4. Open **Settings** to add/remove services or change the refresh interval

The app runs as a menu-bar-only app — it won't appear in the Dock.

## Adding Services

Any service using the Atlassian StatusPage API works. To add one:

1. Click the menu bar icon → **Settings...**
2. Enter a name and the status page domain (e.g. `status.vercel.com`)
3. Click **Add**

To verify a domain works, check that `https://<domain>/api/v2/summary.json` returns JSON in your browser.

## Architecture

- **SwiftUI** with `MenuBarExtra` (`.window` style for rich rendering)
- **Swift Observation** (`@Observable`) for reactive state
- **Actor-based** API client for thread-safe networking
- **Structured concurrency** — `TaskGroup` for parallel fetching, `Task.sleep` for polling
- **UserDefaults** for persistence

## Project Structure

```
StatusApp/
  App/
    StatusAppApp.swift              — Entry point, MenuBarExtra + Settings scenes
  Models/
    StatusPageModels.swift          — Codable structs for StatusPage API v2
    ServiceConfiguration.swift      — Service config + defaults
    ServiceStatus.swift             — Status enums + result types
  Services/
    StatusPageClient.swift          — Actor-based async API client
    StatusPollingService.swift      — Observable polling coordinator
  Views/
    StatusMenuView.swift            — Main dropdown content
    ServiceRowView.swift            — Expandable service row
    ComponentRowView.swift          — Component status line
    StatusIndicatorView.swift       — Reusable colored status dot
    SettingsView.swift              — Tabbed settings window
  Utilities/
    MenuBarIconRenderer.swift       — Tinted SF Symbol for menu bar
    StatusColor.swift               — Status-to-color/label mapping
```

## License

MIT
