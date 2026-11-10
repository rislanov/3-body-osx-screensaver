# Recorded validation

The `1.0.x` names are historical internal development labels from before public versioning began at `0.1.0`. They have not been renamed or presented as new release measurements.

These files preserve results from the development Mac; they are not automatically regenerated badges or a claim that every platform passes.

- [0.1.3 black-preview regression](black-preview-0.1.3.md): installed Settings preview and two user-confirmed fullscreen sessions.
- `core-tests-1.0.9.log`: 15 core tests, including randomized launch and deterministic replay.
- `lifecycle-1.0.9.log`: 20 bundle-harness cycles. This is not the system-host cycle count.
- `soak-1.0.9.json`: five-minute system-host observation, three starting seeds, and post-exit memory results.

Raw process dumps, memory graphs, installed bundles, and administrative power logs are intentionally local, ignored artifacts. Reproduce core tests with `swift test -c release` and the bundle harness with `./script/verify.sh`. System-host tests require an installed saver and manual lock/unlock observation; they are not performed by the verification script.
