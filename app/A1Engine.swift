// ABLETON ASSISTANT A1, the engine: everything apps/a1.lua did, in Swift (13.10.2026, Marko: "no more Lua, only Swift").
//   THE FILTER   an event tap between his hands and Live, active only while Live is in front and the key is addressed to
//                Live's own process, never while something that takes text has the focus; every override has its tick.
//   THE MEMORY   the insert point written to a .txt beside the set the moment it moves, put back when Live starts.
//   THE BLOBS    the clock of the insert point; the E16 MIDI monitor.
//   THE MARKERS  7 / 8 / 9, two ticked markers are the loop, I and O on the next transient's zero, L the loop.
// The settings are the Lua's own file, ~/.config/ableton-assistant-a1.json, kept key for key.
import AppKit
import ApplicationServices

let A1_CONF = URL(fileURLWithPath: NSHomeDirectory() + "/.config/ableton-assistant-a1.json")
let A1_OLD_CONF = URL(fileURLWithPath: NSHomeDirectory() + "/.config/live-keys.json")
let A1_FALLBACK = NSHomeDirectory() + "/.config/ableton-assistant-a1/positions"
let A1_POSTED: Int64 = 0xA1A1                      // our own keystrokes carry this, so the tap lets them through

// THE MAPPINGS (MEASURED 13-15.9.2026 in Live 12's menus): from the key he presses; to / tomods what Live gets; act what
// A1 does itself; menu the menu item pressed through accessibility; does / was what it does now, what it did before.
let A1_DEFAULT_MAPS: [[String: Any]] = [
    ["from": "1", "mods": [String](), "to": "-", "tomods": [String](), "blob": "zoom out", "does": "Zoom Out on the time ruler (Live's -)", "was": "nothing in Live's Arrangement"],
    ["from": "2", "mods": [String](), "to": "pad+", "tomods": [String](), "blob": "zoom in", "does": "Zoom In on the time ruler (Live's +)", "was": "nothing in Live's Arrangement"],
    ["from": "1", "mods": ["shift"], "to": "pad-", "tomods": ["alt"], "blob": "track lower", "does": "Lower the selected track (Live's Option−)", "was": "Shift+1: nothing in the Arrangement (Option+Shift+1 is the Sample tab)"],
    ["from": "2", "mods": ["shift"], "to": "pad+", "tomods": ["alt"], "blob": "track higher", "does": "Raise the selected track (Live's Option+)", "was": "Shift+2: nothing in the Arrangement (Option+Shift+2 is the Envelopes tab)"],
    ["from": "h", "mods": [String](), "to": "e", "tomods": ["cmd"], "blob": "split", "does": "Split at the selection (Live's ⌘E)", "was": "H: Optimize Arrangement Height (fit all tracks to the window)"],
    ["from": "f", "mods": ["cmd"], "to": "5", "tomods": ["cmd", "alt"], "only": "Browser", "types": true, "blob": "browser closed",
     "does": "With the browser shown: close it (Live's ⌘⌥5). With it hidden, ⌘F is Live's own: the browser opens on its search", "was": "⌘F: Search in Browser (still, when the browser is hidden)"],
    ["from": "f2", "mods": [String](), "to": "4", "tomods": ["cmd", "alt"], "blob": "device view", "does": "Device View shown, and hidden again: the devices, plug-ins, the chain (Live's ⌘⌥4)", "was": "F2: activate or deactivate track 2"],
    ["from": "f3", "mods": [String](), "to": "m", "tomods": ["cmd", "alt"], "blob": "mixer", "does": "Mixer shown, and hidden again (Live's ⌘⌥M)", "was": "F3: activate or deactivate track 3"],
    ["from": "f4", "mods": [String](), "to": "3", "tomods": ["cmd", "alt"], "blob": "clip view", "does": "Clip View shown, and hidden again (Live's ⌘⌥3)", "was": "F4: activate or deactivate track 4"],
    ["from": "7", "mods": [String](), "act": "prev-marker", "gets": "AbletonOSC: jump_to_prev_cue", "blob": "marker back", "does": "Jump the playhead back to the previous marker (Live's own Previous Locator)", "was": "7: nothing in Live (⌥7 is Help View)"],
    ["from": "8", "mods": [String](), "act": "locator", "menu": ["Create", ["Add Locator", "Delete Locator"]] as [Any], "gets": "Create › Add / Delete Locator", "blob": "locator",
     "does": "Add a marker at the playhead; standing on one, delete it (Live's Create › Add Locator, the transport's Set button)", "was": "8: nothing in Live's Arrangement"],
    ["from": "9", "mods": [String](), "act": "next-marker", "gets": "AbletonOSC: jump_to_next_cue", "blob": "marker on", "does": "Jump the playhead on to the next marker (Live's own Next Locator)", "was": "9: nothing in Live (⌘⌥7 is Help View; 9 is nothing)"],
    ["from": "down", "mods": [String](), "act": "next-transient", "gets": "the next transient, then AbletonOSC", "blob": "transient ▶", "does": "Put the insert point on the next transient to the right; nothing is marked", "was": "↓: Live moves the track selection down (it is on ⌘↓ now)"],
    ["from": "up", "mods": [String](), "act": "back-transient", "gets": "the previous transient, then AbletonOSC", "blob": "◀ transient", "does": "Put the insert point on the previous transient to the left; nothing is marked", "was": "↑: Live moves the track selection up (it is on ⌘↑ now)"],
    ["from": "down", "mods": ["cmd"], "act": "next-track", "gets": "AbletonOSC: selected_track", "blob": "track ▼", "does": "Select the next track down", "was": "⌘↓: nothing in Live's menus"],
    ["from": "up", "mods": ["cmd"], "act": "back-track", "gets": "AbletonOSC: selected_track", "blob": "track ▲", "does": "Select the previous track up", "was": "⌘↑: nothing in Live's menus"],
    ["from": "down", "mods": ["alt"], "act": "move-track-down", "gets": "the track header, dragged", "blob": "track moved down", "does": "Move the selected track down one place (its header is dragged past the track below, as your hand would)", "was": "⌥↓: nothing in Live's menus"],
    ["from": "up", "mods": ["alt"], "act": "move-track-up", "gets": "the track header, dragged", "blob": "track moved up", "does": "Move the selected track up one place (its header is dragged past the track above, as your hand would)", "was": "⌥↑: nothing in Live's menus"],
    ["from": "i", "mods": [String](), "act": "in-transient", "gets": "the next transient, then AbletonOSC", "blob": "transient in", "does": "Jump to the first transient to the right of the insert point and mark the loop's IN on its waveform's zero", "was": "I: nothing in Live (⌘I is Insert Silence)"],
    ["from": "o", "mods": [String](), "act": "out-transient", "gets": "the next transient, then AbletonOSC", "blob": "transient out", "does": "Jump to the first transient to the right of the insert point and mark the loop's OUT on its waveform's zero", "was": "O: Playback › Metronome on or off"],
    ["from": "l", "mods": [String](), "act": "toggle", "menu": ["Edit", ["Deactivate Loop", "Activate Loop"]] as [Any], "gets": "Edit › Activate / Deactivate Loop", "blob": "loop", "does": "Turn Live's loop on, and off again (Live's own ⌘L, pressed through accessibility)", "was": "L: nothing in Live (⌘L is Deactivate Loop)"],
]
// a keystroke mapping's menu item, when Live has one (MEASURED 14.9.2026): pressed instead of the keystroke
let A1_MENU: [String: [String]] = ["-": ["View", "Zoom Out Time"], "pad+": ["View", "Zoom In Time"], "cmd e": ["Edit", "Split"],
    "cmd alt 5": ["View", "Browser"], "cmd alt 4": ["View", "Device View"], "cmd alt m": ["View", "Mixer"], "cmd alt 3": ["View", "Clip View"]]
let A1_FOLLOW: [Any] = ["Playback", "Move Insert Marker To Playhead"]
let A1_FONTS: [(key: String, name: String, normal: String, bold: String)] = [
    ("menlo", "Menlo", "Menlo-Regular", "Menlo-Bold"), ("monaco", "Monaco", "Monaco", "Monaco"),
    ("helvetica", "Helvetica Neue", "HelveticaNeue", "HelveticaNeue-Bold"), ("avenir", "Avenir Next", "AvenirNext-Regular", "AvenirNext-DemiBold"),
    ("futura", "Futura", "Futura-Medium", "Futura-Bold"), ("din", "DIN Alternate", "DINAlternate-Bold", "DINAlternate-Bold"),
    ("dincond", "DIN Condensed", "DINCondensed-Bold", "DINCondensed-Bold"), ("courier", "Courier New", "CourierNewPSMT", "CourierNewPS-BoldMT"),
    ("impact", "Impact", "Impact", "Impact"), ("copperplate", "Copperplate", "Copperplate", "Copperplate-Bold")]
let A1_SIZES: [Int] = [22, 30, 38, 48, 64]
let A1_DELTAS = ["sensitive": 0.12, "normal": 0.25, "strong": 0.45]
let A1_FLAGS: Set<String> = ["space", "follow", "openLast", "resume", "viaMenu", "blob", "midiBlob"]

func mapMods(_ m: [String: Any], _ k: String = "mods") -> [String] { (m[k] as? [String]) ?? [] }
func mapId(_ m: [String: Any]) -> String { (A1MODS.filter { mapMods(m).contains($0) } + ["\(m["from"] ?? "")"]).joined(separator: " ") }

struct A1Seen { var key = "", focus = "", did = "", at: Double = 0 }
struct A1Command { let path: [String]; let words: String; let key: String; let enabled: Bool }
struct A1Marker { let key: String; let name: String; let time: Double; let clock: String; let bars: String; let ticked: Bool; let role: String? }

final class A1Engine: ObservableObject {
    static var shared: A1Engine!
    @Published var tick = 0                       // the window redraws on it
    var conf: [String: Any] = [:]
    var on = false

    // the filter
    var tap: CFMachPort?, tapSource: CFRunLoopSource?, tapRetry: Timer?
    var tapOK = false
    var byCode: [Int: [[String: Any]]] = [:]
    var typing = false
    var held: Set<Int> = []
    var seen = A1Seen()
    var countSpace = 0, countKeys = 0
    var status = "", statusAt: Double = 0

    // Live
    var liveAX: AXUIElement?, liveAXPid: pid_t = 0
    let wire = A1Wire()
    var sampler: Timer?, fast: Timer?, hunt: Timer?
    var samplerPid: pid_t = 0
    var knownTitle: String?
    var launchUntil: Double = 0
    var lastLaunch = (at: 0.0, note: "")
    var tempo: Double?, numerator: Double?, tempoAt: Double = 0
    var playing = false
    var files: [String: (path: String, at: Double, fallback: Bool)] = [:]
    var written: [String: Double] = [:], lastBeats: [String: Double] = [:]
    var posState = (title: "", note: "", at: 0.0)
    var restoring: (title: String, beats: Double, until: Double)?
    var lastWhy: String?

    // markers and the loop
    var cues: [OSC.Cue] = [], cuesAt: Double = 0
    var liveLoop: (on: Bool?, start: Double?, length: Double?) = (nil, nil, nil)
    var loopNote: String?
    var selectedTrack: Int?, numTracks: Int?
    var transientTask: Process?, transientAt: Double = 0
    var dragging = false
    var pythonFound: String?, pythonWhy: String?, pythonAt: Double = 0

    // Live's whole menu, read through accessibility
    var commands: [A1Command] = [], commandsPid: pid_t = 0, commandsWhy = "not read yet", readingMenus = false

    // the plates
    lazy var timeBlob: TimeBlob = {
        let b = TimeBlob(); b.screen = { [weak self] in self?.liveScreen() ?? a1TopLeft(NSScreen.main?.visibleFrame ?? .zero) }
        if let p = conf["blobPos"] as? [String: Any], let x = (p["x"] as? NSNumber)?.doubleValue, let y = (p["y"] as? NSNumber)?.doubleValue { b.pos = CGPoint(x: x, y: y) }
        b.moved = { [weak self] p in self?.setConf("blobPos", p.map { ["x": $0.x, "y": $0.y] }) }
        b.closed = { [weak self] in self?.setFlag("blob", false) }
        b.resized = { [weak self] s in self?.setConf("blobSize", Int(s)) }
        b.style(fontName(), CGFloat(intConf("blobSize", 30)))
        return b
    }()
    let midi = A1MIDI()
    lazy var e16: E16Blob = {
        let b = E16Blob(); b.screen = { [weak self] in self?.liveScreen() ?? a1TopLeft(NSScreen.main?.visibleFrame ?? .zero) }
        if let p = conf["midiBlobPos"] as? [String: Any], let x = (p["x"] as? NSNumber)?.doubleValue, let y = (p["y"] as? NSNumber)?.doubleValue { b.pos = CGPoint(x: x, y: y) }
        b.moved = { [weak self] p in self?.setConf("midiBlobPos", p.map { ["x": $0.x, "y": $0.y] }) }
        b.closed = { [weak self] in self?.setFlag("midiBlob", false) }
        b.cleared = { [weak self] in self?.midiClear() }
        b.resized = { [weak self] s in self?.conf["midiBlobW"] = Double(s.width); self?.conf["midiBlobH"] = Double(s.height); self?.save() }
        b.fontSize = CGFloat(intConf("midiBlobSize", 13))
        if let w = (conf["midiBlobW"] as? NSNumber)?.doubleValue, let h = (conf["midiBlobH"] as? NSNumber)?.doubleValue { b.fixed = CGSize(width: w, height: h) }
        return b
    }()
    var midiTimer: Timer?

    init() { A1Engine.shared = self; load() }

    // MARK: the settings

    func flag(_ k: String) -> Bool { (conf[k] as? Bool) ?? true }
    func str(_ k: String, _ d: String) -> String { (conf[k] as? String) ?? d }
    func intConf(_ k: String, _ d: Int) -> Int { (conf[k] as? NSNumber)?.intValue ?? d }
    var maps: [[String: Any]] { get { (conf["maps"] as? [[String: Any]]) ?? [] } set { conf["maps"] = newValue } }
    func dict(_ k: String) -> [String: Any] { (conf[k] as? [String: Any]) ?? [:] }
    func setConf(_ k: String, _ v: Any?) { conf[k] = v; save() }
    func fontName() -> String {
        let f = A1_FONTS.first { $0.key == str("blobFamily", "menlo") } ?? A1_FONTS[0]
        return flag("blobBold") ? f.bold : f.normal
    }

    func load() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: A1_CONF.path) && fm.fileExists(atPath: A1_OLD_CONF.path) { try? fm.moveItem(at: A1_OLD_CONF, to: A1_CONF) }
        var c = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: A1_CONF))) as? [String: Any]) ?? [:]
        if !(c["maps"] is [Any]) { c = ["space": true, "follow": true, "openLast": true, "resume": true, "viaMenu": true, "blob": true,
                                        "unit": "minsec", "blobFamily": "menlo", "blobBold": true, "blobSize": 30, "midiBlob": false, "midiDevice": "",
                                        "midiLines": 12, "midiBlobSize": 13, "midiColour": "knob", "midiScene": "", "midiPage": 1,
                                        "loops": [String: Any](), "marks": [String: Any](), "transient": "normal", "removed": [String: Any](), "maps": A1_DEFAULT_MAPS] }
        for k in ["space", "follow", "openLast", "resume", "viaMenu", "blob"] where c[k] == nil { c[k] = true }
        if c["midiBlob"] == nil { c["midiBlob"] = false }
        if !(c["midiDevice"] is String) { c["midiDevice"] = "" }
        if ((c["midiLines"] as? NSNumber)?.intValue ?? -1) < 0 { c["midiLines"] = 12 }
        if ((c["midiBlobSize"] as? NSNumber)?.intValue ?? 0) < 9 { c["midiBlobSize"] = 13 }
        if (c["midiColour"] as? String) != "alternate" { c["midiColour"] = "knob" }
        if !(c["midiScene"] is String) { c["midiScene"] = "" }
        if ((c["midiPage"] as? NSNumber)?.intValue ?? 0) < 1 { c["midiPage"] = 1 }
        if !["minsec", "bars", "beats"].contains(c["unit"] as? String ?? "") { c["unit"] = "minsec" }
        if !A1_FONTS.contains(where: { $0.key == c["blobFamily"] as? String }) { c["blobFamily"] = "menlo" }
        if c["blobBold"] == nil { c["blobBold"] = true }
        if ((c["blobSize"] as? NSNumber)?.intValue ?? 0) < 10 { c["blobSize"] = 30 }
        for k in ["loops", "marks", "removed"] where !(c[k] is [String: Any]) { c[k] = [String: Any]() }     // an empty table may have been written as []
        if !["sensitive", "normal", "strong"].contains(c["transient"] as? String ?? "") { c["transient"] = "normal" }
        // the shipped mappings are fresh from this code every load; his tick (off) survives; his own additions stay
        var shipped: [String: [String: Any]] = [:]; for d in A1_DEFAULT_MAPS { shipped[mapId(d)] = d }
        var kept: [[String: Any]] = []
        for m in (c["maps"] as? [[String: Any]]) ?? [] {
            if var d = shipped[mapId(m)] { if let off = m["off"] { d["off"] = off }; kept.append(d) }
            else if m["act"] == nil { kept.append(m) }
        }
        let removed = (c["removed"] as? [String: Any]) ?? [:]
        for d in A1_DEFAULT_MAPS where removed[mapId(d)] == nil && !kept.contains(where: { mapId($0) == mapId(d) }) { kept.append(d) }
        c["maps"] = kept
        conf = c
        index()
    }
    func save() {
        try? FileManager.default.createDirectory(at: A1_CONF.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONSerialization.data(withJSONObject: conf, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: A1_CONF) }
    }
    func index() {
        byCode = [:]
        for m in maps where (m["off"] as? Bool) != true {
            guard let code = A1KEY["\(m["from"] ?? "")"] else { continue }
            if m["act"] != nil || m["menu"] != nil || A1KEY["\(m["to"] ?? "")"] != nil { byCode[code, default: []].append(m) }
        }
    }
    func say(_ s: String) { status = s; statusAt = a1Time(); tick += 1 }

    // MARK: on and off

    func start() {
        guard !on else { return }
        on = true
        load()
        typing = false
        startTap()
        tapRetry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in if self?.tap == nil { self?.startTap() } }
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(launched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(switched(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        if liveApp() != nil { samplerStart() }
        say("Ableton Assistant A1 is on")
    }
    func stop() {
        guard on else { return }
        on = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hunt?.invalidate(); hunt = nil
        samplerStop()
        tapRetry?.invalidate(); tapRetry = nil
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        if let s = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil; tapSource = nil; tapOK = false
        timeBlob.hide(); midiHide()
        say("off: every key is Live's own again")
    }
    func isLive(_ n: Notification) -> Bool { (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == BUNDLE }
    @objc func launched(_ n: Notification) {
        guard isLive(n) else { return }
        launchUntil = a1Time() + 180                   // Live scans its plug-ins first
        say(flag("openLast") ? "Live is starting: loading the last project" : "Live is starting")
        samplerStart(); knownTitle = nil
        if flag("openLast") { huntStart() }
    }
    @objc func terminated(_ n: Notification) { if isLive(n) { samplerStop() } }
    @objc func switched(_ n: Notification) { typing = false }            // a switch of app ends any typing

    // MARK: Live through accessibility

    func live() -> AXUIElement? {
        guard let app = liveApp() else { liveAX = nil; return nil }
        if liveAX == nil || liveAXPid != app.processIdentifier { liveAX = axBounded(AXUIElementCreateApplication(app.processIdentifier)); liveAXPid = app.processIdentifier }
        return liveAX
    }
    func menuItem(_ path: [Any]) -> (AXUIElement?, String) {
        guard let a = live() else { return (nil, "Live is not running") }
        guard var level = axEl(a, kAXMenuBarAttribute).map(axBounded) else { return (nil, "no menu bar") }
        for (i, step) in path.enumerated() {
            var found: AXUIElement?, near: AXUIElement?, wore = ""
            for it in axKids(level) {
                _ = axBounded(it)
                let title = axString(it, kAXTitleAttribute) ?? ""
                for name in a1Names(step) {
                    if title == name { found = it; wore = title; break }
                    if near == nil && title.hasPrefix(name) { near = it; wore = title }
                }
                if found != nil { break }
            }
            guard let f = found ?? near else { return (nil, "no menu item " + a1Names(step).joined(separator: " or ")) }
            if i == path.count - 1 { return (f, wore) }
            guard let sub = axKids(f).first.map(axBounded) else { return (nil, a1PathWords([step]) + " has no submenu") }
            level = sub
        }
        return (nil, "an empty path")
    }
    func pressMenu(_ path: [Any]) -> (Bool, String) {
        let (mi, wore) = menuItem(path)
        guard let m = mi else { return (false, wore) }
        if !axEnabled(m) { return (false, wore + " is greyed out") }
        if !axPress(m) { return (false, wore + " did not take the press") }
        return (true, wore)
    }
    func viewTicked(_ name: String) -> Bool { let (mi, _) = menuItem(["View", name]); return mi.flatMap { ax($0, "AXMenuItemMarkChar") } != nil }
    func menuEnabled(_ path: [Any]) -> Bool? { let (mi, _) = menuItem(path); return mi.map(axEnabled) }
    // what has the keyboard focus in Live: a field means he is typing, and every key is his own
    func focusRole() -> (String?, String?, Bool) {
        guard let a = live(), let el = axEl(a, kAXFocusedUIElementAttribute).map(axBounded) else { return (nil, nil, false) }
        let role = axString(el, kAXRoleAttribute), sub = axString(el, kAXSubroleAttribute)
        let editable: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        if editable.contains(role ?? "") || editable.contains(sub ?? "") { return (role, sub, true) }
        var settable: DarwinBoolean = false
        let isStr = ax(el, kAXValueAttribute) is String
        AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable)
        return (role, sub, isStr && settable.boolValue)
    }
    func findAll(_ el: AXUIElement, _ role: String, _ label: String?, _ out: inout [AXUIElement], _ depth: Int) {
        if depth > 6 { return }
        for c in axKids(el) {
            _ = axBounded(c)
            if axString(c, kAXRoleAttribute) == role && (label == nil || (axString(c, kAXTitleAttribute) ?? axString(c, kAXDescriptionAttribute)) == label) { out.append(c) }
            findAll(c, role, label, &out, depth + 1)
        }
    }
    func inWindowAll(_ role: String, _ label: String?) -> [AXUIElement] {
        guard let a = live() else { return [] }
        var out: [AXUIElement] = []
        for w in (ax(a, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { findAll(axBounded(w), role, label, &out, 1) }
        return out
    }
    func pressButton(_ title: String) -> (Bool, String) {
        guard let b = inWindowAll("AXButton", title).first else { return (false, "no AXButton \(title) in Live's window") }
        if !axEnabled(b) { return (false, title + " is greyed out") }
        return axPress(b) ? (true, "") : (false, title + " did not take the press")
    }
    func liveWindowTitle() -> String? {
        guard let a = live() else { return nil }
        for w in (ax(a, kAXWindowsAttribute) as? [AXUIElement]) ?? [] where axString(w, kAXSubroleAttribute) == kAXStandardWindowSubrole { return axString(w, kAXTitleAttribute) ?? "" }
        for k in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] { if let w = axEl(a, k), axString(w, kAXSubroleAttribute) == kAXStandardWindowSubrole { return axString(w, kAXTitleAttribute) ?? "" } }
        return nil
    }
    // Live's screen, top-left coordinates, the visible part
    func liveScreen() -> CGRect {
        if let a = live(), let w = axEl(a, kAXMainWindowAttribute) ?? axEl(a, kAXFocusedWindowAttribute), let f = axFrame(w) {
            let c = CGPoint(x: f.midX, y: f.midY)
            for s in NSScreen.screens where a1TopLeft(s.frame).contains(c) { return a1TopLeft(s.visibleFrame) }
        }
        return a1TopLeft(NSScreen.main?.visibleFrame ?? .zero)
    }

    // LIVE'S WHOLE MENU, SEARCHED (15.9.2026): every command, with the key Live gives it
    func readMenus(force: Bool = false) {
        guard let app = liveApp() else { commandsWhy = "Live is not running"; tick += 1; return }
        if !force && commandsPid == app.processIdentifier && !commands.isEmpty { return }
        if readingMenus { return }
        readingMenus = true; commandsWhy = "reading Live's menu…"; tick += 1
        let pid = app.processIdentifier
        DispatchQueue.global().async {
            let root = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(root, 1)
            var out: [A1Command] = []
            func walk(_ menu: AXUIElement, _ path: [String]) {
                for it in axKids(menu) {
                    guard let title = axString(it, kAXTitleAttribute), !title.isEmpty else { continue }
                    let here = path + [title]
                    if let sub = axKids(it).first, !axKids(sub).isEmpty { walk(sub, here); continue }
                    var key = ""
                    if let ch = axString(it, kAXMenuItemCmdCharAttribute), !ch.isEmpty {
                        let m = (ax(it, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0
                        var mods: [String] = []
                        if m & 1 != 0 { mods.append("shift") }; if m & 2 != 0 { mods.append("alt") }; if m & 4 != 0 { mods.append("ctrl") }; if m & 8 == 0 { mods.append("cmd") }
                        key = a1Chord(mods, ch.lowercased())
                    }
                    out.append(A1Command(path: here, words: here.joined(separator: " › "), key: key, enabled: axEnabled(it)))
                }
            }
            if let bar = axEl(root, kAXMenuBarAttribute) {
                for top in axKids(bar) { guard let t = axString(top, kAXTitleAttribute), t != "Apple", let m = axKids(top).first else { continue }; walk(m, [t]) }
            }
            DispatchQueue.main.async {
                self.readingMenus = false
                if out.isEmpty { self.commandsWhy = "Live gave no menu back" }
                else { self.commands = out; self.commandsPid = pid; self.commandsWhy = "\(out.count) commands, read \(a1Clock(a1Time()))" }
                self.tick += 1
            }
        }
    }

    // MARK: THE FILTER

    func startTap() {
        guard tap == nil else { return }
        // a look at the window while the Lua A1 still holds the keys: launched with --a1-no-tap, nothing is filtered
        if CommandLine.arguments.contains("--a1-no-tap") { status = "the key filter is off for this run (--a1-no-tap)"; return }
        var mask: CGEventMask = 0
        for t in [CGEventType.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown] { mask |= 1 << t.rawValue }
        let cb: CGEventTapCallBack = { _, type, ev, _ in A1Engine.shared.filter(type, ev) }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: cb, userInfo: nil) else { tapOK = false; return }
        let s = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes); CGEvent.tapEnable(tap: t, enable: true)
        tap = t; tapSource = s; tapOK = true; tick += 1
    }
    func note(_ key: String, _ focus: String, _ did: String) { seen = A1Seen(key: key, focus: focus, did: did, at: a1Time()) }
    func same(_ f: CGEventFlags, _ mods: [String]) -> Bool {
        f.contains(.maskCommand) == mods.contains("cmd") && f.contains(.maskAlternate) == mods.contains("alt")
            && f.contains(.maskControl) == mods.contains("ctrl") && f.contains(.maskShift) == mods.contains("shift")
    }
    func menuOf(_ m: [String: Any]) -> [Any]? {
        if let p = m["menu"] as? [Any] { return p }
        guard let to = m["to"] as? String else { return nil }
        return A1_MENU[(A1MODS.filter { mapMods(m, "tomods").contains($0) } + [to]).joined(separator: " ")]
    }
    // a keystroke of our own, marked so the tap lets it pass
    func post(_ mods: [String], _ key: String) {
        guard let code = A1KEY[key] else { return }
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)
            e?.flags = a1Flags(mods); e?.setIntegerValueField(.eventSourceUserData, value: A1_POSTED)
            e?.post(tap: .cghidEventTap)
        }
    }
    func act(_ path: [Any]?, _ mods: [String], _ key: String, _ what: String, _ noKey: Bool, _ word: String) {
        DispatchQueue.main.async {
            if (self.flag("viaMenu") || noKey), let p = path {
                let (ok, why) = self.pressMenu(p)
                if ok { self.seen.did = what + ": " + a1PathWords(p) + " pressed"; self.say(word); return }
                if noKey { self.seen.did = what + ": " + a1PathWords(p) + " is not there (\(why)); nothing done"; self.say(word + ": not now (\(why))"); return }
                self.seen.did = what + ": " + a1PathWords(p) + " failed (\(why)), the keystroke instead"
            } else { self.seen.did = what + ": the keystroke " + a1Chord(mods, key) }
            self.say(word)
            self.post(mods, key)
        }
    }

    func filter(_ type: CGEventType, _ e: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(e)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }; return pass }
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown { typing = false; return pass }
        if e.getIntegerValueField(.eventSourceUserData) == A1_POSTED { return pass }
        let code = Int(e.getIntegerValueField(.keyboardEventKeycode))
        let maps = byCode[code]
        let isSpace = code == A1KEY["space"]!
        let f = e.flags
        let down = type == .keyDown
        let ends = [A1KEY["return"]!, A1KEY["padenter"]!, A1KEY["escape"]!].contains(code)
        let isR = code == A1KEY["r"]! && f.contains(.maskCommand) && !f.contains(.maskAlternate) && !f.contains(.maskControl) && !f.contains(.maskShift)
        if maps == nil && !isSpace && !ends && !isR { return pass }
        guard let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier == BUNDLE else { return pass }
        let target = e.getIntegerValueField(.eventTargetUnixProcessID)
        if target > 0 && pid_t(target) != front.processIdentifier { return pass }
        if ends { if down && typing { typing = false; say("typing ended") }; return pass }
        if isR {                                       // Edit › Rename: he types a name until Return, Escape or a click
            if down && menuEnabled(["Edit", "Rename"]) != false { typing = true; note("⌘R", "Rename", "typing begins"); say("typing: every key is yours") }
            return pass
        }
        if let maps = maps {
            if !down { if held.remove(code) != nil { return nil }; return pass }   // the keyUp goes the way its keyDown went
            for m in maps where same(f, mapMods(m)) {
                let ch = a1Chord(mapMods(m), "\(m["from"] ?? "")")
                if let only = m["only"] as? String, !viewTicked(only) {      // not the moment: the key is Live's own
                    if (m["types"] as? Bool) == true { typing = true; note(ch, only + " hidden", "Live's own; typing begins"); say("search: typing, every key is yours") }
                    return pass
                }
                if typing { note(ch, "typing (after ⌘R or ⌘F)", "typed, Live's own"); return pass }
                let (role, sub, editable) = focusRole()
                if editable { note(ch, (role ?? "?") + (sub.map { "/" + $0 } ?? ""), "a field: typed, Live's own"); return pass }
                held.insert(code)
                let actName = m["act"] as? String
                note(ch, role ?? "nothing", actName.map { "A1 itself: " + $0 } ?? "mapping")
                if let a = actName {
                    DispatchQueue.main.async {
                        switch a {
                        case "in", "out": self.markLoop(a)
                        case "in-transient": self.jumpToTransient("in")
                        case "out-transient": self.jumpToTransient("out")
                        case "locator": self.locator()
                        case "prev-marker": self.jumpCue(back: true)
                        case "next-marker": self.jumpCue(back: false)
                        case "next-transient": self.jumpToTransient(nil, "right")
                        case "back-transient": self.jumpToTransient(nil, "left")
                        case "next-track": self.selectTrack(1)
                        case "back-track": self.selectTrack(-1)
                        case "move-track-down": self.moveTrack(down: true)
                        case "move-track-up": self.moveTrack(down: false)
                        default: self.toggleLoop()
                        }
                        self.seen.did = (m["does"] as? String) ?? a
                    }
                } else {
                    let tm = mapMods(m, "tomods"), to = (m["to"] as? String) ?? ""
                    act(menuOf(m), tm, to, (m["does"] as? String) ?? a1Chord(tm, to), (m["noKey"] as? Bool) == true, (m["blob"] as? String) ?? (m["does"] as? String) ?? a1Chord(tm, to))
                }
                countKeys += 1
                return nil                          // the pressed key itself never reaches Live
            }
            return pass
        }
        // SPACE CONTINUES: Space is ⇧Space (Continue Playback), then ⌘⇧Space (the insert point to the playhead)
        guard flag("space") else { return pass }
        if f.contains(.maskCommand) || f.contains(.maskAlternate) || f.contains(.maskControl) || f.contains(.maskSecondaryFn) { return pass }
        if typing { if down { note("Space", "typing (after ⌘R or ⌘F)", "typed, Live's own") }; return pass }
        let (role, sub, editable) = focusRole()
        if editable { if down { note("Space", (role ?? "?") + (sub.map { "/" + $0 } ?? ""), "a field: typed, Live's own") }; return pass }
        if f.contains(.maskShift) { e.flags = []; return pass }      // Shift+Space goes on to Live as a plain Space: Play
        if !down { return nil }
        countSpace += 1
        note("Space", role ?? "nothing", "Continue Playback")
        let (pair, whence) = braceOf()
        let intoLoop = pair != nil && (whence == "two ticked markers" || liveLoop.on == true) && !playing && !OSC.inside(lastBeats[knownTitle ?? ""], pair)
        DispatchQueue.main.async {
            if intoLoop, let p = pair {
                self.wire.tell("/live/song/set/loop", [true])
                self.wire.tell("/live/song/set/current_song_time", [p.a])
                self.seen.did = "the playhead to the loop's start marker (\(self.clock(p.a))), then Continue Playback"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (intoLoop ? 0.12 : 0)) { self.post(["shift"], "space") }
            self.say(intoLoop ? "Space: play from the loop's start " + self.clock(pair!.a) : "Space: continue, or stop")
            if self.flag("follow") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.post(["cmd", "shift"], "space"); self.seen.did = "Continue Playback (⇧Space), then the insert point to the playhead (⌘⇧Space)" } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.wire.ask("/live/song/get/is_playing", wait: 1.5) { a, _ in
                    if let p = a?.first as? Bool { self.setPlaying(p); self.say(p ? "playing" : (self.flag("follow") ? "stopped: the insert point follows" : "stopped")) }
                    else if let p = a?.first as? Double { self.setPlaying(p != 0) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.sample() }
        }
        return nil                                  // the plain space itself never reaches Live
    }

    // MARK: THE MEMORY: the insert point beside the set

    func clock(_ beats: Double?) -> String { OSC.clock(beats, tempo, str("unit", "minsec"), numerator) }
    func setFile(_ title: String) -> String {
        if let f = files[title], !f.fallback || a1Time() - f.at < 30 { return f.path }
        let (_, out) = a1Shell("/usr/bin/mdfind", ["-name", title + ".als"], timeout: 5)
        var best: String?, bestAt = Date.distantPast
        for line in out.split(separator: "\n").map(String.init) where line.hasSuffix("/" + title + ".als") && !line.contains("/Backup/") {
            let at = ((try? FileManager.default.attributesOfItem(atPath: line))?[.modificationDate] as? Date) ?? .distantPast
            if best == nil || at > bestAt { best = line; bestAt = at }
        }
        let path: String, fallback: Bool
        if let b = best { path = String(b.dropLast(4)) + ".txt"; fallback = false }
        else {
            try? FileManager.default.createDirectory(atPath: A1_FALLBACK, withIntermediateDirectories: true)
            path = A1_FALLBACK + "/" + title.replacingOccurrences(of: "/", with: "-") + ".txt"; fallback = true
        }
        files[title] = (path, a1Time(), fallback)
        return path
    }
    func hairRead(_ title: String) -> Double? {
        guard let s = try? String(contentsOfFile: setFile(title)) else { return nil }
        let num = s.trimmingCharacters(in: .whitespacesAndNewlines).prefix { "-0123456789.".contains($0) }
        return Double(num)
    }
    func hairWrite(_ title: String, _ beats: Double) -> (Bool, String) {
        let path = setFile(title)
        do { try String(format: "%.6f\n", beats).write(toFile: path, atomically: true, encoding: .utf8) } catch { return (false, "cannot write " + path) }
        written[title] = beats
        return (true, path)
    }
    func posNote(_ n: String) { posState = (knownTitle ?? "", n, a1Time()) }
    func blobPosition(_ beats: Double?, _ wr: Double?) {
        guard flag("blob") else { return }
        let (w, saved) = OSC.blob(beats, wr, tempo, str("unit", "minsec"), numerator, playing)
        timeBlob.position(w, saved: saved)
    }
    func setPlaying(_ p: Bool) {
        if p == playing { return }
        playing = p
        fast?.invalidate(); fast = nil
        if playing { fast = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.sample() } }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.sample() } }   // stopped: the stop is written at once
    }
    func sample() {
        if restoring != nil || wire.isPending("/live/song/get/current_song_time") { return }
        let title = knownTitle
        guard OSC.isSet(title) else {
            if title != nil { blobPosition(nil, nil); if lastWhy != "untitled" { lastWhy = "untitled"; say("an unsaved set has no file: save it first") } }
            return
        }
        wire.ask("/live/song/get/current_song_time") { a, why in
            guard let beats = a?.first as? Double else {
                self.posNote(why ?? "no answer"); self.blobPosition(nil, nil)
                if self.lastWhy != why { self.lastWhy = why; self.say(why ?? "no answer") }
                return
            }
            self.lastWhy = nil
            guard let t = title, t == self.knownTitle, self.restoring == nil else { return }   // the set changed while Live was thinking
            self.lastBeats[t] = beats
            if self.flag("resume") && !self.playing && OSC.moved(self.written[t], beats) {
                let (ok, where_) = self.hairWrite(t, beats)
                self.posState = (t, (ok ? "insert point at " : "NOT WRITTEN: ") + OSC.words(beats, self.numerator) + "  →  " + where_, a1Time())
                self.say(ok ? "saved " + OSC.words(beats, self.numerator) + " to " + (where_ as NSString).lastPathComponent : "NOT SAVED: " + where_)
            }
            self.blobPosition(beats, self.written[t])
            self.tick += 1
        }
    }
    func restoreTick() {
        guard let r = restoring else { return }
        if r.title != knownTitle || a1Time() > r.until {
            restoring = nil
            if r.title == knownTitle { posNote("Live did not answer in 40 s; \"\(r.title)\" stays where Live put it"); say("no answer from Live: the insert point stays where Live put it") }
            return
        }
        wire.ask("/live/song/get/current_song_time", wait: 2.5) { a, _ in
            guard let rr = self.restoring, rr.title == r.title else { return }
            guard let now = a?.first as? Double else { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.restoreTick() }; return }
            if abs(now - r.beats) < 0.01 {
                self.restoring = nil; self.written[r.title] = now; self.lastBeats[r.title] = now
                self.posState = (r.title, "came up with the insert point already at " + OSC.words(now, self.numerator), a1Time())
                self.say("insert point already at " + OSC.words(now, self.numerator)); self.blobPosition(now, now)
                return
            }
            self.wire.tell("/live/song/set/current_song_time", [r.beats])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard self.restoring?.title == r.title else { return }
                if liveFront() { self.post(["cmd", "shift"], "space") } else { _ = self.pressMenu(A1_FOLLOW) }
                self.restoring = nil; self.written[r.title] = r.beats; self.lastBeats[r.title] = r.beats
                self.posState = (r.title, "came up, insert point put back at " + OSC.words(r.beats, self.numerator) + " from " + self.setFile(r.title), a1Time())
                self.lastLaunch.note += "; insert point at " + OSC.words(r.beats, self.numerator)
                self.say("insert point put back at " + OSC.words(r.beats, self.numerator)); self.blobPosition(r.beats, r.beats)
            }
        }
    }
    func secondTick() {
        guard let app = liveApp() else { return }
        if app.processIdentifier != samplerPid { samplerPid = app.processIdentifier; knownTitle = nil; restoring = nil }   // a new Live: nothing known
        if flag("blob") { if !timeBlob.showing { timeBlob.show() } } else if timeBlob.showing { timeBlob.hide() }
        if flag("midiBlob") { if !e16.showing { midiShow() } } else if e16.showing { midiHide() }
        if wire.state == "not started" { wire.start() }
        guard let title = liveWindowTitle() else { return }
        if title != knownTitle {
            let was = knownTitle
            knownTitle = title; restoring = nil; tempoAt = 0
            cues = []; cuesAt = 0; liveLoop = (nil, nil, nil); loopNote = nil
            if !OSC.isSet(title) { if was != nil { posNote("Live shows " + title) }; blobPosition(nil, nil) }
            else if a1Time() > launchUntil {
                posNote("\"\(title)\" came up with Live already running: left alone (put back at a start of Live only); its file is " + setFile(title))
                say(title + ": left where Live put it")
            } else {
                launchUntil = 0
                if flag("resume"), let beats = hairRead(title) {
                    restoring = (title, beats, a1Time() + 40)
                    posNote("\"\(title)\" is coming up: the insert point goes back to " + OSC.words(beats, numerator) + " (" + setFile(title) + ")")
                    say(title + ": insert point going back to " + OSC.words(beats, numerator))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.restoreTick() }
                    return
                }
                posNote("\"\(title)\" has no file yet: " + setFile(title)); say(title + ": no file yet, the first move writes it")
            }
        }
        if !wire.isPending("/live/song/get/is_playing") {
            wire.ask("/live/song/get/is_playing", wait: 1.5) { a, _ in
                if let p = a?.first as? Bool { self.setPlaying(p) } else if let p = a?.first as? Double { self.setPlaying(p != 0) }
            }
        }
        if a1Time() - tempoAt > 10 {
            tempoAt = a1Time()
            if !wire.isPending("/live/song/get/tempo") { wire.ask("/live/song/get/tempo", wait: 2) { a, _ in if let t = a?.first as? Double { self.tempo = t } } }
            if !wire.isPending("/live/song/get/signature_numerator") { wire.ask("/live/song/get/signature_numerator", wait: 2) { a, _ in if let n = a?.first as? Double { self.numerator = n } } }
        }
        if a1Time() - cuesAt > 2 { askCues() }
        sample()
    }
    func samplerStart() {
        sampler?.invalidate()
        samplerPid = liveApp()?.processIdentifier ?? 0
        knownTitle = liveWindowTitle()                // a set already open when A1 starts is not moved
        restoring = nil; tempoAt = 0
        wire.start()
        if flag("blob") { timeBlob.show() }
        sampler = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.secondTick() }
    }
    func samplerStop() {
        sampler?.invalidate(); sampler = nil; fast?.invalidate(); fast = nil
        playing = false
        wire.stop()
        timeBlob.hide()
        restoring = nil; knownTitle = nil; samplerPid = 0
    }
    func resumeNow() -> String {
        let title = knownTitle ?? liveWindowTitle(); knownTitle = title
        guard OSC.isSet(title), let beats = hairRead(title!) else { return "no file for \(title ?? "no set")" }
        restoring = (title!, beats, a1Time() + 10)
        restoreTick()
        return "the insert point goes to " + OSC.words(beats, numerator) + " in " + title!
    }
    func forget() -> String {
        restoring = nil
        let title = knownTitle ?? liveWindowTitle()
        guard OSC.isSet(title) else { return "no set is open" }
        let path = setFile(title!)
        let ok = (try? FileManager.default.removeItem(atPath: path)) != nil
        written[title!] = nil
        posState = (title!, ok ? "its file deleted: \(path); the next start is Live's own" : "no file at " + path, a1Time())
        say(ok ? "forgot: " + (path as NSString).lastPathComponent + " deleted" : "no file: " + (path as NSString).lastPathComponent)
        blobPosition(lastBeats[title!], nil)
        return ok ? "deleted " + path : "no file at " + path
    }
    func positionWords() -> String {
        if !flag("resume") { return "The insert point is not remembered: Live puts it where it saved it" }
        if posState.at == 0 { return "No insert point read yet since A1 started" }
        return "\(a1Clock(posState.at))  " + (posState.title.isEmpty ? "" : "\"\(posState.title)\" ") + posState.note
    }

    // MARK: OPEN THE LAST SET (File › Open Recent, through accessibility)

    func recentRows() -> ([(title: String?, enabled: Bool)], [AXUIElement], String)? {
        guard let a = live(), let bar = axEl(a, kAXMenuBarAttribute) else { return nil }
        for it in axKids(bar) where axString(it, kAXTitleAttribute) == "File" {
            for mi in axKids(axKids(it).first ?? it) where Pick.isRecentRow(axString(mi, kAXTitleAttribute)) {
                let sub = axKids(mi).first
                let els = sub.map(axKids) ?? []
                return (els.map { (axString($0, kAXTitleAttribute), axEnabled($0)) }, els, axString(mi, kAXTitleAttribute) ?? "Open Recent")
            }
            return ([], [], "File has no Recent row")
        }
        return nil
    }
    func openLast() -> (Bool, String) {
        guard let (rows, els, where_) = recentRows() else { return (false, "Live's menu bar is not there yet") }
        guard let title = Pick.pick(rows) else { return (false, where_ + " holds no set") }
        for (i, r) in rows.enumerated() where r.title?.trimmingCharacters(in: .whitespaces) == title {
            _ = axPress(els[i])
            lastLaunch = (a1Time(), "opened \(title) from " + where_)
            say("opening " + title)
            return (true, "opening " + title)
        }
        return (false, "the row vanished")
    }
    func huntStart() {
        hunt?.invalidate()
        let until = a1Time() + 180
        var seenAt: Double?
        hunt = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if !self.flag("openLast") || a1Time() > until || liveApp() == nil { t.invalidate(); return }
            guard let title = self.liveWindowTitle() else { return }
            if seenAt == nil { seenAt = a1Time(); return }            // the window is new: one more second
            if a1Time() - seenAt! < 2 { return }
            t.invalidate()
            if !title.hasPrefix("Untitled") { self.lastLaunch = (a1Time(), "Live started on \"\(title)\"; left alone"); self.say("Live started on " + title); return }
            let (ok, msg) = self.openLast()
            if !ok { self.lastLaunch = (a1Time(), msg); self.say(msg) }
        }
    }

    // MARK: THE MARKERS AND THE LOOP

    func loops(_ t: String) -> [String] { (dict("loops")[t] as? [String]) ?? [] }
    func setLoops(_ t: String, _ v: [String]) { var d = dict("loops"); d[t] = v; conf["loops"] = d }
    func marks(_ t: String) -> OSC.Pair? {
        guard let m = dict("marks")[t] as? [String: Any], let a = (m["a"] as? NSNumber)?.doubleValue, let b = (m["b"] as? NSNumber)?.doubleValue else { return nil }
        return OSC.Pair(a: a, b: b)
    }
    func setMarks(_ t: String, _ p: OSC.Pair?) { var d = dict("marks"); d[t] = p.map { ["a": $0.a, "b": $0.b] }; conf["marks"] = d }
    func ticksOf(_ title: String?) -> ([String], OSC.Pair?) { guard OSC.isSet(title) else { return ([], nil) }; return OSC.pair(loops(title!), cues) }
    func braceOf() -> (OSC.Pair?, String?) {
        let t = knownTitle
        if OSC.isSet(t), let m = marks(t!) { return (m, "I and O") }
        let (_, p) = ticksOf(t)
        return p != nil ? (p, "two ticked markers") : (nil, nil)
    }
    func sendBrace(_ a: Double, _ b: Double) {
        wire.tell("/live/song/set/loop_start", [0.0]); wire.tell("/live/song/set/loop_length", [b - a]); wire.tell("/live/song/set/loop_start", [a])
    }
    func applyLoop(_ why: String?) {
        let t = knownTitle
        let (kept, pair) = ticksOf(t)
        if OSC.isSet(t) {
            let drop = !kept.isEmpty && marks(t!) != nil
            if drop { setMarks(t!, nil) }
            if drop || loops(t!).count != kept.count { setLoops(t!, kept); save() }
        }
        if let p = pair {
            let a = OSC.f32(p.a), b = OSC.f32(p.b)
            sendBrace(a, b); wire.tell("/live/song/set/loop", [true])
            loopNote = "loop \(clock(p.a)) → \(clock(p.b)) sent to Live" + (why.map { " (\($0))" } ?? "")
            say("loop \(clock(p.a)) → \(clock(p.b))")
        } else if let w = why {
            wire.tell("/live/song/set/loop", [false]); loopNote = "loop off in Live (\(w))"; say("loop off")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cuesAt = 0 }
    }
    func askCues() {
        cuesAt = a1Time()
        if !wire.isPending("/live/song/get/cue_points") {
            wire.ask("/live/song/get/cue_points", wait: 2) { a, _ in
                guard let a = a else { return }
                let t = self.knownTitle
                self.cues = OSC.cues(a)
                if OSC.isSet(t), !self.loops(t!).isEmpty {
                    let (kept, pair) = OSC.pair(self.loops(t!), self.cues)
                    if kept.count != self.loops(t!).count {
                        self.setLoops(t!, kept); self.save()
                        if pair == nil { self.wire.tell("/live/song/set/loop", [false]); self.loopNote = "a ticked marker is gone from the set: loop off" }
                    }
                }
                self.tick += 1
            }
        }
        let q: [(String, (Double) -> Void)] = [
            ("/live/song/get/loop_start", { self.liveLoop.start = $0 }), ("/live/song/get/loop_length", { self.liveLoop.length = $0 }),
            ("/live/view/get/selected_track", { self.selectedTrack = Int($0) }), ("/live/song/get/num_tracks", { self.numTracks = Int($0) })]
        for (addr, set) in q where !wire.isPending(addr) { wire.ask(addr, wait: 2) { a, _ in if let v = a?.first as? Double { set(v) } } }
        if !wire.isPending("/live/song/get/loop") {
            wire.ask("/live/song/get/loop", wait: 2) { a, _ in if let v = a?.first as? Bool { self.liveLoop.on = v } else if let v = a?.first as? Double { self.liveLoop.on = v != 0 } }
        }
    }
    func tickMarker(_ key: String, _ on: Bool) {
        guard let t = knownTitle, OSC.isSet(t) else { say("no set is open"); return }
        var ticks = loops(t).filter { $0 != key }
        if on { ticks.append(key) }
        setLoops(t, ticks); save()
        applyLoop(on ? "ticked" : "unticked")
    }
    func loopOff() {
        if let t = knownTitle, OSC.isSet(t) { setLoops(t, []); setMarks(t, nil); save() }
        applyLoop("cleared")
    }
    func nowBeats(_ fn: @escaping (Double?, String) -> Void) {
        let t = knownTitle ?? ""
        if wire.isPending("/live/song/get/current_song_time") { fn(lastBeats[t], "the last number sampled"); return }
        wire.ask("/live/song/get/current_song_time", wait: 1.5) { a, _ in
            if let b = a?.first as? Double { fn(b, "asked at the press") } else { fn(self.lastBeats[t], "the last number sampled") }
        }
    }
    func markLoop(_ which: String, at: Double? = nil, given: String? = nil) {
        let t = knownTitle
        let apply: (Double?, String) -> Void = { beats, how in
            guard let beats = beats else { self.loopNote = "loop \(which): Live did not say where the insert point is"; self.say("loop \(which): no answer from Live"); return }
            guard var br = OSC.brace(which, beats, OSC.isSet(t) ? self.marks(t!) : nil, self.liveLoop.start, self.liveLoop.length, self.numerator) else { return }
            br = OSC.Pair(a: OSC.f32(br.a), b: OSC.f32(br.b))
            self.sendBrace(br.a, br.b)
            if OSC.isSet(t) { self.setMarks(t!, br); self.setLoops(t!, []); self.save() }
            let A = self.clock(br.a), B = self.clock(br.b)
            self.loopNote = "\(which == "in" ? "IN" : "OUT") marked at \(self.clock(beats)) (\(how)): the loop is \(A) → \(B)"
            self.say("loop \(which) \(self.clock(beats))  ·  \(A) → \(B)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cuesAt = 0 }
        }
        if let a = at { apply(a, given ?? "given") } else { nowBeats(apply) }
    }
    func toggleLoop() {
        let (ok, what) = pressMenu(["Edit", ["Deactivate Loop", "Activate Loop"]])
        if ok {
            let was = what.hasPrefix("Deactivate")
            liveLoop.on = !was
            loopNote = "Live's \(what) pressed through accessibility: the loop is " + (liveLoop.on! ? "ON" : "off")
        } else {
            let on = !(liveLoop.on ?? false)
            wire.tell("/live/song/set/loop", [on]); liveLoop.on = on
            loopNote = "the loop switch set over AbletonOSC (\(what)): the loop is " + (on ? "ON" : "off")
        }
        say("loop " + (liveLoop.on! ? "on" : "off"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cuesAt = 0 }
    }
    func locator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let (ok, what) = self.pressMenu(["Create", ["Add Locator", "Delete Locator"]])
            if ok { self.say(what.hasPrefix("Delete") ? "marker deleted" : "marker set"); self.loopNote = "Live's \(what) pressed through accessibility" }
            else { self.wire.tell("/live/song/set_or_delete_cue"); self.say("marker set, or deleted"); self.loopNote = "the marker set or deleted over AbletonOSC (\(what))" }
            self.cuesAt = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.cuesAt = 0; self.sample() }
        }
    }
    func jumpCue(back: Bool) {
        let name = back ? "Previous Locator" : "Next Locator"
        let (ok, why) = pressButton(name)
        if ok { loopNote = "Live's \(name) button pressed through accessibility" }
        else { wire.tell(back ? "/live/song/jump_to_prev_cue" : "/live/song/jump_to_next_cue"); loopNote = "the marker jump over AbletonOSC (\(why))" }
        say(back ? "marker back" : "marker on")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.sample() }
    }
    func markers() -> ([A1Marker], OSC.Pair?) {
        let (kept, pair) = ticksOf(knownTitle)
        let rows = cues.map { c -> A1Marker in
            let role: String? = pair.flatMap { abs(c.time - $0.a) < 0.001 ? "start" : (abs(c.time - $0.b) < 0.001 ? "end" : nil) }
            return A1Marker(key: c.key, name: c.name, time: c.time, clock: clock(c.time), bars: OSC.clock(c.time, tempo, "bars", numerator), ticked: kept.contains(c.key), role: role)
        }
        return (rows, pair)
    }
    func loopWords() -> String {
        let (br, whence) = braceOf()
        let mine = br.map { "loop from \(whence!): \(clock($0.a)) → \(clock($0.b))" } ?? "no loop: press I and O in Live, or tick two markers"
        let lives = liveLoop.start.map { "Live's loop: \(liveLoop.on == true ? "ON" : "off"), \(clock($0)) → \(clock($0 + (liveLoop.length ?? 0)))" } ?? "Live's loop: not heard yet"
        return mine + "  ·  " + lives + (loopNote.map { "  ·  " + $0 } ?? "")
    }

    // MARK: THE TRACKS

    func selectTrack(_ step: Int) {
        let go: (Int?) -> Void = { i in
            guard let i = i else { self.say("the track: no answer from Live"); return }
            var j = i + step
            if j < 0 { j = 0 }; if let n = self.numTracks, j > n - 1 { j = n - 1 }
            if j == i { self.say(step < 0 ? "the first track already" : "the last track already"); return }
            self.selectedTrack = j
            self.wire.tell("/live/view/set/selected_track", [j])
            let of = self.numTracks.map { " of \($0)" } ?? ""
            self.say("track \(j + 1)\(of)"); self.loopNote = "the selection to track \(j + 1)\(of)"
        }
        if wire.isPending("/live/view/get/selected_track") { go(selectedTrack); return }
        wire.ask("/live/view/get/selected_track", wait: 1.5) { a, _ in go((a?.first as? Double).map { Int($0) } ?? self.selectedTrack) }
    }
    // Live has no command for moving a track: its header is dragged past its neighbour (the only mouse A1 ever moves)
    func moveTrack(down: Bool) {
        if dragging { say("the track is still moving"); return }
        guard liveFront() else { say("the track moves only while Live is in front"); loopNote = "the track was not moved: Live was not the front application"; return }
        let outlines = inWindowAll("AXOutline", "Track Headers")
        var best: [(name: String, frame: CGRect)]?, bestSpread: CGFloat = 0, axisY = true
        for o in outlines {
            let rows = axKids(o).compactMap { r -> (String, CGRect)? in
                guard axString(r, kAXRoleAttribute) == "AXRow", let f = axFrame(r) else { return nil }
                return (axString(r, kAXTitleAttribute) ?? "", f)
            }
            guard rows.count > 1 else { continue }
            let dy = abs(rows[1].1.minY - rows[0].1.minY), dx = abs(rows[1].1.minX - rows[0].1.minX)
            if best == nil || max(dx, dy) > bestSpread { best = rows.map { (name: $0.0, frame: $0.1) }; bestSpread = max(dx, dy); axisY = dy >= dx }
        }
        guard let rows = best else { say("the track: Live's Track Headers hold no rows"); return }
        var movable = rows.count
        if rows[movable - 1].name.hasPrefix("Main") { movable -= 1 }
        let i = (selectedTrack ?? 0) + 1
        guard i >= 1 && i <= movable else { say("no track to move"); return }
        let j = i + (down ? 1 : -1)
        guard j >= 1 && j <= movable else { say(down ? "the last track already" : "the first track already"); return }
        let from = rows[i - 1].frame, to = rows[j - 1].frame
        let x = from.midX, y0 = from.midY
        let x1 = axisY ? x : (down ? to.maxX + 4 : to.minX + to.width * 0.25)
        let y1 = axisY ? (down ? to.maxY + 4 : to.minY + to.height * 0.25) : y0
        dragging = true
        let back = CGEvent(source: nil)?.location ?? .zero
        func at(_ t: CGEventType, _ px: CGFloat, _ py: CGFloat) { CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGPoint(x: px, y: py), mouseButton: .left)?.post(tap: .cghidEventTap) }
        at(.mouseMoved, x, y0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            at(.leftMouseDown, x, y0)
            var n = 0
            func step() {
                n += 1
                at(.leftMouseDragged, x + (x1 - x) * CGFloat(n) / 10, y0 + (y1 - y0) * CGFloat(n) / 10)
                if n < 10 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.015, execute: step); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    at(.leftMouseUp, x1, y1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        CGWarpMouseCursorPosition(back); CGAssociateMouseAndMouseCursorPosition(1)
                        self.dragging = false; self.selectedTrack = j - 1
                        self.say("track \(i) moved \(down ? "down" : "up")"); self.loopNote = "the selected track dragged from place \(i) to place \(j) by its header"
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: step)
        }
    }

    // MARK: THE TRANSIENTS (helpers/a1_transients.py: the set's .als, ffmpeg, spectral flux, the foot, the zero)

    func numpyPython() -> (String?, String?) {
        if let p = pythonFound { return (p, nil) }
        if let w = pythonWhy, a1Time() - pythonAt < 60 { return (nil, w) }
        for p in [NSHomeDirectory() + "/.pyenv/shims/python3", PYTHON, "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"] where FileManager.default.isExecutableFile(atPath: p) {
            if a1Shell(p, ["-c", "import numpy"], timeout: 10).0 == 0 { pythonFound = p; return (p, nil) }
        }
        pythonWhy = "the transients need a python3 with numpy (pyenv, Homebrew or /usr/bin): none has it"; pythonAt = a1Time()
        return (nil, pythonWhy)
    }
    func jumpToTransient(_ which: String?, _ direction: String = "right") {
        if let t = transientTask, t.isRunning, a1Time() - transientAt < 20 { say("still listening for the transient"); return }
        guard let title = knownTitle, OSC.isSet(title) else { loopNote = "the transient: no set is open"; say("no set is open"); return }
        let als = String(setFile(title).dropLast(4)) + ".als"
        guard FileManager.default.fileExists(atPath: als) else { let w = "the set's own .als was not found (\(als))"; loopNote = "the transient: " + w; say(w); return }
        let (py, whyPy) = numpyPython()
        guard let python = py else { loopNote = "the transient: " + (whyPy ?? ""); say(whyPy ?? ""); return }
        nowBeats { beats, _ in
            guard let beats = beats else { self.say("the transient: no answer from Live"); return }
            var args = [A1_HELPERS + "/a1_transients.py", als, String(format: "%.6f", beats), "--tempo", String(format: "%.6f", self.tempo ?? 120),
                        "--delta", String(format: "%.3f", A1_DELTAS[self.str("transient", "normal")] ?? 0.25), "--direction", direction]
            if let tr = self.selectedTrack { args += ["--track", "\(tr)"] }
            self.say("listening for the \(direction == "left" ? "previous" : "next") transient…")
            self.transientAt = a1Time()
            let p = Process(); p.executableURL = URL(fileURLWithPath: python); p.arguments = args
            let out = Pipe(), err = Pipe(); p.standardOutput = out; p.standardError = err
            p.terminationHandler = { proc in
                let o = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let e = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                DispatchQueue.main.async {
                    let js = o.range(of: "\\{.*\\}", options: .regularExpression).map { String(o[$0]) } ?? ""
                    let j = (try? JSONSerialization.jsonObject(with: Data(js.utf8))) as? [String: Any]
                    guard let jj = j, (jj["ok"] as? Bool) == true, let beat = (jj["beat"] as? NSNumber)?.doubleValue else {
                        var why = (j?["why"] as? String) ?? e.trimmingCharacters(in: .whitespacesAndNewlines)
                        if why.isEmpty { why = "the transients could not be read (\(proc.terminationStatus))" }
                        self.loopNote = "the transient: " + why; self.say("no transient: " + why); return
                    }
                    self.wire.tell("/live/song/set/current_song_time", [beat])               // the jump
                    let db = (jj["zero_db"] as? NSNumber)?.doubleValue ?? 0
                    guard let w = which else {                                              // the arrows: only the insert point moves
                        self.loopNote = String(format: "the insert point to the %@ transient, %@ (%.0f dB under the stroke)", direction == "left" ? "previous" : "next", self.clock(beat), db)
                        self.say((direction == "left" ? "◀ transient " : "transient ▶ ") + self.clock(beat))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.sample() }
                        return
                    }
                    let sec = (jj["sec"] as? NSNumber)?.doubleValue ?? 0, from = (jj["from_sec"] as? NSNumber)?.doubleValue ?? 0
                    let file = ((jj["file"] as? String ?? "") as NSString).lastPathComponent
                    self.markLoop(w, at: beat, given: String(format: "the %@ transient %.2f s %@, on the waveform's zero (%.0f dB under the stroke), in %@",
                        direction == "left" ? "previous" : "next", abs(sec - from), direction == "left" ? "back" : "on", db, file))
                }
            }
            do { try p.run(); self.transientTask = p } catch { self.say("the transients could not start: \(error)") }
        }
    }

    // MARK: THE E16 BLOB

    func fitLines() -> Int {
        let n = intConf("midiLines", 12)
        if n > 0 { return n }
        let s = liveScreen(), top = e16.showing ? e16.frameTL().minY : s.minY + 28
        let lineH = CGFloat(intConf("midiBlobSize", 13)) * 1.45
        return max(3, min(120, Int(((s.maxY - 16) - top - (lineH + 30)) / lineH)))
    }
    func midiRecent() -> [E16Line] { Array(midi.log.suffix(fitLines()).reversed()) }
    func midiUpdate() {
        var head: String
        if midi.listening.isEmpty { head = "nothing is open — is a MIDI device plugged in?" }
        else {
            head = "listening: " + midi.listening.map(A1MIDI.portName).joined(separator: ", ")
            if midi.colour == "knob" { head += "   ·  colours: " + (midi.sceneName ?? "none — " + (midi.sceneWhy ?? "no scene")) }
            if !midi.heard { head += "   — nothing heard yet" }
        }
        var lines = midiRecent()
        if lines.isEmpty { lines = [E16Line(text: "turn a knob, press a key", tone: "w", rgb: nil)] }
        lines.insert(E16Line(text: A1MIDI.HEAD, tone: "h", rgb: nil), at: 0)
        e16.set(head, lines, heard: midi.heard)
    }
    func midiShow() {
        guard flag("midiBlob") else { return }
        midi.colour = str("midiColour", "knob"); midi.scenePath = str("midiScene", ""); midi.page = intConf("midiPage", 1)
        midi.start(device: str("midiDevice", ""))
        e16.show(); midiUpdate()
        midiTimer?.invalidate()
        midiTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, self.midi.dirty else { return }
            self.midi.dirty = false; self.midiUpdate(); self.tick += 1
        }
    }
    func midiHide() { midi.stop(); midiTimer?.invalidate(); midiTimer = nil; e16.hide() }
    func midiClear() { midi.clear(); if e16.showing { midiUpdate() } }

    // MARK: the page's switches (the Lua's set(what, on))

    func setFlag(_ what: String, _ v: Bool) {
        if A1_FLAGS.contains(what) {
            conf[what] = v; save()
            if what == "blob" { if v { if liveApp() != nil { timeBlob.show() } } else { timeBlob.hide() } }
            if what == "midiBlob" { if v { midiShow() } else { midiHide() } }
            if what == "resume" { if v { if liveApp() != nil { wire.start() } } else { wire.stop() } }
            say((v ? "on: " : "off: ") + what)
        }
    }
    func setMap(_ i: Int, _ v: Bool) {
        var m = maps; guard i < m.count else { return }
        if v { m[i]["off"] = nil } else { m[i]["off"] = true }
        maps = m; save(); index()
        say((v ? "on: " : "off: ") + a1Chord(mapMods(m[i]), "\(m[i]["from"] ?? "")") + " " + ((m[i]["blob"] as? String) ?? ""))
    }
    func removeMap(_ i: Int) {
        var m = maps; guard i < m.count else { return }
        var r = dict("removed"); r[mapId(m[i])] = true; conf["removed"] = r
        m.remove(at: i); maps = m; save(); index(); tick += 1
    }
    func addMap(key: String, mods: String, command: A1Command) -> String {
        let from = key.lowercased().trimmingCharacters(in: .whitespaces)
        guard A1KEY[from] != nil else { return "unknown key name: \(from)" }
        guard command.path.count >= 2 else { return "that is not a menu path" }
        var m = maps
        m.append(["from": from, "mods": a1Words(mods), "menu": command.path, "noKey": true, "does": "Live's " + command.words, "was": "", "blob": command.path.last!.lowercased()])
        maps = m; save(); index(); tick += 1
        return "\(a1Chord(a1Words(mods), from)) presses \(command.words)"
    }
    func setUnit(_ u: String) {
        conf["unit"] = u; save()
        if let t = knownTitle, OSC.isSet(t) { blobPosition(lastBeats[t], written[t]) }
        say("the clock shows " + (["minsec": "minutes and seconds", "bars": "bars, beats and sixteenths", "beats": "beats"][u] ?? u))
    }
    func setLook(family: String? = nil, size: Int? = nil, bold: Bool? = nil) {
        if let f = family { conf["blobFamily"] = f }; if let b = bold { conf["blobBold"] = b }; if let s = size { conf["blobSize"] = s }
        save(); timeBlob.style(fontName(), CGFloat(intConf("blobSize", 30)))
        say("the blob: \(fontName()) \(intConf("blobSize", 30))")
    }
    func setMidi(device: String? = nil, colour: String? = nil, scene: String? = nil, page: Int? = nil, size: Int? = nil, lines: Int? = nil) {
        if let d = device { conf["midiDevice"] = d }; if let c = colour { conf["midiColour"] = c }; if let s = scene { conf["midiScene"] = s }
        if let p = page { conf["midiPage"] = max(1, p) }; if let s = size { conf["midiBlobSize"] = s }; if let l = lines { conf["midiLines"] = l }
        save()
        midi.colour = str("midiColour", "knob"); midi.scenePath = str("midiScene", ""); midi.page = intConf("midiPage", 1)
        if device != nil && flag("midiBlob") { midi.start(device: str("midiDevice", "")) }
        if scene != nil || page != nil || colour != nil { midi.loadScene() }
        if size != nil { e16.style(CGFloat(intConf("midiBlobSize", 13))) }
        midi.dirty = true; if e16.showing { midiUpdate() }; tick += 1
    }
    func setTransient(_ how: String) { conf["transient"] = how; save(); say("the transients: " + how) }
    func lastSeen() -> String {
        if seen.at == 0 { return "No mapped key or Space pressed in Live since A1 started" }
        return "\(a1Clock(seen.at))  last key \(seen.key) met \(seen.focus) → \(seen.did)" + (typing ? "  (typing now)" : "")
    }
}
