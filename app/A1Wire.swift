// A1'S WIRE TO ABLETONOSC (Live's Control Surface): questions and orders go to UDP 127.0.0.1:11000, answers come back to
// port 11001, always 11001. In the Lua A1 the wire was a1_ears.py over its pipes, because Hammerspoon's own UDP sockets
// once stopped calling back (MANTRA_STAR LESSONS 23). In Swift one socket does both: it holds 11001, so every question
// leaves from it and every answer arrives on it, read by a dispatch source on the main queue. While another app holds
// 11001 (the Teacher, the Guide) the wire says "busy": orders still go out from a spare socket, answers cannot be heard.
// THE ROUTER (24.10.2026, Marko: "make an OSC router so both apps can use it"): while the wire holds 11001 it also
// listens on 127.0.0.1:11002. Any other app sends its OSC there instead of to 11000; the router passes it to Live from
// the 11001 socket, and every answer Live sends back is handed to A1 and copied to every app that spoke through the
// router in the last two minutes (each app keeps the answers for the addresses it asked).
import Foundation
import Darwin

final class A1Wire {
    static let ANSWER: UInt16 = 11001
    static let ROUTER: UInt16 = 11002
    static let CLIENT_TTL = 120.0
    var state = "not started"                 // "listening", "busy", or what went wrong
    var asked = 0, answered = 0
    var lastAnswer: Double?
    private var fd: Int32 = -1                // the socket on 11001
    private var spare: Int32 = -1             // sends while 11001 is not ours
    private var source: DispatchSourceRead?
    private var rfd: Int32 = -1               // the router's socket on 127.0.0.1:11002
    private var rsource: DispatchSourceRead?
    private var clients: [String: (to: sockaddr_in, seen: Double)] = [:]
    var routed = 0
    private var retry: Timer?
    private var pending: [String: (fn: ([Any]?, String?) -> Void, timer: Timer)] = [:]

    var running: Bool { fd >= 0 || state == "busy" }

    func start() {
        guard fd < 0 else { return }
        retry?.invalidate(); retry = nil
        let s = socket(AF_INET, SOCK_DGRAM, 0)
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = A1Wire.ANSWER.bigEndian; a.sin_addr.s_addr = INADDR_ANY
        let ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } == 0
        if !ok {
            close(s)
            state = "busy"
            retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in self?.start() }
            return
        }
        fd = s; state = "listening"
        let src = DispatchSource.makeReadSource(fileDescriptor: s, queue: .main)
        src.setEventHandler { [weak self] in self?.read() }
        src.resume(); source = src
        routerStart()
    }
    private func routerStart() {
        guard rfd < 0 else { return }
        let s = socket(AF_INET, SOCK_DGRAM, 0)
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = A1Wire.ROUTER.bigEndian; a.sin_addr.s_addr = inet_addr("127.0.0.1")
        guard withUnsafePointer(to: &a, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }) == 0 else { close(s); return }
        rfd = s
        let src = DispatchSource.makeReadSource(fileDescriptor: s, queue: .main)
        src.setEventHandler { [weak self] in self?.routerRead() }
        src.resume(); rsource = src
    }
    // a packet from another app: remember who sent it, pass it on to Live from 11001 so the answer comes back here
    private func routerRead() {
        var buf = [UInt8](repeating: 0, count: 65536)
        var from = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let n = withUnsafeMutablePointer(to: &from) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(rfd, &buf, buf.count, 0, $0, &len) } }
        guard n > 0 else { return }
        clients["\(from.sin_addr.s_addr):\(from.sin_port)"] = (from, a1Time())
        routed += 1
        var to = sockaddr_in(); to.sin_family = sa_family_t(AF_INET); to.sin_port = UInt16(11000).bigEndian
        to.sin_addr.s_addr = inet_addr("127.0.0.1")
        _ = withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, buf, n, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    }
    // an answer from Live: a copy to every app heard from in the last two minutes
    private func routerForward(_ buf: [UInt8], _ n: Int) {
        guard rfd >= 0, !clients.isEmpty else { return }
        let now = a1Time()
        clients = clients.filter { now - $0.value.seen < A1Wire.CLIENT_TTL }
        for (_, c) in clients {
            var to = c.to
            _ = withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(rfd, buf, n, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        }
    }
    func stop() {
        retry?.invalidate(); retry = nil
        source?.cancel(); source = nil
        if fd >= 0 { close(fd); fd = -1 }
        rsource?.cancel(); rsource = nil
        if rfd >= 0 { close(rfd); rfd = -1 }
        clients = [:]
        if spare >= 0 { close(spare); spare = -1 }
        state = "not started"
        failPending("the wire was stopped")
    }
    private func read() {
        var buf = [UInt8](repeating: 0, count: 65536)
        let n = recv(fd, &buf, buf.count, 0)
        guard n > 0 else { return }
        routerForward(buf, n)
        guard let (addr, args) = OSC.parse(Data(buf[0..<n])) else { return }
        answered += 1; lastAnswer = a1Time()
        if let q = pending.removeValue(forKey: addr) { q.timer.invalidate(); q.fn(args, nil) }
    }
    @discardableResult func send(_ addr: String, _ args: [Any] = []) -> Bool {
        if fd < 0 && state != "busy" { start() }
        var s = fd
        if s < 0 { if spare < 0 { spare = socket(AF_INET, SOCK_DGRAM, 0) }; s = spare }
        let d = OSC.message(addr, args)
        var to = sockaddr_in(); to.sin_family = sa_family_t(AF_INET); to.sin_port = UInt16(11000).bigEndian
        to.sin_addr.s_addr = inet_addr("127.0.0.1")
        let n = d.withUnsafeBytes { p in withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(s, p.baseAddress, d.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
        return n == d.count
    }
    // an order: nothing comes back
    func tell(_ addr: String, _ args: [Any] = []) { send(addr, args) }
    // a question: the answer to that address, or nil and why after `wait` seconds
    func ask(_ addr: String, wait: Double = 2.5, _ fn: @escaping ([Any]?, String?) -> Void) {
        if fd < 0 && state != "busy" { start() }
        if state == "busy" { fn(nil, words()); return }
        if pending[addr] != nil { fn(nil, "a question is still out"); return }
        let t = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            guard let self = self, let q = self.pending.removeValue(forKey: addr) else { return }
            q.fn(nil, "Live did not answer (\(self.words()); is AbletonOSC its Control Surface?)")
        }
        pending[addr] = (fn, t)
        asked += 1
        if !send(addr) { pending.removeValue(forKey: addr)?.timer.invalidate(); fn(nil, "the question could not be sent") }
    }
    func isPending(_ addr: String) -> Bool { pending[addr] != nil }
    func failPending(_ why: String) {
        let all = pending; pending = [:]
        for (_, q) in all { q.timer.invalidate(); q.fn(nil, why) }
    }
    func words() -> String {
        if state == "busy" { return "port \(A1Wire.ANSWER) is held by another app (\(holder())): Live's answers cannot be heard" }
        if state == "listening" {
            let ago = lastAnswer.map { String(format: ", the last answer %.1f s ago", a1Time() - $0) } ?? ", no answer yet"
            let r = rfd >= 0 ? "; the router on \(A1Wire.ROUTER): \(clients.count) app(s), \(routed) passed on" : "; the router could not open \(A1Wire.ROUTER)"
            return "the wire holds \(A1Wire.ANSWER); \(asked) asked, \(answered) answered\(ago)\(r)"
        }
        return "the wire: \(state)"
    }
    private var holderCache: (who: String, at: Double)?
    func holder() -> String {
        if let h = holderCache, a1Time() - h.at < 30 { return h.who }
        let (_, out) = a1Shell("/usr/sbin/lsof", ["-nP", "-iUDP:\(A1Wire.ANSWER)", "-Fpc"], timeout: 3)
        var names: [String] = [], pid = ""
        for l in out.split(separator: "\n") {
            if l.hasPrefix("p") { pid = String(l.dropFirst()) } else if l.hasPrefix("c") { names.append("\(l.dropFirst()) \(pid)") }
        }
        let who = names.isEmpty ? "nobody visible" : names.joined(separator: ", ")
        holderCache = (who, a1Time()); return who
    }
}
