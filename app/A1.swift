// ABLETON ASSISTANT A1, the module: the switch, the menu-bar rows and the window section that replaces the Lua's page at
// :8849 (every override with its tick, the markers, the loop, the blobs, Live's whole menu searched for ADD A MAPPING).
// The engine is A1Engine.swift; the settings file is the Lua's own, ~/.config/ableton-assistant-a1.json.
import SwiftUI
import AppKit

final class A1Module: NSObject, LiveModule {
    let id = "a1"
    let title = "ABLETON ASSISTANT A1"
    let about = "Space continues, 1 and 2 zoom, h splits, 7/8/9 the markers, the arrows walk the transients, I and O mark the loop on the next transient's zero, L the loop; the insert point remembered beside the set; the clock blob"
    let defaultOn = true
    let engine = A1Engine()

    func setOn(_ on: Bool) { on ? engine.start() : engine.stop() }
    func liveCame() {}                                  // A1 watches Live's launch itself, from the first moment
    func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }      // every key goes through A1's own filter
    func status() -> String {
        if !engine.on { return "OFF" }
        if !engine.tapOK { return "NEEDS ACCESSIBILITY" }
        let t = engine.knownTitle
        return OSC.isSet(t) ? engine.clock(engine.lastBeats[t!]) : (liveApp() == nil ? "WAITING FOR LIVE" : "ON")
    }
    private var keep: [NSMenuItem] = []
    @objc func mLoop() { engine.toggleLoop() }
    @objc func mOff() { engine.loopOff() }
    @objc func mResume() { engine.say(engine.resumeNow()) }
    @objc func mOpenLast() { engine.say(engine.openLast().1) }
    @objc func mBlob() { engine.setFlag("blob", !engine.flag("blob")) }
    @objc func mE16() { engine.setFlag("midiBlob", !engine.flag("midiBlob")) }
    func menuItems() -> [NSMenuItem] {
        func item(_ t: String, _ s: Selector?, _ on: Bool = false) -> NSMenuItem {
            let i = NSMenuItem(title: t, action: s, keyEquivalent: ""); i.target = self; i.state = on ? .on : .off; if s == nil { i.isEnabled = false }; return i
        }
        keep = [item("  " + engine.loopWords(), nil),
                item("  Loop on, and off again (L)", #selector(mLoop)), item("  Loop off: clear the ticks and I / O", #selector(mOff)),
                item("  The time blob on Live's screen", #selector(mBlob), engine.flag("blob")),
                item("  The E16 blob on the screen", #selector(mE16), engine.flag("midiBlob")),
                item("  Put the insert point back where it was written", #selector(mResume)), item("  Open the last set now", #selector(mOpenLast)),
                item("  " + engine.status, nil)]
        return keep
    }
    func settingsView() -> AnyView { AnyView(A1View(e: engine)) }
}

struct Head: View { let t: String; var body: some View { Text(t).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(AMBER).padding(.top, 6) } }
struct Tick: View {
    let on: Bool; let action: () -> Void
    var body: some View {
        Image(systemName: on ? "checkmark.square.fill" : "square").foregroundColor(on ? AMBER : GREY).font(.system(size: 16)).onTapGesture(perform: action)
    }
}

struct A1View: View {
    @ObservedObject var e: A1Engine
    @State var search = ""
    @State var picked: A1Command?
    @State var key = ""
    @State var mods = ""
    @State var added = ""
    let units = [("minsec", "MIN:SEC"), ("bars", "BARS"), ("beats", "BEATS")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !e.tapOK {
                Text("Accessibility: not allowed yet. System Settings → Privacy & Security → Accessibility → Ableton Live Actions (Mantra) on.")
                    .font(.system(size: 11)).foregroundColor(AMBER).fixedSize(horizontal: false, vertical: true)
            }
            // the clock, the status, the wire
            HStack(alignment: .firstTextBaseline) {
                let t = e.knownTitle
                let (w, saved) = OSC.blob(OSC.isSet(t) ? e.lastBeats[t!] : nil, OSC.isSet(t) ? e.written[t!] : nil, e.tempo, e.str("unit", "minsec"), e.numerator, e.playing)
                Text(w).font(.system(size: 26, weight: .bold, design: .monospaced)).foregroundColor(saved ? .white : Color(nsColor: BLOB_RED))
                Text((t.map { "\"\($0)\"  ·  " } ?? "") + e.status).font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
            }
            Small(text: (liveApp() != nil ? "Live is running · " : "Live is not running · ") + e.wire.words() + (OSC.isSet(e.knownTitle) ? "  ·  file: " + e.setFile(e.knownTitle!) : ""))

            // THE MARKERS AND THE LOOP
            Head(t: "THE MARKERS")
            let (rows, _) = e.markers()
            if rows.isEmpty { Small(text: "no markers in this set yet: press 8 in Live, or SET below, to add one at the playhead") }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rows, id: \.key) { m in
                        HStack(spacing: 8) {
                            Tick(on: m.ticked) { e.tickMarker(m.key, !m.ticked) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.clock).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(m.ticked ? AMBER : .white)
                                Text(m.bars + "  " + m.name).font(.system(size: 10, design: .monospaced)).foregroundColor(GREY)
                                if let r = m.role { Text(r == "start" ? "LOOP START" : "LOOP END").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(AMBER) }
                            }
                        }.padding(8).overlay(RoundedRectangle(cornerRadius: 10).stroke(m.ticked ? AMBER : GREY.opacity(0.4)))
                    }
                }
            }
            // two rows, so the keys fit the narrowest window (one row was wider than 640 and cut the page)
            HStack(spacing: 0) {
                Word(text: "7 BACK", on: false) { e.jumpCue(back: true) }; Word(text: "8 SET", on: false) { e.locator() }; Word(text: "9 ON", on: false) { e.jumpCue(back: false) }
                Spacer()
            }
            HStack(spacing: 0) {
                Word(text: "I", on: false) { e.jumpToTransient("in") }; Word(text: "O", on: false) { e.jumpToTransient("out") }
                Word(text: "L " + (e.liveLoop.on == true ? "ON" : "OFF"), on: e.liveLoop.on == true) { e.toggleLoop() }
                Word(text: "IN HERE", on: false) { e.markLoop("in") }; Word(text: "OUT HERE", on: false) { e.markLoop("out") }
                Word(text: "LOOP OFF", on: false) { e.loopOff() }
            }
            Small(text: e.loopWords())
            HStack(spacing: 0) {
                Label10(text: "THE TRANSIENTS ")
                ForEach(["sensitive", "normal", "strong"], id: \.self) { h in Word(text: h == "sensitive" ? "EVERY HIT" : h == "normal" ? "NORMAL" : "THE STRONG ONES", on: e.str("transient", "normal") == h) { e.setTransient(h) } }
            }
            HStack(spacing: 0) {
                Label10(text: "THE CLOCK ")
                ForEach(units, id: \.0) { u in Word(text: u.1, on: e.str("unit", "minsec") == u.0) { e.setUnit(u.0) } }
                Small(text: "   tempo \(e.tempo.map { String(format: "%.1f", $0) } ?? "?") · \(e.numerator.map { "\(Int($0))" } ?? "?")/4")
            }

            // THE KEYS
            Head(t: "THE KEYS (WHILE LIVE IS IN FRONT)")
            row("space", e.flag("space"), "Space", "⇧Space" + (e.flag("follow") ? ", then ⌘⇧Space" : ""), "Continue Playback; ⇧Space is Live's Play (the jump back)", nil)
            row("follow", e.flag("follow"), "after Space", "⌘⇧Space", "Move Insert Marker To Playhead: the insert point follows every stop", nil)
            ForEach(Array(e.maps.enumerated()), id: \.offset) { i, m in
                let via = (e.flag("viaMenu") || (m["noKey"] as? Bool) == true || m["act"] != nil) ? e.menuOf(m) : nil
                let gets = via.map(a1PathWords) ?? (m["gets"] as? String) ?? a1Chord(mapMods(m, "tomods"), "\(m["to"] ?? "")")
                HStack(alignment: .top, spacing: 8) {
                    Tick(on: (m["off"] as? Bool) != true) { e.setMap(i, (m["off"] as? Bool) == true) }
                    Text(a1Chord(mapMods(m), "\(m["from"] ?? "")")).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.white).frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(gets).font(.system(size: 11, design: .monospaced)).foregroundColor(GREEN)
                        Text((m["does"] as? String) ?? "").font(.system(size: 11)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                        if let was = m["was"] as? String, !was.isEmpty { Text("before: " + was).font(.system(size: 10)).foregroundColor(GREY) }
                    }
                    Spacer()
                    Word(text: "REMOVE", on: false) { e.removeMap(i) }
                }.opacity((m["off"] as? Bool) == true ? 0.45 : 1)
            }

            // WHAT IT DOES BY ITSELF
            Head(t: "WHAT THE ASSISTANT DOES BY ITSELF")
            row("openLast", e.flag("openLast"), "Live starts", "File › Open Recent", "the newest recent set is opened through the menu", nil)
            row("resume", e.flag("resume"), "every second", "AbletonOSC", "the insert point written beside the set, and put back when Live starts", nil)
            row("viaMenu", e.flag("viaMenu"), "a mapped key", "accessibility", "Live's own menu item is pressed; a keystroke only where there is no menu item", nil)
            HStack(spacing: 0) {
                Word(text: "PUT THE INSERT POINT BACK", on: false) { e.say(e.resumeNow()) }
                Word(text: "FORGET THIS SET'S POINT", on: false) { _ = e.forget() }
                Word(text: "OPEN THE LAST SET NOW", on: false) { e.say(e.openLast().1) }
            }
            Small(text: e.lastSeen() + "\n" + e.positionWords() + "\n\(e.countSpace) space bars swapped, \(e.countKeys) keys mapped")

            // ADD A MAPPING
            Head(t: "ADD A MAPPING: LIVE'S WHOLE MENU")
            HStack {
                TextField("search Live's commands (split, locator, mixer …)", text: $search).textFieldStyle(.roundedBorder)
                Word(text: "READ LIVE'S MENU AGAIN", on: false) { e.readMenus(force: true) }
            }
            Small(text: e.commandsWhy)
            let q = search.lowercased().split(separator: " ")
            let list = e.commands.filter { c in q.allSatisfy { c.words.lowercased().contains($0) } }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(list.prefix(200).enumerated()), id: \.offset) { _, c in
                        HStack {
                            Text(c.words).font(.system(size: 11, design: .monospaced)).foregroundColor(picked?.words == c.words ? AMBER : (c.enabled ? .white : GREY))
                            Spacer()
                            Text(c.key.isEmpty ? (c.enabled ? "" : "greyed out now") : c.key).font(.system(size: 11, design: .monospaced)).foregroundColor(GREY)
                        }.padding(.vertical, 3).contentShape(Rectangle()).onTapGesture { picked = c }
                    }
                }
            }.frame(height: 160).background(Color.black.opacity(0.25))
            if let p = picked {
                HStack {
                    Text(p.words).font(.system(size: 11, design: .monospaced)).foregroundColor(AMBER)
                    TextField("the key (i, f5, pad+ …)", text: $key).textFieldStyle(.roundedBorder).frame(width: 130)
                    TextField("with (shift cmd alt ctrl)", text: $mods).textFieldStyle(.roundedBorder).frame(width: 160)
                    Word(text: "ADD", on: false) { added = e.addMap(key: key, mods: mods, command: p) }
                }
            }
            if !added.isEmpty { Small(text: added) }

            // THE TIME BLOB
            Head(t: "THE TIME BLOB")
            HStack(spacing: 0) {
                Word(text: "VISIBLE", on: e.flag("blob")) { e.setFlag("blob", true) }; Word(text: "INVISIBLE", on: !e.flag("blob")) { e.setFlag("blob", false) }
                Word(text: "BACK TO THE BOTTOM MIDDLE", on: false) { e.timeBlob.goHome() }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) { ForEach(A1_FONTS, id: \.key) { f in Word(text: f.name.uppercased(), on: e.str("blobFamily", "menlo") == f.key) { e.setLook(family: f.key) } } }
            }
            HStack(spacing: 0) {
                Word(text: "NORMAL", on: !e.flag("blobBold")) { e.setLook(bold: false) }; Word(text: "BOLD", on: e.flag("blobBold")) { e.setLook(bold: true) }
                ForEach(A1_SIZES, id: \.self) { z in Word(text: "\(z)", on: e.intConf("blobSize", 30) == z) { e.setLook(size: z) } }
            }

            // THE E16 BLOB
            Head(t: "THE E16 BLOB (A MIDI MONITOR)")
            HStack(spacing: 0) {
                Word(text: "VISIBLE", on: e.flag("midiBlob") && e.conf["midiBlob"] as? Bool == true) { e.setFlag("midiBlob", true) }
                Word(text: "INVISIBLE", on: e.conf["midiBlob"] as? Bool != true) { e.setFlag("midiBlob", false) }
                Word(text: "CLEAR", on: false) { e.midiClear() }; Word(text: "FIT", on: false) { e.conf["midiBlobW"] = nil; e.conf["midiBlobH"] = nil; e.save(); e.e16.setSize(nil) }
                Word(text: "TOP RIGHT", on: false) { e.e16.goHome() }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Word(text: "EVERY PORT", on: e.str("midiDevice", "").isEmpty) { e.setMidi(device: "") }
                    ForEach(A1MIDI.sources().map { $0.1 }, id: \.self) { n in Word(text: A1MIDI.portName(n).uppercased(), on: e.str("midiDevice", "") == n) { e.setMidi(device: n) } }
                }
            }
            HStack(spacing: 0) {
                Word(text: "EACH KNOB ITS OWN", on: e.str("midiColour", "knob") == "knob") { e.setMidi(colour: "knob") }
                Word(text: "ALTERNATING", on: e.str("midiColour", "knob") == "alternate") { e.setMidi(colour: "alternate") }
                Small(text: e.midi.sceneName.map { "from " + $0 } ?? (e.midi.sceneWhy ?? ""))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Word(text: "THE NEWEST SCENE", on: e.str("midiScene", "").isEmpty) { e.setMidi(scene: "") }
                    ForEach(e.midi.scenes(), id: \.path) { s in Word(text: s.name.uppercased(), on: e.str("midiScene", "") == s.path) { e.setMidi(scene: s.path) } }
                }
            }
            HStack(spacing: 0) {
                Label10(text: "PAGE ")
                ForEach(1...12, id: \.self) { n in Word(text: "\(n)", on: e.intConf("midiPage", 1) == n) { e.setMidi(page: n) } }
            }
            HStack(spacing: 0) {
                Label10(text: "SIZE ")
                ForEach([11, 13, 16, 20], id: \.self) { z in Word(text: "\(z)", on: e.intConf("midiBlobSize", 13) == z) { e.setMidi(size: z) } }
                Label10(text: "  LINES ")
                ForEach([6, 12, 24, 0], id: \.self) { n in Word(text: n == 0 ? "TO THE BOTTOM" : "\(n)", on: e.intConf("midiLines", 12) == n) { e.setMidi(lines: n) } }
            }
            Text(([A1MIDI.HEAD] + e.midiRecent().prefix(8).map { $0.text }).joined(separator: "\n"))
                .font(.system(size: 10, design: .monospaced)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { e.readMenus() }
    }

    func row(_ what: String, _ on: Bool, _ key: String, _ gets: String, _ does: String, _ was: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Tick(on: on) { e.setFlag(what, !on) }
            Text(key).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.white).frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(gets).font(.system(size: 11, design: .monospaced)).foregroundColor(GREEN)
                Text(does).font(.system(size: 11)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
            }
        }.opacity(on ? 1 : 0.45)
    }
}
