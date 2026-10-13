// The Key Stroke table's mind, tested without the app: MIDI_TO_KEYSTROKE tests/test_rules.lua ported.
//   swiftc -o /tmp/ks_test app/MidiKeysRules.swift tests/midikeys_rules_test.swift && /tmp/ks_test
import Foundation

var pass = 0, fail = 0
func eq<T: Equatable>(_ got: T?, _ want: T?, _ what: String) {
    if got == want { pass += 1 } else { fail += 1; print("FAIL  \(what): got \(String(describing: got)), wanted \(String(describing: want))") }
}
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }
func row(_ d: [String: Any]) -> KSRow { KSRules.clean(d).0! }
func keys(_ a: [KSRules.Act]) -> [String] { a.compactMap { if case .key(let k, _, _) = $0 { return k }; return nil } }
func pct(_ a: [KSRules.Act]) -> Int? { for x in a { if case .volume(let p, _) = x { return p } }; return nil }

@main struct T { static func main() {
    eq(KSRules.cc(13), 13, "a CC number"); eq(KSRules.cc("13"), 13, "a CC typed into the box")
    eq(KSRules.cc(128), nil, "128 is not a CC"); eq(KSRules.cc(-1), nil, "-1 is not a CC"); eq(KSRules.cc("x"), nil, "a word is not a CC")
    eq(KSRules.value(""), nil, "empty = any"); eq(KSRules.value("any"), nil, "any"); eq(KSRules.value("*"), nil, "star")
    eq(KSRules.value(0), 0, "zero is a value"); eq(KSRules.value(127), 127, "127"); eq(KSRules.value(200), nil, "200 is not a value")

    let r = row(["id": 1, "cc": 13, "value": 127, "kind": "key", "key": "O", "mods": ["shift"]])
    eq(r.cc, 13, "keeps its CC"); eq(r.value, 127, "keeps its value"); eq(r.key, "o", "key kept as Hammerspoon spells it")
    eq(r.mods.first, "shift", "modifier kept"); eq(r.on, true, "a new row is on"); eq(KSRules.target(r), "\u{21E7}O", "chord")
    let (bad, why) = KSRules.clean(["cc": 900, "kind": "key", "key": "a"])
    ok(bad == nil, "CC out of range refused"); ok(why.contains("0 to 127"), "and says why")
    let waiting = row(["id": 2, "cc": 20, "kind": "key"])
    eq(waiting.key, nil, "a row with no key yet is kept"); eq(KSRules.matches(waiting, 20, 64, "cc"), false, "but never fires")

    let rows = [row(["id": 1, "cc": 13, "value": 127, "kind": "key", "key": "o", "mods": ["shift"]]),
                row(["id": 2, "cc": 13, "value": 1, "kind": "key", "key": "i"]),
                row(["id": 3, "cc": 21, "value": "any", "kind": "key", "key": "space"]),
                row(["id": 4, "cc": 7, "value": 90, "kind": "volume"]),
                row(["id": 5, "cc": 30, "value": 64, "kind": "key", "key": "a", "on": false])]
    eq(keys(KSRules.fire(rows, 13, 127, "cc")), ["o"], "one row on CC 13 = 127")
    eq(keys(KSRules.fire(rows, 13, 1, "cc")), ["i"], "the same CC at another value")
    eq(KSRules.fire(rows, 13, 64, "cc").count, 0, "a value nothing asked for")
    eq(keys(KSRules.fire(rows, 21, 0, "cc")), ["space"], "any-value row at 0"); eq(keys(KSRules.fire(rows, 21, 127, "cc")), ["space"], "and at 127")
    eq(KSRules.fire(rows, 30, 64, "cc").count, 0, "a row ticked off"); eq(KSRules.fire(rows, 99, 64, "cc").count, 0, "a CC in no row")
    eq(rows[3].value, nil, "a volume row takes every value"); eq(KSRules.valueText(rows[3]), "0-127", "and says so")
    eq(pct(KSRules.fire(rows, 7, 0, "cc")), 0, "0 is silence"); eq(pct(KSRules.fire(rows, 7, 127, "cc")), 100, "127 is full")
    eq(pct(KSRules.fire(rows, 7, 64, "cc")), 50, "the middle is half"); eq(KSRules.percent(90), 71, "90 of 127 is 71 %")
    eq(KSRules.target(rows[3]), "System volume", "the special's name")
    let c = KSRules.clashes([row(["id": 1, "cc": 13, "value": 127, "kind": "key", "key": "o"]),
                             row(["id": 2, "cc": 13, "value": 127, "kind": "key", "key": "p"]),
                             row(["id": 3, "cc": 14, "value": 127, "kind": "key", "key": "q"])])
    ok(c.contains(1) && c.contains(2), "two rows on one message clash"); ok(!c.contains(3), "a row of its own does not")
    eq(KSRules.nextId([KSRow(id: 1, cc: 0), KSRow(id: 7, cc: 0), KSRow(id: 3, cc: 0)]), 8, "next id")

    // notes (26.9.2026)
    let notes = [row(["id": 1, "cc": 60, "type": "note", "kind": "key", "key": "j"]), row(["id": 2, "cc": 60, "kind": "key", "key": "c"])]
    eq(keys(KSRules.fire(notes, 60, 100, "note")), ["j"], "a note fires only note rows")
    eq(keys(KSRules.fire(notes, 60, 100, "cc")), ["c"], "CC 60 is another button")
    eq(KSRules.fire(notes, 60, 0, "note").count, 0, "a note's release fires nothing")
    eq(KSRules.parseMidi("N 60").map { "\($0.0) \($0.1)" }, "note 60", "N 60"); eq(KSRules.parseMidi("cc13").map { "\($0.0) \($0.1)" }, "cc 13", "cc13")
    eq(KSRules.midiText(notes[0]), "N 60", "the MIDI column")
    // his own table, as the file has it
    if let d = try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.config/midi-to-keystroke.json"))) as? [String: Any] {
        let mine = ((d["rows"] as? [[String: Any]]) ?? []).compactMap { KSRules.clean($0).0 }
        eq(mine.count, ((d["rows"] as? [Any]) ?? []).count, "every row of his file is read")
        for m in mine { let back = KSRules.clean(m.dict).0; eq(back, m, "row \(m.id) survives a round trip to the file") }
    }
    print("\(pass) passed, \(fail) failed"); exit(fail == 0 ? 0 : 1)
} }
