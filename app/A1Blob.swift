// A1'S TWO PLATES (a1_blob.lua, a1_e16blob.lua): half-transparent black, rounded, above every window, on every space.
// THE TIME BLOB is the clock of the insert point, one line, white once the .txt beside the set holds that number, red
// until then and while Live plays; at the bottom middle of Live's screen by default. THE E16 BLOB is a MIDI monitor,
// newest message at the top, at the top right. Both: press anywhere and drag to move (the place is remembered, in the
// Lua's top-left screen coordinates), ✕ hides it, the ◢ grip resizes. The E16 plate also has CLEAR.
import AppKit

// top-left global coordinates (as Hammerspoon and the settings file count) ↔ AppKit's bottom-left
func a1PrimaryH() -> CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
func a1TopLeft(_ r: NSRect) -> CGRect { CGRect(x: r.minX, y: a1PrimaryH() - r.maxY, width: r.width, height: r.height) }
func a1Cocoa(_ r: CGRect) -> NSRect { NSRect(x: r.minX, y: a1PrimaryH() - r.minY - r.height, width: r.width, height: r.height) }

let BLOB_RED = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
let BLOB_GREEN = NSColor(red: 0.30, green: 0.85, blue: 0.44, alpha: 1)
let BLOB_ORANGE = NSColor(red: 0.98, green: 0.62, blue: 0.20, alpha: 1)
let BLOB_DIM = NSColor(white: 1, alpha: 0.45)

final class PlateView: NSView {
    var onClose: (() -> Void)?, onClear: (() -> Void)?, onMoved: (() -> Void)?, onResize: ((NSPoint) -> Void)?, onResized: (() -> Void)?
    var hasClear = false
    private enum Drag { case move(NSPoint), resize }
    private var drag: Drag?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func draw(_ r: NSRect) {
        NSColor(white: 0, alpha: 0.5).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        let a: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Menlo", size: 12)!, .foregroundColor: BLOB_DIM]
        ("✕" as NSString).draw(at: NSPoint(x: bounds.width - 20, y: 4), withAttributes: a)
        ("◢" as NSString).draw(at: NSPoint(x: bounds.width - 17, y: bounds.height - 18), withAttributes: a)
        if hasClear { ("CLEAR" as NSString).draw(at: NSPoint(x: bounds.width - 78, y: 7), withAttributes: [.font: NSFont(name: "Menlo", size: 10)!, .foregroundColor: BLOB_DIM]) }
    }
    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if p.x > bounds.width - 24 && p.y < 24 { onClose?(); return }
        if hasClear && p.x > bounds.width - 84 && p.x < bounds.width - 26 && p.y < 24 { onClear?(); return }
        if p.x > bounds.width - 22 && p.y > bounds.height - 22 { drag = .resize; return }
        drag = .move(NSPoint(x: NSEvent.mouseLocation.x - window!.frame.minX, y: NSEvent.mouseLocation.y - window!.frame.minY))
    }
    override func mouseDragged(with e: NSEvent) {
        guard let d = drag, let w = window else { return }
        let m = NSEvent.mouseLocation
        switch d {
        case .move(let off): w.setFrameOrigin(NSPoint(x: m.x - off.x, y: m.y - off.y))
        case .resize: onResize?(m)
        }
    }
    override func mouseUp(with e: NSEvent) {
        if case .move = drag { onMoved?() } else if case .resize = drag { onResized?() }
        drag = nil
    }
}

class Plate {
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 58), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let view = PlateView()
    var screen: () -> CGRect = { a1TopLeft(NSScreen.main?.visibleFrame ?? .zero) }   // Live's screen, top-left coordinates
    var pos: CGPoint?                                                              // where he left it, top-left
    var moved: ((CGPoint?) -> Void)?
    var closed: (() -> Void)?
    init() {
        panel.level = .statusBar; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false; panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = view
        view.onClose = { [weak self] in if let c = self?.closed { c() } else { self?.hide() } }
        view.onMoved = { [weak self] in guard let self = self else { return }; let tl = a1TopLeft(self.panel.frame); self.pos = tl.origin; self.moved?(tl.origin) }
    }
    var size: CGSize { panel.frame.size }
    func home() -> CGRect { fatalError("subclass") }
    // the remembered place, if it is still on a screen
    func remembered() -> CGRect? {
        guard let p = pos else { return nil }
        let c = CGPoint(x: p.x + size.width / 2, y: p.y + size.height / 2)
        for s in NSScreen.screens where a1TopLeft(s.frame).contains(c) { return CGRect(origin: p, size: size) }
        return nil
    }
    func place() { panel.setFrame(a1Cocoa(remembered() ?? home()), display: true) }
    func setFrameTL(_ r: CGRect) { panel.setFrame(a1Cocoa(r), display: true); view.needsDisplay = true }
    func show() { if !panel.isVisible { place(); panel.orderFrontRegardless() } }
    func hide() { panel.orderOut(nil) }
    var showing: Bool { panel.isVisible }
    func goHome() { pos = nil; moved?(nil); setFrameTL(home()) }
    func frameTL() -> CGRect { a1TopLeft(panel.frame) }
}

final class TimeBlob: Plate {
    let label = NSTextField(labelWithString: "--:--")
    var font = "Menlo-Bold", fontSize: CGFloat = 30
    var resized: ((CGFloat) -> Void)?
    let PADX: CGFloat = 22, PADY: CGFloat = 10
    override init() {
        super.init()
        label.alignment = .center; label.textColor = BLOB_RED; label.backgroundColor = .clear
        view.addSubview(label)
        view.onResize = { [weak self] m in
            guard let self = self else { return }
            let top = self.panel.frame.maxY
            let h = max(28, top - m.y)
            let s = max(10, min(200, ((h - 2 * self.PADY) / 1.35).rounded(.down)))
            if s != self.fontSize { self.fontSize = s; self.style(nil, s, keepTop: true) }
        }
        view.onResized = { [weak self] in guard let self = self else { return }; self.resized?(self.fontSize) }
        style(nil, nil)
    }
    override func home() -> CGRect {
        let s = screen(); let w = size.width, h = size.height
        return CGRect(x: s.minX + (s.width - w) / 2, y: s.maxY - h - 28, width: w, height: h)
    }
    func fit(keepTop: Bool = false) {
        label.sizeToFit()
        let w = max(120, ceil(label.frame.width) + 2 * PADX), h = max(40, ceil(label.frame.height) + 2 * PADY)
        var f = panel.frame
        if keepTop { f.origin.y = f.maxY - h }
        f.size = CGSize(width: w, height: h)
        if f != panel.frame { panel.setFrame(f, display: true) }
        label.frame = NSRect(x: PADX / 2, y: PADY, width: w - PADX, height: h - 2 * PADY)
        view.needsDisplay = true
    }
    func position(_ text: String, saved: Bool) {
        let changed = text.count != label.stringValue.count
        label.stringValue = text
        label.textColor = saved ? .white : BLOB_RED
        if changed { fit() }
    }
    func style(_ f: String?, _ s: CGFloat?, keepTop: Bool = false) {
        if let f = f, !f.isEmpty { font = f }
        if let s = s, s > 0 { fontSize = s }
        label.font = NSFont(name: font, size: fontSize) ?? .monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        fit(keepTop: keepTop)
    }
}

struct E16Line { let text: String; let tone: String; let rgb: [Double]? }   // tone "w", "o", or "h" (the headings)

final class E16Blob: Plate {
    let head = NSTextField(labelWithString: "")
    let body = NSTextField(labelWithString: "")
    var font = "Menlo", fontSize: CGFloat = 13
    var fixed: CGSize?
    var resized: ((CGSize) -> Void)?
    var cleared: (() -> Void)?
    let PADX: CGFloat = 18, PADY: CGFloat = 10
    private var lastHead = "", lastBodyCount = -1
    override init() {
        super.init()
        view.hasClear = true
        for t in [head, body] { t.backgroundColor = .clear; t.lineBreakMode = .byClipping; t.maximumNumberOfLines = 0; view.addSubview(t) }
        view.onClear = { [weak self] in self?.cleared?() }
        view.onResize = { [weak self] m in
            guard let self = self else { return }
            let f = self.panel.frame
            let w = max(220, m.x - f.minX), h = max(60, f.maxY - m.y)
            self.fixed = CGSize(width: w, height: h)
            self.panel.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: w, height: h), display: true)
            self.layout()
        }
        view.onResized = { [weak self] in guard let self = self, let s = self.fixed else { return }; self.resized?(s) }
    }
    override func home() -> CGRect {
        let s = screen(); let w = size.width, h = size.height
        return CGRect(x: s.maxX - w - 28, y: s.minY + 28, width: w, height: h)
    }
    func layout() {
        let w = panel.frame.width, h = panel.frame.height
        let headH = ceil(fontSize * 1.5)
        head.frame = NSRect(x: PADX, y: PADY, width: max(40, w - 2 * PADX - 90), height: headH)
        body.frame = NSRect(x: PADX, y: PADY * 2 + headH, width: max(40, w - 2 * PADX), height: max(10, h - (PADY * 3 + headH)))
        view.needsDisplay = true
    }
    func fit() {
        if let f = fixed { var r = panel.frame; r.origin.y = r.maxY - f.height; r.size = f; panel.setFrame(r, display: true); layout(); return }
        let hz = head.attributedStringValue.size(), bz = body.attributedStringValue.size()
        var w = max(300, ceil(max(hz.width + 124, bz.width)) + 2 * PADX)
        var h = max(70, ceil(fontSize * 1.5 + bz.height) + 3 * PADY)
        let s = screen(), at = frameTL()
        w = min(w, max(300, s.maxX - at.minX - 8)); h = min(h, max(70, s.maxY - at.minY - 8))
        var r = panel.frame; r.origin.y = r.maxY - h; r.size = CGSize(width: w, height: h)
        if r != panel.frame { panel.setFrame(r, display: true) }
        layout()
    }
    func set(_ headText: String, _ lines: [E16Line], heard: Bool) {
        let f = NSFont(name: font, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        head.attributedStringValue = NSAttributedString(string: headText, attributes: [.font: f, .foregroundColor: heard ? BLOB_GREEN : BLOB_RED])
        let st = NSMutableAttributedString()
        for (i, l) in lines.enumerated() {
            var c: NSColor = .white
            if l.tone == "h" { c = BLOB_DIM } else if let rgb = l.rgb, rgb.count == 3 { c = NSColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1) } else if l.tone == "o" { c = BLOB_ORANGE }
            st.append(NSAttributedString(string: (i > 0 ? "\n" : "") + l.text, attributes: [.font: f, .foregroundColor: c]))
        }
        body.attributedStringValue = st
        let changed = headText != lastHead || lines.count != lastBodyCount
        lastHead = headText; lastBodyCount = lines.count
        if changed { fit() } else { layout() }
    }
    func style(_ s: CGFloat) { fontSize = s; fit() }
    func setSize(_ s: CGSize?) { fixed = s; fit() }
}
