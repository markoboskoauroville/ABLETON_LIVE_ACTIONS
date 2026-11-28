// CUSTOM SHORTCUTS on the engine side (v28): the rows are A1's key mappings, his own key per row is an override read from
// ~/.config/ableton-assistant-shortcuts.json (Shortcuts.swift), CAPTURE waits for the next key, and Launcher (Mantra)'s box
// announcement. The model is in Shortcuts.swift (pure); this file is the part that touches the keyboard.
import AppKit

struct PendingKey { let id: String; let spec: KeySpec; let other: String?; let warnings: [String] }

let SHORTCUTS_FILE = URL(fileURLWithPath: NSHomeDirectory() + "/.config/ableton-assistant-shortcuts.json")

extension A1Engine {
    func shortLabel(_ from: String) -> String {
        let names = ["down": "↓", "up": "↑", "left": "←", "right": "→", "space": "Space", "return": "Return", "tab": "Tab", "escape": "Esc", "delete": "Delete", "pad+": "keypad +", "pad-": "keypad −"]
        if let n = names[from] { return n }
        if from.count > 1, from.hasPrefix("f"), Int(from.dropFirst()) != nil { return from.uppercased() }
        return from.count == 1 ? from.uppercased() : from
    }
    /// a plain-words name for a row: what it does, up to the first bracket or colon
    func shortcutName(_ m: [String: Any]) -> String {
        var s = (m["does"] as? String) ?? (m["blob"] as? String) ?? "\(m["from"] ?? "")"
        if let r = s.range(of: " (") { s = String(s[..<r.lowerBound]) }
        if s.count > 70 { s = String(s.prefix(67)) + "…" }
        return s
    }
    func shortcutRows() -> [ShortcutRow] {
        maps.compactMap { m in
            if (m["unbound"] as? Bool) == true { return ShortcutRow(id: mapId(m), name: shortcutName(m), original: KeySpec(code: -1, mods: [], label: "no key")) }
            guard let code = A1KEY["\(m["from"] ?? "")"] else { return nil }
            return ShortcutRow(id: mapId(m), name: shortcutName(m), original: KeySpec(code: code, mods: mapMods(m), label: shortLabel("\(m["from"] ?? "")")))
        }
    }
    func loadShortcutOverrides() {
        let data = try? Data(contentsOf: SHORTCUTS_FILE)
        let (ov, note) = ShortcutFile.parse(data)
        shortcuts.overrides = ov
        shortcutsNote = note
        if let n = note { AppLog.write("shortcuts: " + n) }
    }
    func persistShortcuts() {
        if !ShortcutFile.write(shortcuts.overrides, to: SHORTCUTS_FILE) { shortcutsNote = "the shortcuts file could not be written"; AppLog.write("shortcuts: could not write " + SHORTCUTS_FILE.path) }
        index(); tick += 1
    }
    /// the key a row has now, as the tab and the A1 tab show it
    func effectiveChord(_ m: [String: Any]) -> String {
        if let o = shortcuts.overrides[mapId(m)] { return o.shown }
        if (m["unbound"] as? Bool) == true { return "no key" }
        return a1Chord(mapMods(m), "\(m["from"] ?? "")")
    }

    // CAPTURE
    func beginCapture(_ id: String) {
        captureId = id; captureUntil = a1Time() + 15; pendingKey = nil; tick += 1
        AppLog.write("capture: waiting for a key for \(id)")
    }
    func cancelCapture() { captureId = nil; pendingKey = nil; tick += 1 }
    /// called from the key tap first: while a row waits, the next key is the shortcut and goes nowhere else (not to Live)
    func captureFilter(_ type: CGEventType, _ e: CGEvent, _ id: String) -> Unmanaged<CGEvent>? {
        let code = Int(e.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp { if captureSwallow.remove(code) != nil { return nil }; return Unmanaged.passUnretained(e) }
        let f = e.flags
        var mods: [String] = []
        if f.contains(.maskCommand) { mods.append("cmd") }; if f.contains(.maskAlternate) { mods.append("alt") }
        if f.contains(.maskControl) { mods.append("ctrl") }; if f.contains(.maskShift) { mods.append("shift") }
        captureSwallow.insert(code)
        if code == A1KEY["escape"]! && mods.isEmpty { DispatchQueue.main.async { self.cancelCapture(); self.say("capture cancelled") }; return nil }
        // the label: a named key (arrows, F-keys, Space ...) by its name; a letter, digit or sign by the CURRENT keyboard layout's own character
        let named = A1KEY.first(where: { $0.value == code }).map { shortLabel($0.key) }
        var label = named ?? ""
        if label.count <= 1 && !f.contains(.maskAlternate) {
            var n = 0; var buf = [UniChar](repeating: 0, count: 4)
            e.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &n, unicodeString: &buf)
            let typed = n > 0 ? String(utf16CodeUnits: buf, count: n).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            if !typed.isEmpty { label = typed.uppercased() }
        }
        if label.isEmpty { label = "key \(code)" }
        let spec = KeySpec(code: code, mods: mods, label: label)
        DispatchQueue.main.async { self.captured(id, spec) }
        return nil
    }
    func captured(_ id: String, _ spec: KeySpec) {
        captureId = nil
        var warnings: [String] = []
        if let w = ShortcutKeys.systemClash(spec) { warnings.append("the Mac: " + w) }
        if let w = shortcuts.liveClash(spec, commands: commands.map { ($0.key, $0.words) }) { warnings.append("Live: " + w + " would lose its key") }
        var probe = shortcuts
        let r = probe.capture(id, spec)
        var other: String? = nil
        if case .clash(let o) = r { other = o }
        if r == .unchanged { say("same key: nothing changed"); tick += 1; return }
        if warnings.isEmpty && other == nil {
            _ = shortcuts.capture(id, spec); persistShortcuts()
            say("\(spec.shown) is now \(shortcuts.rows.first { $0.id == id }?.name ?? id)")
            AppLog.write("capture: \(id) -> \(spec.shown)")
        } else {
            pendingKey = PendingKey(id: id, spec: spec, other: other, warnings: warnings)
            AppLog.write("capture: \(id) -> \(spec.shown) asks: " + (warnings + (other.map { ["held by " + $0] } ?? [])).joined(separator: "; "))
            tick += 1
        }
    }
    func resolvePending(swap: Bool, saveAnyway: Bool) {
        guard let p = pendingKey else { return }
        pendingKey = nil
        if let o = p.other {
            guard swap else { tick += 1; return }
            shortcuts.swap(p.id, with: o, p.spec)
        } else {
            guard saveAnyway else { tick += 1; return }
            _ = shortcuts.capture(p.id, p.spec)
        }
        persistShortcuts()
        say("\(p.spec.shown) is now \(shortcuts.rows.first { $0.id == p.id }?.name ?? p.id)")
        AppLog.write("capture: \(p.id) -> \(p.spec.shown) saved after the question")
    }
    func resetShortcut(_ id: String) { shortcuts.reset(id); persistShortcuts(); AppLog.write("shortcuts: reset \(id)") }
    func resetAllShortcuts() { shortcuts.resetAll(); persistShortcuts(); AppLog.write("shortcuts: reset all") }

    // LAUNCHER (MANTRA): its box announces itself (com.mantra.launcher.box, userInfo open true / false)
    func watchLauncher() {
        DistributedNotificationCenter.default().addObserver(forName: .init("com.mantra.launcher.box"), object: nil, queue: .main) { [weak self] n in
            guard let self = self else { return }
            let open = (n.userInfo?["open"] as? Bool) ?? ((n.userInfo?["open"] as? NSNumber)?.boolValue ?? false)
            self.launcherBox = open; self.launcherAt = a1Time(); self.focusCache = nil
            AppLog.write("Launcher box " + (open ? "open: every key is free until it closes (or \(Int(A1Engine.launcherTimeout)) s, or a click in Live)" : "closed"))
            self.refreshMode()
        }
    }
    static let launcherTimeout = 60.0
    var launcherBoxActive: Bool { launcherBox && a1Time() - launcherAt < A1Engine.launcherTimeout }

    /// "Play from the loop's start": a command of its own, with no key until he gives it one (v31). Space never does this.
    func playLoopStart() {
        let (pair, _) = braceOf()
        guard let p = pair else { say("play from the loop start: no loop is set"); return }
        wire.tell("/live/song/set/loop", [true]); liveLoop.on = true
        // v37: by AbletonOSC, not by a keystroke. Until v36 a stopped Live got ⇧Space (Continue Playback), which starts where Live
        // last STOPPED, not at the playhead just set (measured 28.11.2026: Continue played from 0:06 with the playhead set to 2:28),
        // and the posted key did not start Live at all in the test. Stopped: Live's start (Song.start_time) to the loop's start,
        // then Play; playing: the playhead jumps there.
        wire.ask("/live/song/get/is_playing", wait: 0.4) { a, _ in
            let isPlaying = (a?.first as? Bool) ?? oscDouble(a?.first).map { $0 != 0 } ?? self.playing
            if isPlaying { self.wire.tell("/live/song/set/current_song_time", [p.a]) }
            else { self.wire.tell("/live/mantra/start_time", [p.a]); self.wire.tell("/live/song/start_playing") }
            self.say("play from the loop's start " + self.clock(p.a))
            AppLog.write("play-loop-start: \(isPlaying ? "playing, the playhead" : "stopped, Live's start and Play") to \(self.clock(p.a))")
        }
    }

    // I AND O (v28)
    var snapIn: LoopMarks.Snap { LoopMarks.Snap(rawValue: str("snapIn", "off")) ?? .off }
    var snapOut: LoopMarks.Snap { LoopMarks.Snap(rawValue: str("snapOut", "off")) ?? .off }
    func cycleSnap(_ which: String) {
        let key = which == "in" ? "snapIn" : "snapOut"
        let next: [String: String] = ["off": "beat", "beat": "bar", "bar": "off"]
        setConf(key, next[str(key, "off")] ?? "off"); tick += 1
    }
    func markNow(_ which: String) {
        let tPress = a1Time()
        let t = knownTitle
        let finish: (Double, Double, String) -> Void = { raw, rtt, how in
            let pos = LoopMarks.atPress(reading: raw, playing: self.playing, roundTripSeconds: rtt, tempo: self.tempo)
            let marks = OSC.isSet(t) ? self.marks(t!) : nil
            let curA = marks?.a ?? self.liveLoop.start
            let curB = marks?.b ?? ((self.liveLoop.start != nil && self.liveLoop.length != nil) ? self.liveLoop.start! + self.liveLoop.length! : nil)
            let r = LoopMarks.decide(position: pos, currentIn: curA, currentOut: curB, which: which, snap: which == "in" ? self.snapIn : self.snapOut, loopOn: self.liveLoop.on, beatsPerBar: self.numerator)
            let a = OSC.f32(r.start), b = OSC.f32(r.end)
            self.sendBrace(a, b)
            if r.loopOn && self.liveLoop.on != true { self.wire.tell("/live/song/set/loop", [true]); self.liveLoop.on = true }
            if OSC.isSet(t) { self.setMarks(t!, OSC.Pair(a: a, b: b)); self.setLoops(t!, []); self.save() }
            let secs = (self.tempo ?? 0) > 0 ? String(format: "%.1f s", r.length * 60 / self.tempo!) : String(format: "%.1f beats", r.length)
            self.loopNote = "\(which == "in" ? "IN" : "OUT") at \(self.clock(pos)) (\(how)): the loop is \(self.clock(a)) → \(self.clock(b))"
            self.say(which == "in" ? "in \(self.clock(pos))" : "out \(self.clock(pos)), loop \(secs)")
            AppLog.write(String(format: "loop %@ at %@ (%.3f beats): %@; round trip %.0f ms, %@ taken back; brace %@ → %@, loop %@", which, self.clock(pos), pos, how, rtt * 1000,
                                self.playing ? String(format: "%.0f ms", rtt * 500) : "nothing (stopped)", self.clock(a), self.clock(b), r.loopOn ? "on" : "unchanged"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.cuesAt = 0 }
        }
        let fallback: () -> Void = {
            guard let last = self.lastBeats[t ?? ""] else { self.say("\(which): Live did not say where it is"); return }
            finish(last, 0, "the last number sampled")
        }
        if wire.isPending("/live/song/get/current_song_time") { fallback(); return }
        wire.ask("/live/song/get/current_song_time", wait: 1.0) { a, _ in
            if let b = oscDouble(a?.first) { finish(b, a1Time() - tPress, "read from Live at the press") } else { fallback() }
        }
    }
}
