# statusbar

## 1.5.2

### Patch Changes

- 94b7889: Keep the dropdown stable during a refresh. Rows were removed and added back while statuses were fetched, which made the panel jump in height and could leave it at the wrong size. Rows now stay in place and update when their new status arrives.
  
  Only show the panel's scrollbar when its content really doesn't fit, so it no longer flashes while the panel resizes.

## 1.5.1

### Patch Changes

- 86eb896: Make the settings window readable. The whole window was 10% transparent, so whatever was behind it showed through the text. It now uses a blurred translucent background with fully opaque text and controls, and opening Settings from the dropdown also brings an already open window forward.
- 86eb896: Keep the dropdown on screen. Long lists now scroll inside their row and the panel scrolls when it would exceed the screen height, so an expanded service such as Vercel can always be collapsed again. Critical advisories are listed above high ones, and all advisories of a topic can be reached instead of the first 8.
  
  Show which component each status.io region belongs to, for example `Composable Commerce: APIs · Europe (AWS)`. Regions are shared between components, so the list could show the same name several times.

## 1.5.0

### Minor Changes

- 71310ae: Check GitHub Releases for new versions at launch and every 6 hours. When one is available, a banner in the dropdown offers an Update button that downloads the release, verifies it, replaces the app and relaunches. Settings → General shows the current version and a Check Now button.

## 1.4.0

### Minor Changes

- 9bfce00: Add security advisory monitoring. Follow an ecosystem or specific packages (for example `npm: next, react`) and the dropdown lists high and critical advisories from the GitHub Advisory Database published in the last 7 days, with relative timestamps and links to GitHub. Each topic can follow high, critical or both. New advisories trigger Time Sensitive notifications. Topics, check interval and notifications are managed in a new Advisories settings tab.

### Patch Changes

- 2f136a8: Change the default GitHub service from `eu.githubstatus.com` to `www.githubstatus.com`. The EU page covers GitHub Enterprise Cloud with EU data residency (GHE.com), which has moved off Atlassian StatusPage and now returns 404 on `/api/v2/summary.json`; `www.githubstatus.com` reports status for github.com.

## 1.3.1

### Patch Changes

- 13d79dd: Fix the menu bar dropdown rendering blank on macOS 26, and stop a single slow service from blanking the list for the others. The previous content-height measurement (and a `ViewThatFits` fallback) no longer rendered inside `MenuBarExtra(.window)` on macOS 26; the service list is now laid out directly. Per-service fetches stream into the menu as they complete instead of waiting for all of them to finish.

## 1.3.0

### Minor Changes

- a25ff29: Add Cachet as a new status page provider. Users can now monitor services powered by Cachet (e.g. status.bluestonepim.com) by selecting the "Cachet" provider when adding a service. Uses the Cachet API v1 component groups endpoint.
- 8a6889e: Add status.io as a new status page provider. Users can now monitor services powered by status.io (e.g. status.commercetools.com) by selecting the "status.io" provider when adding a service. The statuspage ID is auto-discovered from the domain.
- 805c4d7: Add UptimeRobot as a new status page provider. Users can now monitor services powered by UptimeRobot (e.g. uptime.storyblok.com) — the provider is auto-detected from the URL.
- e9d36e0: Auto-detect status page provider and service name from URL. Users now only need to enter the status page URL when adding a service — the provider type and service name are automatically detected by probing known API endpoints.

## 1.2.1

### Patch Changes

- ad2f37e: Add notifications enabled/disabled toggle in Settings and make settings panel floating with slight transparency

## 1.2.0

### Minor Changes

- 1a3c0ce: Fix release publish job: chain via job outputs instead of tag trigger

## 1.1.0

### Minor Changes

- 6c415b1: Add changesets-based release flow with automated GitHub Releases
