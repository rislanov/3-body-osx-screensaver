import Foundation

public struct Preset: Sendable {
  public let id: String
  public let title: String
  public let bodies: [Body]
  public let softening: Double
  public let duration: Double
  public static let catalog: [Preset] = {
    // Simó's rounded fixture published by Richard Montgomery, UCSC.
    let eight = [
      Body(position: V2(-0.97000436, 0.24308753), velocity: V2(-0.466203685, -0.43236573)),
      Body(position: V2(0.97000436, -0.24308753), velocity: V2(-0.466203685, -0.43236573)),
      Body(position: .zero, velocity: V2(0.93240737, 0.86473146)),
    ]
    var result = [
      Preset(id: "eight", title: "Figure Eight", bodies: eight, softening: 0, duration: 150)
    ]
    let names = [
      ("ribbon", "Silk Ribbon"), ("tide", "Tidal Waltz"), ("ember", "Ember Exchange"),
      ("drift", "Quiet Turbulence"),
    ]
    for i in 0..<4 {
      var b = eight
      b[0].velocity.x += [0.022, -0.035, 0.065, -0.09][i]
      b[1].velocity.y += [0.032, 0.045, -0.04, 0.06][i]
      let v = b.reduce(V2.zero) { $0 + $1.velocity } / 3
      for j in b.indices { b[j].velocity = b[j].velocity - v }
      result.append(
        Preset(
          id: names[i].0, title: names[i].1, bodies: b, softening: 0.055,
          duration: Double(120 + i * 15)))
    }
    // Original hierarchical triples; barycentric positions and velocities.
    for i in 0..<3 {
      let r = [2.3, 2.7, 3.0][i]
      let v = sqrt(3 / r) * [0.82, 0.9, 0.76][i]
      var b = [
        Body(position: V2(-0.46, -r / 3), velocity: V2(v / 3, -0.72)),
        Body(position: V2(0.46, -r / 3), velocity: V2(v / 3, 0.72)),
        Body(position: V2(0, 2 * r / 3), velocity: V2(-2 * v / 3, 0)),
      ]
      for j in b.indices {
        b[j].position = b[j].position.rotated(Double(i) * 0.4)
        b[j].velocity = b[j].velocity.rotated(Double(i) * 0.4)
      }
      result.append(
        Preset(
          id: ["binary", "satellite", "exchange"][i],
          title: ["Binary Nocturne", "Distant Companion", "Golden Exchange"][i], bodies: b,
          softening: 0.055, duration: 180))
    }
    return result
  }()
}
