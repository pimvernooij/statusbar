# StatusApp

A lightweight macOS menu bar app that monitors cloud service status pages at a glance.

StatusApp polls [Atlassian StatusPage](https://www.atlassian.com/software/statuspage) APIs and [incident.io](https://incident.io) RSS feeds, showing a colored icon in your menu bar reflecting the worst status across all monitored services. Click it to see per-service and per-component details.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![No Dependencies](https://img.shields.io/badge/dependencies-none-green)

## Features

- **Menu bar icon** that changes color based on overall status (green/yellow/orange/red/gray)
- **Two provider types** — Atlassian StatusPage (JSON API) and incident.io (RSS feed)
- **Expandable service rows** with component-level breakdown
- **Quick links** to open status pages in your browser
- **Configurable polling interval** (30s to 10 minutes)
- **Add any StatusPage or incident.io service** via Settings
- **Translucent settings panel** with vibrancy background, adapts to light/dark mode
- **Zero dependencies** — built entirely with system frameworks

## Default Services

| Service | Domain | Provider |
|---------|--------|----------|
| Claude | status.claude.com | StatusPage |
| GitHub | eu.githubstatus.com | StatusPage |
| OpenAI | status.openai.com | incident.io |

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
3. **Click** a service row to expand and see individual component statuses
4. Open **Settings** to add/remove services or change the refresh interval

The app runs as a menu-bar-only app — it won't appear in the Dock.

## Adding Services

### StatusPage services

Any service using the Atlassian StatusPage API works (Vercel, Cloudflare, Datadog, Twilio, etc.). To verify a domain, check that `https://<domain>/api/v2/summary.json` returns JSON.

### incident.io services

Services using incident.io status pages expose an RSS feed. To verify, check that `https://<domain>/feed.rss` returns XML.

### Adding a service

1. Click the menu bar icon → **Settings...**
2. Enter a name and the status page domain (e.g. `status.vercel.com`)
3. Select the provider type (**StatusPage** or **incident.io**)
4. Click **+** to add

## Architecture

- **SwiftUI** with `MenuBarExtra` (`.window` style for rich rendering)
- **Swift Observation** (`@Observable`) for reactive state
- **Actor-based** API client for thread-safe networking
- **XMLParser** for RSS feed parsing (incident.io provider)
- **Structured concurrency** — `TaskGroup` for parallel fetching, `Task.sleep` for polling
- **NSVisualEffectView** for translucent settings window
- **UserDefaults** for persistence

## Project Structure

```
StatusApp/
  App/
    StatusAppApp.swift              — Entry point, MenuBarExtra + Settings scenes
  Models/
    StatusPageModels.swift          — Codable structs for StatusPage API v2
    ServiceConfiguration.swift      — Service config, provider enum + defaults
    ServiceStatus.swift             — Status enums + result types
  Services/
    StatusPageClient.swift          — Actor-based async API client (JSON + RSS)
    StatusPollingService.swift      — Observable polling coordinator
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
