# Release pipeline implementation plan

**Goal:** Produce versioned PKG/ZIP artifacts and GitHub tag releases, beginning at 0.1.0.

**Architecture:** Keep native shell build scripts. Centralize public and build versions; package system-wide bundles using Apple's tools. CI tests and inspects artifacts before a separate release job publishes them.

**Constraints:** Apple Silicon, macOS 14+, no installation during verification, preserve historical evidence, no invented signing credentials.

- [x] Add VERSION and BUILD_NUMBER validation; consume them in clean bundle builds.
- [x] Package fixed installation paths, ZIP, and checksums; reject stale or diagnostic bundles.
- [x] Add CI checks and tag-only release publishing.
- [x] Separate quick-start, technical documentation, release procedures, and historical evidence.
- [x] Run core tests, actual package build, payload verification, and workflow/static checks.

Review focus: mismatched tags, stale bundle metadata, diagnostic markers, fixed upgrade destinations, and preservation of historical version labels.
