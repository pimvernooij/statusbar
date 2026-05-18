---
"statusbar": patch
---

Fix the menu bar dropdown rendering blank on macOS 26, and stop a single slow service from blanking the list for the others. The previous content-height measurement (and a `ViewThatFits` fallback) no longer rendered inside `MenuBarExtra(.window)` on macOS 26; the service list is now laid out directly. Per-service fetches stream into the menu as they complete instead of waiting for all of them to finish.
