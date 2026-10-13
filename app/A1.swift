// ABLETON ASSISTANT A1: a stub until its engine is ported to Swift (13.10.2026). Its section says so; nothing runs.
import SwiftUI
import AppKit

final class A1Module: LiveModule {
    let id = "a1"
    let title = "ABLETON ASSISTANT A1"
    let about = "Space, markers, loop, transients and the clock blob, fitted to Live"
    let defaultOn = false
    func setOn(_ on: Bool) {}
    func liveCame() {}
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }
    func menuItems() -> [NSMenuItem] { [] }
    func settingsView() -> AnyView { AnyView(Small(text: "Being ported from Lua to Swift; until then it runs in the star's Lua host.")) }
    func status() -> String { "COMING" }
}
