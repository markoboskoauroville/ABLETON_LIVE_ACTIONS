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
    case playIntoLoop        // the playhead is put at the loop's start by OSC, then Shift+Space (Continue Playback) plays from there
    case continuePlayback    // the v20 behaviour when stopped (the bug): decide never returns it; the workflow mutates decide to return it and the test must fail
    case plainSpace          // Live's own answer unknown: a plain Space toggles whichever way Live is, and nothing is planted
}

enum Transport {
    /// A reading of "is Live playing" older than this is not trusted (the sampler asks once a second, twice a second
    /// while playing); the caller then asks Live afresh before deciding.
    static let freshFor = 1.5

    /// `playing`: Live's own answer (true/false), or nil when there is none that is fresh.
    static func decide(playing: Bool?, intoLoop: Bool, follow: Bool) -> SpaceAction {
        guard let playing = playing else { return .plainSpace }
        if playing { return follow ? .stopAndPlant : .stop }
        return intoLoop ? .playIntoLoop : .playFromInsertPoint
    }

    /// The cached reading is used only while it is fresh; otherwise nil (so the caller asks, or falls back to .plainSpace).
    static func trusted(_ cached: Bool, readAt: Double, now: Double) -> Bool? {
        now - readAt <= freshFor ? cached : nil
    }
}
