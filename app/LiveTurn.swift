// LIVE'S OSC, SHARED: USE, LET GO (Marko, 31.10.2026: "if there are two sessions accessing at the same time, one cannot
// block the other ... You use it and you let go. Always like this.").
//
// AbletonOSC answers every question to UDP 11001. Nobody keeps that port: a question takes the turn (an exclusive flock
// on ~/.config/liveosc.lock), binds 127.0.0.1:11001 (without SO_REUSEADDR, so a program from before the rule is waited
// for, never robbed), sends, reads its own answer (the address, and for a track question its index first), closes the
// port and lets the turn go. An order has no answer: any socket, no turn. The same rule and lock as ABLETON_LIVE_ACTIONS
// helpers/liveosc.py and MANTRA_STAR a1_ears.py (manifest ableton-live-audio.md). This file is copied as it is into
// every Swift app that talks to Live; change it here and copy it again.
import Foundation
import Darwin

enum LiveTurn {
    static let ANSWER: UInt16 = 11001
    static let WAIT = 1.5             // the longest a turn is held: one question and its answer
    static let TURN = 6.0             // the longest a program waits for its turn
    static var lockPath: String { NSHomeDirectory() + "/.config/liveosc.lock" }

    // MARK: OSC, the subset AbletonOSC speaks
    static func message(_ address: String, _ args: [Any]) -> Data {
        func str(_ s: String) -> Data { var d = Data(s.utf8); d.append(0); while d.count % 4 != 0 { d.append(0) }; return d }
        var tags = ",", body = Data()
        for a in args {
            switch a {
            case let b as Bool: tags += b ? "T" : "F"
            case let i as Int: tags += "i"; var v = Int32(truncatingIfNeeded: i).bigEndian; body.append(Data(bytes: &v, count: 4))
            case let i as Int32: tags += "i"; var v = i.bigEndian; body.append(Data(bytes: &v, count: 4))
            case let f as Double: tags += "f"; var v = Float(f).bitPattern.bigEndian; body.append(Data(bytes: &v, count: 4))
            case let f as Float: tags += "f"; var v = f.bitPattern.bigEndian; body.append(Data(bytes: &v, count: 4))
            case let s as String: tags += "s"; body.append(str(s))
            default: break
            }
        }
        return str(address) + str(tags) + body
    }

    static func decode(_ b: [UInt8]) -> (String, [Any])? {
        func cstr(_ at: Int) -> (String, Int)? {
            guard at < b.count, let z = b[at...].firstIndex(of: 0) else { return nil }
            return (String(decoding: b[at..<z], as: UTF8.self), (z / 4 + 1) * 4)
        }
        guard b.first == UInt8(ascii: "/"), let (addr, p0) = cstr(0) else { return nil }
        guard p0 < b.count, b[p0] == UInt8(ascii: ","), let (tags, p1) = cstr(p0) else { return (addr, []) }
        var p = p1, out: [Any] = []
        func u32(_ at: Int) -> UInt32 { b[at..<at + 4].reduce(0) { $0 << 8 | UInt32($1) } }
        for t in tags.dropFirst() {
            switch t {
            case "i": guard p + 4 <= b.count else { return (addr, out) }; out.append(Int(Int32(bitPattern: u32(p)))); p += 4
            case "f": guard p + 4 <= b.count else { return (addr, out) }; out.append(Double(Float(bitPattern: u32(p)))); p += 4
            case "d": guard p + 8 <= b.count else { return (addr, out) }
                out.append(Double(bitPattern: UInt64(u32(p)) << 32 | UInt64(u32(p + 4)))); p += 8
            case "s": guard let (s, n) = cstr(p) else { return (addr, out) }; out.append(s); p = n
            case "T": out.append(true)
            case "F": out.append(false)
            default: return (addr, out)
            }
        }
        return (addr, out)
    }

    private static func sockaddr(_ port: UInt16) -> sockaddr_in {
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = port.bigEndian
        a.sin_addr.s_addr = inet_addr("127.0.0.1"); return a
    }

    private static func sendto(_ fd: Int32, _ d: Data, _ port: UInt16) -> Bool {
        var to = sockaddr(port)
        let n = d.withUnsafeBytes { p in withUnsafePointer(to: &to) { $0.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) {
            Darwin.sendto(fd, p.baseAddress, d.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
        return n == d.count
    }

    /// An order to Live: no answer, so no turn and no port.
    @discardableResult static func tell(_ address: String, _ args: [Any] = []) -> Bool {
        let fd = socket(AF_INET, SOCK_DGRAM, 0); guard fd >= 0 else { return false }
        defer { close(fd) }
        return sendto(fd, message(address, args), 11000)
    }

    /// A question to Live in one turn: its answer's arguments, or nil (no answer in time, no turn, or the port kept by
    /// a program from before the rule). Blocks for at most TURN + wait seconds: call it off the main thread.
    static func ask(_ address: String, _ args: [Any] = [], wait: Double = WAIT) -> [Any]? {
        try? FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/.config", withIntermediateDirectories: true)
        let lk = open(lockPath, O_CREAT | O_RDWR, 0o644); guard lk >= 0 else { return nil }
        defer { close(lk) }
        let until = Date().addingTimeInterval(TURN)
        while flock(lk, LOCK_EX | LOCK_NB) != 0 {
            if Date() > until { return nil }
            usleep(10_000)
        }
        defer { flock(lk, LOCK_UN) }                                   // let go: the port (below) first, then the turn
        let fd = socket(AF_INET, SOCK_DGRAM, 0); guard fd >= 0 else { return nil }
        defer { close(fd) }
        var me = sockaddr(ANSWER)
        let bindUntil = Date().addingTimeInterval(WAIT)
        while withUnsafePointer(to: &me, { $0.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }) != 0 {
            if Date() > bindUntil { return nil }                       // kept by a program from before the rule
            usleep(50_000)
        }
        var tv = timeval(tv_sec: 0, tv_usec: 50_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        guard sendto(fd, message(address, args), 11000) else { return nil }
        let end = Date().addingTimeInterval(wait)
        var buf = [UInt8](repeating: 0, count: 65536)
        while Date() < end {
            let n = recv(fd, &buf, buf.count, 0)
            guard n > 0, let (a, r) = decode(Array(buf[0..<n])) else { continue }
            if a == "/live/error" { return nil }
            if a == address {
                if let t = args.first as? Int, let first = r.first as? Int, first != t { continue }   // another track's late answer
                return r
            }
        }
        return nil
    }
}
