# ThreeBody

A native macOS screensaver with three stars, live Newtonian dynamics, and a gently deformed gravitational fabric. Two visual modes: Gravity Fabric and Cinematic. No network, account, sound, or background service.

![Gravity Fabric](docs/media/gravity-fabric.png)

**Current version: 0.1.1.** Apple Silicon only; macOS 14 or later is the deployment target. See the [validation report](docs/ACCEPTANCE.md) for the hardware and OS versions actually tested.

## Install

Download the `.pkg` from [GitHub Releases](https://github.com/rislanov/3-body-osx-screensaver/releases). The installer requires administrator authorization and installs:

- `/Applications/ThreeBodyPreview.app`
- `/Library/Screen Savers/ThreeBody.saver`

Select ThreeBody in System Settings → Screen Saver after installation. The installer does not select the saver, change lock settings, or terminate the system host. Stop the saver before updating. macOS may keep an old module loaded until logout/login. If you previously installed a per-user copy, remove that exact `~/Library/Screen Savers/ThreeBody.saver` first to avoid two versions.

The current packages contain **ad-hoc-signed bundles and an unsigned installer; they are not notarized**. Downloaded builds may be blocked by Gatekeeper. For now, building locally is the development path; do not disable system protections. Developer ID distribution requirements are documented in [Releasing](docs/RELEASING.md).

The ZIP contains the same bundles plus documentation for manual installation. Open `ThreeBody.saver` to use the system installation dialog, or run the preview app directly.

To uninstall, select another saver and remove only the installed `ThreeBody.saver` and `ThreeBodyPreview.app`. Leave the parent folders intact.

## Build and run

Requires Apple Silicon, Xcode with a macOS SDK, Swift 5.9 or later, and Python 3 for build metadata. No third-party package dependencies; Python is not a runtime dependency.

```sh
./script/build_and_run.sh       # build both bundles and launch preview
swift test -c release           # physics and scene tests
./script/build.sh               # build bundles in dist/
./script/package.sh             # build PKG, ZIP, and SHA-256 checksums
./script/verify-package.sh      # inspect package without installing it
./script/verify.sh              # local GUI lifecycle and image checks
```

Outputs: `dist/ThreeBodyPreview.app`, `dist/ThreeBody.saver`, and `dist/ThreeBody-0.1.1-macos-arm64.{pkg,zip,sha256}`. To package an existing build, use `./script/package.sh --no-build`; stale versions and diagnostic builds are rejected.

The Codex Run action invokes `script/build_and_run.sh`. If Xcode's optional Metal compiler is missing, the build bundles shader source for local runtime compilation. With the compiler installed, the build also includes a compiled metallib.

## Controls and settings

In the preview, click **Open Screen Saver Settings**, then select **ThreeBody** in System Settings. If it is missing, install the ThreeBody package first. The same command is available in the application menu.

The saver itself shows no controls. Settings provide visual mode, preset, speed, trails, glow, grid brightness, render quality, seed, and JSON import/export.

Preview shortcuts: Space pauses, N advances the scene, R restarts, F toggles fullscreen, D toggles diagnostics, H hides controls, and ⌘, opens settings. Locking and screensaver input remain controlled by macOS.

Randomize each start is enabled by default. Disable it to use a fixed seed. CLI seeds and exported replay configurations remain deterministic. Preview and saver store settings separately; transfer them with JSON export/import.

## Documentation

- [Development guide](docs/DEVELOPMENT.md): capture commands, architecture, rendering, physics, and scenes.
- [Releasing](docs/RELEASING.md): version policy, CI/CD, package layout, and signing status.
- [Changelog](CHANGELOG.md): changes starting with 0.1.0.
- [Product specification](SPECIFICATION.md): intended behavior and acceptance targets.
- [Historical acceptance report](docs/ACCEPTANCE.md) and [recorded evidence](docs/validation/README.md): measured results and outstanding checks.

The older `1.0.x` labels were internal development identifiers. Public versioning begins at `0.1.0`; historical evidence retains its original labels.
