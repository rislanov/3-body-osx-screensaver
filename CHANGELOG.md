# Changelog

Public versions follow MAJOR.MINOR.PATCH, starting at 0.1.0. Previous 1.0.x labels were internal development builds; historical evidence keeps those labels.

## [0.1.2] - 2026-11-10

- Add a custom figure-eight gallery thumbnail with three colored bodies, including a Retina asset, instead of the generic screen saver image.

## [0.1.1] - 2026-11-10

- Add an English “Open Screen Saver Settings” button, application menu command, and short setup instructions to the preview.
- Open the Screen Saver pane inside Wallpaper on macOS 26; keep the earlier destination for macOS 14–15.
- Leave screen saver selection and user settings under user control.

## [0.1.0] - 2026-11-10

- Establish public versioning in `VERSION` and an independent, increasing bundle build number in `BUILD_NUMBER` (11).
- Add GitHub Actions tests, native Apple Silicon builds, package validation, and tag-triggered GitHub Releases.
- Deliver a macOS installer PKG, a portable ZIP, and SHA-256 checksums.
- Document installation, development, release procedures, and the scope of historical validation.
- Include the existing live three-body simulation, two rendering modes, eight presets, randomized starts, deterministic replay, and lifecycle fixes.

Packages are unsigned installers containing ad-hoc-signed bundles, without notarization.
