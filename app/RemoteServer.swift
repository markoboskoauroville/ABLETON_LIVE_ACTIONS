import AppKit
import CryptoKit
import Network

/// The phone's line (PHONE REMOTE module of Ableton Live Assistant since 24.11.2026): ONE port, 8966 (MANTRA_PORTS name `ableton-live-remote`), HTTP and a WebSocket on it, announced by
/// Bonjour as `_mantralive._tcp` so the phone finds the Mac on the same Wi-Fi by itself.
///   GET /hello            {"name","app","version"}
///   GET /ws               WebSocket: the helper pushes the set's state (JSON) whenever it changes (4 a second while
///                         Live plays); the phone sends orders as text, "c=play", "c=arm&t=3&v=1" (Live.order)
///   GET /state            the state once (for a test from the shell)
///   GET /do?c=...         one order (the same words as over the WebSocket)
///   GET /wave?t=N         track N's waveform on the timeline (RemotePeaks.wave)
///   GET /window           the Ableton Live window's rectangle on the screen, in points and pixels (the SESSION tab)
/// Only the home network, Tailscale and this Mac itself (adb reverse) are answered.
let REMOTE_PORT: UInt16 = 8966

final class RemotePeer {
    let c: NWConnection
    var buffer = Data()
    var ws = false
    let who: String
    init(_ c: NWConnection, who: String) { self.c = c; self.who = who }
}

final class RemoteServer {
    let live: RemoteLive
    let peaks = RemotePeaks()
    var onSeen: (String) -> Void = { _ in }
    var onPhones: () -> Void = {}
    /// the Assistant's own switches for the phone (GET /features, order c=feature&id=..&v=1|0)
    var features: () -> [[String: Any]] = { [] }
    var setFeature: (String, Bool) -> Bool = { _, _ in false }
    private var listener: NWListener?
    private var peers: [ObjectIdentifier: RemotePeer] = [:]
    private(set) var status = "starting"
    let name = Host.current().localizedName ?? "Mac"

    init(live: RemoteLive) { self.live = live }

    /// The phones holding a WebSocket now.
    var phones: [String] { peers.values.filter { $0.ws }.map { $0.who } }

    func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: REMOTE_PORT),
              let l = try? NWListener(using: .tcp, on: port) else { status = "port \(REMOTE_PORT) is taken"; return }
        l.service = NWListener.Service(name: name, type: "_mantralive._tcp")
        l.newConnectionHandler = { [weak self] c in self?.serve(c) }
        l.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:
                self?.status = "listening on \(REMOTE_PORT)"
                Ports.record("ableton-live-remote", REMOTE_PORT, udp: false, health: "/hello")
            case .failed(let e):
                self?.status = "failed: \(e)"
                self?.listener = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.start() }
            default: break
            }
        }
        l.start(queue: .main)
        listener = l
        if !beating { beating = true; startHeartbeat() }
    }
    private var beating = false

    /// A heartbeat every second to every phone (v5): the phone takes three seconds of silence as a lost line.
    func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for p in self.peers.values where p.ws { self.sendText(p, Data("{\"hb\":1}".utf8)) }
        }
    }

    /// The module switched off: the port closed, every phone let go.
    func stop() {
        listener?.cancel(); listener = nil
        for id in Array(peers.keys) { drop(id) }
        status = "off"
    }

    /// The set changed: every phone gets it now.
    func broadcast() {
        guard !peers.isEmpty else { return }
        let body = json(live.json)
        for p in peers.values where p.ws { sendText(p, body) }
    }

    // MARK: who may ask

    private static func ip(_ c: NWConnection) -> String? {
        guard case let .hostPort(host, _) = c.endpoint else { return nil }
        return "\(host)".replacingOccurrences(of: "::ffff:", with: "").components(separatedBy: "%")[0]
    }

    private func allowed(_ ip: String) -> Bool {
        if ip == "127.0.0.1" || ip == "::1" { return true }
        let p = ip.split(separator: ".").compactMap { Int($0) }
        guard p.count == 4 else { return false }
        return p[0] == 10 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && (16...31).contains(p[1]))
            || (p[0] == 100 && (64...127).contains(p[1]))
    }

    // MARK: HTTP

    private func serve(_ c: NWConnection) {
        guard let ip = RemoteServer.ip(c), allowed(ip) else { c.cancel(); return }
        let p = RemotePeer(c, who: ip == "127.0.0.1" || ip == "::1" ? "the cable (adb)" : ip)
        let id = ObjectIdentifier(p)
        peers[id] = p
        c.stateUpdateHandler = { [weak self] st in
            switch st {
            case .failed, .cancelled: self?.drop(id)
            default: break
            }
        }
        c.start(queue: .main)
        readRequest(p)
    }

    private func drop(_ id: ObjectIdentifier) {
        guard let p = peers.removeValue(forKey: id) else { return }
        if p.ws { live.watchers = phones.count; onPhones() }
        p.c.cancel()
    }

    private func readRequest(_ p: RemotePeer) {
        p.c.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, done, err in
            guard let self = self else { return }
            if let d = data { p.buffer.append(d) }
            if let r = p.buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: p.buffer[p.buffer.startIndex..<r.lowerBound], as: UTF8.self)
                let rest = Data(p.buffer[r.upperBound...])
                p.buffer = rest
                self.handle(p, head)
                return
            }
            if done || err != nil || p.buffer.count > 16384 { self.drop(ObjectIdentifier(p)); return }
            self.readRequest(p)
        }
    }

    private func handle(_ p: RemotePeer, _ head: String) {
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2, let u = URLComponents(string: String(parts[1])) else { drop(ObjectIdentifier(p)); return }
        var headers: [String: String] = [:]
        for l in lines.dropFirst() {
            guard let colon = l.firstIndex(of: ":") else { continue }
            headers[l[..<colon].trimmingCharacters(in: .whitespaces).lowercased()] =
                l[l.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        var q: [String: String] = [:]
        for i in u.queryItems ?? [] { q[i.name] = i.value ?? "" }
        onSeen(p.who)
        switch u.path {
        case "/ws":
            guard (headers["upgrade"] ?? "").lowercased() == "websocket", let key = headers["sec-websocket-key"] else {
                reply(p, Data("WebSocket only".utf8), status: "400 Bad Request", type: "text/plain"); return
            }
            let accept = Data(Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)))
                .base64EncodedString()
            let resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" +
                "Sec-WebSocket-Accept: \(accept)\r\n\r\n"
            p.c.send(content: Data(resp.utf8), completion: .contentProcessed { _ in })
            p.ws = true
            live.watchers = phones.count
            onPhones()
            sendText(p, json(live.json))
            readFrames(p)
        case "/hello":
            // "app" stays "ableton-live-remote": the phone looks for it; "host" says who serves it now
            reply(p, json(["name": name, "app": "ableton-live-remote", "host": "ableton-live-assistant", "version": VERSION]))
        case "/features":
            reply(p, json(["features": features()]))
        case "/state":
            live.lookNow()
            reply(p, json(live.json))
        case "/do":
            let ok = q["c"] == "feature" ? setFeature(q["id"] ?? "", q["v"] == "1") : live.order(q)
            reply(p, json(["ok": ok]))
        case "/wave":
            let t = Int(q["t"] ?? "") ?? -1
            let tempo = live.snap.tempo, end = max(live.snap.end, live.snap.loopStart + live.snap.loopLen)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let body: Data
                if t >= 0, let clips = RemoteLive.clips(t) {
                    body = self.json(self.peaks.wave(track: t, clips: clips, tempo: tempo, end: end))
                } else {
                    body = self.json(["t": t, "error": "Live did not answer"])
                }
                DispatchQueue.main.async { self.reply(p, body) }
            }
        case "/window":
            reply(p, json(RemoteWindow.find()))
        default:
            reply(p, Data("no such thing".utf8), status: "404 Not Found", type: "text/plain")
        }
    }

    private func json(_ j: [String: Any]) -> Data { (try? JSONSerialization.data(withJSONObject: j)) ?? Data("{}".utf8) }

    private func reply(_ p: RemotePeer, _ body: Data, status: String = "200 OK", type: String = "application/json") {
        var out = Data(("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n" +
                        "Cache-Control: no-store\r\nConnection: close\r\n\r\n").utf8)
        out.append(body)
        let id = ObjectIdentifier(p)
        p.c.send(content: out, completion: .contentProcessed { [weak self] _ in self?.drop(id) })
    }

    // MARK: WebSocket (RFC 6455, the small part a phone needs: text, ping, close)

    private func readFrames(_ p: RemotePeer) {
        parseFrames(p)
        guard peers[ObjectIdentifier(p)] != nil else { return }
        p.c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, err in
            guard let self = self else { return }
            if let d = data { p.buffer.append(d) }
            if done || err != nil { self.drop(ObjectIdentifier(p)); return }
            self.readFrames(p)
        }
    }

    private func parseFrames(_ p: RemotePeer) {
        while true {
            let b = [UInt8](p.buffer)
            guard b.count >= 2 else { return }
            let op = b[0] & 0x0F
            let masked = (b[1] & 0x80) != 0
            var len = Int(b[1] & 0x7F)
            var at = 2
            if len == 126 {
                guard b.count >= 4 else { return }
                len = Int(b[2]) << 8 | Int(b[3]); at = 4
            } else if len == 127 {
                guard b.count >= 10 else { return }
                len = 0
                for i in 2..<10 { len = len << 8 | Int(b[i]) }
                at = 10
            }
            guard len >= 0, len < 1 << 20 else { drop(ObjectIdentifier(p)); return }
            var mask: [UInt8] = [0, 0, 0, 0]
            if masked {
                guard b.count >= at + 4 else { return }
                mask = Array(b[at..<at + 4]); at += 4
            }
            guard b.count >= at + len else { return }
            var payload = Array(b[at..<at + len])
            if masked { for i in 0..<len { payload[i] ^= mask[i & 3] } }
            p.buffer = Data(b[(at + len)...])
            switch op {
            case 0x1:
                let text = String(decoding: payload, as: UTF8.self)
                var q: [String: String] = [:]
                for i in URLComponents(string: "/?" + text)?.queryItems ?? [] { q[i.name] = i.value ?? "" }
                if q["c"] == "feature" { _ = setFeature(q["id"] ?? "", q["v"] == "1") } else { live.order(q) }
            case 0x8:
                sendFrame(p, op: 0x8, payload: [])
                drop(ObjectIdentifier(p)); return
            case 0x9:
                sendFrame(p, op: 0xA, payload: payload)
            default:
                break
            }
        }
    }

    private func sendText(_ p: RemotePeer, _ d: Data) { sendFrame(p, op: 0x1, payload: [UInt8](d)) }

    private func sendFrame(_ p: RemotePeer, op: UInt8, payload: [UInt8]) {
        var f: [UInt8] = [0x80 | op]
        let n = payload.count
        if n < 126 { f.append(UInt8(n)) }
        else if n < 65536 { f += [126, UInt8(n >> 8), UInt8(n & 0xFF)] }
        else { f.append(127); for i in (0..<8).reversed() { f.append(UInt8((n >> (i * 8)) & 0xFF)) } }
        f += payload
        p.c.send(content: Data(f), completion: .contentProcessed { _ in })
    }
}

/// The Ableton Live window on the screen, for the SESSION tab's crop (CGWindowList: owners and bounds need no permission).
///   found     a Live window exists at all;  onScreen  it is on the current Space and not minimized
///   x y w h   its place in points (top left of the main screen);  fx fy fw fh  the same in the VNC picture's pixels:
///             Apple's server puts each screen at its top-left in points and draws it at its pixel size
///             (MANTRA_REMOTE_VIEWING LESSONS, 8.11.2026)
///   covered   the part of it (0…1) under other apps' windows;  by  those apps;  front  Live is the app in front
enum RemoteWindow {
    static func find() -> [String: Any] {
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        guard let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let on = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return ["found": false] }
        func owner(_ w: [String: Any]) -> String { (w[kCGWindowOwnerName as String] as? String) ?? "" }
        func layer(_ w: [String: Any]) -> Int { (w[kCGWindowLayer as String] as? Int) ?? 0 }
        func bounds(_ w: [String: Any]) -> CGRect {
            guard let bd = w[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: bd as CFDictionary) else { return .zero }
            return r
        }
        func id(_ w: [String: Any]) -> Int { (w[kCGWindowNumber as String] as? Int) ?? -1 }
        func biggestLive(_ list: [[String: Any]]) -> [String: Any]? {
            list.filter { owner($0) == "Live" && layer($0) == 0 && bounds($0).width > 200 && bounds($0).height > 150 }
                .max { bounds($0).width * bounds($0).height < bounds($1).width * bounds($1).height }
        }
        guard biggestLive(all) != nil else { return ["found": false, "onScreen": false, "front": front == "Live"] }
        guard let main = biggestLive(on), let idx = on.firstIndex(where: { id($0) == id(main) }) else {
            return ["found": true, "onScreen": false, "front": front == "Live"]
        }
        let r = bounds(main)
        // what lies over it: every window in front of it (the list runs front to back) that is not Live's own
        var coveredArea: CGFloat = 0
        var by: [String] = []
        for w in on[..<idx] {
            let o = owner(w)
            guard o != "Live", o != "Window RemoteServer", layer(w) < 1000 else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a < 0.05 { continue }
            let i = bounds(w).intersection(r)
            guard !i.isNull, i.width * i.height > 400 else { continue }
            coveredArea += i.width * i.height
            if !by.contains(o) { by.append(o) }
        }
        // the screens in top-left points, and where the window falls in the VNC picture
        let screens = NSScreen.screens
        let mainH = screens.first?.frame.height ?? 0
        let tl = screens.map { (x: $0.frame.minX, y: mainH - $0.frame.maxY, w: $0.frame.width, h: $0.frame.height,
                                s: $0.backingScaleFactor) }
        let minX = tl.map { $0.x }.min() ?? 0, minY = tl.map { $0.y }.min() ?? 0
        let c = CGPoint(x: r.midX, y: r.midY)
        let sc = tl.first { c.x >= $0.x && c.x < $0.x + $0.w && c.y >= $0.y && c.y < $0.y + $0.h } ?? tl.first
        var out: [String: Any] = ["found": true, "onScreen": true, "front": front == "Live", "frontApp": front,
                                  "x": r.minX, "y": r.minY, "w": r.width, "h": r.height,
                                  "covered": min(1, Double(coveredArea / max(1, r.width * r.height))), "by": by]
        if let s = sc {
            out["fx"] = Int(((s.x - minX) + (r.minX - s.x) * s.s).rounded())
            out["fy"] = Int(((s.y - minY) + (r.minY - s.y) * s.s).rounded())
            out["fw"] = Int((r.width * s.s).rounded())
            out["fh"] = Int((r.height * s.s).rounded())
            out["scale"] = s.s
        }
        return out
    }
}

/// The cable, or wireless ADB, when the Wi-Fi is not shared: every 5 s each phone adb sees gets
/// `adb reverse tcp:8966 tcp:8966` (and 15900 → the Mac's VNC 5900), so on the phone the Mac is at 127.0.0.1.
final class RemoteCable {
    private let adb = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
    private(set) var phones: [String] = []
    var onChange: () -> Void = {}

    /// ~/.config/ableton-live-remote/no-cable: no adb reverse (the phone then finds the Mac on the Wi-Fi or Tailscale),
    /// and the reverses already made are taken away. For a Wi-Fi test with the cable in, and for "no ADB" (v5).
    static var off: Bool { FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.config/ableton-live-remote/no-cable") }
    private var wasOff = false

    private var timer: Timer?
    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    func stop() { timer?.invalidate(); timer = nil; phones = [] }

    private func serials() -> [String] {
        run(["devices"]).split(separator: "\n").dropFirst().compactMap { l -> String? in
            let f = l.split(separator: "\t"); return f.count == 2 && f[1] == "device" ? String(f[0]) : nil
        }
    }

    private func run(_ args: [String]) -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: adb); p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return "" }
        let d = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: d, encoding: .utf8) ?? ""
    }

    private func tick() {
        guard FileManager.default.isExecutableFile(atPath: adb) else { return }
        let off = RemoteCable.off
        if off && wasOff { return }
        wasOff = off
        DispatchQueue.global().async {
            if off {
                for s in self.serials() {
                    _ = self.run(["-s", s, "reverse", "--remove", "tcp:\(REMOTE_PORT)"])
                    _ = self.run(["-s", s, "reverse", "--remove", "tcp:15900"])
                }
                DispatchQueue.main.async { self.phones = []; self.onChange() }
                return
            }
            let serials = self.serials()
            var names: [String] = []
            for s in serials {
                let list = self.run(["-s", s, "reverse", "--list"])
                if !list.contains("tcp:\(REMOTE_PORT)") {
                    _ = self.run(["-s", s, "reverse", "tcp:\(REMOTE_PORT)", "tcp:\(REMOTE_PORT)"])
                }
                // the Mac's Screen Sharing (VNC 5900) for the SESSION tab, at 127.0.0.1:15900 on the phone
                if !list.contains("tcp:15900") {
                    _ = self.run(["-s", s, "reverse", "tcp:15900", "tcp:5900"])
                }
                let model = self.run(["-s", s, "shell", "getprop", "ro.product.model"]).trimmingCharacters(in: .whitespacesAndNewlines)
                names.append(model.isEmpty ? s : model)
            }
            DispatchQueue.main.async {
                if names != self.phones { self.phones = names; self.onChange() }
            }
        }
    }
}
