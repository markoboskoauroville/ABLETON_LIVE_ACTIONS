// I and O as in an editing program, tested without Live (the workflow copies this to main.swift beside app/LoopMarks.swift).
import Foundation

var pass = 0, fail = 0
func ok(_ c: Bool, _ what: String) { if c { pass += 1 } else { fail += 1; print("FAIL  \(what)") } }
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0005 }
func d(_ p: Double, _ i: Double?, _ o: Double?, _ w: String, snap: LoopMarks.Snap = .off, on: Bool? = false) -> LoopMarksResult {
    LoopMarks.decide(position: p, currentIn: i, currentOut: o, which: w, snap: snap, loopOn: on, beatsPerBar: 4)
}
// I keeps the OUT, O keeps the IN
var r = d(8, 4, 20, "in"); ok(near(r.start, 8) && near(r.end, 20), "I at 8 with 4..20: start 8, the OUT 20 kept")
r = d(14, 4, 20, "out"); ok(near(r.start, 4) && near(r.end, 14), "O at 14 with 4..20: the IN 4 kept, end 14")
// first I, then O
r = d(10, nil, nil, "in"); ok(near(r.start, 10) && near(r.length, 4) && !r.loopOn, "I with no brace: start 10, a bar long, the loop stays off")
r = d(18, 10, 14, "out", on: false); ok(near(r.start, 10) && near(r.end, 18) && r.loopOn, "the first O after an I: 10..18 and the loop turns on")
// the new mark wins
r = d(30, 4, 20, "in"); ok(near(r.start, 30) && near(r.length, 16) && near(r.end, 46), "I later than the OUT: the end moves on, the brace keeps its length 16")
r = d(2, 10, 20, "out"); ok(near(r.end, 2) && r.start >= 0 && r.length > 0.001, "O earlier than the IN: never a negative length")
ok(near(r.start, 0) && near(r.length, 2), "O at 2 with a brace 10 long: the start cannot go below 0, so the brace is 0..2")
r = d(5, 6, 6.0005, "out"); ok(r.length > 0.001 && r.start >= 0, "an empty brace never results")
// I while the loop is on: the loop stays on
r = d(12, 4, 20, "in", on: true); ok(r.loopOn && near(r.start, 12), "I while the loop plays moves the start, the switch is untouched (on)")
r = d(12, 4, 20, "in", on: false); ok(!r.loopOn, "I with the loop off leaves it off")
// two I in a row: the last wins
r = d(6, 4, 20, "in"); r = d(9, r.start, r.end, "in"); ok(near(r.start, 9) && near(r.end, 20), "two I: the last start wins, the OUT is still 20")
// snapping: default off = exact
r = d(7.37, nil, nil, "in", snap: .off); ok(near(r.start, 7.37), "snap OFF: the exact position 7.37")
r = d(7.37, nil, nil, "in", snap: .beat); ok(near(r.start, 7), "snap BEAT: 7")
r = d(7.62, nil, nil, "in", snap: .beat); ok(near(r.start, 8), "snap BEAT: 8")
r = d(9.9, nil, nil, "in", snap: .bar); ok(near(r.start, 8), "snap BAR: 8")
r = d(-0.3, nil, nil, "in"); ok(near(r.start, 0), "the position never goes below 0")
// the press: playing is compensated by half the round trip, stopped is not
ok(near(LoopMarks.atPress(reading: 10, playing: true, roundTripSeconds: 0.1, tempo: 120), 10 - 0.05 * 2), "playing: 50 ms back at 120 BPM is 0.1 beat")
ok(near(LoopMarks.atPress(reading: 10, playing: false, roundTripSeconds: 0.1, tempo: 120), 10), "stopped: the insert point does not move: no compensation")
ok(near(LoopMarks.atPress(reading: 10, playing: true, roundTripSeconds: 0.1, tempo: nil), 10), "no tempo known: the reading as it is")
print(fail == 0 ? "loopmarks_test: all \(pass) passed" : "loopmarks_test: \(fail) FAILED of \(pass + fail)")
exit(fail == 0 ? 0 : 1)
