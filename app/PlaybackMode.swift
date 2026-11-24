// THE PLAYBACK MODE, one switch for Live, the Assistant and the phone (Marko, 24.11.2026: "two ways of playback ...
// DAW playback or DaVinci playback ... It's setting Ableton Live actually"). What Live does after ANY stop (Space,
// Live's own buttons, a controller, the phone):
//   return    the DAW way: the playhead goes back to the insert point; every Play starts there again
//   continue  the editing way (DaVinci Resolve): the insert point moves to where playback stopped
// The switch is the file ~/.config/mantra-live-playback-mode; the watcher inside AbletonOSC (its Mantra patch, kept in
// abletonosc/) acts on it with or without this app. A1's old "follow" flag (Space stops, then ⌘⇧Space plants the insert
// point on the playhead) IS this switch now: follow = continue (A1Engine.flag / setFlag).
import SwiftUI

enum PlaybackMode {
    static let path = NSHomeDirectory() + "/.config/mantra-live-playback-mode"

    static func read() -> String {
        let m = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return m == "continue" ? "continue" : "return"
    }

    /// Written here and told to AbletonOSC at once (it also reads the file again at every stop).
    static func write(_ m: String) {
        guard m == "return" || m == "continue" else { return }
        try? FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/.config", withIntermediateDirectories: true)
        try? (m + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        DispatchQueue.global(qos: .userInitiated).async { LiveTurn.tell("/live/mantra/playback_mode", [m]) }
        AppLog.write("playback mode: " + m)
    }
}

/// The two pictograms, the same as on the phone (line style like Live's Follow button): RETURN, an insert point with the
/// arrow curling back to it; CONTINUE, the arrow running on to a second, filled insert point.
struct ModeIcon: View {
    let cont: Bool
    var color: Color = .white
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, sw = w * 0.07
            let amber = AMBER
            func marker(_ x: CGFloat, _ filled: Bool) {
                var l = Path(); l.move(to: CGPoint(x: x, y: h * 0.12)); l.addLine(to: CGPoint(x: x, y: h * 0.92))
                ctx.stroke(l, with: .color(filled ? amber : color), lineWidth: sw)
                var f = Path()
                f.move(to: CGPoint(x: x - w * 0.1, y: h * 0.08)); f.addLine(to: CGPoint(x: x + w * 0.1, y: h * 0.08))
                f.addLine(to: CGPoint(x: x, y: h * 0.26)); f.closeSubpath()
                if filled { ctx.fill(f, with: .color(amber)) } else { ctx.stroke(f, with: .color(color), lineWidth: sw * 0.8) }
            }
            func head(_ x: CGFloat, _ y: CGFloat, right: Bool) {
                let d: CGFloat = right ? -1 : 1
                var p = Path()
                p.move(to: CGPoint(x: x + d * w * 0.13, y: y - h * 0.11)); p.addLine(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + d * w * 0.13, y: y + h * 0.11))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))
            }
            if !cont {
                marker(w * 0.18, true)
                var p = Path()
                p.move(to: CGPoint(x: w * 0.26, y: h * 0.42)); p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.42))
                p.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.58), control: CGPoint(x: w * 0.95, y: h * 0.42))
                p.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.74), control: CGPoint(x: w * 0.95, y: h * 0.74))
                p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.74))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                head(w * 0.28, h * 0.74, right: false)
            } else {
                marker(w * 0.12, false)
                var p = Path(); p.move(to: CGPoint(x: w * 0.2, y: h * 0.58)); p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.58))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                head(w * 0.74, h * 0.58, right: true)
                marker(w * 0.86, true)
            }
        }
        .accessibilityLabel(cont ? "playback mode continue" : "playback mode return")
    }
}

/// The switch as two keys, the lit one is the mode in force (A1's window and the PHONE REMOTE section).
struct ModeSwitch: View {
    @State private var mode = PlaybackMode.read()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 10) {
            ForEach(["return", "continue"], id: \.self) { m in
                let on = mode == m
                ModeIcon(cont: m == "continue", color: on ? .white : GREY)
                    .frame(width: 44, height: 44).padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? AMBER : Color(white: 0.2), lineWidth: on ? 2 : 1))
                    .contentShape(Rectangle())
                    .onTapGesture { PlaybackMode.write(m); mode = m; A1Engine.shared?.objectWillChange.send() }
                    .accessibilityAddTraits(.isButton)
            }
            Small(text: mode == "continue" ? "after a stop the insert point moves to where it stopped (the editing way)"
                                            : "after a stop the playhead goes back to the insert point (the DAW way)")
        }
        .onReceive(timer) { _ in let m = PlaybackMode.read(); if m != mode { mode = m } }
    }
}
