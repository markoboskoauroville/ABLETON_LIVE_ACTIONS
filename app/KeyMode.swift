// COMMAND MODE OR TYPING? The decision for each of his command keys, as a pure function (Foundation only, tested by the
// workflow without Live: tests/keymode_test.swift). Marko, 22.11.2026: "when I press control space to search some software
// in my computer, I still am not able to type these letters ... When I'm inside the dialogue box, when I enter the names,
// it should be free and I could enter any key. Only when I'm in the command mode, then I have command keys."
//
// His command keys act only in COMMAND mode: Live is in front, the keyboard focus is in Live, it is not a text entry, no
// dialog or other window of Live has the keys, and he is not in Live's rename or search typing. Everything else is TYPING:
// every key is free. When it is not known, the key goes through as typing: a command that does not fire is a small loss, a
// letter he cannot type is the bug he reported.
import Foundation

/// What the system reports about where the keyboard focus is, read at the moment of the key.
struct FocusReading: Equatable {
    var live: Bool? = nil            // does the focused element belong to Live? false = another process holds the keys; nil = not known
    var otherApp: String? = nil      // that other process, for the log
    var role: String? = nil          // Accessibility role of the focused element
    var editable = false             // its value is a settable string (a field Live draws itself)
    var dialog = false               // the focus is in a dialog, a sheet or another window of Live than its main window
}

enum KeyDecision: Equatable {
    case command
    case free(String)                // typing, with the reason
}

enum KeyMode {
    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// frontIsLive: Live is the front application. focus: nil when it could not be read at all.
    /// typingFlag: Live's own rename or search typing, begun by ⌘R or ⌘F and ended by Return, Escape, Tab or a click.
    /// launcherBox: Launcher (Mantra) announced that its search box is open (the surest signal for that case).
    /// isMappedKey: the key with its modifiers is one of his command keys (any other combination is free).
    static func decide(frontIsLive: Bool, focus: FocusReading?, typingFlag: Bool, launcherBox: Bool = false, isMappedKey: Bool) -> KeyDecision {
        if !isMappedKey { return .free("not one of his keys") }
        if !frontIsLive { return .free("Live is not in front") }
        if launcherBox { return .free("the Launcher's box is open") }           // Launcher (Mantra) says so itself (com.mantra.launcher.box)
        guard let focus = focus else { return .free("the focus could not be read") }
        if focus.live == false { return .free("another app holds the keys" + (focus.otherApp.map { " (" + $0 + ")" } ?? "")) }
        if focus.live == nil { return .free("the focus is not known") }
        if typingFlag { return .free("typing began (rename or search)") }
        if focus.dialog { return .free("a dialog or another window has the keys") }
        if let r = focus.role, KeyMode.textRoles.contains(r) { return .free("a text field has the focus (" + r + ")") }
        if focus.editable { return .free("a field that takes text has the focus") }
        return .command
    }
    /// Is the window that holds the focus a dialog (keys free) or part of his work (keys are commands)? Measured in Live 12.4.7,
    /// 28.11.2026: Export Audio/Video is an AXDialog (free, v36 already); Settings is an AXStandardWindow with AXMain true, so v36
    /// took its keys as commands (an h in Settings split a clip): free now, by its title; the set's window and the second window
    /// (title "") are standard windows (commands); a plug-in window is an AXFloatingWindow titled "<device>/<track>": part of his
    /// work, his keys stay commands there (a text role inside it is still free by the role rule).
    static let dialogTitles: Set<String> = ["Settings", "Preferences"]
    static func windowIsDialog(subrole: String?, main: Bool?, title: String?) -> Bool {
        let t = title ?? ""
        if subrole == "AXFloatingWindow" && t.contains("/") { return false }
        if let s = subrole, s != "AXStandardWindow" { return true }
        if dialogTitles.contains(t) { return true }
        if main == false { return true }
        return false
    }
    static func word(_ d: KeyDecision) -> String { d == .command ? "COMMAND" : "TYPING" }
    static func why(_ d: KeyDecision) -> String { if case .free(let w) = d { return w }; return "Live's arrangement has the keys" }
}
