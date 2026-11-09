import Foundation

public struct TrailSample: Sendable {
  public let positions: [V2]
  public let time: Double
}
public struct TrailBuffer: Sendable {
  public static let capacity = 1600
  private var storage = [TrailSample?](repeating: nil, count: capacity)
  private var head = 0
  public private(set) var count = 0
  public mutating func append(_ sample: TrailSample, cutoff: Double) {
    storage[(head + count) % Self.capacity] = sample
    if count == Self.capacity { head = (head + 1) % Self.capacity } else { count += 1 }
    while count > 1, let first = storage[head], first.time < cutoff {
      storage[head] = nil
      head = (head + 1) % Self.capacity
      count -= 1
    }
  }
  public var samples: [TrailSample] {
    (0..<count).compactMap { storage[(head + $0) % Self.capacity] }
  }
}
public final class Scene {
  public static let unitsPerSecond = 0.18
  public static func launch(
    settings: Settings, randomSeed: UInt64 = UInt64.random(in: .min ... .max)
  ) -> Scene {
    Scene(settings: settings, seed: settings.randomizeStart == false ? settings.seed : randomSeed)
  }
  public var settings: Settings
  public var physics: Physics
  public private(set) var trails = TrailBuffer()
  public private(set) var presetIndex: Int
  public private(set) var generation = 0
  public private(set) var opacity = 1.0
  public private(set) var lastTransitionReason = "initial"
  public private(set) var cameraScale = 2.8
  public private(set) var cameraCenter = V2.zero
  public private(set) var episodeTime = 0.0
  public private(set) var episodeSeed: UInt64 = 0
  public var viewportAspect = 1.6
  private var random: UInt64
  private var accumulator = 0.0
  private var previous: [Body]
  private var tick = 0
  private var initialEnergy: Double
  private var energyScale: Double
  private var transition: Double? = nil
  private var targetPreset: Int? = nil
  private var oldGeneration = 0
  public var isTransitioning: Bool { transition != nil }
  public var radius: Double {
    physics.bodies.map { ($0.position - physics.center).length }.max() ?? 0
  }
  public var positions: [V2] {
    let t = min(1, max(0, accumulator / Physics.dt))
    return zip(previous, physics.bodies).map { $0.position * (1 - t) + $1.position * t }
  }
  public init(settings: Settings = Settings(), seed: UInt64 = 42, presetIndex: Int? = nil) {
    var s = settings
    s.sanitize()
    s.seed = seed
    self.settings = s
    self.random = seed
    self.presetIndex = min(
      7, max(0, presetIndex ?? Preset.catalog.firstIndex(where: { $0.id == s.presetID }) ?? 1))
    let p = Preset.catalog[self.presetIndex]
    self.physics = Physics(bodies: p.bodies, softening: p.softening)
    self.previous = p.bodies
    initialEnergy = physics.energy
    energyScale = physics.energyScale
    reset(index: self.presetIndex)
  }
  private func reset(index: Int) {
    presetIndex = settings.scenes == .eight ? 0 : index
    let p = Preset.catalog[presetIndex]
    episodeSeed = random
    random = random &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    let angle = Double(random >> 32) / Double(UInt32.max) * 2 * Double.pi
    let b = p.bodies.map {
      Body(
        position: $0.position.rotated(angle), velocity: $0.velocity.rotated(angle), mass: $0.mass)
    }
    physics = Physics(bodies: b, softening: p.softening)
    previous = b
    initialEnergy = physics.energy
    energyScale = physics.energyScale
    trails = TrailBuffer()
    tick = 0
    accumulator = 0
    episodeTime = 0
    // A deterministic 10-second-equivalent history, bounded to 4320 steps.
    for _ in 0..<4320 {
      previous = physics.bodies
      physics.step()
      tick += 1
      if tick % 12 == 0 { recordTrail() }
    }
    cameraCenter = physics.center
    cameraScale = max(2.6, radius * (settings.mode == .cinematic ? 2.1 : 1.65))
    generation += 1
  }
  private func recordTrail() {
    trails.append(
      TrailSample(positions: physics.bodies.map(\.position), time: physics.time),
      cutoff: physics.time - settings.trailSeconds * Self.unitsPerSecond)
  }
  public func next(index: Int? = nil, reason: String = "requested") {
    guard transition == nil else { return }
    targetPreset = index
    transition = 0
    oldGeneration = generation
    lastTransitionReason = reason
  }
  private func selectNext() -> Int {
    if settings.scenes == .eight { return 0 }
    random = random &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    let count = settings.scenes == .chaotic ? 7 : 8
    let base = settings.scenes == .chaotic ? 1 : 0
    var index = base + Int((random >> 32) % UInt64(count))
    if index == presetIndex { index = base + (index - base + 1) % count }
    return index
  }
  public func reseed(_ seed: UInt64) {
    random = seed
    episodeSeed = seed
    settings.seed = seed
  }
  public func restart() {
    random = episodeSeed
    transition = nil
    opacity = 1
    reset(index: presetIndex)
  }
  public var replaySettings: Settings {
    var result = settings
    result.randomizeStart = false
    result.seed = episodeSeed
    result.presetID = Preset.catalog[presetIndex].id
    return result
  }
  private func outsideComposition(_ p: V2) -> Bool {
    let p = p - cameraCenter
    let perspective = 1 / max(0.5, 1 - p.y * 0.12 - 0.42 * 0.03)
    let tilt = settings.mode == .fabric ? 0.58 : 0.86
    let offset = settings.mode == .fabric ? -0.14 : -0.40
    let x = p.x / max(0.25, viewportAspect) * 1.48 / cameraScale * perspective
    let y = (0.42 * 0.84 - p.y * tilt) * 1.48 / cameraScale * perspective + offset
    return abs(x) > 0.87 || abs(y) > 0.87
  }
  private func unsafeReason() -> String? {
    if !physics.isFinite { return "non-finite state" }
    if physics.minSeparation < 0.025 { return "close approach limit" }
    if radius > 5.5 { return "escape envelope" }
    if physics.bodies.contains(where: { outsideComposition($0.position) }) {
      return "composition envelope"
    }
    if abs(physics.energy - initialEnergy) / energyScale > 0.002 { return "energy limit" }
    return nil
  }
  public func advance(seconds delta: Double) {
    guard delta.isFinite, delta > 0, delta <= 0.25 else {
      accumulator = 0
      return
    }
    if let t = transition {
      let n = t + delta
      transition = n
      if n < 1.5 {
        opacity = 1 - smooth(n / 1.5)
      } else {
        if generation == oldGeneration { reset(index: targetPreset ?? selectNext()) }
        opacity = smooth((n - 1.5) / 1.5)
        if n >= 3 {
          transition = nil
          targetPreset = nil
          opacity = 1
        }
      }
      return
    }
    if let reason = unsafeReason() {
      next(reason: reason)
      return
    }
    episodeTime += delta
    if episodeTime >= Preset.catalog[presetIndex].duration {
      next(reason: "episode duration")
      return
    }
    accumulator = min(accumulator + delta * Self.unitsPerSecond * settings.speed, 0.09)
    var steps = 0
    while accumulator + 1e-12 >= Physics.dt && steps < 216 {
      previous = physics.bodies
      physics.step()
      accumulator -= Physics.dt
      tick += 1
      steps += 1
      if tick % 12 == 0 {
        if let reason = unsafeReason() {
          physics.bodies = previous
          next(reason: reason)
          accumulator = 0
          break
        }
        recordTrail()
      }
    }
    accumulator = max(0, accumulator)
    let target = max(2.6, min(8, radius * (settings.mode == .cinematic ? 2.1 : 1.65)))
    if target > cameraScale * 1.08 || target < cameraScale * 0.78 {
      cameraScale += max(-delta * 0.08, min(delta * 0.15, (target - cameraScale) * delta * 0.25))
    }
    cameraCenter = cameraCenter + (physics.center - cameraCenter) * min(1, delta * 0.2)
  }
  private func smooth(_ x: Double) -> Double {
    let t = min(1, max(0, x))
    return t * t * (3 - 2 * t)
  }
}
