ThreeBody 0.1.0 starts public versioning and automated packaging.

- Apple Silicon; macOS 14 or later deployment target.
- PKG installs the preview to `/Applications` and the saver to `/Library/Screen Savers` with administrator authorization.
- ZIP supports manual installation; SHA-256 checksums cover both downloads.
- Live three-body dynamics, Gravity Fabric and Cinematic modes, native settings, and deterministic replay.

The installer is unsigned; contained bundles are ad-hoc signed. This release is not notarized and downloaded builds may be blocked by Gatekeeper. Do not disable system protections. See the repository's development instructions to build locally.

The earlier 1.0.x numbers were internal development labels. Historical validation is retained under those names, not claimed as new testing of this package. Longer system-host runs, sleep/wake, and multiple-display acceptance remain outstanding.
