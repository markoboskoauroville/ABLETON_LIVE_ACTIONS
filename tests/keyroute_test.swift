// Which branch handles a key (app/KeyRoute.swift), tested without Live. The workflow copies this to main.swift beside
// app/KeyRoute.swift. The first block is the bug of 24-28.11.2026: his ⌥Space override shadowed every plain Space.
import Foundation

var pass = 0, fail = 0
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }
func r(space: Bool = false, isR: Bool = false, end: Bool = false, _ mods: [String], fn: Bool = false, maps: [[String]] = [], spaceOn: Bool = true, typing: Bool = false) -> KeyRoute {
    KeyRoute.route(isSpace: space, isR: isR, isEnd: end, mods: mods, fn: fn, mapMods: maps, spaceOn: spaceOn, typing: typing)
}

// THE BUG: an override puts a second chord (⌥Space, "play from the loop's start") on Space's key code
ok(r(space: true, [], maps: [["alt"]]) == .space, "⌥Space captured: a plain Space still goes to the Space logic (stop and plant / play from the insert point)")
ok(r(space: true, ["alt"], maps: [["alt"]]) == .map(0), "⌥Space captured: ⌥Space is his command")
ok(r(space: true, ["shift"], maps: [["alt"]]) == .space, "⌥Space captured: ⇧Space is still the Space logic (Live gets a plain Space)")
ok(r(space: true, ["cmd"], maps: [["alt"]]) == .liveOwn, "⌥Space captured: ⌘Space is not his, Live's own (Spotlight)")
ok(r(space: true, ["ctrl"], maps: [["alt"]]) == .liveOwn, "⌃Space: Live's own (the Launcher)")
ok(r(space: true, [], maps: []) == .space, "no map on Space: a plain Space is the Space logic")
ok(r(space: true, [], maps: [["alt"]], spaceOn: false) == .liveOwn, "the Space switch off: a plain Space is Live's own even with ⌥Space captured")
ok(r(space: true, ["alt"], maps: [["alt"]], spaceOn: false) == .map(0), "the Space switch off: ⌥Space is still his command")
ok(r(space: true, [], maps: [[]]) == .map(0), "he captured a plain Space itself: his command wins")
ok(r(space: true, [], fn: true, maps: [["alt"]]) == .liveOwn, "fn+Space: Live's own")

// the same hole for every key that has built-in handling
ok(r(isR: true, ["cmd"]) == .rename, "⌘R with no map: rename, typing begins")
ok(r(isR: true, ["cmd"], maps: [["shift"]]) == .rename, "a map on R with other modifiers: ⌘R is still rename")
ok(r(isR: true, ["shift"], maps: [["shift"]]) == .map(0), "⇧R captured: his command")
ok(r(isR: true, ["cmd"], maps: [["cmd"]]) == .map(0), "⌘R captured (SAVE ANYWAY): his command wins over rename")
ok(r(isR: true, [], maps: [["shift"]]) == .liveOwn, "plain R with only ⇧R captured: Live's own")
ok(r(end: true, []) == .end, "Return / Escape / Tab: Live's own, typing ends")
ok(r(end: true, ["alt"], maps: [["alt"]]) == .map(0), "⌥Return captured: his command")
ok(r(end: true, [], maps: [["alt"]]) == .end, "⌥Return captured: a plain Return still ends typing and is Live's own")
ok(r(end: true, ["alt"], maps: [["alt"]], typing: true) == .end, "while typing, even a captured chord on Return ends the typing first")

// ordinary maps
ok(r(["shift"], maps: [[], ["shift"]]) == .map(1), "1 and ⇧1 on one code: ⇧1 finds the second map")
ok(r([], maps: [[], ["shift"]]) == .map(0), "1 and ⇧1 on one code: 1 finds the first")
ok(r(["alt"], maps: [[], ["shift"]]) == .liveOwn, "⌥1 is not his: Live's own")
ok(r(["shift", "cmd"], maps: [["cmd", "shift"]]) == .map(0), "the order of the modifiers does not matter")
ok(r([], fn: true, maps: [[]]) == .map(0), "an arrow or F-key carries the fn flag by itself: still his command")
ok(r([], maps: []) == .liveOwn, "no map, no built-in: Live's own")

// which routes are his command keys (asked of KeyMode)
ok(KeyRoute.isMapped(.map(0)) && KeyRoute.isMapped(.space) && KeyRoute.isMapped(.rename), "maps, Space and ⌘R are his keys")
ok(!KeyRoute.isMapped(.end) && !KeyRoute.isMapped(.liveOwn), "ending keys and other keys are not")

// numbers from AbletonOSC: integers (selected_track, num_tracks, signature_numerator) were read as nil until v37
ok(oscDouble(24) == 24, "an OSC integer (selected_track 24) is read")
ok(oscDouble(7.5) == 7.5, "an OSC float is read")
ok(oscDouble(true) == 1 && oscDouble(false) == 0, "an OSC boolean is read")
ok(oscDouble(Int32(4)) == 4, "an Int32 is read")
ok(oscDouble("x") == nil && oscDouble(nil) == nil, "a string or nothing is not a number")

print(fail == 0 ? "keyroute_test: all \(pass) passed" : "keyroute_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
