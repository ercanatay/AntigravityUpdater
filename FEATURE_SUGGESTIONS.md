# Feature Suggestions for AntigravityUpdater

This document outlines proposed new features based on an analysis of the current codebase (v1.6.5), feature gaps across platforms, and common patterns in update management tools.

---

## 1. Linux Backup & Rollback Support

**Priority:** High
**Platforms:** Linux
**Current gap:** Feature Matrix shows backup and rollback are only available on macOS and Windows.

### What it would do
- Create a backup of the installed package (`.deb`, `.rpm`) or AppImage binary before updating.
- Provide a `--rollback` flag (matching macOS/Windows) to restore the previous version.
- Keep the last 3 backups with timestamps, consistent with other platforms.

### Why it matters
Linux users currently have no safety net if an update introduces a regression. This is the most visible feature gap in the project.

---

## 2. GitHub API Token Support

**Priority:** High
**Platforms:** All
**Current gap:** Unauthenticated GitHub API limit is 60 requests/hour (noted in Troubleshooting).

### What it would do
- Accept a `--token` / `-Token` parameter or read from `GITHUB_TOKEN` environment variable.
- Pass the token as a `Authorization: Bearer` header in GitHub API requests.
- Increase rate limit from 60 to 5,000 requests/hour per user.

### Why it matters
Environments with multiple users behind a shared IP (offices, CI servers) hit the rate limit quickly. This is already listed as a known issue in the README troubleshooting section.

---

## 3. Version Pinning

**Priority:** Medium
**Platforms:** All
**Current gap:** Users can only update to the latest release.

### What it would do
- Add a `--version <tag>` parameter to install a specific release instead of the latest.
- Validate that the requested version exists in the GitHub releases list.
- Useful for testing, compliance, or environments that require a specific version.

### Why it matters
Some users or organizations need to stay on a validated version rather than always jumping to the latest. This is standard in most package managers.

---

## 4. JSON / Machine-Readable Output Mode

**Priority:** Medium
**Platforms:** All
**Current gap:** Output is human-readable only. No structured output for automation.

### What it would do
- Add a `--json` flag that outputs structured JSON instead of formatted text.
- Include fields like: `current_version`, `latest_version`, `update_available`, `platform`, `asset_url`, `status`.
- Combine with `--check-only` for monitoring and alerting pipelines.

### Example output
```json
{
  "current_version": "1.6.4",
  "latest_version": "1.6.5",
  "update_available": true,
  "platform": "linux",
  "asset": "antigravity-tools_1.6.5_amd64.deb"
}
```

### Why it matters
Enables integration with monitoring dashboards, CI/CD pipelines, and fleet management tools. Silent mode is not enough for automation because it still produces unstructured text.

---

## 5. Self-Update Mechanism

**Priority:** Medium
**Platforms:** All
**Current gap:** The updater itself has no way to update itself.

### What it would do
- Add a `--self-update` flag that checks the `ercanatay/AntigravityUpdater` repository for a newer updater version.
- Download and replace the updater scripts in place.
- Verify integrity of the downloaded updater (SHA256 or signature).

### Why it matters
Users who cloned the repo can run `git pull`, but users who downloaded a release or the `.app` bundle have no mechanism to get updater fixes (such as the critical security patches in v1.6.x).

---

## 6. Pre/Post Update Hooks

**Priority:** Medium
**Platforms:** All
**Current gap:** No extensibility point for custom actions.

### What it would do
- Look for optional hook scripts in the config directory:
  - `pre-update.sh` / `pre-update.ps1` — runs before the update starts.
  - `post-update.sh` / `post-update.ps1` — runs after the update completes.
- Pass environment variables to hooks: `$OLD_VERSION`, `$NEW_VERSION`, `$PLATFORM`, `$ASSET_PATH`.
- Non-zero exit from `pre-update` aborts the update.

### Why it matters
Allows users to run custom validations, send notifications, stop dependent services, or trigger deployments around updates without modifying the core scripts.

---

## 7. Desktop Notification Support

**Priority:** Low
**Platforms:** macOS, Windows, Linux
**Current gap:** Update results are only visible in the terminal.

### What it would do
- Send a system notification when an automatic (scheduled) update completes or fails.
- macOS: `osascript` or `terminal-notifier`
- Windows: PowerShell `BurntToast` module or `[System.Windows.Forms.MessageBox]`
- Linux: `notify-send`

### Why it matters
When auto-update scheduling is enabled, users may not be watching the terminal. A desktop notification provides immediate visibility into update results.

---

## 8. Download Resume / Retry

**Priority:** Low
**Platforms:** All
**Current gap:** A failed download requires starting over from scratch.

### What it would do
- Use `curl -C -` to resume interrupted downloads.
- Implement retry logic (3 attempts with exponential backoff) for transient network failures.
- Log each retry attempt.

### Why it matters
Large release assets on slow or unstable connections can fail partway through. Resume support avoids re-downloading the entire file.

---

## 9. Update History Log

**Priority:** Low
**Platforms:** All
**Current gap:** Logs exist but there's no structured update history.

### What it would do
- Maintain a separate `update-history.json` file in the config directory.
- Record each update: timestamp, old version, new version, status (success/failure/rollback), asset filename.
- Add a `--history` flag to display the last N updates.

### Example
```json
[
  {
    "timestamp": "2026-02-10T14:30:00Z",
    "from_version": "1.6.4",
    "to_version": "1.6.5",
    "status": "success",
    "platform": "macos",
    "asset": "AntigravityTools-1.6.5-universal.dmg"
  }
]
```

### Why it matters
Provides an audit trail of all updates. Useful for debugging issues that started after a specific update, and for compliance in managed environments.

---

## 10. Checksum Cache for Skipping Redundant Downloads

**Priority:** Low
**Platforms:** All
**Current gap:** Re-running the updater when already on the latest version still exits early, but there's no asset caching.

### What it would do
- Cache the SHA256 hash (and optionally the downloaded asset) of the last installed version.
- On the next run, if the latest release matches the cached hash, skip the download entirely.
- Reduce bandwidth usage and speed up no-op update checks.

### Why it matters
Useful for automated/scheduled runs where the check happens frequently but updates are rare. Reduces unnecessary network traffic and GitHub API load.

---

## Summary Table

| # | Feature | Priority | Platforms | Complexity |
|---|---------|----------|-----------|------------|
| 1 | Linux Backup & Rollback | High | Linux | Medium |
| 2 | GitHub API Token Support | High | All | Low |
| 3 | Version Pinning | Medium | All | Low |
| 4 | JSON Output Mode | Medium | All | Low |
| 5 | Self-Update Mechanism | Medium | All | Medium |
| 6 | Pre/Post Update Hooks | Medium | All | Medium |
| 7 | Desktop Notifications | Low | macOS/Win/Linux | Low |
| 8 | Download Resume/Retry | Low | All | Low |
| 9 | Update History Log | Low | All | Low |
| 10 | Checksum Cache | Low | All | Medium |
