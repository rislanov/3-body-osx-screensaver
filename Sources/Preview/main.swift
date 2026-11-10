import AppKit
import MetalKit
import ScreenSaver

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSWindow!
  var renderer: Renderer!
  var metal: MTKView!
  var timer: Timer?
  var lastTime: Double?
  var paused = false
  var panel: SettingsPanel?
  var controls: NSVisualEffectView!
  var diagnostics = NSTextField(labelWithString: "")
  var subtitle = NSTextField(labelWithString: "")
  var lastTitleUpdate = 0.0
  var benchmarkActivity: NSObjectProtocol?
  var benchmarkStart: Double?
  var benchmarkFrames = 0
  var frameIntervals: [Double] = []
  var memorySamples: [UInt64] = []
  var benchmarkLastFrame: Double?
  let defaults = UserDefaults.standard
  let args = CommandLine.arguments
  func argument(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    do {
      var settings = Settings.load(defaults)
      if let seed = argument("--seed").flatMap(UInt64.init) {
        settings.seed = seed
        settings.randomizeStart = false
      }
      if let q = argument("--quality").flatMap({ Quality(rawValue: $0.capitalized) }) {
        settings.quality = q
      }
      if argument("--benchmark") != nil {
        benchmarkActivity = ProcessInfo.processInfo.beginActivity(
          options: [.userInitiated, .latencyCritical], reason: "ThreeBody renderer benchmark")
      }
      if argument("--mode") == "cinematic" { settings.mode = .cinematic }
      let index = argument("--preset").flatMap { id in Preset.catalog.firstIndex { $0.id == id } }
      renderer = try Renderer(
        scene: Scene(
          settings: settings,
          seed: settings.randomizeStart == false ? settings.seed : UInt64.random(in: .min ... .max),
          presetIndex: index), bundle: .main)
      let size = argument("--size")?.split(separator: "x").compactMap { Int($0) } ?? [1440, 900]
      let width = size.count == 2 ? max(1, min(8192, size[0])) : 1440
      let height = size.count == 2 ? max(1, min(8192, size[1])) : 900
      let windowScale = min(1, min(1440.0 / Double(width), 900.0 / Double(height)))
      window = NSWindow(
        contentRect: NSRect(
          x: 0, y: 0, width: max(640, Double(width) * windowScale),
          height: max(400, Double(height) * windowScale)),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.title = "ThreeBody"
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.backgroundColor = .black
      window.collectionBehavior = [.fullScreenPrimary]
      window.minSize = NSSize(width: 640, height: 400)
      window.delegate = self
      metal = MTKView(frame: window.contentView!.bounds, device: renderer.device)
      renderer.configure(metal)
      metal.autoresizingMask = [.width, .height]
      window.contentView = metal
      if let pixels = argument("--pixels")?.split(separator: "x").compactMap({ Int($0) }),
        pixels.count == 2, pixels.allSatisfy({ $0 > 0 && $0 <= 8192 })
      {
        metal.autoResizeDrawable = false
        metal.drawableSize = CGSize(width: pixels[0], height: pixels[1])
      }
      setupControls()
      setupMenu()
      window.center()
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      if let destination = argument("--snapshot") {
        DispatchQueue.main.async {
          do {
            let time = max(0, min(3600, self.argument("--time").flatMap(Double.init) ?? 0))
            self.renderer.scene.viewportAspect = Double(width) / Double(height)
            for _ in 0..<Int(time * 60) { self.renderer.scene.advance(seconds: 1 / 60) }
            let rep = try self.renderer.snapshot(width: width, height: height)
            try rep.representation(using: .png, properties: [:])!.write(
              to: URL(fileURLWithPath: destination))
          } catch { NSLog("Snapshot failed: %@", String(describing: error)) }
          NSApp.terminate(nil)
        }
        return
      }
      if let destination = argument("--capture") {
        DispatchQueue.main.async {
          self.capture(destination: destination, width: width, height: height)
        }
        return
      }
      if args.contains("--lifecycle-test") {
        DispatchQueue.main.async { self.lifecycleTest() }
        return
      }
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, self.window.isKeyWindow, !(self.window.firstResponder is NSTextView),
          event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        else { return event }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": self.pause(nil)
        case "n": self.next(nil)
        case "r": self.restart(nil)
        case "f": self.fullscreen(nil)
        case "d": self.diagnostics.isHidden.toggle()
        case "h": self.controls.isHidden.toggle()
        case ",": self.settings(nil)
        default: return event
        }
        return nil
      }
      startTimer()
    } catch {
      NSAlert(error: error).runModal()
      NSApp.terminate(nil)
    }
  }
  func startTimer() {
    timer?.invalidate()
    lastTime = nil
    let fps = renderer.preferredFPS(
      pixelCount: Int(metal.drawableSize.width * metal.drawableSize.height))
    timer = Timer(
      timeInterval: 1 / Double(fps), target: self, selector: #selector(frame), userInfo: nil,
      repeats: true)
    timer!.tolerance = 0.001
    RunLoop.main.add(timer!, forMode: .common)
  }
  @objc func frame() {
    guard window.isVisible, !window.isMiniaturized,
      argument("--benchmark") != nil || window.occlusionState.contains(.visible)
    else {
      lastTime = nil
      return
    }
    renderer.scene.viewportAspect = max(
      0.25, metal.drawableSize.width / max(1, metal.drawableSize.height))
    let now = CACurrentMediaTime()
    if !paused, let lastTime { renderer.scene.advance(seconds: now - lastTime) }
    lastTime = now
    let drawn =
      argument("--benchmark") != nil
      ? renderer.benchmarkFrame(
        width: Int(metal.drawableSize.width), height: Int(metal.drawableSize.height))
      : renderer.draw(view: metal)
    if let duration = argument("--benchmark").flatMap(Double.init) {
      if benchmarkStart == nil { benchmarkStart = now + 3 }
      if now >= benchmarkStart! {
        if drawn {
          benchmarkFrames += 1
          if let last = benchmarkLastFrame { frameIntervals.append(now - last) }
          benchmarkLastFrame = now
        }
        if now - benchmarkStart! >= duration {
          renderer.drain()
          let sorted = frameIntervals.sorted()
          let report: [String: Any] = [
            "seconds": now - benchmarkStart!, "frames": benchmarkFrames,
            "fps": Double(benchmarkFrames) / (now - benchmarkStart!),
            "p95FrameIntervalMS": sorted.isEmpty
              ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] * 1000,
            "renderer": renderer.metrics, "width": metal.drawableSize.width,
            "height": metal.drawableSize.height, "mode": renderer.scene.settings.mode.rawValue,
            "quality": renderer.scene.settings.quality.rawValue, "battery": Renderer.onBattery,
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "memoryFootprintBytes": memorySamples,
          ]
          if let data = try? JSONSerialization.data(
            withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
          {
            try? data.write(
              to: URL(fileURLWithPath: argument("--log") ?? "/tmp/ThreeBody-benchmark.json"))
          }
          NSApp.terminate(nil)
          return
        }
      }
    }
    if now - lastTitleUpdate > 1 {
      subtitle.stringValue =
        "\(Preset.catalog[renderer.scene.presetIndex].title)  ·  \(renderer.scene.settings.mode.rawValue)"
      diagnostics.stringValue =
        renderer.metrics
        + String(
          format: "\nSimulation %.3f · seed %llu · %@", renderer.scene.physics.time,
          renderer.scene.episodeSeed, renderer.scene.lastTransitionReason)
      if benchmarkStart != nil { memorySamples.append(Self.footprint()) }
      lastTitleUpdate = now
      let fps = renderer.preferredFPS(
        pixelCount: Int(metal.drawableSize.width * metal.drawableSize.height))
      if abs((timer?.timeInterval ?? 0) - 1 / Double(fps)) > 0.001 { startTimer() }
    }
  }
  static func footprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { p in
      p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
  }
  func setupControls() {
    controls = NSVisualEffectView()
    controls.material = .hudWindow
    controls.blendingMode = .withinWindow
    controls.state = .active
    controls.wantsLayer = true
    controls.layer?.cornerRadius = 18
    controls.translatesAutoresizingMaskIntoConstraints = false
    metal.addSubview(controls)
    let name = NSTextField(labelWithString: "T H R E E B O D Y")
    name.font = .systemFont(ofSize: 11, weight: .semibold)
    name.textColor = .white
    subtitle.font = .systemFont(ofSize: 11)
    subtitle.textColor = .secondaryLabelColor
    let titles = NSStackView(views: [name, subtitle])
    titles.orientation = .vertical
    titles.alignment = .leading
    titles.spacing = 5
    titles.widthAnchor.constraint(greaterThanOrEqualToConstant: 270).isActive = true
    let stack = NSStackView(views: [titles])
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    for (title, action, tip) in [
      ("Pause", #selector(pause(_:)), "Space · Pause / resume"),
      ("Next", #selector(next(_:)), "N · Next scene"),
      ("Settings", #selector(settings(_:)), "⌘, · Settings"),
      ("⛶", #selector(fullscreen(_:)), "F · Full screen"),
    ] {
      let b = NSButton(title: title, target: self, action: action)
      b.bezelStyle = .rounded
      b.toolTip = tip
      stack.addArrangedSubview(b)
    }
    let screenSaverButton = NSButton(
      title: "Open Screen Saver Settings", target: self, action: #selector(openScreenSaverSettings(_:)))
    screenSaverButton.bezelStyle = .rounded
    screenSaverButton.toolTip = "Open System Settings to choose ThreeBody as your screen saver."
    let instructions = NSTextField(wrappingLabelWithString:
      "Select ThreeBody as your screen saver. If it is missing, install the ThreeBody package first.")
    instructions.font = .systemFont(ofSize: 11)
    instructions.textColor = .secondaryLabelColor
    instructions.widthAnchor.constraint(equalToConstant: 280).isActive = true
    let installation = NSStackView(views: [screenSaverButton, instructions])
    installation.spacing = 12
    let content = NSStackView(views: [stack, installation])
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 12
    content.translatesAutoresizingMaskIntoConstraints = false
    controls.addSubview(content)
    NSLayoutConstraint.activate([
      controls.centerXAnchor.constraint(equalTo: metal.centerXAnchor),
      controls.bottomAnchor.constraint(equalTo: metal.bottomAnchor, constant: -24),
      content.leadingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 20),
      content.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: -20),
      content.topAnchor.constraint(equalTo: controls.topAnchor, constant: 16),
      content.bottomAnchor.constraint(equalTo: controls.bottomAnchor, constant: -16),
    ])
    diagnostics.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    diagnostics.textColor = .secondaryLabelColor
    diagnostics.maximumNumberOfLines = 3
    diagnostics.isHidden = true
    diagnostics.translatesAutoresizingMaskIntoConstraints = false
    metal.addSubview(diagnostics)
    NSLayoutConstraint.activate([
      diagnostics.leadingAnchor.constraint(equalTo: metal.leadingAnchor, constant: 24),
      diagnostics.topAnchor.constraint(equalTo: metal.topAnchor, constant: 48),
    ])
  }
  @objc func openScreenSaverSettings(_ sender: Any?) {
    // Tahoe moved Screen Saver into Wallpaper settings.
    let destination: String
    if #available(macOS 26, *) {
      destination = "com.apple.Wallpaper-Settings.extension?ScreenSaver"
    } else {
      destination = "com.apple.ScreenSaver-Settings.extension"
    }
    let url = URL(string: "x-apple.systempreferences:\(destination)")!
    guard NSWorkspace.shared.open(url) else {
      let alert = NSAlert()
      alert.messageText = "Open Screen Saver Settings"
      alert.informativeText =
        "Open System Settings and find Screen Saver, then select ThreeBody. If ThreeBody is missing, install the ThreeBody package first."
      alert.addButton(withTitle: "OK")
      alert.beginSheetModal(for: window)
      return
    }
  }

  func setupMenu() {
    let bar = NSMenu()
    let appItem = NSMenuItem()
    let viewItem = NSMenuItem()
    bar.addItem(appItem)
    bar.addItem(viewItem)
    let app = NSMenu()
    appItem.submenu = app
    app.addItem(withTitle: "Settings…", action: #selector(settings(_:)), keyEquivalent: ",")
      .target = self
    app.addItem(
      withTitle: "Open Screen Saver Settings", action: #selector(openScreenSaverSettings(_:)),
      keyEquivalent: "").target = self
    app.addItem(.separator())
    app.addItem(
      withTitle: "Quit ThreeBody", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    let view = NSMenu(title: "View")
    viewItem.submenu = view
    for (title, action, key) in [
      ("Pause / Resume", #selector(pause(_:)), "p"), ("Next Scene", #selector(next(_:)), "n"),
      ("Restart", #selector(restart(_:)), "r"), ("Full Screen", #selector(fullscreen(_:)), "f"),
    ] { view.addItem(withTitle: title, action: action, keyEquivalent: key).target = self }
    NSApp.mainMenu = bar
  }
  @objc func pause(_ sender: Any?) {
    paused.toggle()
    lastTime = nil
  }
  @objc func next(_ sender: Any?) { renderer.scene.next() }
  @objc func restart(_ sender: Any?) {
    renderer.scene.restart()
    lastTime = nil
  }
  @objc func fullscreen(_ sender: Any?) { window.toggleFullScreen(nil) }
  @objc func settings(_ sender: Any?) {
    panel = SettingsPanel(
      settings: renderer.scene.settings,
      replay: { [weak self] in self?.renderer.scene.replaySettings ?? Settings() }
    ) { [weak self] s in
      guard let self else { return }
      let old = self.renderer.scene.settings
      s.save(self.defaults)
      self.renderer.scene.settings = s
      if old.scenes != s.scenes || old.seed != s.seed || old.presetID != s.presetID {
        self.renderer.scene.reseed(s.seed)
        self.renderer.scene.next(index: Preset.catalog.firstIndex { $0.id == s.presetID })
      }
      self.startTimer()
    }
    window.beginSheet(panel!.window)
  }
  func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
  func applicationWillTerminate(_ notification: Notification) {
    timer?.invalidate()
    renderer?.drain()
    if let benchmarkActivity { ProcessInfo.processInfo.endActivity(benchmarkActivity) }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  func capture(destination: String, width: Int, height: Int) {
    do {
      try Capture.run(
        renderer: renderer, destination: URL(fileURLWithPath: destination), width: width,
        height: height, video: !args.contains("--no-video"))
      NSApp.terminate(nil)
    } catch {
      try? String(describing: error).write(
        toFile: destination + "/capture-error.txt", atomically: true, encoding: .utf8)
      NSApp.terminate(nil)
    }
  }
  func lifecycleTest() {
    do {
      let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(
        "ThreeBody.saver")
      guard let bundle = Bundle(url: url), bundle.load(),
        let type = bundle.principalClass as? ScreenSaverView.Type
      else { throw RenderError.unavailable("Saver bundle failed to load") }
      var log = ["Loaded development saver from \(url.path)"]
      var retainedViews: [ScreenSaverView] = []
      for cycle in 0..<20 {
        let view = type.init(
          frame: NSRect(
            x: 0, y: 0, width: cycle % 2 == 0 ? 320 : 1200, height: cycle % 2 == 0 ? 200 : 750),
          isPreview: cycle % 2 == 0)!
        metal.addSubview(view)
        weak var releasedMetal: MTKView?
        weak var releasedDelegate: AnyObject?
        try autoreleasepool {
          view.startAnimation()
          view.startAnimation()
          var drawableIDs = Set<UInt64>()
          for _ in 0..<5 {
            view.animateOneFrame()
            drawableIDs.insert(
              (view.value(forKey: "diagnosticLastDrawableID") as! NSNumber).uint64Value)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
          }
          guard drawableIDs.count > 1 else {
            view.stopAnimation()
            throw RenderError.unavailable(
              "FAIL: displayed drawable never changed across five frames")
          }
          releasedMetal = view.subviews.first as? MTKView
          releasedDelegate = releasedMetal?.delegate
          view.stopAnimation()
        }
        guard releasedMetal == nil && releasedDelegate == nil else {
          throw RenderError.unavailable("FAIL: stopped saver retains its Metal view or renderer")
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        // A layer-backed ancestor may keep an implicit CALayer, but a stopped
        // saver must not request its own backing store or retain bitmap contents.
        guard !view.wantsLayer && view.layer?.contents == nil else {
          throw RenderError.unavailable(
            "FAIL: stopped saver retains bitmap contents or requests a backing store")
        }
        let before = view.value(forKey: "diagnosticSubmittedFrames") as! Int
        let time = view.value(forKey: "diagnosticSimulationTime") as! Double
        view.animateOneFrame()
        precondition(before == view.value(forKey: "diagnosticSubmittedFrames") as! Int)
        precondition(time == view.value(forKey: "diagnosticSimulationTime") as! Double)

        weak var detachedMetal: MTKView?
        try autoreleasepool {
          view.startAnimation()
          view.animateOneFrame()
          guard (view.value(forKey: "diagnosticSubmittedFrames") as! Int) > 0 else {
            throw RenderError.unavailable("FAIL: restarted saver does not render")
          }
          detachedMetal = view.subviews.first as? MTKView
          view.removeFromSuperview()
          view.animateOneFrame()
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        guard detachedMetal == nil else {
          throw RenderError.unavailable(
            "FAIL: detached saver retains Metal resources without stop callback")
        }
        metal.addSubview(view)
        view.stopAnimation()
        view.setFrameSize(.zero)
        view.startAnimation()
        view.animateOneFrame()
        view.stopAnimation()
        precondition(view.hasConfigureSheet && view.configureSheet != nil)
        view.removeFromSuperview()
        retainedViews.append(view)
        log.append(
          "cycle \(cycle+1): repeated start, rotating drawables, stop, late callback, restart, zero size, settings PASS"
        )
      }
      withExtendedLifetime(retainedViews) {}
      try log.joined(separator: "\n").write(
        toFile: argument("--log") ?? "/tmp/ThreeBody-lifecycle.log", atomically: true,
        encoding: .utf8)
    } catch {
      try? String(describing: error).write(
        toFile: argument("--log") ?? "/tmp/ThreeBody-lifecycle.log", atomically: true,
        encoding: .utf8)
    }
    NSApp.terminate(nil)
  }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
