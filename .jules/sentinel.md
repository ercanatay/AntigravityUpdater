# Sentinel's Journal

## 2026-02-06 - Unsafe Update Sequence
**Vulnerability:** The macOS updater removed the existing application before verifying the integrity of the downloaded update. Furthermore, code signature verification failure was only logged as a warning, allowing installation of potentially compromised code.
**Learning:** Checking integrity *after* destructive actions leaves users vulnerable to denial-of-service (broken app) or compromise. Warnings are insufficient for critical security checks.
**Prevention:** Perform all integrity and security checks on the new artifact (e.g., inside the mounted DMG) *before* touching the existing installation. Enforce strict exit on verification failure. Use `ditto` for app bundles to preserve attributes and reject symlinked sources to prevent path traversal attacks.
