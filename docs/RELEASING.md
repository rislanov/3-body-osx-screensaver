# Versioning and releases

## Version policy

`VERSION` is the single source for the public version, initially `0.1.0`. Use exactly `MAJOR.MINOR.PATCH`, without a prefix, leading zeros, or prerelease suffix. Both bundles' `CFBundleShortVersionString`, PKG metadata, archive names, and Git tags derive from it. Tags have the form `v0.1.0` and must match the file; mismatched tags fail before building.

`BUILD_NUMBER` supplies `CFBundleVersion`. Increase it for every distributed revision, including when resetting the public version. It starts at 11 because internal build 10 already existed. It is checked in rather than derived from CI run numbers, so local and CI builds have identical metadata. Supported values are 1–9999.

Use PATCH for fixes, MINOR for new functionality (and breaking changes during 0.x development), and MAJOR for the eventual stable 1.0 and later incompatible changes. Never move a published version tag; issue a new version. Earlier 1.0.x strings in validation records are historical internal labels, not public releases.

## CI and CD

`.github/workflows/ci.yml` runs on pull requests, pushes to `main`, `v*` tags, and manual dispatch. Its `macos-15` Apple Silicon job:

1. Validates metadata and native architecture; records the Xcode and Swift versions.
2. Runs release-mode core tests.
3. Builds both bundles and packages the PKG and ZIP.
4. Expands the PKG without installing it, checking versions, target paths, architecture, signatures, OS requirements, and checksums.
5. Uploads downloads and logs as workflow artifacts.

A separate job with `contents: write` publishes a GitHub Release only after a successful tag build. It downloads the exact tested artifacts, creates a draft, uploads assets, then publishes. A failed upload leaves a draft for retry. Branch, PR, and manually dispatched runs only produce artifacts. No custom secrets are needed; publication uses the repository's `GITHUB_TOKEN`.

The hosted runner is selected explicitly rather than using `macos-latest`; the runner's default Xcode can still change. Runner architecture is documented in [GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

CI does not claim visual or installed-system-host validation. Run `./script/verify.sh` in a local graphical session for lifecycle and screenshot checks, then complete the manual checks in [ACCEPTANCE.md](ACCEPTANCE.md) separately.

## Publish a version

1. Update `VERSION`, increment `BUILD_NUMBER`, and update `CHANGELOG.md`, `docs/RELEASE-NOTES.md`, and README's current version/examples.
2. Run `swift test -c release`, `./script/package.sh`, and `./script/verify-package.sh`.
3. Commit and merge the changes to `main`; confirm CI is green.
4. Create and push the matching annotated tag:

```sh
git tag -a v0.1.0 -m "ThreeBody 0.1.0"
git push origin v0.1.0
```

Use the new version instead of `0.1.0` on later releases. Tags should point to reviewed commits on `main`; configure repository rules to protect `main` and release tags if needed. The workflow files must be pushed to GitHub before they can run.

## Artifacts and installation

`./script/package.sh` creates `dist/ThreeBody-VERSION-macos-arm64.pkg`, `.zip`, and `.sha256`. `--no-build` reuses bundles only after checking versions and signatures. Diagnostic builds are rejected. Build outputs are ignored by Git.

The PKG is restricted to Apple Silicon and macOS 14+, installs system-wide, and contains no installer scripts. Bundles are non-relocatable so upgrades target `/Applications/ThreeBodyPreview.app` and `/Library/Screen Savers/ThreeBody.saver` rather than copies elsewhere. Packaging and verification never install anything. The ZIP includes both bundles and documentation.

Check a download from its directory:

```sh
shasum -a 256 -c ThreeBody-0.1.0-macos-arm64.sha256
```

Keep both the PKG and ZIP beside the checksum file when checking it. Checksums detect corruption; they are not Developer ID signatures.

## Signing status

Current builds use ad-hoc code signatures; the installer is unsigned and no notarization occurs. This produces development artifacts, not a Gatekeeper-approved external distribution. Downloaded artifacts may be blocked.

To add trusted distribution, configure Developer ID Application signing for both bundles, assess hardened runtime compatibility with the saver host, sign the installer with Developer ID Installer, submit it through `notarytool`, staple the accepted ticket, then validate a downloaded package on a clean Mac. Certificates and notarization credentials are not available or configured by this workflow. Do not disable Gatekeeper to compensate.

## Moving from a per-user installation

A running `legacyScreenSaver` process may retain the old module and its original bundle URL even after System Settings is closed. Moving `~/Library/Screen Savers/ThreeBody.saver` while that module is loaded can leave it unable to locate its resources, producing black output. Installing a valid system-wide package does not unload the earlier library.

Keep the original path available during migration. On the development Mac, after the old per-user bundle had been backed up, a compatibility symlink from `~/Library/Screen Savers/ThreeBody.saver` to `/Library/Screen Savers/ThreeBody.saver` restored the existing host's resource access. This is one installed bundle with a second path, not a second binary copy. Do not overwrite an existing bundle or unrelated symlink blindly.

For a clean transition, finish work and log out/in after installing the system-wide package; remove only the compatibility link once the old host is gone, then select the system-wide ThreeBody if necessary. Do not terminate the system host from the installer or alter lock/security settings. Reopen System Settings to refresh a cached gallery thumbnail.

After migration, verify visible motion in System Settings and in a real fullscreen ScreenSaverEngine session. Package/signature checks and standalone preview rendering do not establish that the installed host is working.
