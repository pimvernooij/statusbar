---
"statusbar": patch
---

Keep the dropdown stable during a refresh. Rows were removed and added back while statuses were fetched, which made the panel jump in height and could leave it at the wrong size. Rows now stay in place and update when their new status arrives.

Only show the panel's scrollbar when its content really doesn't fit, so it no longer flashes while the panel resizes.
