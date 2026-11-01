---
"statusbar": patch
---

Fix the dropdown not resizing in released builds. Expanding a row left the panel at its old height, which cut off the content. The app now sets the panel height itself, and releases are built with the macOS 26 SDK.
