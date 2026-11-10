# Installed black-preview regression check

November 10, 2026. Local development version 0.1.3 / build 14, MacBook Air M4, macOS 26.7.2. This is not a published release or a CI result.

## Reproduced causes

The old system host retained a per-user module after its bundle had been moved. Its original resource path was unavailable; restoring that path temporarily with a compatibility symlink restored rendering. Installing another bundle did not unload the earlier library.

A separate lifecycle regression remained: the Settings preview could report `isPreview == false`, discover a fullscreen ScreenSaverEngine launched later, and stop when that unrelated process exited. After the first fullscreen check of the old build, the small preview turned black. Lifecycle diagnostics recorded the late engine binding followed by termination and resource release.

## Fix and installed verification

Engine identity is captured only when a view starts. A view started without an engine does not attach to a later session. Ended-session guards and owned-resource cleanup remain in place. The saver principal class is now module-qualified rather than using the old global Objective-C name.

- Built and packaged 0.1.3, validated the package, and installed it with the macOS Installer.
- Loaded the bundle in a standalone harness: its principal class resolved to `ThreeBodySaver.ThreeBodyView`, and starting it created an MTKView. This alone was not treated as visual acceptance.
- Closed Settings and gracefully terminated the identified, owned idle legacy host only after confirming no ScreenSaverEngine was running. This was a manual diagnostic operation, not installer/product behavior. Fresh hosts were checked with `lsof`: the loaded library inode matched the installed 0.1.3 executable.
- Removed the temporary compatibility symlink and moved the diagnostic-only saver out of the installation directory. The system-wide production bundle remains installed.
- Observed animated output in System Settings.
- Launched the actual system ScreenSaverEngine twice. The Mac locked normally; the user confirmed visible animation in both sessions and unlocked manually.
- After each exit, observed the small Settings preview still rendering. After the second exit, successive screenshots showed changed star positions, confirming continued motion rather than a frozen frame.

Security and lock settings were not weakened. No automatic saver selection for other accounts was added.

## Limits

The fullscreen observations are user-confirmed because the automation tool cannot inspect the locked screen. These two short system-host cycles do not establish long-duration stability, sleep/wake behavior, multi-display behavior, or compatibility with other macOS releases. Historical acceptance measurements remain in the separate report and were not rerun as part of this check.
