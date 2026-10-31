// A1'S WIRE TO ABLETONOSC (Live's Control Surface): questions and orders go to UDP 127.0.0.1:11000, answers come back to
// port 11001, always 11001. USE, LET GO (Marko, 31.10.2026: "if there are two sessions accessing at the same time, one
// cannot block the other ... You use it and you let go. Always like this."): this wire no longer keeps 11001 while the
// app runs, and the router on 11002 (24.10.2026) is gone with it. A question takes the shared turn on 11001
// (LiveTurn.swift: flock ~/.config/liveosc.lock, bind, ask, read its answer, let go) on a background queue and the answer
// comes back on the main queue as before; an order goes from any socket. Every other program on the Mac takes the same
// turn (helpers/liveosc.py, MANTRA_STAR a1_ears.py), so none needs a router any more.
import Foundation
import Darwin

final class A1Wire {
    static let ANSWER: UInt16 = 11001
    var state = "not started"                 // "sharing" once started
    var asked = 0, answered = 0
    var lastAnswer: Double?
    private var spare: Int32 = -1             // orders go out from here
    private let queue = DispatchQueue(label: "a1wire.turns")      // this app's questions one after another
    private var pending: [String: Bool] = [:]
    var routed: Int { 0 }                      // the router is gone (USE, LET GO); kept for the status words

    var running: Bool { state == "sharing" }

    func start() {
        if spare < 0 { spare = socket(AF_INET, SOCK_DGRAM, 0) }
        state = "sharing"
    }
    func stop() {
        if spare >= 0 { close(spare); spare = -1 }
        state = "not started"
        failPending("the wire was stopped")
    }
    @discardableResult func send(_ addr: String, _ args: [Any] = []) -> Bool {
        if state != "sharing" { start() }
        let d = OSC.message(addr, args)
        var to = sockaddr_in(); to.sin_family = sa_family_t(AF_INET); to.sin_port = UInt16(11000).bigEndian
        to.sin_addr.s_addr = inet_addr("127.0.0.1")
        let n = d.withUnsafeBytes { p in withUnsafePointer(to: &to) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(spare, p.baseAddress, d.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
        return n == d.count
    }
    // an order: nothing comes back
    func tell(_ addr: String, _ args: [Any] = []) { send(addr, args) }
    // a question: the answer to that address, or nil and why after `wait` seconds; fn runs on the main queue
    func ask(_ addr: String, wait: Double = 2.5, _ fn: @escaping ([Any]?, String?) -> Void) {
        if state != "sharing" { start() }
        if pending[addr] != nil { fn(nil, "a question is still out"); return }
        pending[addr] = true
        asked += 1
        queue.async { [weak self] in
            let r = LiveTurn.ask(addr, [], wait: min(wait, 2.5))
            DispatchQueue.main.async {
                guard let self = self, self.pending.removeValue(forKey: addr) != nil else { return }
                if let r = r { self.answered += 1; self.lastAnswer = a1Time(); fn(r, nil) }
                else { fn(nil, "Live did not answer (\(self.words()); is AbletonOSC its Control Surface?)") }
            }
        }
    }
    func isPending(_ addr: String) -> Bool { pending[addr] != nil }
    func failPending(_ why: String) {
        pending = [:]          // the answers still on their way are dropped when they come
        _ = why
    }
    func words() -> String {
        if state == "sharing" {
            let ago = lastAnswer.map { String(format: ", the last answer %.1f s ago", a1Time() - $0) } ?? ", no answer yet"
            return "Live's port \(A1Wire.ANSWER) shared (use, let go); \(asked) asked, \(answered) answered\(ago)"
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
        let who = names.isEmpty ? "nobody (shared)" : names.joined(separator: ", ")
        holderCache = (who, a1Time()); return who
    }
}
