import Foundation

public enum VisualMode: String, Codable, CaseIterable, Sendable {
  case fabric = "Gravity Fabric"
  case cinematic = "Cinematic"
}
public enum SceneMode: String, Codable, CaseIterable, Sendable {
  case auto = "Auto"
  case chaotic = "Chaotic"
  case eight = "Figure Eight"
}
public enum Quality: String, Codable, CaseIterable, Sendable {
  case auto = "Auto"
  case high = "High"
  case low = "Low"
}
public struct Settings: Codable, Equatable, Sendable {
  public var mode: VisualMode = .fabric
  public var scenes: SceneMode = .auto
  public var speed = 1.0
  public var trailSeconds = 18.0
  public var glow = 1.0
  public var grid = 0.7
  public var quality: Quality = .auto
  // nil in older configuration files means the new random-start default.
  public var randomizeStart: Bool? = true
  public var seed: UInt64 = 42
  public var presetID: String? = nil
  public init() {}
  public mutating func sanitize() {
    if ![0.5, 1, 2].contains(speed) { speed = 1 }
    trailSeconds = trailSeconds.isFinite ? min(25, max(8, trailSeconds)) : 18
    glow = glow.isFinite ? min(2, max(0.2, glow)) : 1
    grid = grid.isFinite ? min(1.5, max(0, grid)) : 0.7
  }
  public static func load(_ defaults: UserDefaults) -> Settings {
    guard let data = defaults.data(forKey: "configuration"),
      var s = try? JSONDecoder().decode(Self.self, from: data)
    else { return Settings() }
    s.sanitize()
    return s
  }
  public func save(_ defaults: UserDefaults) {
    if let d = try? JSONEncoder().encode(self) { defaults.set(d, forKey: "configuration") }
  }
}
