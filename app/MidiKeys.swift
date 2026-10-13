// MIDI TO KEY STROKE: a stub until its engine is ported to Swift (13.10.2026). Its section says so; nothing runs.
import SwiftUI
import AppKit

final class MidiKeysModule: LiveModule {
    let id = "midikeys"
    let title = "MIDI TO KEY STROKE"
    let about = "A knob's CC or a key's note becomes a key stroke, or the Mac's own volume"
    let defaultOn = false
    func setOn(_ on: Bool) {}
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func menuItems() -> [NSMenuItem] { [] }
    func settingsView() -> AnyView { AnyView(Small(text: "Being ported from Lua to Swift; until then it runs in the star's Lua host.")) }
    func status() -> String { "COMING" }
}
