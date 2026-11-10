import Foundation

public struct V2: Equatable, Codable, Sendable {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
  public static let zero = V2(0, 0)
  public var lengthSquared: Double { x * x + y * y }
  public var length: Double { sqrt(lengthSquared) }
  public var isFinite: Bool { x.isFinite && y.isFinite }
  public static func + (a: Self, b: Self) -> Self { V2(a.x + b.x, a.y + b.y) }
  public static func - (a: Self, b: Self) -> Self { V2(a.x - b.x, a.y - b.y) }
  public static prefix func - (a: Self) -> Self { .zero - a }
  public static func * (a: Self, b: Double) -> Self { V2(a.x * b, a.y * b) }
  public static func / (a: Self, b: Double) -> Self { a * (1 / b) }
  public func rotated(_ angle: Double) -> Self {
    V2(x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle))
  }
}
public struct Body: Equatable, Codable, Sendable {
  public var position: V2
  public var velocity: V2
  public var mass: Double
  public init(position: V2, velocity: V2, mass: Double = 1) {
    self.position = position
    self.velocity = velocity
    self.mass = mass
  }
}
public struct Physics: Sendable {
  public static let dt = 1.0 / 2400.0
  public var bodies: [Body]
  public let softening: Double
  public private(set) var time = 0.0
  public init(bodies: [Body], softening: Double) {
    self.bodies = bodies
    self.softening = softening
  }
  public func accelerations() -> [V2] {
    var a = Array(repeating: V2.zero, count: bodies.count)
    for i in bodies.indices {
      for j in (i + 1)..<bodies.count {
        let d = bodies[j].position - bodies[i].position
        let r2 = d.lengthSquared + softening * softening
        let force = d / (r2 * sqrt(r2))
        a[i] = a[i] + force * bodies[j].mass
        a[j] = a[j] - force * bodies[i].mass
      }
    }
    return a
  }
  public mutating func step() {
    let a = accelerations()
    let h = Self.dt
    for i in bodies.indices {
      bodies[i].position = bodies[i].position + bodies[i].velocity * h + a[i] * (0.5 * h * h)
      bodies[i].velocity = bodies[i].velocity + a[i] * (0.5 * h)
    }
    let b = accelerations()
    for i in bodies.indices { bodies[i].velocity = bodies[i].velocity + b[i] * (0.5 * h) }
    time += h
  }
  public var kinetic: Double { bodies.reduce(0) { $0 + 0.5 * $1.mass * $1.velocity.lengthSquared } }
  public var potential: Double {
    var u = 0.0
    for i in bodies.indices {
      for j in (i + 1)..<bodies.count {
        u -=
          bodies[i].mass * bodies[j].mass
          / sqrt((bodies[j].position - bodies[i].position).lengthSquared + softening * softening)
      }
    }
    return u
  }
  public var energy: Double { kinetic + potential }
  public var energyScale: Double { kinetic + abs(potential) }
  public var momentum: V2 { bodies.reduce(.zero) { $0 + $1.velocity * $1.mass } }
  public var center: V2 {
    bodies.reduce(.zero) { $0 + $1.position * $1.mass } / bodies.reduce(0) { $0 + $1.mass }
  }
  public var isFinite: Bool {
    bodies.allSatisfy { $0.position.isFinite && $0.velocity.isFinite }
      && accelerations().allSatisfy(\.isFinite) && energy.isFinite
  }
  public var minSeparation: Double {
    var result = Double.infinity
    for i in bodies.indices {
      for j in (i + 1)..<bodies.count {
        result = min(result, (bodies[i].position - bodies[j].position).length)
      }
    }
    return result
  }
}
