// MACROS: pre-recorded runs, a name and RUN (Marko, 27.10.2026: "We have a new category, which is kind of a
// pre-recorded macro. There will be a macro name and then the run."). Each macro is a helper script in
// Resources/helpers; its lines are shown as they come, the last one is the verdict. CHECK runs it with --dry: every
// check, nothing changed.
import SwiftUI
import AppKit

// a macro's buttons: a word and the arguments its script gets ("RUN" none, "CHECK" --dry)
struct Macro {
    let name: String; let script: String; let about: String
    var buttons: [(String, [String])] = [("RUN", []), ("CHECK", ["--dry"])]
    var auto: [String]? = nil          // the arguments of its AUTO run, when it can run by itself as a set opens
}

let MACROS = [
    Macro(name: "Map Channels to Allen & Heath CQ12T", script: "macro_cq12t.py",
          about: "CQ MixPad opened on the MacBook Pro screen, the CQ12T chosen and connected, Stream Mode set to Multitrack (16 × 16, the Mac confirms), the mixer scene \"Live Multitrack\" recalled (names, inputs 1–10 from USB; stored by itself the first time), Live's audio input and output the CQ12T, then track 1 → Ext. Out 1 and Ext. In 1, track 2 → 2 … up to 16",
          auto: ["--auto"]),
    // the names both ways (Marko, 27.10.2026: "add button to transfer names in both directions, from Mixer to Ableton
    // or from Ableton to Mixer")
    Macro(name: "Names between Live and the CQ12T", script: "macro_names.py",
          about: "track N ↔ CQ input N (1–10). MIXER → LIVE: the CQ's names become the track names. LIVE → MIXER: the track names go to the CQ, cut to its 6 characters (svemir VOC → SvmVOC). CHECK: both lists, nothing changed",
          buttons: [("MIXER → LIVE", ["--to-live"]), ("LIVE → MIXER", ["--to-mixer"]), ("CHECK", ["--dry"])]),
]

final class MacrosModule: NSObject, LiveModule, ObservableObject {
    let id = "macros"
    let title = "MACROS"
    let about = "pre-recorded runs: a name and RUN; CHECK only looks"
    let defaultOn = true
    @Published var running: String?
    @Published var last = 0                     // the button pressed last, lit while its run goes on
    @Published var lines: [String: [String]] = [:]
    private var proc: Process?
    // AUTO (Marko, 27.10.2026, after "can this configuration be saved ... and then just applied automatically"): a
    // macro with AUTO on runs by itself a few seconds after a set opens in Live. The set is Live's window title; the
    // first title seen when this app starts is not an opening.
    @Published var autoOn: [String: Bool] = SETTINGS.read()["macroAuto"] as? [String: Bool] ?? [:]
    private var watch: Timer?
    private var lastSet: String?
    private var pendingAuto: DispatchWorkItem?

    func setOn(_ on: Bool) {
        if !on { proc?.terminate(); watch?.invalidate(); watch = nil; return }
        lastSet = liveSet()
        watch = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.look() }
    }
    func setAuto(_ m: Macro, _ v: Bool) { autoOn[m.name] = v; SETTINGS.change { $0["macroAuto"] = self.autoOn } }
    // the set open in Live: its main window's title, through accessibility (nil when Live is not running)
    func liveSet() -> String? {
        guard let app = liveApp() else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var w: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXMainWindowAttribute as CFString, &w) == .success, let win = w else { return nil }
        var t: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win as! AXUIElement, kAXTitleAttribute as CFString, &t) == .success else { return nil }
        let title = (t as? String ?? "").trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
    private func look() {
        guard let set = liveSet(), set != lastSet else { return }
        lastSet = set
        pendingAuto?.cancel()
        let job = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            for m in MACROS where m.auto != nil && self.autoOn[m.name] == true && self.running == nil {
                self.lines[m.name] = ["AUTO: \"\(set)\" opened"]
                self.run(m, m.auto!, keep: true); break
            }
        }
        pendingAuto = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: job)     // the set loads its tracks first
    }
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func status() -> String { running.map { "RUNNING · " + $0 } ?? "\(MACROS.count) MACRO" + (MACROS.count == 1 ? "" : "S") }

    func run(_ m: Macro, _ args: [String], keep: Bool = false) {
        guard running == nil else { return }
        running = m.name; if !keep { lines[m.name] = [] }
        let p = Process(); p.executableURL = URL(fileURLWithPath: PYTHON)
        p.arguments = ["-u", SCRIPTS + "/" + m.script] + args
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
    @objc func mRun(_ i: NSMenuItem) { let m = MACROS[i.tag / 10]; run(m, m.buttons[i.tag % 10].1) }
    func menuItems() -> [NSMenuItem] {
        keep = MACROS.enumerated().flatMap { n, m in
            m.buttons.enumerated().filter { $0.element.0 != "CHECK" }.map { b, btn in
                let i = NSMenuItem(title: "  ▶ " + m.name + (m.buttons.count > 2 ? "  ·  " + btn.0 : ""), action: running == nil ? #selector(mRun(_:)) : nil, keyEquivalent: "")
                i.target = self; i.tag = n * 10 + b; return i
            }
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
                        Text(mac.name + (m.running == mac.name ? "  · running" : "")).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if mac.auto != nil {
                            Word(text: "AUTO", on: m.autoOn[mac.name] == true) { m.setAuto(mac, !(m.autoOn[mac.name] == true)) }
                                .help("runs by itself a few seconds after a set opens in Live")
                        }
                        ForEach(mac.buttons.indices, id: \.self) { b in
                            Word(text: mac.buttons[b].0, on: m.running == mac.name && m.last == b) { m.last = b; m.run(mac, mac.buttons[b].1) }
                        }
                    }
                    Small(text: mac.about + (mac.auto != nil ? (m.autoOn[mac.name] == true ? ". AUTO is on: it runs by itself when a set opens (tracks already right are left alone, CQ MixPad only if the Mac does not see 16 × 16)" : ". AUTO: switch it on and it runs by itself when a set opens") : ""))
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
