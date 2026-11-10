import AppKit

final class SettingsPanel: NSObject {
  let window: NSWindow
  private var value: Settings
  private let changed: (Settings) -> Void
  private let replay: (() -> Settings)?
  private var mode = NSPopUpButton(), scenes = NSPopUpButton(), speed = NSPopUpButton(),
    quality = NSPopUpButton()
  private var trail = NSSlider(), glow = NSSlider(), grid = NSSlider()
  private let seed = NSTextField()
  private var randomStart = NSButton(
    checkboxWithTitle: "Randomize each start", target: nil, action: nil)
  init(settings: Settings, replay: (() -> Settings)? = nil, changed: @escaping (Settings) -> Void) {
    value = settings
    self.changed = changed
    self.replay = replay
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 540), styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = "ThreeBody · Settings"
    window.isReleasedWhenClosed = false
    super.init()
    let root = NSStackView()
    root.orientation = .vertical
    root.alignment = .leading
    root.spacing = 16
    root.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
    window.contentView = root
    let title = NSTextField(labelWithString: "A little gravity. A lot of quiet.")
    title.font = .systemFont(ofSize: 18, weight: .medium)
    root.addArrangedSubview(title)
    mode.addItems(withTitles: VisualMode.allCases.map(\.rawValue))
    scenes.addItems(withTitles: SceneMode.allCases.map(\.rawValue))
    speed.addItems(withTitles: ["0.5×", "1×", "2×"])
    quality.addItems(withTitles: Quality.allCases.map(\.rawValue))
    func row(_ title: String, _ view: NSView) {
      let label = NSTextField(labelWithString: title)
      label.widthAnchor.constraint(equalToConstant: 115).isActive = true
      let r = NSStackView(views: [label, view])
      r.spacing = 12
      view.widthAnchor.constraint(equalToConstant: 245).isActive = true
      root.addArrangedSubview(r)
    }
    row("Visual mode", mode)
    row("Scenes", scenes)
    row("Speed", speed)
    trail = NSSlider(
      value: settings.trailSeconds, minValue: 8, maxValue: 25, target: self,
      action: #selector(update))
    glow = NSSlider(
      value: settings.glow, minValue: 0.2, maxValue: 2, target: self, action: #selector(update))
    grid = NSSlider(
      value: settings.grid, minValue: 0, maxValue: 1.5, target: self, action: #selector(update))
    row("Trail · 8–25 s", trail)
    row("Glow", glow)
    row("Grid light", grid)
    row("Quality", quality)
    seed.stringValue = String(settings.seed)
    seed.target = self
    seed.action = #selector(update)
    randomStart.target = self
    randomStart.action = #selector(update)
    row("Start", randomStart)
    row("Fixed seed", seed)
    for p in [mode, scenes, speed, quality] {
      p.target = self
      p.action = #selector(update)
    }
    let buttons = NSStackView()
    buttons.spacing = 10
    for (name, action) in [
      ("Reset", #selector(reset)), ("Import…", #selector(importSettings)),
      ("Export…", #selector(exportSettings)), ("Done", #selector(done)),
    ] { buttons.addArrangedSubview(NSButton(title: name, target: self, action: action)) }
    root.addArrangedSubview(buttons)
    sync()
  }
  private func sync() {
    mode.selectItem(withTitle: value.mode.rawValue)
    scenes.selectItem(withTitle: value.scenes.rawValue)
    speed.selectItem(at: [0.5, 1, 2].firstIndex(of: value.speed) ?? 1)
    quality.selectItem(withTitle: value.quality.rawValue)
    trail.doubleValue = value.trailSeconds
    glow.doubleValue = value.glow
    grid.doubleValue = value.grid
    seed.stringValue = String(value.seed)
    randomStart.state = value.randomizeStart == false ? .off : .on
    seed.isEnabled = randomStart.state == .off
  }
  @objc private func update() {
    value.mode = VisualMode(rawValue: mode.titleOfSelectedItem ?? "") ?? .fabric
    value.scenes = SceneMode(rawValue: scenes.titleOfSelectedItem ?? "") ?? .auto
    value.speed = [0.5, 1, 2][max(0, speed.indexOfSelectedItem)]
    value.quality = Quality(rawValue: quality.titleOfSelectedItem ?? "") ?? .auto
    value.trailSeconds = trail.doubleValue
    value.glow = glow.doubleValue
    value.grid = grid.doubleValue
    value.seed = UInt64(seed.stringValue) ?? value.seed
    value.randomizeStart = randomStart.state == .on
    seed.isEnabled = randomStart.state == .off
    value.sanitize()
    changed(value)
  }
  @objc private func reset() {
    value = Settings()
    sync()
    changed(value)
  }
  @objc private func done() {
    update()
    if let parent = window.sheetParent { parent.endSheet(window) } else { window.close() }
  }
  @objc private func importSettings() {
    let p = NSOpenPanel()
    p.allowedContentTypes = [.json]
    p.canChooseDirectories = false
    p.beginSheetModal(for: window) { response in
      guard response == .OK, let url = p.url else { return }
      do {
        var s = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
        s.sanitize()
        self.value = s
        self.sync()
        self.changed(s)
      } catch {
        let a = NSAlert(error: error)
        a.beginSheetModal(for: self.window)
      }
    }
  }
  @objc private func exportSettings() {
    update()
    let p = NSSavePanel()
    p.allowedContentTypes = [.json]
    p.nameFieldStringValue = "ThreeBody.json"
    p.beginSheetModal(for: window) { response in
      guard response == .OK, let url = p.url else { return }
      do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self.replay?() ?? self.value).write(to: url, options: .atomic)
      } catch {
        let a = NSAlert(error: error)
        a.beginSheetModal(for: self.window)
      }
    }
  }
}
