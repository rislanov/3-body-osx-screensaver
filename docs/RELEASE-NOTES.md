ThreeBody 0.1.2 adds a custom screen saver gallery thumbnail.

- A dark figure-eight orbit with cyan, pink, and gold bodies replaces the generic gallery artwork.
- Includes standard and Retina PNG assets and explicit screen saver thumbnail metadata.
- Package verification checks both thumbnail dimensions and their presence in the installer payload.
- Includes the English Open Screen Saver Settings button and setup instructions introduced in 0.1.1.
- Version 0.1.2, build 13. Apple Silicon; macOS 14 or later deployment target.

The PKG installs the preview to `/Applications` and the saver to `/Library/Screen Savers` with administrator authorization. Screen saver selection remains manual. ZIP and SHA-256 checksums are also provided.

The installer is unsigned; contained bundles are ad-hoc signed. This release is not notarized and downloaded builds may be blocked by Gatekeeper. Do not disable system protections. See the repository's development instructions to build locally.
