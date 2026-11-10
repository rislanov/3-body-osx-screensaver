import AppKit

// Deterministic vector artwork for the System Settings gallery, at 1× and 2×.
// This is an illustrative figure-eight orbit, not a simulation snapshot.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for scale in [1, 2] {
  let width = 480 * scale, height = 312 * scale
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = NSAffineTransform()
  transform.scale(by: CGFloat(scale))
  transform.concat()
  NSGradient(starting: NSColor(calibratedRed: 0.025, green: 0.04, blue: 0.075, alpha: 1),
             ending: NSColor(calibratedRed: 0.006, green: 0.009, blue: 0.02, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: 480, height: 312), angle: -90)
  func point(_ t: Double) -> NSPoint {
    NSPoint(x: 240 + 178 * cos(t), y: 156 + 85 * sin(2 * t))
  }
  let colors = [
    NSColor(calibratedRed: 0.39, green: 0.87, blue: 1, alpha: 1),
    NSColor(calibratedRed: 1, green: 0.50, blue: 0.66, alpha: 1),
    NSColor(calibratedRed: 1, green: 0.84, blue: 0.54, alpha: 1),
  ]
  // Three adjoining trail segments form one complete, legible figure eight.
  for j in 0..<3 {
    let head = 0.35 + Double(j) * 2 * .pi / 3
    for k in 0..<240 {
      let fraction = Double(k) / 240
      let t = head - 2 * .pi / 3 + fraction * 2 * .pi / 3
      let path = NSBezierPath()
      path.move(to: point(t))
      path.line(to: point(t + 2 * .pi / (3 * 240)))
      path.lineWidth = 1.2 + fraction * 1.4
      path.lineCapStyle = .round
      colors[j].withAlphaComponent(0.18 + fraction * 0.72).setStroke()
      path.stroke()
    }
    let p = point(head)
    for radius in stride(from: 24.0, through: 5.0, by: -1) {
      colors[j].withAlphaComponent(0.025).setFill()
      NSBezierPath(ovalIn: NSRect(x: p.x - radius, y: p.y - radius,
                                 width: radius * 2, height: radius * 2)).fill()
    }
    colors[j].setFill()
    NSBezierPath(ovalIn: NSRect(x: p.x - 4.2, y: p.y - 4.2, width: 8.4, height: 8.4)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: p.x - 2.1, y: p.y - 2.1, width: 4.2, height: 4.2)).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  let name = scale == 1 ? "thumbnail.png" : "thumbnail@2x.png"
  try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
