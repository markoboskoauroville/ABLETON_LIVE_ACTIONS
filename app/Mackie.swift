// MIDI TO MK CONTROL: a stub until its engine is ported to Swift (13.10.2026). Its section says so; nothing runs.
import SwiftUI
import AppKit

final class MackieModule: LiveModule {
    let id = "mackie"
    let title = "MIDI TO MK CONTROL"
    let about = "A knob on a MIDI controller becomes a Mackie Control command in Live"
    let defaultOn = false
    func setOn(_ on: Bool) {}
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func menuItems() -> [NSMenuItem] { [] }
    func settingsView() -> AnyView { AnyView(Small(text: "Being ported from Lua to Swift; until then it runs in the star's Lua host.")) }
    func status() -> String { "COMING" }
}
