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
    mutating func press(_ reading: Bool?, intoLoop: Bool = false, loopStart: Double = 0, follow: Bool = true) {
        switch Transport.decide(playing: reading, intoLoop: intoLoop, follow: follow) {
        case .stopAndPlant: shiftSpace(); plant()
        case .stop: shiftSpace()
        case .playFromInsertPoint: space()
        case .playIntoLoop: playhead = loopStart; stopPos = loopStart; shiftSpace()
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
    ok(Transport.decide(playing: true, intoLoop: false, follow: true) == .stopAndPlant, "(a) decide: playing -> stopAndPlant")
    ok(Transport.decide(playing: true, intoLoop: true, follow: true) == .stopAndPlant, "(a) decide: playing, loop irrelevant")
    ok(Transport.decide(playing: true, intoLoop: false, follow: false) == .stop, "(a) follow off: stop without planting")
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
    ok(Transport.decide(playing: nil, intoLoop: true, follow: true) == .plainSpace, "unknown reading: plain Space even with a loop")
    ok(Transport.trusted(false, readAt: 100.0, now: 100.5) == false, "fresh reading is kept")
}
// stale reading that says "playing" while Live is in fact stopped and the insert point was moved: never Continue Playback
do {
    var l = FakeLive(); l.insert = 5; l.stopPos = 5; l.click(60)
    l.press(Transport.trusted(true, readAt: 0, now: 10))
    ok(l.playhead == 60, "stale 'playing' on a stopped Live: still starts at the insert point 60, got \(l.playhead)")
}
// the loop case is kept: stopped, outside the loop, a loop in force
do {
    var l = FakeLive(); l.insert = 200; l.stopPos = 200
    l.press(false, intoLoop: true, loopStart: 64)
    ok(l.playing && l.playhead == 64, "stopped outside the loop: plays from the loop's start 64, got \(l.playhead)")
    ok(Transport.decide(playing: false, intoLoop: false, follow: true) == .playFromInsertPoint, "decide: stopped, no loop -> playFromInsertPoint")
}
print(fail == 0 ? "transport_test: all \(pass) passed" : "transport_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
