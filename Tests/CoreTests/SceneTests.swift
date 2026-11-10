import XCTest

@testable import ThreeBodyCore

final class SceneTests: XCTestCase {
  func testLaunchRandomnessAndReplay() throws {
    let a = Scene.launch(settings: Settings(), randomSeed: 123)
    let b = Scene.launch(settings: Settings(), randomSeed: 987)
    XCTAssertNotEqual(a.physics.bodies, b.physics.bodies)
    XCTAssertEqual(a.physics.energy, b.physics.energy, accuracy: 1e-9)
    let replay = Scene.launch(settings: a.replaySettings, randomSeed: 999)
    XCTAssertEqual(a.physics.bodies, replay.physics.bodies)
    var fixed = Settings()
    fixed.randomizeStart = false
    XCTAssertEqual(
      Scene.launch(settings: fixed, randomSeed: 123).physics.bodies,
      Scene.launch(settings: fixed, randomSeed: 987).physics.bodies)
    var legacy =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as! [String: Any]
    legacy.removeValue(forKey: "randomizeStart")
    let decoded = try JSONDecoder().decode(
      Settings.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertNotEqual(
      Scene.launch(settings: decoded, randomSeed: 123).physics.bodies,
      Scene.launch(settings: decoded, randomSeed: 987).physics.bodies)
  }

  func testSchedulesAndLongPause() {
    let a = Scene(seed: 42, presetIndex: 0)
    let b = Scene(seed: 42, presetIndex: 0)
    for _ in 0..<600 { a.advance(seconds: 1 / 60) }
    for _ in 0..<300 { b.advance(seconds: 1 / 30) }
    for j in 0..<3 {
      XCTAssertLessThan((a.physics.bodies[j].position - b.physics.bodies[j].position).length, 1e-10)
    }
    let before = a.physics.bodies
    a.advance(seconds: 3600)
    XCTAssertEqual(before, a.physics.bodies)
  }
  func testTrailsAndTransitions() {
    let s = Scene(seed: 5, presetIndex: 0)
    for _ in 0..<3600 { s.advance(seconds: 1 / 30) }
    XCTAssertLessThanOrEqual(s.trails.count, TrailBuffer.capacity)
    XCTAssertLessThanOrEqual(
      s.physics.time - s.trails.samples.first!.time,
      s.settings.trailSeconds * Scene.unitsPerSecond + 0.02)
    s.next()
    s.advance(seconds: 0.1)
    XCTAssertLessThan(s.opacity, 1)
    for _ in 0..<16 { s.advance(seconds: 0.1) }
    XCTAssertNotEqual(s.presetIndex, 0)
    for _ in 0..<20 { s.advance(seconds: 0.1) }
    XCTAssertEqual(s.opacity, 1, accuracy: 1e-9)
  }
  func testPresetHorizons() {
    for index in Preset.catalog.indices {
      for speed in [0.5, 1.0, 2.0] {
        var settings = Settings()
        settings.speed = speed
        let scene = Scene(settings: settings, seed: 17, presetIndex: index)
        let initialGeneration = scene.generation
        var elapsed = 0.0
        while elapsed < Preset.catalog[index].duration + 4 && scene.generation == initialGeneration
        {
          scene.advance(seconds: 1 / 30)
          elapsed += 1 / 30
          XCTAssertTrue(scene.physics.isFinite)
          XCTAssertLessThan(scene.radius, 8)
        }
        XCTAssertGreaterThan(scene.generation, initialGeneration)
        print(
          "qualified \(Preset.catalog[index].id) speed=\(speed) first episode=\(elapsed) reason=\(scene.lastTransitionReason)"
        )
      }
    }
  }
  func testRestartReplaysTheSameEpisode() {
    let s = Scene(seed: 123, presetIndex: 1)
    let initial = s.physics.bodies
    for _ in 0..<120 { s.advance(seconds: 1 / 30) }
    s.restart()
    XCTAssertEqual(initial, s.physics.bodies)
  }
  func testFullRawPhysicalHorizons() {
    for p in Preset.catalog {
      for speed in [0.5, 1.0, 2.0] {
        var s = Physics(bodies: p.bodies, softening: p.softening)
        let horizon = 1.8 + p.duration * Scene.unitsPerSecond * speed
        while s.time < horizon { s.step() }
        XCTAssertTrue(s.isFinite, "Full raw horizon: \(p.id) \(speed)")
      }
    }
  }
  func testCinematicKeepsBodiesInsideFrame() {
    var settings = Settings()
    settings.mode = .cinematic
    for index in [5, 6] {
      let s = Scene(settings: settings, seed: 17, presetIndex: index)
      let generation = s.generation
      for _ in 0..<5400 {
        s.advance(seconds: 1 / 30)
        if s.generation != generation { break }
        for body in s.physics.bodies {
          let p = body.position - s.cameraCenter
          let perspective = 1 / max(0.5, 1 - p.y * 0.12 - 0.42 * 0.03)
          let y = (0.42 * 0.84 - p.y * 0.86) * 1.48 / s.cameraScale * perspective - 0.40
          XCTAssertLessThan(abs(y), 0.95)
        }
      }
    }
  }
  func testCompositionAllModesSpeedsAndAspectRatios() {
    for mode in VisualMode.allCases {
      for speed in [0.5, 1.0, 2.0] {
        for aspect in [1.6, 16.0 / 9, 21.0 / 9] {
          for index in Preset.catalog.indices {
            var settings = Settings()
            settings.mode = mode
            settings.speed = speed
            let s = Scene(settings: settings, seed: 17, presetIndex: index)
            s.viewportAspect = aspect
            let generation = s.generation
            for _ in 0..<5500 {
              s.advance(seconds: 1 / 30)
              if s.generation != generation { break }
              for body in s.physics.bodies {
                let p = body.position - s.cameraCenter
                let perspective = 1 / max(0.5, 1 - p.y * 0.12 - 0.42 * 0.03)
                let x = p.x / aspect * 1.48 / s.cameraScale * perspective
                let y =
                  (0.42 * 0.84 - p.y * (mode == .fabric ? 0.58 : 0.86)) * 1.48 / s.cameraScale
                  * perspective + (mode == .fabric ? -0.14 : -0.40)
                XCTAssertLessThan(max(abs(x), abs(y)), 0.95, "\(mode) \(index) \(speed) \(aspect)")
              }
            }
          }
        }
      }
    }
  }
  func testLaterEpisodeReplay() {
    let s = Scene(seed: 42, presetIndex: 1)
    s.next()
    for _ in 0..<100 { s.advance(seconds: 1 / 30) }
    s.restart()
    let replay = Scene(settings: s.replaySettings, seed: s.replaySettings.seed)
    XCTAssertEqual(s.presetIndex, replay.presetIndex)
    XCTAssertEqual(s.physics.bodies, replay.physics.bodies)
  }
  func testSettingsSanitize() {
    var s = Settings()
    s.speed = 900
    s.trailSeconds = -5
    s.glow = .infinity
    s.sanitize()
    XCTAssertEqual(s.speed, 1)
    XCTAssertEqual(s.trailSeconds, 8)
    XCTAssertEqual(s.glow, 1)
  }
  func testUnsafeStateTerminates() {
    let s = Scene(seed: 0, presetIndex: 0)
    s.physics.bodies[0].position = s.physics.bodies[1].position
    s.advance(seconds: 1 / 30)
    XCTAssertTrue(s.isTransitioning)
    let escape = Scene(seed: 0, presetIndex: 0)
    escape.physics.bodies[0].position = V2(20, 0)
    escape.advance(seconds: 1 / 30)
    XCTAssertTrue(escape.isTransitioning)
  }
}
