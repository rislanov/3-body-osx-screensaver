import AppKit
import MetalKit
import ScreenSaver

final class ThreeBodyView: ScreenSaverView {
  private var renderer: Renderer?
  private var metalView: MTKView?
  private var lastTime: Double?
  private var active = false
  private var engine: NSRunningApplication?
  private var sessionTimer: Timer?

  private var settingsPanel: SettingsPanel?
  private var powerCheck = 0
  private var statsStart = 0.0
  private var statsFrames = 0
  private var capturedDiagnostics = false
  private let diagnosticID = UUID().uuidString
  private static var diagnosticCaptures = 0
  private let defaults = ScreenSaverDefaults(forModuleWithName: "studio.threebody.saver")!
  override init?(frame: NSRect, isPreview: Bool) {
    super.init(frame: frame, isPreview: isPreview)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
  }
  // ScreenSaverView's default drawing creates a full-size bitmap backing store.
  // This container only needs a solid background; all pixels come from MTKView.
  override var wantsUpdateLayer: Bool { true }
  override func updateLayer() { layer?.backgroundColor = NSColor.black.cgColor }

  private func setup() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
    guard renderer == nil else { return }
    let settings = Settings.load(defaults)
    do {
      let r = try Renderer(
        scene: Scene.launch(settings: settings), bundle: Bundle(for: Self.self))
      let v = MTKView(frame: bounds, device: r.device)
      v.autoresizingMask = [.width, .height]
      r.configure(v)
      r.setTransactionPresentation(true, view: v)
      updateDiagnosticPresentation(r, view: v)
      addSubview(v)
      metalView = v
      renderer = r
      animationTimeInterval =
        1 / Double(r.preferredFPS(pixelCount: Int(v.drawableSize.width * v.drawableSize.height)))
    } catch {
      NSLog("ThreeBody renderer unavailable: %@", String(describing: error))
    }
  }
  override func startAnimation() {
    if engine?.isTerminated == true {
      stopAnimation()
      recordLifecycle("ignored-ended-session")
      return
    }
    guard !active else { return }
    setup()
    guard renderer != nil else { return }
    active = true
    capturedDiagnostics = false
    powerCheck = 0
    if !isPreview {
      // Tahoe can label the Settings preview as non-preview. Only bind an
      // Engine that exists when this view starts, never a later fullscreen run.
      engine = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.ScreenSaver.Engine"
      ).first { !$0.isTerminated }
    }
    if engine != nil {
      let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
        self?.checkEngineSession()
      }
      sessionTimer = timer
      RunLoop.main.add(timer, forMode: .common)
    }
    recordLifecycle("start")
    statsStart = CACurrentMediaTime()
    statsFrames = renderer?.submittedFrames ?? 0
    NSLog(
      "ThreeBody start preview=%d size=%.0fx%.0f", isPreview ? 1 : 0, bounds.width,
      bounds.height)
    lastTime = nil
    super.startAnimation()
  }
  override func animateOneFrame() {
    guard active, let r = renderer, let v = metalView, bounds.width > 0, bounds.height > 0,
      window != nil, !isHidden
    else {
      lastTime = nil
      return
    }
    r.scene.viewportAspect = max(0.25, v.drawableSize.width / max(1, v.drawableSize.height))
    let now = CACurrentMediaTime()
    if let lastTime { r.scene.advance(seconds: now - lastTime) }
    lastTime = now
    powerCheck += 1
    if powerCheck % 120 == 0 {
      updateDiagnosticPresentation(r, view: v)
      animationTimeInterval =
        1 / Double(r.preferredFPS(pixelCount: Int(v.drawableSize.width * v.drawableSize.height)))
    }
    r.draw(view: v)
    if !capturedDiagnostics && r.submittedFrames >= 60
      && Bundle(for: Self.self).url(forResource: "DiagnosticsEnabled", withExtension: "txt") != nil
    {
      capturedDiagnostics = true
      captureDiagnostics(r, view: v)
    }
    if now - statsStart >= 60 {
      let frames = r.submittedFrames - statsFrames
      NSLog(
        "ThreeBody heartbeat fps=%.2f sim=%.3f drawable=%llu %@",
        Double(frames) / (now - statsStart), r.scene.physics.time, r.lastDrawableID, r.metrics)
      statsStart = now
      statsFrames = r.submittedFrames
    }
  }
  private func updateDiagnosticPresentation(_ r: Renderer, view: MTKView) {
    guard
      Bundle(for: Self.self).url(forResource: "DiagnosticsEnabled", withExtension: "txt") != nil,
      let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return }
    let config = cache.appendingPathComponent("ThreeBodyDiagnostics/presentation-mode.txt")
    let mode = (try? String(contentsOf: config)) ?? "transaction"
    let enabled = !mode.contains("async")
    if r.transactionPresentation != enabled {
      r.setTransactionPresentation(enabled, view: view)
      capturedDiagnostics = false
    }
  }
  // Opt-in development probe. No screen capture, input capture, or network access:
  // this reads only our own scene and writes at most six small captures per host.
  private func captureDiagnostics(_ r: Renderer, view: MTKView) {
    guard Self.diagnosticCaptures < 6 else { return }
    Self.diagnosticCaptures += 1
    guard let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return }
    let directory = cache.appendingPathComponent("ThreeBodyDiagnostics", isDirectory: true)
    let name = "\(ProcessInfo.processInfo.processIdentifier)-\(diagnosticID)"
    var record: [String: Any] = [
      "version": Bundle(for: Self.self).object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "unknown",
      "time": ISO8601DateFormatter().string(from: Date()),
      "isPreview": isPreview, "active": active, "viewFrame": NSStringFromRect(frame),
      "bounds": NSStringFromRect(bounds), "metalFrame": NSStringFromRect(view.frame),
      "drawableSize": NSStringFromSize(view.drawableSize), "hidden": isHidden,
      "hiddenAncestor": isHiddenOrHasHiddenAncestor, "metalHidden": view.isHidden,
      "windowFrame": window.map { NSStringFromRect($0.frame) } ?? "nil",
      "windowVisible": window?.isVisible ?? false,
      "windowOccluded": !(window?.occlusionState.contains(.visible) ?? false),
      "backingScale": window?.backingScaleFactor ?? 0,
      "episodeSeed": String(r.scene.episodeSeed),
      "sceneOpacity": r.scene.opacity, "simulationTime": r.scene.physics.time,
      "submittedFrames": r.submittedFrames, "drawableID": r.lastDrawableID,
      "layerOpacity": layer?.opacity ?? -1, "metalLayerOpacity": view.layer?.opacity ?? -1,
      "transactionPresentation": r.transactionPresentation,
      "metrics": r.metrics,
    ]
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let width = 1280
      let aspect = max(0.25, view.drawableSize.width / max(1, view.drawableSize.height))
      let bitmap = try r.snapshot(width: width, height: Int(Double(width) / aspect))
      if let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        record["ownSceneCapture"] = "success"
      }
    } catch { record["error"] = String(describing: error) }
    if let data = try? JSONSerialization.data(
      withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
    {
      try? data.write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
    }
  }
  // Keep the identity of this launch. A later Engine process must not revive
  // a retained view from the previous session. NSWorkspace notifications omit
  // background apps, so use NSRunningApplication's public termination state.
  private func checkEngineSession() {
    guard active, !isPreview else { return }
    if let engine {
      if engine.isTerminated {
        recordLifecycle("engine-terminated")
        stopAnimation()
      }
    }
  }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil && active {
      recordLifecycle("detached")
      stopAnimation()
    }
  }
  override func stopAnimation() {
    guard active || renderer != nil else { return }
    recordLifecycle("stop")
    active = false
    lastTime = nil
    sessionTimer?.invalidate()
    sessionTimer = nil
    // Retain the launch identity even after release. Tahoe sends startAnimation
    // to old views as well as creating new views for the next Engine process.
    // A view bound to an ended Engine must never allocate another renderer.
    super.stopAnimation()
    metalView?.isPaused = true
    metalView?.delegate = nil
    renderer?.drain()
    metalView?.releaseDrawables()
    metalView?.removeFromSuperview()
    metalView = nil
    renderer = nil
    // The system retains stopped ScreenSaverViews. Release our root backing
    // layer too, otherwise each retained view keeps full-size CA surfaces.
    layer?.contents = nil
    wantsLayer = false
    layer = nil
    recordLifecycle("released")
  }
  deinit { sessionTimer?.invalidate() }

  private func recordLifecycle(_ event: String) {
    guard
      Bundle(for: Self.self).url(forResource: "DiagnosticsEnabled", withExtension: "txt") != nil,
      let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return }
    let directory = cache.appendingPathComponent("ThreeBodyDiagnostics", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(
      "lifecycle-\(ProcessInfo.processInfo.processIdentifier).log")
    let line =
      "\(ISO8601DateFormatter().string(from: Date())) id=\(diagnosticID) event=\(event) preview=\(isPreview) engine=\(engine?.processIdentifier ?? 0) frames=\(renderer?.submittedFrames ?? 0) resources=\(renderer != nil)\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: url.path) {
      try? data.write(to: url)
    } else if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    }
  }
  override var hasConfigureSheet: Bool { true }
  override var configureSheet: NSWindow? {
    if settingsPanel == nil {
      settingsPanel = SettingsPanel(
        settings: Settings.load(defaults),
        replay: { [weak self] in self?.renderer?.scene.replaySettings ?? Settings() }
      ) { [weak self] settings in
        guard let self else { return }
        settings.save(self.defaults)
        self.defaults.synchronize()
        if let scene = self.renderer?.scene {
          let changed =
            scene.settings.scenes != settings.scenes || scene.settings.seed != settings.seed
            || scene.settings.presetID != settings.presetID
          scene.settings = settings
          if changed {
            scene.reseed(settings.seed)
            scene.next(index: Preset.catalog.firstIndex { $0.id == settings.presetID })
          }
        }
        self.lastTime = nil
      }
    }
    return settingsPanel?.window
  }
  // Accessible to the standalone lifecycle harness; never controls the host process.
  @objc var diagnosticLastDrawableID: UInt64 { renderer?.lastDrawableID ?? 0 }
  @objc var diagnosticSubmittedFrames: Int { renderer?.submittedFrames ?? 0 }
  @objc var diagnosticSimulationTime: Double { renderer?.scene.physics.time ?? 0 }
}
