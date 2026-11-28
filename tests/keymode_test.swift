// The command-or-typing decision tested without Live (the workflow copies this to main.swift beside app/KeyMode.swift).
import Foundation

var pass = 0, fail = 0
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }
let arrangement = FocusReading(live: true, otherApp: nil, role: "AXStaticText", editable: false, dialog: false)
func d(front: Bool = true, _ f: FocusReading?, typing: Bool = false, launcherBox: Bool = false, mapped: Bool = true) -> KeyDecision {
    KeyMode.decide(frontIsLive: front, focus: f, typingFlag: typing, launcherBox: launcherBox, isMappedKey: mapped)
}
// his command mode
ok(d(arrangement) == .command, "Live in front, focus on the arrangement: his keys are commands (1 and 2 zoom)")
// his two cases, by name
ok(d(FocusReading(live: false, otherApp: "Launcher (Mantra)", role: "AXTextField")) != .command, "Control+Space search over Live: letters go through (Launcher's field has the keys while Live stays front)")
ok(d(FocusReading(live: false, otherApp: "Spotlight", role: "AXSearchField")) != .command, "Spotlight over Live: letters go through")
ok(d(FocusReading(live: true, role: "AXTextField")) != .command, "renaming a track in Live: 1 and 2 type digits")
ok(d(FocusReading(live: false, otherApp: "Launcher (Mantra)", role: nil)) != .command, "another app holds the keys whatever its role: free")
// the other places where he types
ok(d(FocusReading(live: true, role: "AXSearchField")) != .command, "the browser's search field: free")
ok(d(FocusReading(live: true, role: "AXTextArea")) != .command, "a text area: free")
ok(d(FocusReading(live: true, role: "AXComboBox")) != .command, "a combo box: free")
ok(d(FocusReading(live: true, role: "AXGroup", editable: true)) != .command, "a field that takes text but has no text role: free")
ok(d(FocusReading(live: true, role: "AXStaticText", dialog: true)) != .command, "a dialog or Save sheet: free")
ok(d(arrangement, typing: true) != .command, "after Cmd+R (clip rename) the keys are free until Return, Escape, Tab or a click")
ok(d(arrangement, launcherBox: true) != .command, "the Launcher announced its box: free whatever the focus reading says")
ok(d(arrangement, launcherBox: false) == .command, "the box closed: commands again")
// when unsure: free
ok(d(nil) != .command, "the focus could not be read: free")
ok(d(FocusReading(live: nil)) != .command, "the focus is not known: free")
// other cases
ok(d(front: false, arrangement) != .command, "another app in front: free")
ok(d(arrangement, mapped: false) != .command, "a combination that is not one of his shortcuts: free")
if case .free(let w) = d(FocusReading(live: false, otherApp: "Launcher (Mantra)")) { ok(w.contains("Launcher (Mantra)"), "the reason names the app") } else { ok(false, "free expected") }
ok(KeyMode.word(.command) == "COMMAND" && KeyMode.word(.free("x")) == "TYPING", "the words COMMAND and TYPING")
// after a stop of typing the keys are commands again
ok(d(arrangement, typing: false) == .command, "typing ended: commands again")
// which window is a dialog (v37, measured in Live 12.4.7 on 28.11.2026)
ok(KeyMode.windowIsDialog(subrole: "AXStandardWindow", main: true, title: "Settings"), "Live's Settings (a standard window, main): a dialog, keys free")
ok(KeyMode.windowIsDialog(subrole: "AXDialog", main: true, title: "Export Audio/Video"), "Export Audio/Video (AXDialog): a dialog")
ok(!KeyMode.windowIsDialog(subrole: "AXStandardWindow", main: true, title: "STRESS TEST 24.11.2026"), "the set's window: commands")
ok(!KeyMode.windowIsDialog(subrole: "AXStandardWindow", main: true, title: ""), "Live's second window: commands")
ok(!KeyMode.windowIsDialog(subrole: "AXFloatingWindow", main: false, title: "FabFilter Pro-Q 3/Strings"), "a plug-in window: part of his work, commands")
ok(KeyMode.windowIsDialog(subrole: "AXFloatingWindow", main: false, title: "Some Panel"), "another floating window: free")
ok(KeyMode.windowIsDialog(subrole: "AXStandardWindow", main: false, title: "Untitled"), "a standard window that is not main: free")
ok(!KeyMode.windowIsDialog(subrole: nil, main: nil, title: nil), "nothing known about the window: not a dialog by this rule")
print(fail == 0 ? "keymode_test: all \(pass) passed" : "keymode_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
