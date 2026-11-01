---
"statusbar": patch
---

Fix the dropdown not resizing in release builds. Expanding a row left the panel at its old height, which cut off the content. The app now sets the panel height itself.
