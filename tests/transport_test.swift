// The Space decision tested without Live (the workflow copies this to main.swift beside app/Transport.swift):
//   swiftc -o /tmp/transport_test app/Transport.swift tests/transport_test.swift && /tmp/transport_test   (a folder with it as main.swift)
// A small model of Live's transport stands in for Live (Live's manual: Space starts at the insert point, Shift+Space is
// Continue Playback from the stop position, Cmd+Shift+Space moves the insert point to the playhead). The model is not
// Live: the real proof of the bug is Marko's hand.
import Foundation

var pass = 0, fail = 0
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }

struct FakeLive {
    var playing = false, playhead = 0.0, insert = 0.0, stopPos = 0.0
    mutating func space() { if playing { stop() } else { playing = true; playhead = insert } }              // plain Space
    mutating func shiftSpace() { if playing { stop() } else { playing = true; playhead = stopPos } }        // Continue Playback
    mutating func plant() { insert = playhead }                                                              // Cmd+Shift+Space
    mutating func stop() { playing = false; stopPos = playhead }
    mutating func click(_ beats: Double) { insert = beats }                                                  // he clicks the waveform
    mutating func run(_ beats: Double) { if playing { playhead += beats } }
    // what the app does for a Space press: the decision, then the keys
    mutating func press(_ reading: Bool?, loop: Transport.LoopContext? = nil, follow: Bool = true, moved: Bool? = false) {
        switch Transport.decide(playing: reading, follow: follow, userMovedWhilePlaying: moved, loop: loop) {
        case .stopAndPlant: shiftSpace(); plant()
        case .stop: shiftSpace()
        case .playFromInsertPoint: space()
        case .jumpToLoopStart: playhead = loop?.start ?? 0; stopPos = playhead; shiftSpace()      // the old, wrong behaviour: never returned
        case .continuePlayback: shiftSpace()
        case .plainSpace: space()
        }
    }
}

// (a) THE PIN: playing, Stop: the insert point jumps to where the playhead stopped
do {
    var l = FakeLive(); l.insert = 10; l.playing = true; l.playhead = 10; l.run(32)
    l.press(true)
    ok(!l.playing, "(a) playing + Space stops")
    ok(l.insert == 42 && l.stopPos == 42, "(a) the insert point is planted on the playhead (42), got \(l.insert)")
    ok(Transport.decide(playing: true, follow: true, userMovedWhilePlaying: false) == .stopAndPlant, "(a) decide: playing -> stopAndPlant")
    ok(Transport.decide(playing: true, follow: true, userMovedWhilePlaying: false) == .stopAndPlant, "(a) decide: playing, loop irrelevant")
    ok(Transport.decide(playing: true, follow: false, userMovedWhilePlaying: false) == .stop, "(a) follow off: stop without planting")
}
// stopped + play, insert point untouched: starts where it stopped
do {
    var l = FakeLive(); l.insert = 42; l.stopPos = 42
    l.press(false)
    ok(l.playing && l.playhead == 42, "stopped, untouched: play from 42, got \(l.playhead)")
}
// (b) THE BUG: stopped, he clicks the waveform elsewhere, then play: from the NEW insert point
do {
    var l = FakeLive(); l.insert = 10; l.playing = true; l.playhead = 10; l.run(32)
    l.press(true)                       // stop: insert 42
    l.click(120)                        // he moves the insert point
    l.press(false)                      // play
    ok(l.playing && l.playhead == 120, "(b) stopped, insert point moved to 120, play starts at 120, got \(l.playhead)")
    var old = l; old.playing = false; old.playhead = 0; old.shiftSpace()
    ok(old.playhead == 42, "(b) the model reproduces the old bug: Continue Playback starts at the old 42")
}
// stop followed quickly by a user move, then play (the reading is still "playing" and stale)
do {
    var l = FakeLive(); l.insert = 0; l.playing = true; l.playhead = 0; l.run(16)
    l.press(true); l.click(77)
    let stale = Transport.trusted(true, readAt: 100.0, now: 100.0 + 2.0)   // the cached "playing" is 2 s old
    ok(stale == nil, "stale reading: not trusted after \(Transport.freshFor) s")
    l.press(stale)                      // unknown -> plain Space
    ok(l.playing && l.playhead == 77, "stop, quick user move, stale reading, play: starts at 77, got \(l.playhead)")
    ok(Transport.decide(playing: nil, follow: true, userMovedWhilePlaying: false) == .plainSpace, "unknown reading: plain Space even with a loop")
    ok(Transport.trusted(false, readAt: 100.0, now: 100.5) == false, "fresh reading is kept")
}
// stale reading that says "playing" while Live is in fact stopped and the insert point was moved: never Continue Playback
do {
    var l = FakeLive(); l.insert = 5; l.stopPos = 5; l.click(60)
    l.press(Transport.trusted(true, readAt: 0, now: 10))
    ok(l.playhead == 60, "stale 'playing' on a stopped Live: still starts at the insert point 60, got \(l.playhead)")
}
// v31 (22.11.2026): Space never moves the playhead to a loop: stopped + Space = a plain play from the insert point, ALWAYS
do {
    var n = 0
    for loopOn in [false, true] { for ticked in [false, true] {
        for minutes in [0.5, 60.0] {                                  // 0:30 and 60 minutes into the timeline, at 120 BPM
            let beatsPerMin = 120.0, loopStart = 17.8 * 60 * beatsPerMin / 60, loopEnd = loopStart + 32
            for ip in [10.0, loopStart - 100, loopStart, loopStart + 8, loopEnd + 1, minutes * beatsPerMin, minutes * beatsPerMin + 5000] {   // before, inside, after the loop, far in the timeline
                let ctx = Transport.LoopContext(on: loopOn, tickedMarkers: ticked, start: loopStart, end: loopEnd, insertPoint: ip)
                let a = Transport.decide(playing: false, follow: true, userMovedWhilePlaying: false, loop: ctx)
                ok(a == .playFromInsertPoint, "stopped + Space, loop \(loopOn), ticked \(ticked), insert point \(ip): a plain play from the insert point, nothing else, got \(a)")
                var l = FakeLive(); l.insert = ip; l.stopPos = loopStart; l.playhead = loopStart
                l.press(false, loop: ctx)
                ok(l.playing && l.playhead == ip, "the model: it starts at the insert point \(ip), not at the loop's start, got \(l.playhead)")
                n += 1
            }
        }
    } }
    ok(n == 56, "every combination was tried (\(n))")
    let ctx = Transport.LoopContext(on: true, tickedMarkers: true, start: 1, end: 9, insertPoint: 500)
    ok(Transport.decide(playing: nil, follow: true, userMovedWhilePlaying: false, loop: ctx) == .plainSpace, "unknown reading: a plain Space, the loop ignored")
    ok(Transport.decide(playing: true, follow: true, userMovedWhilePlaying: false, loop: ctx) == .stopAndPlant, "playing: stop and plant, the loop ignored")
}
// ---- v23: he clicks on the waveform WHILE Live plays (22.11.2026) ----
// the decision table
do {
    func d(_ p: Bool?, _ follow: Bool, _ moved: Bool?) -> SpaceAction { Transport.decide(playing: p, follow: follow, userMovedWhilePlaying: moved) }
    ok(d(true, true, false) == .stopAndPlant, "table: playing, not moved -> stopAndPlant (his 'works perfectly')")
    ok(d(true, true, true) == .stop, "table: playing, moved -> stop only, nothing planted")
    ok(d(true, true, nil) == .stop, "table: playing, unknown -> stop only (his chosen place is never lost)")
    ok(d(true, false, false) == .stop, "table: playing, follow off -> stop only")
    ok(d(false, true, true) == .playFromInsertPoint, "table: stopped -> plain play, whatever the flag")
    ok(d(false, true, false) == .playFromInsertPoint, "table: stopped, flag false -> plain play")
    ok(d(false, true, nil) == .playFromInsertPoint, "table: stopped, flag unknown -> plain play")
}
// click during play, then stop, then play: starts at the click
do {
    var l = FakeLive(); l.insert = 10; l.playing = true; l.playhead = 10; l.run(32)
    l.click(90)                                          // he clicks while it plays: Live keeps playing, the insert point is 90
    l.run(8)
    l.press(true, moved: true)                           // Space: stop only
    ok(!l.playing && l.insert == 90, "click during play, stop: the insert point is still his click 90, got \(l.insert)")
    l.press(false)
    ok(l.playing && l.playhead == 90, "...then play starts at the click 90, got \(l.playhead)")
}
// two clicks during play: the last wins
do {
    var l = FakeLive(); l.insert = 0; l.playing = true; l.playhead = 0; l.run(20)
    l.click(50); l.run(4); l.click(70); l.run(4)
    l.press(true, moved: true); l.press(false)
    ok(l.playhead == 70, "two clicks: the last (70) wins, got \(l.playhead)")
}
// click during play, playback runs past the click, stop: still the click
do {
    var l = FakeLive(); l.insert = 0; l.playing = true; l.playhead = 0; l.run(8)
    l.click(12); l.run(100)
    l.press(true, moved: true)
    ok(l.insert == 12 && l.playhead == 108, "playing past the click: stop leaves the insert point at 12, got \(l.insert)")
    l.press(false)
    ok(l.playhead == 12, "play starts at 12, got \(l.playhead)")
}
// no click: a stop plants (unchanged), and the next play starts where it stopped
do {
    var l = FakeLive(); l.insert = 3; l.playing = true; l.playhead = 3; l.run(40)
    l.press(true, moved: false); l.press(false)
    ok(l.playhead == 43, "no click: stop plants at 43 and play starts there, got \(l.playhead)")
}
// which clicks count (after the AX probe of Live 12, 22.11.2026)
do {
    let c = Transport.clickCounts
    let canvas = ["Arrangement", ""], mixerSlider = ["1-01 Song", "Arrangement"]
    ok(c(true, true, true, "AXStaticText", canvas), "the arrangement canvas counts")
    ok(!c(true, false, true, "AXStaticText", canvas), "a click while another app is in front does not count")
    ok(!c(true, true, false, "AXStaticText", canvas), "a click outside Live's window does not count")
    ok(!c(false, true, true, "AXStaticText", canvas), "a right or other button does not count")
    ok(!c(true, true, true, "AXSlider", mixerSlider), "the mixer's Track Volume slider does not count")
    ok(!c(true, true, true, "AXPopUpButton", mixerSlider), "a track's popup does not count")
    ok(!c(true, true, true, "AXCheckBox", mixerSlider), "Solo or Activator does not count")
    ok(!c(true, true, true, "AXGroup", ["ETHNO_ORCHESTRA", "Live"]), "the transport bar (a plain group) does not count")
    ok(!c(true, true, true, "AXGroup", ["Status", "ETHNO_ORCHESTRA"]), "the status bar does not count")
    ok(!c(true, true, true, "AXGroup", ["Device Detail", ""]), "Device Detail does not count")
    ok(!c(true, true, true, "AXStaticText", ["Track Headers", "Arrangement"]), "a track header's name does not count")
    ok(!c(true, true, true, "AXGroup", ["Loop Brace", "Arrangement"]), "the loop brace does not count")
    ok(!c(true, true, true, "AXStaticText", ["", "ETHNO_ORCHESTRA", "Live"]), "a text outside the arrangement does not count")
    ok(!c(true, true, true, nil, canvas), "no role: not counted (the log shows it; the rule is the probe's)")
}
// when the click is read as 'since this play began'
do {
    ok(Transport.userMoved(lastClickAt: 105, playStartAt: 100, tapGapAt: 0) == true, "a click after the play began: moved")
    ok(Transport.userMoved(lastClickAt: 95, playStartAt: 100, tapGapAt: 0) == false, "a click before the play began: not moved")
    ok(Transport.userMoved(lastClickAt: 0, playStartAt: 100, tapGapAt: 0) == false, "no click at all: not moved")
    ok(Transport.userMoved(lastClickAt: 105, playStartAt: 100, tapGapAt: 102) == nil, "the tap was off since the play began: unknown")
    ok(Transport.userMoved(lastClickAt: 0, playStartAt: 100, tapGapAt: 50) == false, "a tap gap before the play began does not matter")
}
print(fail == 0 ? "transport_test: all \(pass) passed" : "transport_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
