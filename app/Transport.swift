// THE SPACE DECISION: state in, action out, nothing else (no AppKit, no OSC), so GitHub's workflow tests it without Live
// (tests/transport_test.swift). Marko, 22.11.2026: stopped, he clicks the waveform to move the insert point, presses play,
// and the song starts from the OLD place. The cause was that every Space became Shift+Space (Continue Playback, which
// starts at the position where Live last stopped) even when Live was stopped. His own measurement of 21.9.2026 is the
// rule: the insert point is the master. Playing: Space stops and the insert point is planted on the playhead (works,
// keep it). Stopped: plain Play, which starts at the insert point wherever it is NOW; nothing is remembered, nothing is
// planted afterwards.
import Foundation

enum SpaceAction: Equatable {
    case stopAndPlant        // Shift+Space (Continue Playback stops a running Live), then Cmd+Shift+Space (insert point to the playhead)
    case stop                // the same without the planting (the "follow" switch is off)
    case playFromInsertPoint // a plain Space: Live starts at the insert point, wherever he put it
    case jumpToLoopStart     // v31: NEVER returned. Space does not move the playhead to a loop's start; the workflow mutates decide to return it and the tests must fail
    case continuePlayback    // the v20 behaviour when stopped (the bug): decide never returns it; the workflow mutates decide to return it and the test must fail
    case plainSpace          // Live's own answer unknown: a plain Space toggles whichever way Live is, and nothing is planted
}

enum Transport {
    /// A reading of "is Live playing" older than this is not trusted (the sampler asks once a second, twice a second
    /// while playing); the caller then asks Live afresh before deciding.
    static let freshFor = 1.5

    /// `playing`: Live's own answer (true/false), or nil when there is none that is fresh.
    /// `userMovedWhilePlaying` (v23, Marko 22.11.2026: while Live plays he clicks on the waveform and the assistant did not
    /// register the new place): true = he clicked in Live's arrangement since this play began, false = he did not, nil =
    /// not known (the key tap was off for a while). His hand outranks the assistant: the insert point is planted on the
    /// playhead only when he is KNOWN not to have moved it; moved or unknown, the stop leaves it where it is.
    /// `loop` is accepted only so that it can be seen to be IGNORED: v31 (22.11.2026, Marko: "I click somewhere in the last song ... and
    /// I place space bar and it plays from the previous song"). Until v30 a stopped Space jumped the playhead to an active loop's start
    /// whenever the insert point lay outside the loop, the opposite of his rule: the insert point is the master. Stopped + Space is a
    /// plain play from the insert point, ALWAYS: loop on or off, markers ticked or not, the insert point anywhere.
    static func decide(playing: Bool?, follow: Bool, userMovedWhilePlaying: Bool?, loop: LoopContext? = nil) -> SpaceAction {
        guard let playing = playing else { return .plainSpace }
        if playing { return follow && userMovedWhilePlaying == false ? .stopAndPlant : .stop }
        return .playFromInsertPoint
    }
    struct LoopContext { var on: Bool; var tickedMarkers: Bool; var start: Double?; var end: Double?; var insertPoint: Double? }

    /// The cached reading is used only while it is fresh; otherwise nil (so the caller asks, or falls back to .plainSpace).
    static func trusted(_ cached: Bool, readAt: Double, now: Double) -> Bool? {
        now - readAt <= freshFor ? cached : nil
    }

    /// Did he move the insert point by hand since this play began? A click in the arrangement after the play began and
    /// not before; unknown (nil) when the key tap was switched off by macOS at some time since the play began.
    static func userMoved(lastClickAt: Double, playStartAt: Double, tapGapAt: Double) -> Bool? {
        if tapGapAt > playStartAt { return nil }
        return lastClickAt > playStartAt
    }

    /// Does a mouse-down count as "he moved the insert point"? v24 (22.11.2026), from a read-only Accessibility probe of Live 12's
    /// window (1600 hit-tests, no clicks): the arrangement's timeline canvas answers as an AXStaticText ("Clip/Device Drop
    /// Area ...") whose parent chain holds the AXGroup titled "Arrangement". The track headers (AXRow / AXOutline "Track
    /// Headers"), the mixer strip beside them (AXSlider, AXPopUpButton, AXCheckBox), the loop brace, the transport bar and the
    /// status bar (plain AXGroups), and the Device Detail group answer as something else. So a click counts only when: a left
    /// click, Live in front, inside Live's window, the element under the pointer is an AXStaticText, and "Arrangement" is among
    /// its ancestors and "Track Headers", "Loop Brace" and "Device Detail" are not. `ancestors` are the titles or descriptions
    /// of the parent chain, nearest first.
    static func clickCounts(left: Bool, liveFront: Bool, insideLiveWindow: Bool, role: String?, ancestors: [String]) -> Bool {
        guard left, liveFront, insideLiveWindow, role == "AXStaticText" else { return false }
        guard ancestors.contains("Arrangement") else { return false }
        return !ancestors.contains("Track Headers") && !ancestors.contains("Loop Brace") && !ancestors.contains("Device Detail")
    }
}
