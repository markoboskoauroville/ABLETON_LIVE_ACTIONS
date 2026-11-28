// WHICH BRANCH HANDLES THIS KEY? (v37, 28.11.2026) A pure function (Foundation only), tested by the workflow without Live:
// tests/keyroute_test.swift. Marko, 28.11.2026: "Please go and test all my custom shortcuts ... let me know why they don't work."
//
// The cause it fixes: A1Engine.filter looked his key maps up by KEY CODE and, when the code had any map but none matched the
// modifiers, returned the key to Live. When he captured ⌥Space for "play from the loop's start", the Space key's code had a
// map, so every plain Space went straight to Live and never reached the Space logic (stop and plant the insert point, play from
// it): 43 "key Space: command" lines in app.log from 24.11 to 28.11 and not one Space decision. A table lookup by key code is not
// a match: a chord belongs to his map only when code AND modifiers match; anything else falls through to the built-in handling
// of that key (Space, ⌘R rename, Return / Escape / Tab ending the typing), exactly as if no map shared its code.
import Foundation

enum KeyRoute: Equatable {
    case map(Int)        // his shortcut: the index of the matching map among those on this code
    case space           // the Space logic (playing: stop and plant; stopped: play from the insert point)
    case rename          // ⌘R: Live's Edit › Rename, typing begins
    case end             // Return, Enter, Escape, Tab: typing ends, the key is Live's own
    case liveOwn         // not one of his keys: Live's own, untouched

    static let modOrder = ["cmd", "alt", "ctrl", "shift"]
    static func canon(_ m: [String]) -> [String] { modOrder.filter { m.contains($0) } }

    /// mods: the modifiers held (cmd, alt, ctrl, shift); fn: the fn / secondary modifier is held.
    /// mapMods: the modifiers of each of his maps on this key code (empty when none). spaceOn: A1's "space" flag.
    /// typing: Live's rename or search typing is on (then an ending key ends it before anything else).
    static func route(isSpace: Bool, isR: Bool, isEnd: Bool, mods: [String], fn: Bool = false, mapMods: [[String]], spaceOn: Bool, typing: Bool) -> KeyRoute {
        let held = canon(mods)
        if isEnd && typing { return .end }                                            // Return / Escape / Tab end his typing first
        if let i = mapMods.firstIndex(where: { canon($0) == held }) { return .map(i) }   // an exact chord of his: his command wins (fn is not
                                                                                         // compared: arrows and F-keys carry it by themselves)
        if isR && held == ["cmd"] { return .rename }
        if isEnd { return .end }
        // Space: plain (or with Shift, which Live receives as a plain Space) is the Space logic; ⌘ / ⌥ / ⌃ / fn chords are Live's own
        if isSpace && spaceOn && !fn && !held.contains(where: { $0 != "shift" }) { return .space }
        return .liveOwn
    }
    /// is this route one of his command keys (asked of KeyMode: command mode or typing)?
    static func isMapped(_ r: KeyRoute) -> Bool {
        switch r { case .map, .rename, .space: return true; default: return false }
    }
}

/// A number from AbletonOSC as a Double: Live sends floats ("f"), integers ("i": selected_track, num_tracks,
/// signature_numerator) and booleans. Until v37 the integers were read with `as? Double`, which is nil for an Int, so
/// ⌘↓ / ⌘↑ never knew the selected track and ⌥↓ / ⌥↑ dragged track 1 whatever was selected.
func oscDouble(_ v: Any?) -> Double? {
    switch v {
    case let d as Double: return d
    case let f as Float: return Double(f)
    case let i as Int: return Double(i)
    case let i as Int32: return Double(i)
    case let b as Bool: return b ? 1 : 0
    default: return nil
    }
}
