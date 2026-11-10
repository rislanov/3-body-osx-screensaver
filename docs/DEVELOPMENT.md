# Development guide

See [README](../README.md) for prerequisites and build commands, and [RELEASING](RELEASING.md) for packaging.

## Reproduce and capture

```sh
open -n dist/ThreeBodyPreview.app --args --preset eight --seed 42 --size 1440x900
open -n dist/ThreeBodyPreview.app --args --preset binary --seed 17 --mode cinematic
open -n dist/ThreeBodyPreview.app --args --preset eight --seed 42 --time 12 --size 1920x1200 --snapshot "$PWD/artifacts/eight.png"
open -n dist/ThreeBodyPreview.app --args --capture "$PWD/artifacts/visual" --size 1920x1200
open -n dist/ThreeBodyPreview.app --args --lifecycle-test --log "$PWD/artifacts/lifecycle.log"
open -n dist/ThreeBodyPreview.app --args --benchmark 60 --pixels 3840x2160 --log "$PWD/artifacts/benchmark.json"
```

`--capture` creates three real production-renderer PNGs plus a 40-second 1280×800/30fps H.264 movie. `--no-video` skips the movie. The movie requests transitions at 18 s and 28 s, switching to Cinematic in darkness at 29.5 s. Offline capture is **not** an FPS benchmark. The capture workflow searches an existing deterministic trajectory for a close-approach image; runtime scene startup never performs that search.

`--pixels` fixes the Metal surface size independently of the window's point size for benchmarks. Benchmark mode renders into an offscreen production texture even when the window is occluded; ordinary preview pauses when hidden. Results measure actual submitted frame cadence and GPU command duration, not a guarantee about physical display presentation. Benchmark runs include a three-second warmup. Full metadata and limitations are in [the acceptance report](ACCEPTANCE.md).

## Architecture

- `Sources/Core`: Double-precision dynamics, presets, bounded trail history, settings, camera and episode state. Foundation only; no UI/Metal dependency.
- `Sources/Rendering`: shared Metal renderer, shaders, native settings panel. RGBA16Float linear HDR intermediate, additive stars/trails, analytic line antialiasing, reduced-resolution separable bloom, SDR tone mapping and sRGB output with stationary dithering.
- `Sources/Saver`: thin `ScreenSaverView` subclass, one system animation callback, explicit draw into a paused `MTKView`, independent state per view.
- `Sources/Preview`: AppKit host, controls, production-renderer capture, benchmark and standalone bundle lifecycle harness.

GPU work is capped at three in-flight commands. Vertex buffers are reused; trails have at most 1,600 samples shared across the three stars. Render target replacement drains the queue. Stopping the saver gates late callbacks, clears the wall clock, drains submitted work, and releases the renderer and Metal view. A separate 0.5-second lifecycle check observes the bound engine process; it never drives rendering. Ended sessions cannot restart retained views. The solid background uses updateLayer() to avoid a bitmap backing store. Zero-size/no-window/no-drawable frames are skipped. Each display gets an independent scene.

Auto requests 30 FPS on battery/Low Power Mode or above 8.4 million pixels, otherwise 60 FPS. Low uses 30 FPS and quarter-size bloom; High requests 60 FPS. Auto/High normally use half-size bloom. The equations and fixed physics step are unchanged by render quality.

## Physics and scenes

G = 1, masses = 1, unitless planar dynamics. Velocity Verlet, fixed step **1/2400**, CPU Double, Float only at the renderer boundary. One active display second maps to **0.18 simulation time units × speed**. An accumulator is capped at 0.09 simulation units / 216 steps per callback. Gaps above 250 ms discard wall-clock catch-up. Rendering interpolates the previous and current physical states. No artificial forces, walls, energy corrections, or velocity adjustments.

Reference `eight` uses the unsoftened inverse-square law. Its rounded initial conditions are the Simó fixture published by [Richard Montgomery at UCSC](https://people.ucsc.edu/~rmont/Nbdy/NbdyB.html). Period **6.32591398** is given in Figure 1 of [Chenciner & Montgomery, Annals of Mathematics 152 (2000), 881–901](https://arxiv.org/pdf/math/0011268). The UCSC fixture is the paper's configuration rotated by π. The return test allows 0.001 world units because the fixture is rounded and sampling uses a fixed step; this is not a claim of exact infinite periodicity.

Original curated configurations:

| ID | Character | Maximum active seconds |
|---|---|---:|
| `eight` | Reference figure eight, no softening | 150 |
| `ribbon` | Small velocity perturbation of the eight | 120 |
| `tide` | Perturbed exchange | 135 |
| `ember` | Stronger asymmetric exchange | 150 |
| `drift` | Chaotic perturbation | 165 |
| `binary` | Interacting close pair and companion | 180 |
| `satellite` | Wider companion | 180 |
| `exchange` | Eccentric hierarchical triple | 180 |

All except `eight` use Plummer softening ε = **0.055**, consistently in acceleration and potential energy. The seven artistic presets are original configurations here, not claimed published periodic orbits. Seed controls orientation and deterministic sequence, not a promise of unique mathematics. Auto avoids immediate repeats. Figure Eight restarts in finite episodes. A 1.8-unit deterministic warmup provides ten display-seconds-equivalent of initial history.

Trails are sampled every 12 physics steps (0.005 simulation units), in world coordinates; fade duration at 1× is 8–25 active seconds. At 0.5× / 2×, physical trail history lasts twice / half as long in display time. Trail density and lifetime do not depend on 30 vs 60 FPS.

Episodes fade out for 1.5 s, replace all state in darkness, and fade in for 1.5 s. Only three bodies are drawn. They end on duration, separation below 0.025, radius above 5.5, a star leaving the projected 87% composition envelope, non-finite state or normalized energy error above 0.002. Some binary/chaotic configurations reach a safety boundary before their nominal duration, particularly at 2×; this is an intentional safe exit, recorded by qualification tests. No escaping body is followed with unlimited zoom-out.

Camera center follows the center of mass slowly. Scale correction has an 8% outward / 22% inward hysteresis band and rate limits. Gravity Fabric is a decorative embedding of the summed potential with independent visual smoothing and bounded depth. It is not general relativity, and never feeds back into dynamics.


## Screen saver gallery thumbnail

`Resources/thumbnail.png` (480×312) and `thumbnail@2x.png` (960×624) provide the System Settings gallery artwork. The saver bundle declares `ScreenSaverThumbnail`; this is separate from the app icon and live preview. Regenerate the illustrative three-body figure eight with `swift script/make_thumbnail.swift Resources`. Package verification checks the metadata and both PNG dimensions.
