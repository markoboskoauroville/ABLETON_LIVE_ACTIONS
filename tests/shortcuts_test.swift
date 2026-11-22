// The Custom Shortcuts model tested without Live (the workflow copies this to main.swift beside app/Shortcuts.swift and app/KeyMode.swift).
import Foundation

var pass = 0, fail = 0
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }
func k(_ code: Int, _ mods: [String] = [], _ label: String) -> KeySpec { KeySpec(code: code, mods: mods, label: label) }
let rows = [ShortcutRow(id: "1", name: "Zoom out", original: k(18, [], "1")), ShortcutRow(id: "2", name: "Zoom in", original: k(19, [], "2")),
            ShortcutRow(id: "cmd f", name: "Close the browser", original: k(3, ["cmd"], "F")), ShortcutRow(id: "i", name: "IN", original: k(34, [], "I"))]
var m = ShortcutModel(rows: rows)

// capture replaces a key and the old key is free again
ok(m.current("1") == k(18, [], "1"), "the original key is the key at first")
ok(m.capture("1", k(0, [], "A")) == .saved, "capture A for Zoom out: saved")
ok(m.current("1") == k(0, [], "A") && m.isOverridden("1"), "the row now has A")
ok(m.row(forCode: 0, mods: [])?.id == "1", "A is the command Zoom out")
ok(m.row(forCode: 18, mods: []) == nil, "the old key 1 is free again")
ok(m.capture("2", k(18, [], "1")) == .saved, "the old key 1 can be given to another row")
// clash with another of his shortcuts
ok(m.capture("cmd f", k(0, [], "A")) == .clash("1"), "A is held by Zoom out: a clash, naming the row")
ok(m.current("cmd f") == k(3, ["cmd"], "F"), "a clash changes nothing")
// swap
m.swap("cmd f", with: "1", k(0, [], "A"))
ok(m.current("cmd f") == k(0, [], "A") && m.current("1") == k(3, ["cmd"], "F"), "swap: the two rows exchange their keys")
// reset
m.reset("1"); ok(m.current("1") == k(18, [], "1") && !m.isOverridden("1"), "reset puts the original key back")
m.resetAll(); ok(m.overrides.isEmpty && m.current("2") == k(19, [], "2"), "reset all: every original key")
// capturing the original key again removes the override
ok(m.capture("1", k(0, [], "A")) == .saved && m.capture("1", k(18, [], "1")) == .saved && !m.isOverridden("1"), "capturing the original key again clears the override")
ok(m.capture("1", k(18, [], "1")) == .unchanged, "the same key again: unchanged")
// modifier order does not matter
ok(m.capture("2", KeySpec(code: 5, mods: ["shift", "cmd"], label: "G")) == .saved && m.row(forCode: 5, mods: ["cmd", "shift"])?.id == "2", "modifiers in any order are one key")
// system and Live clashes are warnings
ok(ShortcutKeys.systemClash(k(49, ["cmd"], "Space")) != nil && ShortcutKeys.systemClash(k(48, ["cmd"], "Tab")) != nil && ShortcutKeys.systemClash(k(12, ["cmd"], "Q")) != nil, "⌘Space, ⌘Tab and ⌘Q are named as system shortcuts")
ok(ShortcutKeys.systemClash(k(18, [], "1")) == nil, "a plain 1 is not a system shortcut")
let live: [(key: String, words: String)] = [("⌘L", "Edit › Loop Selection"), ("O", "Playback › Metronome"), ("", "x › y")]
ok(m.liveClash(k(37, ["cmd"], "L"), commands: live) == "Edit › Loop Selection", "⌘L is Live's Loop Selection: shown")
ok(m.liveClash(k(31, [], "O"), commands: live) == "Playback › Metronome", "O is Live's Metronome: shown")
ok(m.liveClash(k(0, [], "A"), commands: live) == nil, "A is nothing in Live's menus")
// the file: schema, round trip, migration, a bad file
let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "shortcuts-\(getpid()).json"); defer { try? FileManager.default.removeItem(at: tmp) }
ok(ShortcutFile.parse(nil).overrides.isEmpty && ShortcutFile.parse(nil).note == nil, "no file: the original keys, no note")
ok(ShortcutFile.write(m.overrides, to: tmp), "write")
let back = ShortcutFile.parse(try? Data(contentsOf: tmp))
ok(back.overrides == m.overrides && back.note == nil, "round trip")
ok(ShortcutFile.parse(Data("not json".utf8)).note != nil && ShortcutFile.parse(Data("not json".utf8)).overrides.isEmpty, "a bad file: the originals and a note")
let v0 = Data("{\"keys\":{\"1\":{\"code\":0,\"mods\":[],\"label\":\"A\"}}}".utf8)
ok(ShortcutFile.parse(v0).overrides["1"] == k(0, [], "A") && ShortcutFile.parse(v0).note?.contains("migrated") == true, "a file from before the schema is migrated, his key kept")
ok(ShortcutFile.parse(Data("{\"schema\":9,\"keys\":{}}".utf8)).note?.contains("newer") == true, "a newer schema: the originals and a note")
ok((try? FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()))?.contains { $0.hasPrefix("shortcuts-\(getpid())") && $0 != "shortcuts-\(getpid()).json" } == false, "atomic: no temporary file left beside it")
// the decision of Part 1 uses the current mapping: after a capture the new key is a command key in command mode and free while typing
do {
    var mm = ShortcutModel(rows: rows)
    _ = mm.capture("1", k(0, [], "A"))
    let arrangement = FocusReading(live: true, role: "AXStaticText")
    let typing = FocusReading(live: true, role: "AXTextField")
    let newKey = mm.row(forCode: 0, mods: []) != nil, oldKey = mm.row(forCode: 18, mods: []) != nil
    ok(KeyMode.decide(frontIsLive: true, focus: arrangement, typingFlag: false, launcherBox: false, isMappedKey: newKey) == .command, "after a capture the new key is a command key in command mode")
    ok(KeyMode.decide(frontIsLive: true, focus: typing, typingFlag: false, launcherBox: false, isMappedKey: newKey) != .command, "...and a free key while typing")
    ok(KeyMode.decide(frontIsLive: true, focus: arrangement, typingFlag: false, launcherBox: false, isMappedKey: oldKey) != .command, "the old key is free in command mode too")
}
print(fail == 0 ? "shortcuts_test: all \(pass) passed" : "shortcuts_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
