import XCTest

@testable import ThreeBodyCore

final class PhysicsTests: XCTestCase {
  func testPairForcesAndMomentum() {
    let system = Physics(
      bodies: [
        Body(position: V2(-1, 0), velocity: .zero, mass: 2),
        Body(position: V2(1, 0), velocity: .zero, mass: 3),
      ], softening: 0.04)
    let a = system.accelerations()
    XCTAssertLessThan((a[0] * 2 + a[1] * 3).length, 1e-14)
    var s = Physics(bodies: Preset.catalog[1].bodies, softening: 0.04)
    let p = s.momentum
    for _ in 0..<50000 { s.step() }
    XCTAssertLessThan((s.momentum - p).length, 1e-10)
  }
  func testTwoBodyHundredPeriods() {
    let v = sqrt(2 * (2 / 0.6 - 1)) / 2  // eccentricity 0.4, a=1, periapsis=0.6
    var s = Physics(
      bodies: [
        Body(position: V2(-0.3, 0), velocity: V2(0, -v)),
        Body(position: V2(0.3, 0), velocity: V2(0, v)),
      ], softening: 0)
    let e = s.energy
    let norm = s.energyScale
    var drift = 0.0
    for _ in 0..<Int(100 * 2 * Double.pi / sqrt(2) / Physics.dt) {
      s.step()
      drift = max(drift, abs(s.energy - e) / norm)
    }
    print("two-body max normalized energy drift: \(drift)")
    XCTAssertLessThanOrEqual(drift, 1e-4)
  }
  func testFigureEightTwentyPeriodsAndReturn() {
    var s = Physics(bodies: Preset.catalog[0].bodies, softening: 0)
    let initial = s.bodies
    let e = s.energy
    let norm = s.energyScale
    let period = 6.32591398
    var drift = 0.0
    for i in 1...Int(20 * period / Physics.dt) {
      s.step()
      drift = max(drift, abs(s.energy - e) / norm)
      if i == Int((period / Physics.dt).rounded()) {
        for j in 0..<3 {
          XCTAssertLessThan((s.bodies[j].position - initial[j].position).length, 0.001)
        }
      }
    }
    print("eight max normalized energy drift: \(drift)")
    XCTAssertLessThanOrEqual(drift, 1e-4)
  }
  func testDeterminism() {
    var a = Physics(bodies: Preset.catalog[2].bodies, softening: 0.04)
    var b = a
    for _ in 0..<10000 {
      a.step()
      b.step()
    }
    XCTAssertEqual(a.bodies, b.bodies)
  }
}
