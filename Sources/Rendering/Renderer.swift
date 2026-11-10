import AppKit
import IOKit.ps
import MetalKit

private struct GPUUniforms {
  var viewport: SIMD4<Float>
  var camera: SIMD4<Float>
  var style: SIMD4<Float>
  var a: SIMD4<Float>
  var b: SIMD4<Float>
  var c: SIMD4<Float>
}
private struct GPUVertex {
  var point: SIMD4<Float>
  var tangent: SIMD4<Float>
  var color: SIMD4<Float>
}
enum RenderError: Error { case unavailable(String) }
final class Renderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  let queue: MTLCommandQueue
  let scene: Scene
  private let background: MTLRenderPipelineState
  private let grid: MTLRenderPipelineState
  private let trail: MTLRenderPipelineState
  private let star: MTLRenderPipelineState
  private let horizontal: MTLRenderPipelineState
  private let vertical: MTLRenderPipelineState
  private let composite: MTLRenderPipelineState
  private var benchmarkTarget: MTLTexture?
  private var hdr: MTLTexture?
  private var bloomA: MTLTexture?
  private var bloomB: MTLTexture?
  private var buffers: [MTLBuffer] = []
  private var slot = 0
  private let inflight = DispatchSemaphore(value: 3)
  private var frameCount = 0
  private let metricLock = NSLock()
  private var gpuTimes: [Double] = []
  private var cpuTimes: [Double] = []
  private(set) var submittedFrames = 0
  private(set) var lastDrawableID: UInt64 = 0
  private(set) var transactionPresentation = false
  private var drawRequested = false
  private var drawSucceeded = false
  private var lowResolutionBloom = false
  private var lastPowerSample = -Double.infinity
  private var batteryPower = false
  // Power source changes need not be polled for every rendered frame.
  private var cachedOnBattery: Bool {
    let now = CACurrentMediaTime()
    if now - lastPowerSample >= 1 {
      batteryPower = Self.onBattery
      lastPowerSample = now
    }
    return batteryPower
  }
  private static let colors: [SIMD4<Float>] = [
    SIMD4(0.20, 0.72, 1, 1), SIMD4(1, 0.25, 0.43, 1), SIMD4(1, 0.65, 0.25, 1),
  ]
  init(scene: Scene, bundle: Bundle) throws {
    guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue() else {
      throw RenderError.unavailable("Metal is unavailable")
    }
    device = d
    queue = q
    self.scene = scene
    let library: MTLLibrary
    if let url = bundle.url(forResource: "ThreeBody", withExtension: "metallib") {
      library = try d.makeLibrary(URL: url)
    } else if let source = bundle.url(forResource: "Shaders", withExtension: "metal") {
      library = try d.makeLibrary(source: String(contentsOf: source), options: nil)
    } else {
      throw RenderError.unavailable("Missing bundled Metal shaders")
    }
    func pipeline(
      _ vertex: String, _ fragment: String, format: MTLPixelFormat = .rgba16Float,
      additive: Bool = false
    ) throws -> MTLRenderPipelineState {
      let p = MTLRenderPipelineDescriptor()
      p.vertexFunction = library.makeFunction(name: vertex)
      p.fragmentFunction = library.makeFunction(name: fragment)
      p.colorAttachments[0].pixelFormat = format
      if additive {
        let a = p.colorAttachments[0]!
        a.isBlendingEnabled = true
        a.sourceRGBBlendFactor = .one
        a.destinationRGBBlendFactor = .one
        a.sourceAlphaBlendFactor = .zero
        a.destinationAlphaBlendFactor = .one
      }
      return try d.makeRenderPipelineState(descriptor: p)
    }
    background = try pipeline("fullscreen", "background")
    grid = try pipeline("gridVertex", "gridFragment", additive: true)
    trail = try pipeline("trailVertex", "trailFragment", additive: true)
    star = try pipeline("starVertex", "starFragment", additive: true)
    horizontal = try pipeline("fullscreen", "bloomHorizontal")
    vertical = try pipeline("fullscreen", "bloomVertical")
    composite = try pipeline("fullscreen", "composite", format: .bgra8Unorm_srgb)
    super.init()
    for _ in 0..<3 {
      guard
        let b = d.makeBuffer(
          length: TrailBuffer.capacity * 3 * 6 * MemoryLayout<GPUVertex>.stride,
          options: .storageModeShared)
      else { throw RenderError.unavailable("Trail allocation failed") }
      buffers.append(b)
    }
  }
  static var onBattery: Bool {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
    else { return false }
    return type as String == kIOPSBatteryPowerValue
  }
  func preferredFPS(pixelCount: Int) -> Int {
    switch scene.settings.quality {
    case .high: return 60
    case .low: return 30
    case .auto:
      return cachedOnBattery || ProcessInfo.processInfo.isLowPowerModeEnabled
        || pixelCount > 8_400_000 ? 30 : 60
    }
  }
  func configure(_ view: MTKView) {
    view.delegate = self
    view.device = device
    view.colorPixelFormat = .bgra8Unorm_srgb
    view.isPaused = true
    view.enableSetNeedsDisplay = false
    view.framebufferOnly = true
    view.clearColor = MTLClearColorMake(0.001, 0.002, 0.005, 1)
    view.autoResizeDrawable = true
  }
  func setTransactionPresentation(_ enabled: Bool, view: MTKView) {
    guard transactionPresentation != enabled else { return }
    drain()
    transactionPresentation = enabled
    view.presentsWithTransaction = enabled
  }
  private func texture(
    _ width: Int, _ height: Int, format: MTLPixelFormat = .rgba16Float, shared: Bool = false
  ) -> MTLTexture? {
    let d = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: format, width: width, height: height, mipmapped: false)
    d.usage = [.renderTarget, .shaderRead]
    d.storageMode = shared ? .shared : .private
    return device.makeTexture(descriptor: d)
  }
  private func resize(_ width: Int, _ height: Int) -> Bool {
    let low = scene.settings.quality == .low || (scene.settings.quality == .auto && cachedOnBattery)
    if hdr?.width != width || hdr?.height != height || lowResolutionBloom != low {
      drain()
      lowResolutionBloom = low
      hdr = texture(width, height)
      let divisor = low ? 4 : 2
      bloomA = texture(max(1, width / divisor), max(1, height / divisor))
      bloomB = texture(max(1, width / divisor), max(1, height / divisor))
    }
    return hdr != nil && bloomA != nil && bloomB != nil
  }
  private func uniforms(width: Int, height: Int) -> GPUUniforms {
    let p = scene.positions
    let b = p.enumerated().map {
      SIMD4<Float>(
        Float($0.element.x), Float($0.element.y), Float(scene.physics.bodies[$0.offset].mass), 0)
    }
    return GPUUniforms(
      viewport: SIMD4(
        Float(width), Float(height), Float(width) / Float(height), Float(scene.cameraScale)),
      camera: SIMD4(
        Float(scene.cameraCenter.x), Float(scene.cameraCenter.y), Float(scene.opacity),
        scene.settings.mode == .fabric ? 1 : 0),
      style: SIMD4(
        Float(scene.settings.glow), Float(scene.settings.grid), Float(scene.physics.time), 0),
      a: b[0], b: b[1], c: b[2])
  }
  private func writeTrails(buffer: MTLBuffer) -> Int {
    var samples = scene.trails.samples
    samples.append(TrailSample(positions: scene.positions, time: scene.physics.time))
    guard samples.count > 1 else { return 0 }
    let pointer = buffer.contents().bindMemory(
      to: GPUVertex.self, capacity: TrailBuffer.capacity * 18)
    var count = 0
    let duration = scene.settings.trailSeconds * Scene.unitsPerSecond
    for body in 0..<3 {
      for i in 0..<(min(samples.count, TrailBuffer.capacity) - 1) {
        for (index, side) in [
          (i, Float(-1)), (i, Float(1)), (i + 1, Float(-1)), (i, Float(1)), (i + 1, Float(1)),
          (i + 1, Float(-1)),
        ] {
          let p = samples[index].positions[body]
          let prev = samples[max(0, index - 1)].positions[body]
          let next = samples[min(samples.count - 1, index + 1)].positions[body]
          let tangent = p + (next - prev)
          let age = Float(max(0, min(1, 1 - (scene.physics.time - samples[index].time) / duration)))
          pointer[count] = GPUVertex(
            point: SIMD4(Float(p.x), Float(p.y), side, age),
            tangent: SIMD4(Float(tangent.x), Float(tangent.y), 0, 0), color: Self.colors[body])
          count += 1
        }
      }
    }
    return count
  }
  @discardableResult func draw(view: MTKView) -> Bool {
    guard view.bounds.width > 0, view.bounds.height > 0, view.window != nil, !view.isHidden else {
      return false
    }
    drawSucceeded = false
    drawRequested = true
    defer { drawRequested = false }
    // MTKView releases currentDrawable only at the end of draw(). Bypassing
    // this lifecycle repeatedly presents the same surface and freezes the screen.
    if transactionPresentation {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      view.draw()
      CATransaction.commit()
    } else {
      view.draw()
    }
    return drawSucceeded
  }
  func draw(in view: MTKView) {
    // Ignore unsolicited AppKit callbacks after the external host stops ticking.
    guard drawRequested, let drawable = view.currentDrawable else { return }
    lastDrawableID = UInt64(drawable.drawableID)
    drawSucceeded = render(to: drawable.texture, drawable: drawable, wait: false)
  }
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    // Allocate lazily on the next explicit frame, after draining outstanding work.
  }
  func benchmarkFrame(width: Int, height: Int) -> Bool {
    guard width > 0, height > 0, width <= 8192, height <= 8192 else { return false }
    if benchmarkTarget?.width != width || benchmarkTarget?.height != height {
      drain()
      benchmarkTarget = texture(width, height, format: .bgra8Unorm_srgb)
    }
    guard let target = benchmarkTarget else { return false }
    return render(to: target, drawable: nil, wait: false)
  }
  func snapshot(width: Int, height: Int) throws -> NSBitmapImageRep {
    guard width > 0, height > 0, width <= 8192, height <= 8192,
      let target = texture(width, height, format: .bgra8Unorm_srgb, shared: true)
    else { throw RenderError.unavailable("Invalid capture size") }
    guard render(to: target, drawable: nil, wait: true) else {
      throw RenderError.unavailable("Capture render failed")
    }
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: width * 4, bitsPerPixel: 32)!
    target.getBytes(
      rep.bitmapData!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height),
      mipmapLevel: 0)
    let data = rep.bitmapData!
    for i in stride(from: 0, to: width * height * 4, by: 4) {
      let b = data[i]
      data[i] = data[i + 2]
      data[i + 2] = b
    }
    return rep
  }
  private func render(to target: MTLTexture, drawable: CAMetalDrawable?, wait: Bool) -> Bool {
    let start = CACurrentMediaTime()
    let w = target.width
    let h = target.height
    guard w > 0, h > 0, resize(w, h), inflight.wait(timeout: .now()) == .success else {
      return false
    }
    guard let command = queue.makeCommandBuffer(), let hdr, let bloomA, let bloomB else {
      inflight.signal()
      return false
    }
    var u = uniforms(width: w, height: h)
    let buffer = buffers[slot]
    slot = (slot + 1) % 3
    let count = writeTrails(buffer: buffer)
    func pass(_ target: MTLTexture, _ body: (MTLRenderCommandEncoder) -> Void) {
      let p = MTLRenderPassDescriptor()
      p.colorAttachments[0].texture = target
      p.colorAttachments[0].loadAction = .clear
      p.colorAttachments[0].storeAction = .store
      guard let e = command.makeRenderCommandEncoder(descriptor: p) else { return }
      e.setVertexBytes(&u, length: MemoryLayout<GPUUniforms>.stride, index: 0)
      e.setFragmentBytes(&u, length: MemoryLayout<GPUUniforms>.stride, index: 0)
      body(e)
      e.endEncoding()
    }
    pass(hdr) { e in
      e.setRenderPipelineState(background)
      e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
      if scene.settings.mode == .fabric {
        e.setRenderPipelineState(grid)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 256 * 256 * 6)
      }
      e.setRenderPipelineState(trail)
      e.setVertexBuffer(buffer, offset: 0, index: 1)
      if count > 0 { e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count) }
      e.setRenderPipelineState(star)
      e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 3)
    }
    pass(bloomA) { e in
      e.setRenderPipelineState(horizontal)
      e.setFragmentTexture(hdr, index: 0)
      e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    pass(bloomB) { e in
      e.setRenderPipelineState(vertical)
      e.setFragmentTexture(bloomA, index: 0)
      e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    pass(target) { e in
      e.setRenderPipelineState(composite)
      e.setFragmentTexture(hdr, index: 0)
      e.setFragmentTexture(bloomB, index: 1)
      e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    if let drawable, !transactionPresentation { command.present(drawable) }
    let cpu = CACurrentMediaTime() - start
    command.addCompletedHandler { [weak self, inflight] cmd in
      if let self {
        self.metricLock.lock()
        if self.gpuTimes.count >= 1800 {
          self.gpuTimes.removeFirst()
          self.cpuTimes.removeFirst()
        }
        self.gpuTimes.append(max(0, cmd.gpuEndTime - cmd.gpuStartTime))
        self.cpuTimes.append(cpu)
        self.metricLock.unlock()
      }
      inflight.signal()
    }
    command.commit()
    if let drawable, transactionPresentation {
      // Apple's transaction contract requires scheduling first, then presenting
      // directly on the drawable on the thread owning the CA transaction.
      command.waitUntilScheduled()
      drawable.present()
    }
    submittedFrames += 1
    if wait {
      command.waitUntilCompleted()
      return command.status == .completed
    }
    return true
  }
  func drain() {
    let c = queue.makeCommandBuffer()
    c?.commit()
    c?.waitUntilCompleted()
  }
  var metrics: String {
    metricLock.lock()
    defer { metricLock.unlock() }
    func p95(_ values: [Double]) -> Double {
      let s = values.sorted()
      return s.isEmpty ? 0 : s[min(s.count - 1, Int(Double(s.count) * 0.95))] * 1000
    }
    return String(
      format: "GPU p95 %.2f ms · CPU p95 %.2f ms · %d frames", p95(gpuTimes), p95(cpuTimes),
      submittedFrames)
  }
}
