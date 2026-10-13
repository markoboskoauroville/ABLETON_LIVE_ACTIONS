// THE E16 BLOB'S EARS (apps/a1.lua MB, 17.9.2026): every MIDI message the Mac hears, newest at the top, each line in
// the colour of the OXI One E16 knob that sent it, read from the newest OXI scene (~/Documents/**/*.oxie16: plain JSON,
// pages[p].encoders[k] holds `color`, a hue index 0-99, beside turn_actions[1].nr1, the CC number). Or alternating white
// and orange groups. CoreMIDI in Swift, replacing hs.midi; the scene is looked at again every three seconds.
import Foundation
import CoreMIDI

func a1PadR(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
func a1PadL(_ s: String, _ n: Int) -> String { s.count >= n ? s : String(repeating: " ", count: n - s.count) + s }

final class A1MIDI {
    static let PALETTE: [Int] = [
        0x9D61FF, 0x8F60FF, 0x8960FF, 0x7D60FF, 0x745FFF, 0x675FFF, 0x5B59FF, 0x4D51FF, 0x3F4BFF, 0x454FFF,
        0x4653FF, 0x4C57FF, 0x4B58FF, 0x4F5CFF, 0x5663FF, 0x5A67FF, 0x647BFF, 0x6D8FFF, 0x759EFF, 0x7FAFFF,
        0x87B0FF, 0x90B3FF, 0x97B5FF, 0x9EB6FF, 0xA4B1FF, 0xACB0FF, 0xB8B3FF, 0xC5B9FF, 0xD1BFFF, 0xDAC4FF,
        0xD2B6FF, 0xC8A7FF, 0xDAC4FF, 0xECE1FF, 0xFFFEFF, 0xFFEAF8, 0xFFDCD2, 0xF5FDBC, 0xE8FCB7, 0xD7FCB0,
        0xDEFC9F, 0xEBFB8E, 0xF3FC8C, 0xF9FC8C, 0xFEFA89, 0xF5FDDC, 0xB8F9FF, 0xFFEDFF, 0xFFC9FF, 0xFFBAF7,
        0xFFAAEE, 0xFF99E2, 0xFF89D1, 0xFF8DC1, 0xFF91B2, 0xFF78AF, 0xFF61AE, 0xFF3420, 0xFF3420, 0xFF3420,
        0xFF3420, 0xFF3420, 0xFF3420, 0xFF3420, 0xFF59B9, 0xFF59B9, 0xFF59B9, 0xFF5AD5, 0xFF5AEF, 0xFF5CFF,
        0xF55BFF, 0xE76CFF, 0xDE7CFF, 0xD78FFF, 0xB885FF, 0x937BFF, 0x92ACFF, 0x5695FF, 0x0D8DFF, 0x0A97FF,
        0x05A1FF, 0x00AFFF, 0x00BAFF, 0x00CAFF, 0x00DFFF, 0x00F1FF, 0x00FCEB, 0x00E9C1, 0x00D596, 0x00DE95,
        0x00E58E, 0x00E894, 0x00ED9E, 0x00F2A5, 0x00F3AB, 0x00F6B4, 0x00FABB, 0x00EDB9, 0x00DFB1, 0x00D4AE]
    static let PORTS = ["Port 1": "USB1", "Port 2": "USB2", "Port 3": "USB3", "Bus 1": "IAC Bus 1"]
    static let HEAD = a1PadR("TIME", 8) + "  " + a1PadR("PORT", 11) + "  " + a1PadR("CHAN", 6) + " " + a1PadR("MESSAGE", 9) + " " + a1PadL("VALUE", 5) + "   KNOB"

    var log: [E16Line] = []
    var heard = false
    var dirty = false
    var listening: [String] = []
    var sceneName: String?, sceneWhy: String?
    var colour = "knob"          // "knob" or "alternate"
    var scenePath = "", page = 1
    private var map: [Int: (rgb: [Double], name: String, knob: Int)] = [:]
    private var tone = "w", lastKey = ""
    private var client = MIDIClientRef(), port = MIDIPortRef()
    private var connected: [MIDIEndpointRef] = []
    private var sceneStamp: Date?, sceneTimer: Timer?

    static func portName(_ n: String) -> String { PORTS[n] ?? n }
    static func rgb(_ index: Int?) -> [Double] {
        guard let i = index, i >= 0, i < PALETTE.count else { return [0.6, 0.6, 0.6] }
        let h = PALETTE[i]; return [Double((h >> 16) & 255) / 255, Double((h >> 8) & 255) / 255, Double(h & 255) / 255]
    }
    static func sourceName(_ e: MIDIEndpointRef) -> String {
        var s: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(e, kMIDIPropertyName, &s) == noErr, let n = s?.takeRetainedValue() { return n as String }
        return "?"
    }
    static func sources() -> [(MIDIEndpointRef, String)] {
        (0..<MIDIGetNumberOfSources()).map { let e = MIDIGetSource($0); return (e, sourceName(e)) }
    }

    func start(device: String) {
        stop()
        if client == 0 { MIDIClientCreateWithBlock("A1 E16 blob" as CFString, &client) { _ in } }
        if port == 0 {
            MIDIInputPortCreateWithBlock(client, "A1 in" as CFString, &port) { [weak self] list, src in
                let name = src.map { Unmanaged<NSString>.fromOpaque($0).takeUnretainedValue() as String } ?? "?"
                var bytes: [[UInt8]] = []
                var p = list.pointee.packet
                for _ in 0..<list.pointee.numPackets {
                    let n = Int(p.length)
                    let b = withUnsafeBytes(of: p.data) { Array($0.prefix(n)) }
                    bytes.append(b)
                    p = MIDIPacketNext(&p).pointee
                }
                DispatchQueue.main.async { for b in bytes { self?.heard(name, b) } }
            }
        }
        for (e, n) in A1MIDI.sources() where device.isEmpty || device == n {
            let ref = Unmanaged.passRetained(n as NSString).toOpaque()
            if MIDIPortConnectSource(port, e, ref) == noErr { connected.append(e); listening.append(n) }
        }
        loadScene()
        sceneTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.watchScene() }
    }
    func stop() {
        for e in connected { MIDIPortDisconnectSource(port, e) }
        connected = []; listening = []
        sceneTimer?.invalidate(); sceneTimer = nil
    }
    func clear() { log = []; heard = false; lastKey = ""; tone = "w"; dirty = true }

    private func heard(_ dev: String, _ b: [UInt8]) {
        var i = 0
        while i < b.count {
            let st = b[i]
            guard st >= 0x80 else { i += 1; continue }
            let kind = st & 0xF0, ch = Int(st & 0x0F) + 1
            let len = (kind == 0xC0 || kind == 0xD0) ? 2 : (st >= 0xF0 ? 1 : 3)
            let d1 = i + 1 < b.count ? Int(b[i + 1]) : 0, d2 = i + 2 < b.count ? Int(b[i + 2]) : 0
            var type = "other", what = "", value = ""
            var ccNum: Int?
            switch kind {
            case 0xB0: type = "controlChange"; what = "CC \(d1)"; value = "\(d2)"; ccNum = d1
            case 0x90: type = d2 == 0 ? "noteOff" : "noteOn"; what = (d2 == 0 ? "off " : "note ") + "\(d1)"; value = "\(d2)"
            case 0x80: type = "noteOff"; what = "off \(d1)"; value = "\(d2)"
            case 0xE0: type = "pitchWheel"; what = "pitchWheel"
            case 0xC0: type = "programChange"; what = "programChange"
            case 0xD0: type = "channelPressure"; what = "channelPressure"
            default: if st >= 0xF0 { i += max(1, len); continue }
            }
            i += len
            heard = true
            let key = "\(dev)|\(ch)|\(type)|\(ccNum ?? (kind == 0x90 || kind == 0x80 ? d1 : -1))"
            if key != lastKey { tone = tone == "w" ? "o" : "w"; lastKey = key }
            var d = A1MIDI.portName(dev); if d.count > 11 { d = String(d.prefix(10)) + "…" }
            let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
            var line = tf.string(from: Date()) + "  " + a1PadR(d, 11) + "  ch" + a1PadR("\(ch)", 4) + " " + a1PadR(what, 9) + " " + a1PadL(value, 5)
            var rgb: [Double]? = nil
            if colour == "knob", let c = ccNum, let k = map[c] { line += "   knob " + a1PadR("\(k.knob)", 2) + " " + k.name; rgb = k.rgb }
            log.append(E16Line(text: line, tone: tone, rgb: rgb))
            if log.count > 400 { log.removeFirst(log.count - 400) }
            dirty = true
        }
    }

    // the OXI scenes under ~/Documents, two folders deep, newest first
    func scenes() -> [(path: String, name: String, at: Date)] {
        let fm = FileManager.default, root = NSHomeDirectory() + "/Documents"
        var dirs = [root]
        for a in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
            var isDir: ObjCBool = false; let l1 = root + "/" + a
            if fm.fileExists(atPath: l1, isDirectory: &isDir), isDir.boolValue {
                dirs.append(l1)
                for b in (try? fm.contentsOfDirectory(atPath: l1)) ?? [] { var d2: ObjCBool = false; let l2 = l1 + "/" + b; if fm.fileExists(atPath: l2, isDirectory: &d2), d2.boolValue { dirs.append(l2) } }
            }
        }
        var out: [(String, String, Date)] = []
        for d in dirs { for f in (try? fm.contentsOfDirectory(atPath: d)) ?? [] where f.hasSuffix(".oxie16") {
            let p = d + "/" + f
            out.append((p, String(f.dropLast(7)), ((try? fm.attributesOfItem(atPath: p))?[.modificationDate] as? Date) ?? .distantPast))
        } }
        return out.sorted { $0.2 > $1.2 }.map { (path: $0.0, name: $0.1, at: $0.2) }
    }
    func loadScene() {
        map = [:]; sceneName = nil; sceneWhy = nil
        var path = scenePath
        if path.isEmpty { guard let s = scenes().first else { sceneWhy = "no .oxie16 scene found in ~/Documents"; return }; path = s.path }
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: path)), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let pages = j["pages"] as? [[String: Any]] else { sceneWhy = "that file is not a scene I can read"; return }
        guard page >= 1, page <= pages.count, let enc = pages[page - 1]["encoders"] as? [[String: Any]] else { sceneWhy = "the scene has no page \(page)"; return }
        for (k, e) in enc.enumerated() {
            let turn = (e["turn_actions"] as? [[String: Any]])?.first
            if let cc = (turn?["nr1"] as? NSNumber)?.intValue {
                map[cc] = (A1MIDI.rgb((e["color"] as? NSNumber)?.intValue), (e["abbr"] as? String) ?? (e["name"] as? String) ?? "knob \(k + 1)", k + 1)
            }
        }
        sceneName = "\((j["title"] as? String) ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension), page \(page)"
        sceneStamp = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
    private func watchScene() {
        let path = scenePath.isEmpty ? scenes().first?.path : scenePath
        guard let p = path, let m = (try? FileManager.default.attributesOfItem(atPath: p))?[.modificationDate] as? Date else { return }
        if sceneStamp == nil || m > sceneStamp! { loadScene(); dirty = true }
    }
}
