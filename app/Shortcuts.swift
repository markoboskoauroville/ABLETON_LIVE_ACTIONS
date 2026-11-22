// CUSTOM SHORTCUTS: the model behind the tab, as pure code (Foundation only, tested by the workflow: tests/shortcuts_test.swift).
// Marko, 22.11.2026: "I need to be able to capture any key to these commands I already predefined. So instead of one, two being
// zoom in, zoom out, it can be any key. I just click the capture and then this is changed."
// The rows are A1's key mappings (A1_DEFAULT_MAPS and his own additions); a row's original key is the one in the code, and his own
// choice is an OVERRIDE stored by physical key code with the label from the keyboard layout at the time. The file
// ~/.config/ableton-assistant-shortcuts.json: {"schema":1,"keys":{"<row id>":{"code":18,"mods":["cmd"],"label":"1"}}}, written atomically;
// a missing file means the original keys; a file that cannot be read falls back to the originals and says so.
import Foundation

struct KeySpec: Equatable {
    var code: Int
    var mods: [String]            // canonical order: cmd, alt, ctrl, shift
    var label: String
    static let order = ["cmd", "alt", "ctrl", "shift"]
    static func canon(_ m: [String]) -> [String] { order.filter { m.contains($0) } }
    init(code: Int, mods: [String], label: String) { self.code = code; self.mods = KeySpec.canon(mods); self.label = label }
    /// the key as he reads it: modifier symbols, then the key
    var shown: String { ShortcutKeys.chord(mods, label) }
    func same(code c: Int, mods m: [String]) -> Bool { c == code && KeySpec.canon(m) == mods }
}

enum ShortcutKeys {
    static func chord(_ mods: [String], _ label: String) -> String {
        let sym = ["ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘"]
        var s = ""
        for k in ["ctrl", "alt", "shift", "cmd"] where mods.contains(k) { s += sym[k]! }
        return s + (label.count == 1 ? label.uppercased() : label)
    }
    /// Shortcuts the whole Mac uses: warned about plainly, the choice is his.
    static func systemClash(_ s: KeySpec) -> String? {
        let all: [(KeySpec, String)] = [
            (KeySpec(code: 49, mods: ["cmd"], label: "Space"), "⌘Space opens Spotlight"),
            (KeySpec(code: 49, mods: ["ctrl"], label: "Space"), "⌃Space is the Launcher or the input-source switch"),
            (KeySpec(code: 48, mods: ["cmd"], label: "Tab"), "⌘Tab switches applications"),
            (KeySpec(code: 12, mods: ["cmd"], label: "Q"), "⌘Q quits the application"),
            (KeySpec(code: 4, mods: ["cmd"], label: "H"), "⌘H hides the application"),
            (KeySpec(code: 46, mods: ["cmd"], label: "M"), "⌘M minimises the window"),
            (KeySpec(code: 13, mods: ["cmd"], label: "W"), "⌘W closes the window"),
            (KeySpec(code: 53, mods: ["cmd", "alt"], label: "Esc"), "⌘⌥Esc is Force Quit"),
            (KeySpec(code: 20, mods: ["cmd", "shift"], label: "3"), "⇧⌘3 is a screenshot"),
            (KeySpec(code: 21, mods: ["cmd", "shift"], label: "4"), "⇧⌘4 is a screenshot"),
            (KeySpec(code: 23, mods: ["cmd", "shift"], label: "5"), "⇧⌘5 is the screenshot tool"),
        ]
        return all.first { $0.0.same(code: s.code, mods: s.mods) }?.1
    }
}

struct ShortcutRow: Equatable {
    let id: String                // the map's own id (A1's mapId): "1", "cmd f", "shift 1" ...
    let name: String              // what it does, in plain words
    let original: KeySpec
}

struct ShortcutModel {
    var rows: [ShortcutRow]
    var overrides: [String: KeySpec] = [:]

    func current(_ id: String) -> KeySpec? { overrides[id] ?? rows.first { $0.id == id }?.original }
    func isOverridden(_ id: String) -> Bool { overrides[id] != nil }
    /// which of his commands a pressed key is (nil: not one of them)
    func row(forCode code: Int, mods: [String]) -> ShortcutRow? { rows.first { current($0.id)?.same(code: code, mods: mods) == true } }

    enum Capture: Equatable { case saved, unchanged, clash(String) }   // clash: the id of the other row holding that key

    /// The captured key becomes the row's key; the old key is free again. A key another row holds is a clash: nothing changes
    /// until the caller chooses (swap, or cancel by not calling again).
    mutating func capture(_ id: String, _ spec: KeySpec) -> Capture {
        guard let row = rows.first(where: { $0.id == id }) else { return .unchanged }
        if current(id)?.same(code: spec.code, mods: spec.mods) == true { return .unchanged }
        if let other = rows.first(where: { $0.id != id && current($0.id)?.same(code: spec.code, mods: spec.mods) == true }) { return .clash(other.id) }
        if spec.same(code: row.original.code, mods: row.original.mods) { overrides[id] = nil } else { overrides[id] = spec }
        return .saved
    }
    /// the clash resolved by swapping: the row takes the key, the other row takes the row's old key
    mutating func swap(_ id: String, with other: String, _ spec: KeySpec) {
        guard let old = current(id) else { return }
        set(other, old); set(id, spec)
    }
    private mutating func set(_ id: String, _ spec: KeySpec) {
        guard let row = rows.first(where: { $0.id == id }) else { return }
        if spec.same(code: row.original.code, mods: row.original.mods) { overrides[id] = nil } else { overrides[id] = spec }
    }
    mutating func reset(_ id: String) { overrides[id] = nil }
    mutating func resetAll() { overrides = [:] }

    /// a captured key against Live's own menu keys ("key" as A1's command list gives it, e.g. "⌘L")
    func liveClash(_ spec: KeySpec, commands: [(key: String, words: String)]) -> String? {
        commands.first { !$0.key.isEmpty && $0.key == spec.shown }?.words
    }
}

enum ShortcutFile {
    static let schema = 1
    /// (overrides, a note for the tab and the log when the file was not used as it was)
    static func parse(_ data: Data?) -> (overrides: [String: KeySpec], note: String?) {
        guard let data = data else { return ([:], nil) }
        guard let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let keys = j["keys"] as? [String: Any] else {
            return ([:], "the shortcuts file could not be read: the original keys are used")
        }
        let v = (j["schema"] as? Int) ?? 0
        if v > schema { return ([:], "the shortcuts file is from a newer version (schema \(v)): the original keys are used") }
        var out: [String: KeySpec] = [:]
        for (id, any) in keys {
            guard let d = any as? [String: Any], let code = d["code"] as? Int, let mods = d["mods"] as? [String], let label = d["label"] as? String else { continue }
            out[id] = KeySpec(code: code, mods: mods, label: label)
        }
        return (out, v == 0 ? "the shortcuts file was from before the schema: migrated" : nil)
    }
    static func serialize(_ o: [String: KeySpec]) -> Data {
        var k: [String: Any] = [:]
        for (id, s) in o { k[id] = ["code": s.code, "mods": s.mods, "label": s.label] as [String: Any] }
        return (try? JSONSerialization.data(withJSONObject: ["schema": schema, "keys": k] as [String: Any], options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }
    @discardableResult static func write(_ o: [String: KeySpec], to url: URL) -> Bool {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? serialize(o).write(to: url, options: .atomic)) != nil
    }
}
