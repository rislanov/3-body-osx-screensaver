ThreeBody 0.1.3 fixes black previews after a fullscreen session.

- The Settings preview no longer attaches itself to an unrelated ScreenSaverEngine launched later.
- The saver uses the module-qualified principal class `ThreeBodySaver.ThreeBodyView`.
- Migration instructions explain how a retained per-user module can lose access to resources when its original path is removed.
- Retains the figure-eight gallery thumbnail and English setup button.
- Version 0.1.3, build 14. Apple Silicon; macOS 14 or later deployment target.

The local installed build was checked in System Settings and two fullscreen sessions on the development Mac. See [the regression report](validation/black-preview-0.1.3.md) for evidence and limits.

The PKG installs the preview to `/Applications` and the saver to `/Library/Screen Savers` with administrator authorization. Screen saver selection remains manual. ZIP and SHA-256 checksums are also provided.

The installer is unsigned; contained bundles are ad-hoc signed. This release is not notarized and downloaded builds may be blocked by Gatekeeper. Do not disable system protections. See the repository's development instructions to build locally.
