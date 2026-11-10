ThreeBody 0.1.1 adds an easier way to finish screen saver setup from the preview app.

- New **Open Screen Saver Settings** button and application menu command, with short English instructions for selecting ThreeBody.
- Opens the Screen Saver pane inside Wallpaper on macOS 26; uses the earlier destination on macOS 14–15.
- Screen saver selection remains manual. Installation does not change settings for any account.
- Version 0.1.1, build 12. Apple Silicon; macOS 14 or later deployment target.

The button and compact 640×400 preview layout were checked locally on macOS 26. The macOS 14–15 navigation path has not been retested on those systems.

The PKG installs the preview to `/Applications` and the saver to `/Library/Screen Savers` with administrator authorization. ZIP and SHA-256 checksums are also provided.

The installer is unsigned; contained bundles are ad-hoc signed. This release is not notarized and downloaded builds may be blocked by Gatekeeper. Do not disable system protections. See the repository's development instructions to build locally.
