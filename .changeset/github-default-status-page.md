---
"statusbar": patch
---

Change the default GitHub service from `eu.githubstatus.com` to `www.githubstatus.com`. The EU page covers GitHub Enterprise Cloud with EU data residency (GHE.com), which has moved off Atlassian StatusPage and now returns 404 on `/api/v2/summary.json`; `www.githubstatus.com` reports status for github.com.
