// RemoteLive.swift (the PHONE REMOTE module, moved here from "Ableton Live Remote (Mantra).app" on 24.11.2026, Marko:
// "helper app is unnecessary because it can become part of Ableton Live Assistant"): the set as the phone sees it. This module is the ONLY OSC client of the phone: the
// phone never talks to AbletonOSC (it would steal the answer port from the Mac apps). Questions take the shared turn on
// 11011 (LiveTurn.swift, the same lock as every Mantra app: use, let go), ONE question per look:
// /live/mantra/remote/state (added to the local AbletonOSC on 24.11.2026, patch kept in ABLETON_LIVE_ACTIONS/abletonosc).
// Orders (play, arm, jump ...) need no turn. No start_listen: a listener would push to whoever asked last.
import Foundation

struct RemoteTrack: Equatable {
    var index: Int
    var name: String
    var color: Int
    var kind: Int          // bits: 1 can be armed, 2 audio track, 4 group, 8 inside a group
    var arm: Int           // -1: cannot be armed
    var mute: Bool
    var solo: Bool
    var clips: Int         // audio clips on the Arrangement timeline
    var sum: Double        // changes when a clip moves or is replaced
    var uid = ""           // Live's own identity of the track (the same through renames and moves), "" when not known

    var json: [String: Any] {
        ["i": index, "name": name, "color": color, "kind": kind, "arm": arm, "mute": mute, "solo": solo, "clips": clips,
         "sum": sum.isFinite ? sum : 0, "id": uid]
    }
}

struct RemoteSnapshot: Equatable {
    var playing = false
    var time = 0.0
    var tempo = 120.0
    var metro = false
    var loop = false
    var loopStart = 0.0
    var loopLen = 16.0
    var rec = false
    var sigN = 4
    var sigD = 4
    var end = 0.0
    var tracks: [RemoteTrack] = []
    var insert = 0.0           // Live's insert point (Song.start_time): where Play and Space start
    var mode = "return"        // the playback mode after a stop: "return" (DAW) or "continue" (DaVinci Resolve)
}

/// An audio clip on the Arrangement timeline, read by /live/mantra/remote/clips.
struct RemoteClip {
    var path: String
    var start: Double       // beats on the timeline
    var end: Double
    var startMarker: Double // seconds when not warped, clip beats when warped
    var endMarker: Double
    var warped: Bool
    var muted: Bool
    var markers: [(beat: Double, sec: Double)]

    /// The second of the file that plays at this beat of the timeline (constant tempo).
    func sec(at beat: Double, tempo: Double) -> Double {
        let spb = 60.0 / max(tempo, 1)
        if !warped { return startMarker + (beat - start) * spb }
        let cb = startMarker + (beat - start)
        let m = markers
        guard m.count >= 2 else { return cb * spb }
        var i = 0
        while i < m.count - 2 && cb > m[i + 1].beat { i += 1 }
        let a = m[i], b = m[i + 1]
        let db = b.beat - a.beat
        guard abs(db) > 1e-9 else { return a.sec + (cb - a.beat) * spb }
        return a.sec + (cb - a.beat) * (b.sec - a.sec) / db
    }
}

final class RemoteLive {
    private(set) var snap = RemoteSnapshot()
    private(set) var answering = false
    private(set) var rev = 0
    private(set) var lastAnswer: Date?
    var onChange: () -> Void = {}

    private let lock = NSLock()
    private var _watchers = 0
    private let kick = DispatchSemaphore(value: 0)
    private var started = false

    /// How many phones are watching: the set is looked at only while one is (nobody asks Live for nothing).
    var watchers: Int {
        get { lock.lock(); defer { lock.unlock() }; return _watchers }
        set { lock.lock(); _watchers = newValue; lock.unlock(); if newValue > 0 { kick.signal() } }
    }

    func start() {
        guard !started else { return }
        started = true
        Thread.detachNewThread { [weak self] in self?.run() }
    }

    /// Look now (after an order, or for a one-off /state).
    func lookNow() { kick.signal() }

    private func run() {
        var lastPlaying = false
        while true {
            if watchers == 0 {
                _ = kick.wait(timeout: .now() + 1.0)
                if watchers == 0 { continue }
            }
            let t0 = Date()
            let r = LiveTurn.ask("/live/mantra/remote/state", [], wait: 1.0)
            let s = r.flatMap { RemoteLive.parse($0) }
            DispatchQueue.main.async { self.apply(s) }
            if let s = s { lastPlaying = s.playing }
            // 4 looks a second while playing, about 3 while stopped: each look holds the shared turn for one AbletonOSC
            // tick (up to 100 ms), so the other Mantra apps always get their turn in between
            let every = s == nil ? 1.0 : (lastPlaying ? 0.25 : 0.33)
            let rest = every - Date().timeIntervalSince(t0)
            if rest > 0 { _ = kick.wait(timeout: .now() + rest) }
        }
    }

    private func apply(_ s: RemoteSnapshot?) {
        guard let s = s else {
            if answering { answering = false; rev += 1; onChange() }
            return
        }
        lastAnswer = Date()
        if !answering || s != snap {
            answering = true
            snap = s
            rev += 1
            onChange()
        }
    }

    static func parse(_ r: [Any]) -> RemoteSnapshot? {
        func d(_ i: Int) -> Double {
            guard i < r.count else { return 0 }
            if let x = r[i] as? Double { return x }
            if let x = r[i] as? Int { return Double(x) }
            if let x = r[i] as? Bool { return x ? 1 : 0 }
            return 0
        }
        func n(_ i: Int) -> Int { Int(d(i)) }
        guard r.count >= 12 else { return nil }
        var s = RemoteSnapshot()
        s.playing = n(0) != 0
        s.time = d(1)
        s.tempo = d(2) > 0 ? d(2) : 120
        s.metro = n(3) != 0
        s.loop = n(4) != 0
        s.loopStart = d(5)
        s.loopLen = d(6)
        s.rec = n(7) != 0
        s.sigN = max(1, n(8))
        s.sigD = max(1, n(9))
        s.end = d(10)
        let count = n(11)
        let per = 9
        guard count >= 0, r.count >= 12 + count * per else { return nil }
        for i in 0..<count {
            let b = 12 + i * per
            s.tracks.append(RemoteTrack(index: i, name: (r[b] as? String) ?? "Track \(i + 1)", color: n(b + 1), kind: n(b + 2),
                                      arm: n(b + 3), mute: n(b + 4) != 0, solo: n(b + 5) != 0, clips: n(b + 6),
                                      sum: d(b + 7)))
        }
        let tail = 12 + count * per                         // AbletonOSC of 24.11.2026 adds these two after the tracks
        if r.count >= tail + 2 {
            s.insert = d(tail)
            if let m = r[tail + 1] as? String, m == "return" || m == "continue" { s.mode = m }
        }
        if r.count >= tail + 2 + count {                     // and then one identity per track (24.11.2026)
            for i in 0..<count { if let u = r[tail + 2 + i] as? String { s.tracks[i].uid = u } }
        }
        return s
    }

    /// The audio clips on a track's timeline (blocks up to a few seconds: call off the main thread).
    static func clips(_ track: Int) -> [RemoteClip]? {
        guard let r = LiveTurn.ask("/live/mantra/remote/clips", [track], wait: 2.0), r.count >= 2,
              let t = r[0] as? Int, t == track, let n = r[1] as? Int, n >= 0 else { return nil }
        func d(_ x: Any) -> Double { (x as? Double) ?? Double((x as? Int) ?? 0) }
        var out: [RemoteClip] = []
        var p = 2
        for _ in 0..<n {
            guard p + 8 <= r.count else { break }
            var c = RemoteClip(path: (r[p] as? String) ?? "", start: d(r[p + 1]), end: d(r[p + 2]), startMarker: d(r[p + 3]),
                             endMarker: d(r[p + 4]), warped: d(r[p + 5]) != 0, muted: d(r[p + 6]) != 0, markers: [])
            let m = Int(d(r[p + 7]))
            p += 8
            for _ in 0..<max(0, m) {
                guard p + 2 <= r.count else { break }
                c.markers.append((beat: d(r[p]), sec: d(r[p + 1])))
                p += 2
            }
            c.markers.sort { $0.beat < $1.beat }
            out.append(c)
        }
        return out
    }

    // MARK: orders from the phone

    /// One order, as the phone sends it: c=play | stop | rec&v=1 | metro&v=1 | arm&t=3&v=1 | mute&t=3&v=1 |
    /// solo&t=3&v=1 | jump&b=12.5 | new&k=audio|midi | loop&v=1. No turn: an order has no answer.
    @discardableResult
    func order(_ q: [String: String]) -> Bool {
        let s = snap
        let t = Int(q["t"] ?? "") ?? -1
        let v: Bool? = q["v"].map { $0 == "1" || $0 == "true" }
        var sent = true
        switch q["c"] ?? "" {
        case "play":
            if !s.playing { tell("/live/song/start_playing") }
        case "stop":
            tell("/live/song/stop_playing")
            if s.rec { tell("/live/song/set/record_mode", [false]) }
        case "rec":
            let on = v ?? !s.rec
            tell("/live/song/set/record_mode", [on])
            if on && !s.playing { tell("/live/song/start_playing") }     // as Live's own record button: it starts
        case "metro":
            tell("/live/song/set/metronome", [v ?? !s.metro])
        case "loop":
            tell("/live/song/set/loop", [v ?? !s.loop])
        case "arm":
            guard t >= 0 else { return false }
            let now = s.tracks.first { $0.index == t }?.arm ?? 0
            tell("/live/track/set/arm", [t, v ?? (now != 1)])
        case "mute":
            guard t >= 0 else { return false }
            tell("/live/track/set/mute", [t, v ?? !(s.tracks.first { $0.index == t }?.mute ?? false)])
        case "solo":
            guard t >= 0 else { return false }
            tell("/live/track/set/solo", [t, v ?? !(s.tracks.first { $0.index == t }?.solo ?? false)])
        case "jump":
            // v6 (Marko, 24.11.2026: "next play should start from that point where I did insertion point with finger"):
            // the playhead AND Live's insert point (Song.start_time, where Play starts) go there; setting the song time
            // alone left Play starting from the old insert point
            guard let b = Double(q["b"] ?? ""), b.isFinite else { return false }
            tell("/live/song/set/current_song_time", [max(0, b)])
            tell("/live/mantra/start_time", [max(0, b)])
        case "mode":
            guard let m = q["v"], m == "return" || m == "continue" else { return false }
            PlaybackMode.write(m)
        case "new":
            // v6: at=start puts it before track 1 (index 0), anything else after the last track (-1)
            tell(q["k"] == "midi" ? "/live/song/create_midi_track" : "/live/song/create_audio_track", [q["at"] == "start" ? 0 : -1])
        default:
            sent = false
        }
        if sent { DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { self.kick.signal() } }
        return sent
    }

    private let orders = DispatchQueue(label: "live.orders", qos: .userInitiated)   // one after the other, in order

    private func tell(_ a: String, _ args: [Any] = []) {
        orders.async { LiveTurn.tell(a, args) }
    }

    /// Live's own log says which audio input device it uses; with "No Device" Live does not arm audio tracks (found
    /// 24.11.2026: every ARM was refused in silence). Read at most every 10 s, the end of the log only.
    private var inputChecked = Date.distantPast
    private var _noInput = false
    var noInput: Bool {
        if Date().timeIntervalSince(inputChecked) > 10 {
            inputChecked = Date()
            _noInput = RemoteLive.liveInputIsNone()
        }
        return _noInput
    }

    static func liveInputIsNone() -> Bool {
        let base = NSHomeDirectory() + "/Library/Preferences/Ableton"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: base) else { return false }
        // the Live that runs writes its Log.txt now: the newest log, not the highest version number (several Lives are
        // installed; v2 read 12.4.16's log while 12.4.6 was running)
        let logs = dirs.filter { $0.hasPrefix("Live ") }.map { base + "/" + $0 + "/Log.txt" }
        func mtime(_ p: String) -> Date {
            ((try? FileManager.default.attributesOfItem(atPath: p))?[.modificationDate] as? Date) ?? .distantPast
        }
        guard let newest = logs.max(by: { mtime($0) < mtime($1) }), let h = FileHandle(forReadingAtPath: newest) else { return false }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        try? h.seek(toOffset: size > 400_000 ? size - 400_000 : 0)
        let text = String(decoding: h.readDataToEndOfFile(), as: UTF8.self)
        guard let r = text.range(of: "Input Device: ", options: .backwards) else { return false }
        let line = text[r.upperBound...].prefix { $0 != "\n" && $0 != "\r" }
        return line.trimmingCharacters(in: .whitespaces) == "No Device"
    }

    var json: [String: Any] {
        let s = snap
        func f(_ x: Double) -> Double { x.isFinite ? x : 0 }
        return ["v": rev, "live": answering, "playing": s.playing, "time": f(s.time), "tempo": f(s.tempo), "metro": s.metro,
                "loop": s.loop, "loopStart": f(s.loopStart), "loopLen": f(s.loopLen), "rec": s.rec, "sigN": s.sigN,
                "sigD": s.sigD, "end": f(s.end), "noInput": noInput, "insert": f(s.insert), "mode": s.mode, "tracks": s.tracks.map { $0.json }]
    }
}
