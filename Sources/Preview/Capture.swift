import AVFoundation
import AppKit

// Captures the production renderer, not a separate illustrative implementation.
enum Capture {
  static func run(renderer r: Renderer, destination: URL, width: Int, height: Int, video: Bool)
    throws
  {
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    func png(_ name: String) throws {
      let rep = try r.snapshot(width: width, height: height)
      guard let data = rep.representation(using: .png, properties: [:]) else {
        throw RenderError.unavailable("PNG encoding failed")
      }
      try data.write(to: destination.appendingPathComponent(name))
    }
    r.scene.settings.mode = .fabric
    for _ in 0..<360 { r.scene.advance(seconds: 1 / 30) }
    try png("gravity-fabric.png")
    // Search only the fixed trajectory in capture tooling; runtime startup has no search.
    var bestTime = 0.0
    var bestDistance = Double.infinity
    let scout = Scene(settings: r.scene.settings, seed: r.scene.settings.seed, presetIndex: 1)
    for i in 0..<1800 {
      scout.advance(seconds: 1 / 30)
      if scout.physics.minSeparation < bestDistance && !scout.isTransitioning {
        bestDistance = scout.physics.minSeparation
        bestTime = Double(i + 1) / 30
      }
    }
    r.scene.reseed(r.scene.settings.seed)
    r.scene.restart()
    for _ in 0..<Int((bestTime * 30).rounded()) { r.scene.advance(seconds: 1 / 30) }
    try png("close-approach.png")
    r.scene.settings.mode = .cinematic
    for _ in 0..<300 { r.scene.advance(seconds: 1 / 30) }
    try png("cinematic.png")
    var report =
      "Production Metal renderer captures\n\(width)x\(height)\nClose-approach search: t=\(bestTime), separation=\(bestDistance)\n\(r.metrics)\n"
    if video {
      r.scene.settings.mode = .fabric
      r.scene.reseed(r.scene.settings.seed)
      r.scene.restart()
      let url = destination.appendingPathComponent("ThreeBody-motion.mov")
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
      let w = 1280
      let h = 800
      let fps = 30
      let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
      let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
          AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000],
        ])
      input.expectsMediaDataInRealTime = false
      let adapter = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
          kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
          kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
      writer.add(input)
      guard writer.startWriting() else {
        throw writer.error ?? RenderError.unavailable("Movie writer failed")
      }
      writer.startSession(atSourceTime: .zero)
      for frame in 0..<1200 {
        try autoreleasepool {
          if frame == 540 { r.scene.next() }
          if frame == 840 { r.scene.next() }
          if frame == 885 { r.scene.settings.mode = .cinematic }
          r.scene.advance(seconds: 1 / Double(fps))
          let rep = try r.snapshot(width: w, height: h)
          var pb: CVPixelBuffer?
          guard let pool = adapter.pixelBufferPool,
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let pb
          else { throw RenderError.unavailable("Movie buffer allocation") }
          CVPixelBufferLockBaseAddress(pb, [])
          let dst = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
          let stride = CVPixelBufferGetBytesPerRow(pb)
          let src = rep.bitmapData!
          for y in 0..<h {
            for x in 0..<w {
              let a = y * w * 4 + x * 4
              let b = y * stride + x * 4
              dst[b] = src[a + 2]
              dst[b + 1] = src[a + 1]
              dst[b + 2] = src[a]
              dst[b + 3] = 255
            }
          }
          CVPixelBufferUnlockBaseAddress(pb, [])
          while !input.isReadyForMoreMediaData && writer.status == .writing {
            Thread.sleep(forTimeInterval: 0.002)
          }
          guard
            adapter.append(
              pb, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps)))
          else { throw writer.error ?? RenderError.unavailable("Movie append failed") }
        }
      }
      input.markAsFinished()
      let finished = DispatchSemaphore(value: 0)
      writer.finishWriting { finished.signal() }
      finished.wait()
      if let error = writer.error { throw error }
      report +=
        "40 seconds / 30fps / 1280x800; transitions requested at 18s and 28s; cinematic selected in darkness at 29.5s. Offline capture, not a live FPS benchmark.\n\(r.metrics)\n"
    }
    try report.write(
      to: destination.appendingPathComponent("capture-report.txt"), atomically: true,
      encoding: .utf8)
  }
}
