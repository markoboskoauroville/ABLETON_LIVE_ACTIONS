// PHONE REMOTE, the module that serves the Android app Ableton Live Remote (Mantra) (repo ABLETON_LIVE_REMOTE). Until
// 24.11.2026 a separate Mac helper did this; Marko, 24.11.2026: "helper app is unnecessary because it can become part of
// Ableton Live Assistant to be a helper for remote controller. Then everything we have under one roof ... helper app can
// disable, enable things in Ableton Live Assistant. So, we make one ecosystem, Mantra Ableton Live System."
// One port, 8966 (HTTP + WebSocket, Bonjour _mantralive._tcp, adb reverse 8966 and 15900 → the Mac's VNC 5900): the
// set's state pushed to the phone, its orders to Live, the waveforms, the Live window's place, and the Assistant's own
// switches (/features). Files: RemoteLive.swift, RemoteServer.swift, RemotePeaks.swift; the playback mode PlaybackMode.swift.
import SwiftUI
import AppKit

final class RemoteModule: NSObject, LiveModule, ObservableObject {
    let id = "remote"
    let title = "PHONE REMOTE"
    let about = "the phone app Ableton Live Remote: transport, metronome, arm, new tracks, the waveform, the Live window; it can switch this app's modules"
    let defaultOn = true

    let live = RemoteLive()
    lazy var server = RemoteServer(live: live)
    let cable = RemoteCable()
    @Published var phones: [String] = []
    @Published var lastPhone = "no phone yet"
    private var wired = false
    private var timer: Timer?

    func setOn(_ on: Bool) {
        if on {
            if !wired {
                wired = true
                live.onChange = { [weak self] in self?.server.broadcast(); self?.refresh() }
                server.onPhones = { [weak self] in self?.refresh() }
                server.onSeen = { [weak self] who in self?.lastPhone = who }
                server.features = { RemoteModule.features() }
                server.setFeature = { id, v in RemoteModule.setFeature(id, v) }
                cable.onChange = { [weak self] in self?.refresh() }
                live.start()
            }
            server.start()
            cable.start()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        } else {
            server.stop()
            cable.stop()
            live.watchers = 0
            timer?.invalidate(); timer = nil
        }
        refresh()
    }
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func menuItems() -> [NSMenuItem] {
        let i = NSMenuItem(title: "  Phone: " + (phones.isEmpty ? "none connected" : phones.joined(separator: ", ")), action: nil, keyEquivalent: "")
        i.isEnabled = false
        return [i]
    }
    func settingsView() -> AnyView { AnyView(RemoteView(m: self)) }
    func status() -> String { phones.isEmpty ? server.status.uppercased() : "\(phones.count) PHONE" + (phones.count == 1 ? "" : "S") }

    func refresh() { phones = server.phones }

    // MARK: the Assistant's switches, for the phone

    /// The A1 switches a phone may see and set (the rest of A1 is keys and settings that belong in this window).
    static let a1Flags: [(String, String, String)] = [
        ("space", "THE SPACE KEY", "stopped: Space plays from the insert point; playing: Space stops"),
        ("blob", "THE CLOCK BLOB", "the insert point's time on Live's screen"),
        ("midiBlob", "THE E16 BLOB", "what the E16 knobs do, on the screen"),
        ("resume", "THE INSERT POINT REMEMBERED", "written beside the set, put back when it opens"),
        ("openLast", "OPEN THE LAST SET", "when Live starts"),
        ("viaMenu", "KEYS THROUGH LIVE'S MENU", "a key runs Live's menu command instead of a key stroke")]

    static func features() -> [[String: Any]] {
        var out: [[String: Any]] = []
        for m in MODULES where m.id != "remote" && m.hasSwitch {
            out.append(["id": "module:" + m.id, "group": "MODULES", "name": m.title, "about": m.about,
                        "on": UMBRELLA.on[m.id] == true, "state": m.status()])
        }
        if let e = A1Engine.shared {
            for (k, name, about) in a1Flags {
                out.append(["id": "a1:" + k, "group": "A1", "name": name, "about": about, "on": e.flag(k)])
            }
        }
        return out
    }

    @discardableResult
    static func setFeature(_ id: String, _ v: Bool) -> Bool {
        if id.hasPrefix("module:") {
            let m = String(id.dropFirst(7))
            guard m != "remote", MODULES.contains(where: { $0.id == m }) else { return false }
            UMBRELLA.setModule(m, v)
            AppLog.write("phone: module \(m) " + (v ? "on" : "off"))
            return true
        }
        if id.hasPrefix("a1:"), let e = A1Engine.shared {
            let k = String(id.dropFirst(3))
            guard a1Flags.contains(where: { $0.0 == k }) else { return false }
            e.setFlag(k, v)
            AppLog.write("phone: A1 \(k) " + (v ? "on" : "off"))
            return true
        }
        return false
    }
}

struct RemoteView: View {
    @ObservedObject var m: RemoteModule
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Head(t: "THE PHONE")
            Small(text: m.phones.isEmpty ? "No phone connected. Ableton Live Remote on the phone finds this Mac by itself (the cable, the same Wi-Fi, Tailscale)."
                                         : "Connected: " + m.phones.joined(separator: ", "))
            Small(text: "Last asked by: \(m.lastPhone) · the server: \(m.server.status) (port \(REMOTE_PORT))")
            Small(text: m.cable.phones.isEmpty ? "Cable / adb: no phone" : "Cable / adb: " + m.cable.phones.joined(separator: ", ") + " · adb reverse on")
            Head(t: "AFTER A STOP (LIVE ITSELF, ANY STOP)")
            ModeSwitch()
            Small(text: "The same switch as the phone's fifth transport key and A1's old \"follow\": RETURN is the DAW way, CONTINUE the DaVinci Resolve way.")
        }
    }
}
