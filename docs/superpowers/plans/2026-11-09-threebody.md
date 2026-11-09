# ThreeBody Implementation Plan

**Goal:** Native cinematic three-body screensaver and companion preview, following SPECIFICATION.md.
**Architecture:** Shared pure Swift dynamics and bounded scene state. Shared Metal renderer with HDR intermediate, half-resolution bloom and SDR composite. Thin AppKit and ScreenSaver hosts with explicit ticking.
**Tech Stack:** Swift, Metal, AppKit, ScreenSaver, macOS 14+, arm64. No external dependencies.
**Spec:** ../../../SPECIFICATION.md

## Constraints and decisions
- G=1, Double velocity Verlet; frame-independent fixed steps; softening only for non-reference scenes.
- Eight curated presets, deterministic rotation by seed; 120–180 second episodes, 0.18 simulation units per display second at 1x.
- Independent renderer per view; no automatic installation, no system protection changes.
- Build using installed SDK and swiftc; SwiftPM for core tests. Local development ad-hoc signing only.
- Default gravity fabric, calm camera, cyan/rose/gold stars; no text in saver.

## Work
- [x] Physics: Core/Physics.swift, Presets.swift; tests pair forces, momentum, two-body 100 periods, eight 20 periods and return, deterministic state.
- [x] Scene: Core/Scene.swift, Settings.swift; tests fixed-step schedules, bounded trails, transitions, sleep gaps, full preset horizons at 0.5/1/2x.
- [x] Renderer: Rendering/Renderer.swift and Shaders.metal; render smoke tests and actual offscreen captures; inspect fabric, close approach, cinematic and transition video.
- [x] Hosts: Preview/main.swift, Saver/ThreeBodyView.swift, Rendering/SettingsPanel.swift; native controls, import/export, lifecycle harness; build app and saver.
- [x] Delivery: reproducible build/run/test scripts, actual metrics, archive, README and acceptance report. Clearly separate implemented, verified, and hardware/system checks not performed.

## Review focus
Malformed imported settings must clamp safely. Sleep gaps must not catch up. Late callbacks must not advance stopped saver. No drawable/zero sizes must skip GPU work. Finite but escaping trajectories must fade before losing composition.

Updated verification: installation, three successive fullscreen launches, randomized starts, and a five-minute installed run passed on the development Mac. Twenty system-host cycles, a 60-minute run, sleep/wake, and additional hardware remain unverified; see docs/ACCEPTANCE.md. The build does not auto-install.
