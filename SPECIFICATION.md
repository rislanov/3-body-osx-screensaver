# ThreeBody: cinematic macOS screensaver specification

This is the English edition of the original product brief. Requirements describe the intended product, not completed verification. See [the acceptance report](docs/ACCEPTANCE.md) for actual results and outstanding checks.

## 1. Objective and priorities

Build a complete native macOS screensaver with a live three-body simulation. Deliver polished motion, expressive trails, soft light, and a calm composition. A teaching demo, technical prototype, or video loop is insufficient.

Priorities: image and motion quality, reliable screensaver operation, energy efficiency, then additional settings. Working physics and installation are necessary but do not establish product readiness.

Visual direction: three luminous stars in cyan, rose, and gold against an almost black blue background; thin fading trails; a perspective grid below, with gravitational depressions. This description defines the visual direction without an external reference image.

Initial decisions: Swift and Metal, Apple Silicon, two visual modes, no sound. Resolve minor ambiguities independently and document choices in the README. Avoid unnecessary scope expansion.

## 2. Platform and deliverables

- Primary platform: Apple Silicon; baseline target hardware: MacBook Pro M1 Pro.
- Deployment target: macOS 14.0. Validate each later OS version separately; a deployment target is not a tested compatibility claim.
- Deliver `ThreeBody.saver` and `ThreeBodyPreview.app`, sharing physics, rendering, visualization settings, and scene logic.
- Use ScreenSaver.framework and AppKit for the host, Metal/MetalKit for rendering. SwiftUI is acceptable for settings or the preview window, not per-frame rendering.
- Keep the Swift physics core independent of UI and Metal. Intel, the App Store, and desktop live wallpaper are outside the first release.
- Work entirely offline: no WebView, Electron, Python runtime, remote resources, analytics, accounts, or background service.

A web wrapper would simplify prototyping, and a video loop would guarantee a predetermined image. Native live simulation is chosen because quality control, resource use, and screensaver behavior matter more than prototype convenience.

## 3. Art direction

Aim for a restrained scientific visualization suitable for a large display: generous dark space, small bright objects, and no visual clutter.

| Element | Starting palette |
|---|---|
| Background | Almost black with deep blue, approximately `#03050D` |
| Star A | Cool cyan, `#64DFFF` |
| Star B | Muted rose, `#FF7FA8` |
| Star C | Warm gold, `#FFD58A` |
| Field | Very dark blue-violet, much dimmer than the stars |

**Stars:** compact bright cores, colored coronas, and broad faint halos. Subtle procedural surface variation is optional. They should read as light sources, not flat circles. Overlapping glow must preserve color rather than becoming a white patch.

**Trails:** a thin bright section near the star, smoothly fading and tapering toward the end. Start with 12–25 seconds of history at 1×, with adjustable length and intensity. Store world-space points so trails follow the camera correctly. Sampling density and fading must be independent of FPS. Use a bounded ring buffer. Avoid steps, gaps, and sharp curve artifacts; do not substitute a blurred previous frame.

**Background:** a soft dark gradient, optionally with a few faint distant stars. No bright nebulae, flying dust, continuous flicker, or hyperspace motion.

**Composition:** large enough to read at a distance, with margins and attention centered on interactions. Support 16:10, 16:9, 21:9, and small system previews without stretching.

Do not show text, logos, clocks, equations, legends, FPS, or controls by default.

## 4. Two complete visual modes

### Gravity Fabric, the default

Place stars and trails above a fine perspective grid with smoothly changing depressions. Motion and field must form one scene, not separate widgets.

- Show planar physics through a slightly tilted camera; the stars' visual height above the grid is decorative.
- Field sources and stars use the same planar coordinates.
- Derive grid height from summed gravitational potentials. Normalize and clamp depth only in visualization.
- Use subtle local color to connect each star with its field region.
- Keep the grid secondary to stars and trails, fading into the distance and toward the edges.
- Antialias and suppress moiré. The moving grid must not flicker or become a dense bright fence.

This is an artistic depiction of Newtonian potential, not general relativity. Grid deformation does not affect physics; do not invent gravitational waves.

### Cinematic

Use the same stars and physics without the grid: clean dark space, expressive trails, and light. This is a finished composition, not a debug mode.

Both modes are required. Do not silently drop Gravity Fabric because it is more difficult.

## 5. Motion, camera, and scene transitions

- Keep the camera almost stationary, with gentle center-of-mass tracking and bounded scale adjustment. Avoid jolts, continuous rotation, shaking, or abrupt zooms.
- Apply hysteresis and scale-rate limits so each close approach does not make the camera visibly breathe.
- Show a meaningful composition within two seconds. Precompute a bounded initial state and short trail history if needed; do not perform an expensive search at startup.
- Prepare at least eight qualified initial configurations: expressive chaotic episodes, interacting pairs with a third star, and a separate periodic figure eight.
- Auto alternates configurations without immediate repetition. Target 90–240 seconds of active display per episode. Define display-time conversion to simulation units and qualify the full maximum physical horizon, including 2× speed.
- Figure Eight also uses finite episodes and gentle renewal. Rounded initial conditions do not imply exact infinite periodicity.
- Preserve reproduction by preset, seed, and parameters. Do not promise mathematical uniqueness on every launch.
- End an episode when a body persistently escapes, composition deteriorates, or numerical safety limits are reached. Do not follow an escape with unlimited zoom-out.
- Fade stars, trails, and field out, replace state in darkness, then fade in. Target 2.5–4 seconds total. Keep the dark background continuous and never overlay two triples.
- No invisible walls, restoring springs, artificial central attraction, visible teleportation, or velocity changes for appearance.

Generating arbitrary random systems is optional after the main modes are complete. Bound search time and attempts, keep it outside the critical path, and guarantee a qualified-preset fallback.

The subsequent product refinement requires randomized starts by default. Random rotation of a qualified trajectory is acceptable; fixed-seed replay must remain available.

## 6. Physics and numerical stability

- Exactly three mutually gravitating masses. Planar Newtonian dynamics rendered in 3D is sufficient.
- Dimensionless units with `G = 1`; CPU calculations in `Double`, conversion to `Float` only at the rendering boundary. Do not label time or velocity with physical units without defining a scale.
- Start with fixed-step velocity Verlet/leapfrog. Choose the step from tests, not FPS. Another method requires justification and equivalent validation.
- Separate physics stepping from rendering with a bounded accumulator and interpolation. Quality settings and 30/60 FPS must not change equations or preset parameters.
- Bound catch-up work under load; slowing the presentation is safer than taking a large unstable step. After sleep, discard elapsed wall time rather than simulating hours of absence.
- Chaotic scenes may use a small explicit softening value, consistent in acceleration and potential energy, fixed during an episode, and documented.
- Validate the reference figure eight with published initial conditions and the original unsoftened force law. Do not call a softened variant an exact periodic orbit. Grid smoothing is independent of physical softening.
- Identical preset, seed, step, and time must reproduce within numerical tolerance. Cross-platform bitwise identity is unnecessary.
- Check positions, velocities, accelerations, and energy for finiteness. Prevent NaN, infinity, and unbounded storage; do not hide errors with energy or velocity corrections.

## 7. Rendering and performance

- Use linear color blending, controlled bloom, and final SDR tone mapping. An attractive ordinary SDR display is mandatory; HDR/EDR is not a first-release dependency.
- Reduce bloom resolution while retaining sufficient resolution for star cores, trails, and grid. Check dark-gradient banding, halos, trail intersections, and thin lines.
- Do not use heavy ray tracing or a large 3D engine for three objects.
- Offer Auto, High, and Low quality. On battery, Auto prefers 30 FPS and cheaper postprocessing while preserving simulation speed when computational capacity permits.
- M1 Pro targets, one active display on AC: Auto at 60 FPS through 4K; stable 30 FPS at 5K, with 60 FPS a stretch target. These are requirements to measure, not assumed achievements.
- Publish actual FPS, p95 frame time, memory, and conditions: hardware, OS, resolution, mode, settings, and power source. Optimize bloom, grid, and buffers first if targets are missed, then disclose limitations.
- Bound trail points, GPU resources, and concurrent commands. Memory must not grow with runtime after warmup.
- After stop, submit no new frames and advance no simulation. Complete already-submitted GPU work correctly; restarting must not add rendering loops.

## 8. macOS integration

- Implement a real `ScreenSaverView`: initialization, `startAnimation()`, `animateOneFrame()`, `stopAnimation()`, and native settings. Handle repeated starts/stops and late callbacks.
- Use one rendering clock in the saver: the system callback explicitly draws a paused `MTKView`. The preview may use its own loop; never run both clocks together.
- Persist saver settings with a dedicated `ScreenSaverDefaults` identifier. Preview uses the same schema and defaults; shared storage is optional. Support configuration import/export for reproduction.
- Load shaders and resources from the product's own bundle, not an assumed `Bundle.main`. Both products must work without the source checkout or a particular working directory.
- Give each screensaver view independent simulation and renderer state. First-release displays show independent scenes, not one stretched canvas.
- Handle Retina/backing scale, resize, small previews, missing drawables, display connection changes, and sleep/wake. Check size and visibility independently of `isPreview`; skip zero-size frames.
- Do not intercept passwords, locking, or global keys. macOS handles dismissal. The product must not request Accessibility, Screen Recording, or other unnecessary permissions.
- No private APIs, security changes, sudo, daemons, or global patches to make the product run. Do not call `exit(0)` or kill the system host to repair lifecycle behavior. Document remaining OS-specific defects as support limitations.

## 9. Settings and preview app

Keep settings simple and defaults attractive:

- Gravity Fabric / Cinematic.
- Auto / Chaotic / Figure Eight.
- Speed 0.5× / 1× / 2×.
- Trail length, glow intensity, and grid brightness.
- Auto / High / Low quality.
- Reset to defaults.

The preview additionally provides fullscreen, pause, restart, next preset, fixed seed, and hidden-by-default diagnostics. Support reproducible preset/seed/frame-size launches for testing and capture. Shortcuts apply only to the preview, never to the system screensaver.

## 10. Validation and acceptance

**Physics and logic:** automate pair-force symmetry, momentum conservation, reproducibility, trail lifetime and capacity, transitions, and long-pause behavior. Compare 30 and 60 FPS schedules at the same simulation time.

For a nondegenerate two-body test over 100 periods and the reference figure eight over 20 periods, require an initial energy threshold of `max |E(t) − E(0)| / (K(0) + |U(0)|) ≤ 10⁻⁴`. This is a test normalization, not an infinite-horizon comparison of chaotic trajectories. Check figure-eight return after one period with a documented spatial tolerance. Obtain initial conditions and period from primary sources and account for fixture precision.

Run every included preset, including Figure Eight, over its full episode duration at every supported speed. Verify finite state, suitable composition, and safe boundary exits. The 20-period test does not replace this qualification. Close-approach and escape tests must exercise safe termination rather than hide failures.

**Visuals:** supply at least three real renderer captures: Gravity Fabric overview, close approach, and Cinematic. Include 30–60 seconds of motion video with an episode transition. Do not substitute generated artwork. Inspect the material and correct visible defects.

Reject results that look like three plain circles with lines, lose color to bloom, have dominant or flickering grids, visibly stepped trails, jerky cameras, routine edge clipping, or prolonged empty scenes. A beautiful still does not compensate for poor motion.

**System behavior:** test the installed saver, not just the preview: system preview, fullscreen, exit, restart, settings, and sleep/wake. Complete at least 20 system start/stop cycles and 60 minutes continuously. Test two monitors when available and disclose when unavailable.

## 11. Implementation sequence

1. Check macOS/Xcode availability and whether a minimal Metal saver loads. Identify platform blockers immediately.
2. Build the shared renderer and preview. Complete a visual slice: star, trail, correct three-body motion, light, then grid. Do not start with an elaborate settings menu.
3. Integrate tested physics, the scene library, and smooth transitions. Replace any temporary light-tuning animation entirely with real simulation.
4. Refine both modes, camera, antialiasing, and dark tones. Capture and inspect video.
5. Complete system integration, settings, resource management, optimization, acceptance checks, fixes, and packaging.

Do not stop at the first compiling prototype. Artistic refinement is required.

## 12. Delivery

- Source and a reproducible project with build and test commands.
- On an available Mac, verified saver and preview bundles in an archive.
- README covering build, installation/removal of this module only, settings, architecture, physical assumptions, preset sources, tested OS versions, and limitations.
- Test, performance, and visual reports with captures and video.
- Clearly distinguish development builds from signed/notarized distribution. Do not assume Developer ID credentials or equate ad-hoc signing with notarization. Do not disable Gatekeeper or install/enable the saver automatically without separate user authorization.

Without macOS or a Mac runner, prepare source and available tests, but do not claim bundles were built, installed, or verified. List remaining Mac checks. Separate implemented, verified, and unverified work in reports.

The main criterion is a screensaver worth leaving on for its motion, light, and composition. A technically functional draft does not meet this brief.

## Primary technical references

- [Apple Screen Saver](https://developer.apple.com/documentation/screensaver)
- [Apple ScreenSaverView](https://developer.apple.com/documentation/screensaver/screensaverview)
- [Apple MTKView](https://developer.apple.com/documentation/metalkit/mtkview)
- [Richard Montgomery, UCSC: figure-eight initial conditions and orbit material](https://people.ucsc.edu/~rmont/Nbdy/NbdyB.html)

Check API availability and signing requirements against the installed SDK and Apple documentation before implementation. Study third-party projects if useful, but do not copy code or assets without checking their licenses.
