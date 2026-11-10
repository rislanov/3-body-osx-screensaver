import AppKit

let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
let bounds = NSRect(x: 0, y: 0, width: side, height: side)
let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 22, dy: 22), xRadius: 210, yRadius: 210)
NSGradient(
  starting: NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.12, alpha: 1),
  ending: NSColor(calibratedRed: 0.008, green: 0.012, blue: 0.035, alpha: 1))!.draw(
    in: shape, angle: -90)
let colors = [
  NSColor(calibratedRed: 0.39, green: 0.87, blue: 1, alpha: 1),
  NSColor(calibratedRed: 1, green: 0.5, blue: 0.66, alpha: 1),
  NSColor(calibratedRed: 1, green: 0.84, blue: 0.54, alpha: 1),
]
for j in 0..<3 {
  let offset = Double(j) * 2 * Double.pi / 3
  func point(_ t: Double) -> NSPoint { NSPoint(x: 512 + 320 * cos(t), y: 512 + 160 * sin(2 * t)) }
  for k in 0..<160 {
    let t = offset - 2.6 + Double(k) * 2.6 / 160
    let path = NSBezierPath()
    path.move(to: point(t))
    path.line(to: point(t + 2.6 / 160))
    path.lineWidth = 1 + Double(k) / 60
    colors[j].withAlphaComponent(Double(k) / 200).setStroke()
    path.stroke()
  }
  let p = point(offset)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = colors[j]
  shadow.shadowBlurRadius = 30
  shadow.shadowOffset = .zero
  shadow.set()
  colors[j].setFill()
  NSBezierPath(ovalIn: NSRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)).fill()
  NSColor.white.setFill()
  NSBezierPath(ovalIn: NSRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)).fill()
  NSGraphicsContext.restoreGraphicsState()
}
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(
  using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
