// MACROS: pre-recorded runs, a name and RUN (Marko, 27.10.2026: "We have a new category, which is kind of a
// pre-recorded macro. There will be a macro name and then the run."). Each macro is a helper script in
// Resources/helpers; its lines are shown as they come, the last one is the verdict. CHECK runs it with --dry: every
// check, nothing changed.
import SwiftUI
import AppKit

struct Macro { let name: String; let script: String; let about: String }

let MACROS = [
    Macro(name: "Map Channels to Allen & Heath CQ12T", script: "macro_cq12t.py",
          about: "CQ MixPad opened on the MacBook Pro screen, the CQ12T chosen and connected, Stream Mode set to Multitrack (16 × 16, the Mac confirms), Live's audio input and output the CQ12T, then track 1 → Ext. Out 1 and Ext. In 1, track 2 → 2 … up to 16"),
]

final class MacrosModule: NSObject, LiveModule, ObservableObject {
    let id = "macros"
    let title = "MACROS"
    let about = "pre-recorded runs: a name and RUN; CHECK only looks"
    let defaultOn = true
    @Published var running: String?
    @Published var lines: [String: [String]] = [:]
    private var proc: Process?

    func setOn(_ on: Bool) { if !on { proc?.terminate() } }
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func status() -> String { running.map { "RUNNING · " + $0 } ?? "\(MACROS.count) MACRO" + (MACROS.count == 1 ? "" : "S") }

    func run(_ m: Macro, dry: Bool) {
        guard running == nil else { return }
        running = m.name; lines[m.name] = []
        let p = Process(); p.executableURL = URL(fileURLWithPath: PYTHON)
        p.arguments = ["-u", SCRIPTS + "/" + m.script] + (dry ? ["--dry"] : [])
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        var rest = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { h.readabilityHandler = nil; return }
            rest += String(decoding: d, as: UTF8.self)
            var got: [String] = []
            while let r = rest.firstIndex(of: "\n") { got.append(String(rest[..<r])); rest = String(rest[rest.index(after: r)...]) }
            if !got.isEmpty { DispatchQueue.main.async { self?.lines[m.name, default: []] += got } }
        }
        p.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                if p.terminationStatus != 0 && p.terminationStatus != 1 && p.terminationStatus != 2 {
                    self?.lines[m.name, default: []].append("STOPPED: the helper ended with \(p.terminationStatus)")
                }
                self?.running = nil; self?.proc = nil; UMBRELLA.paint()
            }
        }
        do { try p.run(); proc = p } catch { lines[m.name] = ["STOPPED: \(error)"]; running = nil }
        UMBRELLA.paint()
    }

    private var keep: [NSMenuItem] = []
    @objc func mRun(_ i: NSMenuItem) { run(MACROS[i.tag], dry: false) }
    func menuItems() -> [NSMenuItem] {
        keep = MACROS.enumerated().map { n, m in
            let i = NSMenuItem(title: "  ▶ " + m.name, action: running == nil ? #selector(mRun(_:)) : nil, keyEquivalent: "")
            i.target = self; i.tag = n; return i
        }
        return keep
    }
    func settingsView() -> AnyView { AnyView(MacrosView(m: self)) }
}

struct MacrosView: View {
    @ObservedObject var m: MacrosModule
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MACROS.indices, id: \.self) { i in
                let mac = MACROS[i]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(mac.name).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Word(text: m.running == mac.name ? "RUNNING…" : "RUN", on: m.running == mac.name) { m.run(mac, dry: false) }
                        Word(text: "CHECK", on: false) { m.run(mac, dry: true) }
                    }
                    Small(text: mac.about)
                    let ls = m.lines[mac.name] ?? []
                    if !ls.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(ls.indices, id: \.self) { j in
                                let l = ls[j]
                                Text(l).font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(l.hasPrefix("DONE") ? GREEN : l.hasPrefix("STOPPED") || l.contains("✗") ? AMBER : .white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                    }
                }
            }
        }
    }
}
