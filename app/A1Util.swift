// ABLETON ASSISTANT A1, the pure parts: key names, chords, the OSC bytes and the words of a1_osc.lua, the recent-set
// pick of a1_pick.lua, the accessibility helpers with their quarter-second timeout. Ported 13.10.2026 from MANTRA_STAR
// (a1_osc.lua, a1_pick.lua, apps/a1.lua). Private to A1: nothing here is shared with the other modules.
import AppKit
import ApplicationServices

// the helpers travel inside the app (Resources/helpers); a development run reads them from the repository
let A1_HELPERS: String = {
    let inApp = (Bundle.main.resourcePath ?? "") + "/helpers"
    return FileManager.default.fileExists(atPath: inApp + "/a1_transients.py") ? inApp : NSHomeDirectory() + "/Developer/ABLETON_LIVE_ACTIONS/helpers"
}()

// MARK: key names, the ones hs.keycodes.map knew and the settings file uses

let A1KEY: [String: Int] = {
    var m: [String: Int] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
        "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39,
        "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50,
        "space": 49, "return": 36, "tab": 48, "delete": 51, "escape": 53, "padenter": 76, "pad+": 69, "pad-": 78, "pad*": 67,
        "pad/": 75, "pad=": 81, "pad.": 65, "pad0": 82, "pad1": 83, "pad2": 84, "pad3": 85, "pad4": 86, "pad5": 87, "pad6": 88,
        "pad7": 89, "pad8": 91, "pad9": 92, "left": 123, "right": 124, "down": 125, "up": 126, "home": 115, "end": 119,
        "pageup": 116, "pagedown": 121, "forwarddelete": 117, "help": 114]
    let f = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    for (i, c) in f.enumerated() { m["f\(i + 1)"] = c }
    return m
}()

let A1MODS = ["cmd", "alt", "ctrl", "shift"]
func a1Flags(_ mods: [String]) -> CGEventFlags {
    var f: CGEventFlags = []
    if mods.contains("cmd") { f.insert(.maskCommand) }; if mods.contains("alt") { f.insert(.maskAlternate) }
    if mods.contains("ctrl") { f.insert(.maskControl) }; if mods.contains("shift") { f.insert(.maskShift) }
    return f
}
// a chord in symbols, ⌘⌥5 (ctrl, alt, shift, cmd: the order Live's menus print)
func a1Chord(_ mods: [String], _ key: String) -> String {
    let sym = ["ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘"]
    var s = ""
    for k in ["ctrl", "alt", "shift", "cmd"] where mods.contains(k) { s += sym[k]! }
    let names = ["space": "Space", "pad+": "keypad +", "pad-": "keypad −", "-": "−", "=": "="]
    return s + (names[key] ?? (key.count == 1 ? key.uppercased() : key))
}
// "shift cmd" typed on the page → the modifier names
func a1Words(_ s: String) -> [String] {
    s.lowercased().split(whereSeparator: { $0 == " " || $0 == "+" || $0 == "," }).compactMap { w in
        switch w { case "command", "cmd", "⌘": return "cmd"; case "option", "opt", "alt", "⌥": return "alt"
                   case "control", "ctrl", "⌃": return "ctrl"; case "shift", "⇧": return "shift"; default: return nil }
    }
}

// MARK: OSC, the subset AbletonOSC speaks (a1_osc.lua / a1_ears.py)

enum OSC {
    static func pad(_ d: Data) -> Data { var d = d; let n = 4 - d.count % 4; d.append(contentsOf: [UInt8](repeating: 0, count: n)); return d }
    static func message(_ addr: String, _ args: [Any]) -> Data {
        var tags = ",", body = Data()
        for a in args {
            if let b = a as? Bool { tags += b ? "T" : "F" }
            else if let i = a as? Int { tags += "i"; var v = Int32(truncatingIfNeeded: i).bigEndian; body.append(Data(bytes: &v, count: 4)) }
            else if let x = a as? Double { tags += "f"; var v = Float(x).bitPattern.bigEndian; body.append(Data(bytes: &v, count: 4)) }
            else if let x = a as? Float { tags += "f"; var v = x.bitPattern.bigEndian; body.append(Data(bytes: &v, count: 4)) }
            else { tags += "s"; body.append(pad(Data("\(a)".utf8))) }
        }
        return pad(Data(addr.utf8)) + pad(Data(tags.utf8)) + body
    }
    static func parse(_ d: Data) -> (String, [Any])? {
        let b = [UInt8](d)
        guard b.first == UInt8(ascii: "/"), let z = b.firstIndex(of: 0) else { return nil }
        let addr = String(decoding: b[0..<z], as: UTF8.self)
        var p = (z / 4 + 1) * 4
        guard p < b.count, b[p] == UInt8(ascii: ","), let z2 = b[p...].firstIndex(of: 0) else { return (addr, []) }
        let tags = String(decoding: b[(p + 1)..<z2], as: UTF8.self)
        p = (z2 / 4 + 1) * 4
        var out: [Any] = []
        func u32(_ i: Int) -> UInt32 { guard i + 4 <= b.count else { return 0 }; return UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3]) }
        for t in tags {
            switch t {
            case "f": out.append(Double(Float(bitPattern: u32(p)))); p += 4
            case "i": out.append(Double(Int32(bitPattern: u32(p)))); p += 4
            case "d": let hi = UInt64(u32(p)), lo = UInt64(u32(p + 4)); out.append(Double(bitPattern: hi << 32 | lo)); p += 8
            case "s": let e = b[p...].firstIndex(of: 0) ?? b.count; out.append(String(decoding: b[p..<e], as: UTF8.self)); p = (e / 4 + 1) * 4
            case "T": out.append(true)
            case "F": out.append(false)
            default: return (addr, out)
            }
        }
        return (addr, out)
    }
    // what the wire will carry: OSC numbers are 32-bit floats
    static func f32(_ x: Double) -> Double { Double(Float(x)) }

    static func words(_ beats: Double?, _ numerator: Double?) -> String {
        guard let beats = beats else { return "nowhere" }
        let n = (numerator ?? 0) > 0 ? numerator! : 4
        let bar = (beats / n).rounded(.down) + 1
        let beat = beats - (bar - 1) * n + 1
        var s = String(format: "%.2f", beat)
        while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() }
        return "bar \(Int(bar)), beat \(s)"
    }
    static func moved(_ old: Double?, _ new: Double?) -> Bool {
        guard let new = new else { return false }
        guard let old = old else { return true }
        return abs(old - new) > 0.001
    }
    static func isSet(_ title: String?) -> Bool { guard let t = title, !t.isEmpty else { return false }; return !t.hasPrefix("Untitled") }
    static func clock(_ beats: Double?, _ tempo: Double?, _ unit: String, _ numerator: Double?) -> String {
        guard let beats = beats else { return "--:--" }
        if unit == "beats" { return String(format: "%.1f", beats) }
        let n = (numerator ?? 0) > 0 ? numerator! : 4
        if unit == "bars" {
            let bar = (beats / n).rounded(.down), inBar = beats - bar * n, beat = inBar.rounded(.down)
            let six = ((inBar - beat) * 4 + 1e-6).rounded(.down)
            return "\(Int(bar) + 1).\(Int(beat) + 1).\(Int(six) + 1)"
        }
        let t = (tempo ?? 0) > 0 ? tempo! : 120
        var secs = Int((beats * 60 / t + 1e-6).rounded(.down)); if secs < 0 { secs = 0 }
        let h = secs / 3600, m = (secs / 60) % 60, s = secs % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
    static func blob(_ beats: Double?, _ written: Double?, _ tempo: Double?, _ unit: String, _ numerator: Double?, _ playing: Bool) -> (String, Bool) {
        guard let beats = beats else { return ("--:--", false) }
        return (clock(beats, tempo, unit, numerator), !playing && !moved(written, beats))
    }
    struct Cue { let index: Int; let name: String; let time: Double; let key: String }
    static func key(_ t: Double) -> String { String(format: "%.3f", t) }
    static func cues(_ args: [Any]) -> [Cue] {
        var out: [Cue] = []
        var i = 0
        while i + 1 < args.count {
            if let t = args[i + 1] as? Double { out.append(Cue(index: i / 2, name: "\(args[i])", time: t, key: key(t))) }
            i += 2
        }
        return out.sorted { $0.time < $1.time }
    }
    struct Pair { let a: Double; let b: Double }
    static func pair(_ ticks: [String], _ cues: [Cue]) -> ([String], Pair?) {
        var byKey: [String: Cue] = [:]; for c in cues { byKey[c.key] = c }
        var kept = ticks.filter { byKey[$0] != nil }
        while kept.count > 2 { kept.removeFirst() }
        guard kept.count == 2 else { return (kept, nil) }
        var x = byKey[kept[0]]!.time, y = byKey[kept[1]]!.time
        if x > y { swap(&x, &y) }
        if y - x < 0.001 { return (kept, nil) }
        return (kept, Pair(a: x, b: y))
    }
    static func inside(_ beats: Double?, _ p: Pair?) -> Bool {
        guard let b = beats, let p = p else { return false }
        return b >= p.a - 0.001 && b < p.b - 0.01
    }
    // I and O: the brace's in or out at `now`; the other end kept, pushed along by the brace's own length if crossed
    static func brace(_ which: String, _ now: Double?, _ marks: Pair?, _ liveStart: Double?, _ liveLength: Double?, _ bar: Double?) -> Pair? {
        guard let now = now else { return nil }
        let barLen = (bar ?? 0) > 0 ? bar! : 4
        var a: Double? = marks?.a ?? liveStart
        var b: Double? = marks?.b ?? ((liveStart != nil && liveLength != nil) ? liveStart! + liveLength! : nil)
        let len = (a != nil && b != nil && b! - a! > 0.001) ? b! - a! : barLen
        if which == "in" {
            a = now
            if b == nil || b! < a! + 0.001 { b = a! + len }
        } else {
            b = now
            if a == nil || a! > b! - 0.001 { a = b! - len }
            if a! < 0 { a = 0 }
            if b! < a! + 0.001 { b = a! + len }
        }
        return Pair(a: a!, b: b!)
    }
}

// MARK: the newest recent set (a1_pick.lua)

enum Pick {
    static let notASet: Set<String> = ["clear menu", "clear recent", "clear list"]
    static func pick(_ rows: [(title: String?, enabled: Bool)]) -> String? {
        for r in rows {
            guard let t = r.title?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { continue }
            if !notASet.contains(t.lowercased()) && r.enabled { return t }
        }
        return nil
    }
    static func isRecentRow(_ title: String?) -> Bool { title?.lowercased().contains("recent") ?? false }
}

// MARK: accessibility, every question bounded to a quarter of a second (a Live busy with a sheet answered nothing)

let AX_TIMEOUT: Float = 0.25
func ax(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}
func axString(_ el: AXUIElement, _ name: String) -> String? { ax(el, name) as? String }
func axKids(_ el: AXUIElement) -> [AXUIElement] { (ax(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func axEl(_ el: AXUIElement, _ name: String) -> AXUIElement? {
    guard let v = ax(el, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
    return (v as! AXUIElement)
}
func axBounded(_ el: AXUIElement) -> AXUIElement { AXUIElementSetMessagingTimeout(el, AX_TIMEOUT); return el }
func axPress(_ el: AXUIElement) -> Bool { AXUIElementPerformAction(el, kAXPressAction as CFString) == .success }
func axFrame(_ el: AXUIElement) -> CGRect? {
    guard let p = ax(el, kAXPositionAttribute), let s = ax(el, kAXSizeAttribute) else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
    return CGRect(origin: pt, size: sz)
}
func axEnabled(_ el: AXUIElement) -> Bool { (ax(el, kAXEnabledAttribute) as? Bool) ?? true }

// a step of a menu path: one title, or several of which whichever is there ("Add Locator" / "Delete Locator")
func a1Names(_ step: Any) -> [String] { (step as? [String]) ?? [(step as? String) ?? "\(step)"] }
func a1PathWords(_ path: [Any]) -> String { path.map { a1Names($0).joined(separator: " / ") }.joined(separator: " › ") }

func a1Time() -> Double { Date().timeIntervalSince1970 }
func a1Clock(_ t: Double) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: Date(timeIntervalSince1970: t)) }
func a1Shell(_ path: String, _ args: [String], timeout: TimeInterval = 10) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    do { try p.run() } catch { return (-1, "") }
    let deadline = Date().addingTimeInterval(timeout)
    var data = Data()
    let q = DispatchQueue(label: "a1.shell"); let done = DispatchSemaphore(value: 0)
    q.async { data = pipe.fileHandleForReading.readDataToEndOfFile(); done.signal() }
    while p.isRunning && Date() < deadline { usleep(20_000) }
    if p.isRunning { p.terminate() }
    _ = done.wait(timeout: .now() + 1)
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}
