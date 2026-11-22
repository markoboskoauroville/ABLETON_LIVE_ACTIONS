// The tab CUSTOM SHORTCUTS (v28). Marko, 22.11.2026: "I need to be able to capture any key to these commands I already
// predefined ... I just click the capture and then this is changed." One row per command of A1's key mappings: its name in plain
// words, its key as he reads it, CAPTURE (the next key or combination becomes its key, Esc cancels) and RESET. The key is stored by
// physical key code with the label of the current keyboard layout (Shortcuts.swift). A clash is told before it is saved.
import SwiftUI
import AppKit

final class ShortcutsModule: LiveModule {
    let id = "shortcuts"
    let title = "CUSTOM SHORTCUTS"
    let about = "Every command of the A1 key mappings with its key: CAPTURE gives it any key you press next"
    let defaultOn = true
    var hasSwitch: Bool { false }                     // a view of A1's key mappings: nothing to switch
    func setOn(_ on: Bool) {}
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func menuItems() -> [NSMenuItem] { [] }
    func status() -> String { "\(A1Engine.shared.shortcuts.rows.count) KEYS" }
    func settingsView() -> AnyView { AnyView(ShortcutsView(e: A1Engine.shared)) }
}

/// a word that is an Accessibility button with its own name ("Capture zoom out")
struct KeyWord: View {
    let text: String, label: String, on: Bool
    let action: () -> Void
    var body: some View {
        Text(text).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(on ? AMBER : GREY)
            .padding(.horizontal, 6).padding(.vertical, 4).contentShape(Rectangle()).onTapGesture(perform: action)
            .axButton(label, id: "", value: on ? "on" : "off") { DispatchQueue.main.async(execute: action) }
    }
}

struct ShortcutsView: View {
    @ObservedObject var e: A1Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !e.tapOK {
                Text("Accessibility: not allowed yet. System Settings → Privacy & Security → Accessibility → \(APP_NAME) on.")
                    .font(.system(size: 11)).foregroundColor(AMBER).fixedSize(horizontal: false, vertical: true)
            }
            // which mode a field puts him in, at once
            HStack(spacing: 8) {
                Text(e.modeWord).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(e.modeWord == "COMMAND" ? GREEN : AMBER)
                    .accessibilityLabel("Key mode " + e.modeWord)
                Small(text: e.modeWord == "COMMAND" ? "his command keys act" : "every key is free: " + e.modeWhy)
            }
            if let n = e.shortcutsNote { Text(n).font(.system(size: 11, weight: .bold)).foregroundColor(AMBER).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Small(text: "Press CAPTURE, then the key or combination you want. Esc cancels. The old key is free again at once.")
                Spacer()
                KeyWord(text: "RESET ALL", label: "Reset all shortcuts", on: !e.shortcuts.overrides.isEmpty) { e.resetAllShortcuts() }
            }
            if let p = e.pendingKey { pendingView(p) }
            ForEach(e.shortcuts.rows, id: \.id) { r in row(r) }
        }
    }
    func pendingView(_ p: PendingKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(p.spec.shown) for \(e.shortcuts.rows.first { $0.id == p.id }?.name ?? p.id)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(AMBER)
            ForEach(p.warnings, id: \.self) { Text($0).font(.system(size: 11)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true) }
            if let o = p.other {
                Text("That key is already \(e.shortcuts.rows.first { $0.id == o }?.name ?? o). Swap: that command takes the key this one had.").font(.system(size: 11)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if p.other != nil { KeyWord(text: "SWAP", label: "Swap the two keys", on: true) { e.resolvePending(swap: true, saveAnyway: false) } }
                else { KeyWord(text: "SAVE ANYWAY", label: "Save the key anyway", on: true) { e.resolvePending(swap: false, saveAnyway: true) } }
                KeyWord(text: "CANCEL", label: "Cancel the capture", on: false) { e.resolvePending(swap: false, saveAnyway: false) }
            }
        }
        .padding(10).background(RoundedRectangle(cornerRadius: 6).stroke(AMBER, lineWidth: 1))
    }
    func row(_ r: ShortcutRow) -> some View {
        let waiting = e.captureId == r.id
        let cur = e.shortcuts.current(r.id) ?? r.original
        let isIn = r.id == "i", isOut = r.id == "o"
        return HStack(alignment: .top, spacing: 8) {
            Text(waiting ? "press a key…" : cur.shown).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(waiting ? AMBER : .white)
                .frame(width: 110, alignment: .leading).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name).font(.system(size: 12)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                if e.shortcuts.isOverridden(r.id) { Text("was \(r.original.shown)").font(.system(size: 10)).foregroundColor(GREY) }
                if let m = e.maps.first(where: { mapId($0) == r.id }), let was = m["was"] as? String, !was.isEmpty { Text("before: " + was).font(.system(size: 10)).foregroundColor(GREY).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 4)
            if isIn || isOut {
                let snap = isIn ? e.snapIn : e.snapOut
                KeyWord(text: "SNAP " + snap.rawValue.uppercased(), label: "Snap of " + r.name, on: snap != .off) { e.cycleSnap(isIn ? "in" : "out") }
            }
            KeyWord(text: waiting ? "CANCEL" : "CAPTURE", label: (waiting ? "Cancel capture for " : "Capture ") + r.name, on: waiting) { waiting ? e.cancelCapture() : e.beginCapture(r.id) }
            if e.shortcuts.isOverridden(r.id) { KeyWord(text: "RESET", label: "Reset " + r.name, on: false) { e.resetShortcut(r.id) } }
        }
    }
}
