// I AND O AS IN AN EDITING PROGRAM (v28, 22.11.2026), the decision as a pure function (Foundation only, tested by the workflow:
// tests/loopmarks_test.swift). Marko: "I don't have button to press in and out like in editing software, and then the loop
// bracket is jumping to this in and out ... I want to make them like in any editing software ... in English is I o."
//
// I puts the loop brace's start where he is NOW, O puts its end there. Where he is now: while Live plays the playhead at the
// moment of the press, while it is stopped the insert point (the caller reads it; this file only decides).
// The rules, as an editor has them:
//  - I keeps the current OUT, O keeps the current IN.
//  - the new mark wins: an I later than the OUT, or an O earlier than the IN, moves the OTHER end so that the brace keeps its
//    previous length (a bar when there was none), never a negative or empty length; the start never goes below 0.
//  - the first O turns the loop on; I leaves the loop switch as it is (a brace made by I alone stays off until O).
//  - snapping (to the nearest beat or bar) is an option per key, default OFF: the exact position is the default.
import Foundation

struct LoopMarksResult: Equatable {
    var start: Double
    var length: Double
    var loopOn: Bool
    var end: Double { start + length }
}

enum LoopMarks {
    enum Snap: String { case off, beat, bar }

    static func snapped(_ p: Double, _ snap: Snap, beatsPerBar: Double?) -> Double {
        switch snap {
        case .off: return max(0, p)
        case .beat: return max(0, p.rounded())
        case .bar: let b = (beatsPerBar ?? 0) > 0 ? beatsPerBar! : 4; return max(0, (p / b).rounded() * b)
        }
    }

    /// which: "in" or "out". currentIn / currentOut: the brace as it is now (nil when there is none).
    /// loopOn: Live's loop switch as far as known.
    static func decide(position: Double, currentIn: Double?, currentOut: Double?, which: String, snap: Snap, loopOn: Bool?, beatsPerBar: Double?) -> LoopMarksResult {
        let p = snapped(position, snap, beatsPerBar: beatsPerBar)
        let bar = (beatsPerBar ?? 0) > 0 ? beatsPerBar! : 4
        var len = bar
        if let a = currentIn, let b = currentOut, b - a > 0.001 { len = b - a }
        if which == "in" {
            let end: Double
            if let b = currentOut, b > p + 0.001 { end = b } else { end = p + len }
            return LoopMarksResult(start: p, length: end - p, loopOn: loopOn ?? false)
        }
        var start: Double
        if let a = currentIn, a < p - 0.001 { start = a } else { start = max(0, p - len) }
        if p - start < 0.001 { start = 0; return LoopMarksResult(start: 0, length: max(p, len), loopOn: true) }
        return LoopMarksResult(start: start, length: p - start, loopOn: true)
    }

    /// The position at the press: the reading is Live's answer, which was taken between the press and the reply; while the
    /// playhead runs, half of the round trip (in seconds, at the tempo in beats per minute) is taken back. Stopped: no change.
    static func atPress(reading: Double, playing: Bool, roundTripSeconds: Double, tempo: Double?) -> Double {
        guard playing, let t = tempo, t > 0, roundTripSeconds > 0 else { return reading }
        return max(0, reading - (roundTripSeconds / 2) * t / 60)
    }
}
