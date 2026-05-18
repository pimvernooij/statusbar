# statusbar

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
