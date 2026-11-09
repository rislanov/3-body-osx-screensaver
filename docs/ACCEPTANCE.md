# ThreeBody 1.0.9 — development acceptance report

Updated November 10, 2026. Version **1.0.9, build 10**. The installed saver passed three successive fullscreen launches and a five-minute monitored run. The user confirmed motion, different starting compositions, and no black screen in those checks. **Full acceptance against the original specification remains incomplete:** the one-hour run, 20 system-host cycles, sleep/wake, and multiple displays have not been verified.

## Test environment

MacBook Air M4, 10 CPU cores / 10 GPU cores, 24 GB RAM, built-in 2880×1864 display, macOS 26.7.2 (25G332), Xcode 26.5, battery power. Display scaling produced a 1710×1107-point saver view with a **3420×2214-pixel drawable**. Do not confuse drawable size with panel resolution.

Deployment target is macOS 14.0, arm64. M1 Pro, Intel, other macOS releases, external 4K/5K displays, and multiple monitors were not tested. Products are locally ad-hoc signed, not Developer ID signed or notarized.

The installed diagnostic build includes an opt-in probe; the normal packaged build does not. Both use the same rendering and lifecycle paths. On this machine the optional Xcode Metal compiler component was unavailable, so both products bundled shader source and compiled it offline through Metal at initialization. A partially completed toolchain download was abandoned; it is not a runtime dependency.

## Implemented behavior

Both products share physics, camera, scene state, settings, and the Metal renderer. Gravity Fabric and Cinematic include eight qualified presets, finite episodes, safety exits, and fade transitions without overlapping two triples. Rendering uses linear HDR intermediates, reduced-resolution bloom, SDR tone mapping, analytic line antialiasing, and dark-gradient dithering.

The saver uses a single system animation callback and a paused MTKView. At most three GPU commands are in flight. Trails and vertex buffers are bounded. Resources are loaded from the product's own bundle.

Native settings support JSON import/export. Random starts are enabled by default: a fresh seed rotates a qualified trajectory without changing its energy or inventing new forces. Fixed seeds and exported episode replay remain deterministic. The preview provides pause, fullscreen, next/restart, diagnostics, and production-renderer image/video capture.

## Automated verification

**15 core tests passed with no failures.** [Recorded test output](validation/core-tests-1.0.9.log).

Coverage includes:

- Pair-force symmetry, momentum conservation, and deterministic state.
- Eccentric two-body orbit (`e = 0.4`), 100 periods: maximum normalized energy error **7.10×10⁻⁸**, below the `10⁻⁴` threshold.
- Unsoftened reference figure eight, 20 periods: **3.55×10⁻⁸**, below the same threshold. One-period return tolerance is 0.001 world units, accounting for rounded initial conditions and fixed-step sampling.
- Equal physical results under 30/60 FPS schedules; a one-hour wall-clock gap does not trigger catch-up.
- Bounded trail history, lifetime, transitions, and safe close-approach/escape handling.
- All eight presets over their full maximum physical horizon, including warmup and 2× speed, with finite state.
- Runtime qualification at 0.5×/1×/2× until normal completion or a documented safety exit.
- Composition checks for eight presets × three speeds × two modes × three aspect ratios, using seed 17. Star centers remain inside 95% NDC before transition.
- Cinematic clipping, later-episode replay, randomized launch orientation, unchanged energy under rotation, fixed-seed launch, and migration of older settings JSON.

The bundle harness passed **20 cycles** while retaining stopped ScreenSaverView instances. It checks repeated start, rotating drawable IDs, stop, late callbacks, restart, zero-size handling, settings, release of renderer/MTKView weak references, and removal of owned bitmap contents/backing-store requests. [Harness output](validation/lifecycle-1.0.9.log).

The final memory regression failed against 1.0.8 and passed against 1.0.9. An earlier assertion requiring every CALayer to deallocate was corrected: a layer-backed ancestor may legitimately keep an implicit child layer. Tests instead verify owned-resource release and absence of retained bitmap content. These harness cycles are **not** 20 system-host cycles.

## Installed five-minute run and memory

The user authorized installation for the current account. After a new login session, the installed 1.0.9 ran in host PID 74792. A read-only observer sampled the same engine and host every five seconds for **300.025 seconds**, producing 61 samples. The user confirmed visible motion throughout, no black screen, and a changed starting composition. The saver continued running until the user exited manually; only the monitored window is used below.

| Elapsed time | Physical footprint |
|---:|---:|
| 0 s | 238.2 MB |
| 60 s | 238.9 MB |
| 120 s | 238.9 MB |
| 180 s | 238.9 MB |
| 240 s | 238.9 MB |
| 300 s | 238.9 MB |

Average sampled CPU usage was **5.06% of one core**, maximum 6.1%. This was a memory/lifecycle run, not a new wattage measurement. [Machine-readable summary](validation/soak-1.0.9.json).

Two additional short fullscreen launches also showed motion and different initial positions, confirmed by the user and three distinct recorded seeds. Older instances logged `ignored-ended-session` without recreating renderers. Each exit logged engine termination, stop, and resource release; CPU returned to 0.0% at the displayed precision.

Immediate post-exit footprints were **17.5 → 24.7 → 25.0 MB**. After delayed system cleanup, footprint returned to **17.6 MB**, approximately the first-exit baseline. For comparison, 1.0.8 retained 81.8 MB after three exits, including 43.9 MB of CoreAnimation buffers.

Heap analysis after the third exit found two small retained ThreeBodyView containers but no Renderer, Scene, or MTKView instances. `leaks` reported **0 leaks / 0 leaked bytes**. The two remaining NSViewBackingLayerContents objects trace through system ScreenSaverView layers and LegacyViewController/LegacyExtensionManager. After delayed cleanup, one 7488 KB buffer remained. These class names come from read-only memory-graph diagnostics; the product does not call private APIs.

The evidence supports removal of the observed owned-resource retention and stable memory in this bounded run. It is not a proof that no leak can occur under any OS, configuration, or longer workload.

## Earlier power measurement: 1.0.8

This measurement predates the 1.0.9 memory changes. Do not present it as a fresh 1.0.9 result.

The user manually ran `powermetrics` with a specifically authorized diagnostic sudo exception. That exception does not add privileged operations to the product. The third visible launch was ended manually after approximately 47 seconds. Startup, the diagnostic snapshot, and the exit were excluded. The stable window was November 9, 2026, 22:50:35–22:51:00 UTC: 24 approximately one-second samples, battery power, 3420×2214 drawable, approximately 30 FPS.

| Metric | Stable active window |
|---|---:|
| Saver host CPU | 5.19% of one core; p95 5.74% |
| Whole-chip CPU power | 0.406 W |
| Whole-chip GPU power | 0.458 W |
| GPU hardware active residency | 61.35% |

The preceding desktop baseline had 18 samples: CPU 0.308 W and GPU 0.116 W. The approximately 0.44 W combined difference is only an indication under changing background load, not isolated application power. GPU residency measures time active, not percentage of maximum compute capacity. Process GPU time was not suitable for attribution on this machine. Energy Impact is not watts.

## Earlier offscreen performance benchmarks

These are historical shared-renderer benchmarks, not current fullscreen presentation measurements. Each used three seconds of warmup and 30 seconds of measurement on the M4, on battery, with a real offscreen Metal texture and no readback.

| Texture resolution | Quality | Submitted FPS | Interval p95 | GPU p95 | Warm footprint |
|---|---|---:|---:|---:|---:|
| 3840×2160 | Auto | 30.00 | 33.36 ms | 12.55 ms | 189.7–190.9 MiB |
| 3840×2160 | High | 60.00 | 17.43 ms | 12.87 ms | 215.3–217.7 MiB |
| 5120×2880 | Auto | 30.03 | 34.12 ms | 19.63 ms | 277.6–277.8 MiB |

Interval p95 measures CPU submission cadence; GPU p95 is command-buffer GPU end time minus start time. Neither is display presentation latency. Footprint includes process memory and GPU resources charged to it. Short warm measurements do not replace a long soak. An initial benchmark using an occluded window was rejected and is excluded from these results.

## Visual evidence

These images came from the production renderer, not generated artwork:

- [Gravity Fabric overview](media/gravity-fabric.png).
- [Close approach](media/close-approach.png).
- [Cinematic](media/cinematic.png).
- [Motion contact sheet](media/motion-contact-sheet.jpg).
- [Transition contact sheet](media/transition-contact-sheet.jpg).

The earlier offline motion capture is 40 seconds, 1280×800, 30 FPS. Transitions were requested at 18 and 28 seconds; Cinematic was selected in darkness at 29.5 seconds. It uses the same physics and shaders, but is not a recording of actual display FPS. Regenerate it with the README capture command; the movie remains a local generated artifact.

Visual refinement corrected excessive upper-background grid visibility, reversed perspective convergence, overly bright trails, and Cinematic clipping. Contact sheets show one triple, a continuous background, and scene replacement during darkness. The screenshots document the visual treatment from the earlier capture, not a new 1.0.9 benchmark. Final subjective art approval remains with the owner.

## Lifecycle investigation and release history

| Version | Finding and change |
|---|---|
| 1.0.1 | Fixed static fullscreen output: bypassing MTKView.draw() reused the cached drawable. The delegate path now rotates drawables; the regression failed on the old implementation and passed after the fix. Fullscreen motion was later confirmed by the user. |
| 1.0.2 | Moved both compositions down by 12% of screen height, consistently in rendering and composition safety checks, to clear the system clock. A planned one-hour run was interrupted after about two minutes and was not counted. |
| 1.0.3 | Tried RG11B10Float HDR/bloom targets and cached power-source queries for one second. Offscreen footprint fell from 153.8–157.1 to 130.8–131.4 MiB and GPU p95 from 10.87 to 5.85 ms at 2880×1864. System fullscreen subsequently showed black; these measurements did not establish working fullscreen behavior. |
| 1.0.4 | Added opt-in diagnostics. Own-scene captures were correct despite black fullscreen output; that proved offscreen rendering, not presentation. |
| 1.0.5 | Restored RGBA16Float. Black output persisted, disproving the format as the sole cause. The built-in Flurry saver worked in the control test. |
| 1.0.6 | Transaction-based presentation made the first launch visible, but a repeat was black. The host kept rendering after exit; footprint grew from about 249 to 441 MB and CPU from 3.2% to 7.7% of one core. Power measurements in that faulty state were not accepted as normal operation. |
| 1.0.7 | Released renderer/MTKView on stop and detach, and observed the particular engine process ending through public NSRunningApplication state. Two visible launches succeeded, but logs showed the host restarted the old view as well as a new one, creating duplicate renderers. |
| 1.0.8 | Preserved the ended engine identity and rejected revival of that session. Three visible launches succeeded without duplicate renderers. Residual memory still rose to 81.8 MB, prompting the next investigation. |
| 1.0.9 | Added randomized starts and replay-safe fixed seeds. Replaced inherited bitmap drawing of the solid background with updateLayer(), cleared owned layer contents on stop, and verified release using retained-view tests and system memory analysis. Results are detailed above. |

System hosts may keep an old loaded bundle after its file is replaced. In this session, a manual logout/login was required to load updates; binary identities were checked. No system host was forcibly terminated. macOS controlled locking and the user entered passwords manually.

## Diagnostics and evidence retention

`THREEBODY_DIAGNOSTICS=1 ./script/build.sh` enables local lifecycle logs and at most six own-scene captures per host in its cache directory. It captures no screen or input and sends nothing over the network. Normal builds omit the marker. A diagnostic `presentation-mode.txt` may select transaction or async presentation without editing a signed bundle; transaction presentation is the normal saver path.

Committed evidence is limited to the summary and test logs under [validation](validation/README.md), plus selected renderer images. Raw system diagnostics remain locally under ignored `artifacts/`: historical host samples, `power-1.0.8`, and `memory-1.0.9` including the 61-sample soak, vmmap snapshots, heap graph, ownership traces, lifecycle logs, and three start captures. A clean checkout does not include memory dumps or administrative power logs.

All temporary measurement observers and caffeinate processes were stopped or completed normally.

## Outstanding acceptance checks

- Twenty complete start/stop cycles in the actual system host, distinct from the 20-cycle harness.
- A continuous 60-minute installed run; the verified run is five minutes.
- Real sleep/wake, display connection changes, and two monitors.
- M1 Pro on AC with physical 4K/5K displays and other supported macOS versions.
- Developer ID signing, notarization, and downloaded-archive validation on a clean Mac for external distribution.

The product uses no network resources, global keyboard handler, daemon, private API, or privileged runtime operation. Gatekeeper and system security settings were not weakened.
