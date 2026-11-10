# Changelog

Public versions follow MAJOR.MINOR.PATCH, starting at 0.1.0. Previous 1.0.x labels were internal development builds; historical evidence keeps those labels.

## [0.1.0] - 2026-11-10

- Establish public versioning in `VERSION` and an independent, increasing bundle build number in `BUILD_NUMBER` (11).
- Add GitHub Actions tests, native Apple Silicon builds, package validation, and tag-triggered GitHub Releases.
- Deliver a macOS installer PKG, a portable ZIP, and SHA-256 checksums.
- Document installation, development, release procedures, and the scope of historical validation.
- Include the existing live three-body simulation, two rendering modes, eight presets, randomized starts, deterministic replay, and lifecycle fixes.

Packages are unsigned installers containing ad-hoc-signed bundles, without notarization.
