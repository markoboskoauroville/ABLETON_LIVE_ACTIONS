# TAKEOVER

- `app/Common.swift` (shared: words, JSONFile, Chord, HotKeys), `app/Module.swift` (the LiveModule protocol, MODULES), `app/Main.swift` (Umbrella: status item, menu, window), one file family per module (`A1*.swift`, `Mackie*.swift`, `MidiKeys*.swift`).
- A new module: a class implementing LiveModule, added to the list in Umbrella.init.

**25.10.2026, v5.** Marko: "It's cutting the text." The window was `.frame(width: 640)` with `.contentSize`; the row of
marker and loop keys was wider, so SwiftUI widened and centred the whole page and every line lost both ends. Now: resizable
(min 640 × 480, first 820 × 820), the page in a GeometryReader at exactly the window's width less 2 × 24 and clipped, texts
wrap; the keys in two rows. Checked by a window screenshot. Restarting the app restarts the OSC router on 11002 (the CQ
MixPad Tutorial reconnected by itself).

**27.10.2026, v6–v9: MACROS.** `app/Macros.swift` lists the macros (name, script, about); RUN runs
`helpers/<script>` with the Mantra Python, CHECK with `--dry`, each printed line shown, the last is the verdict. The first
macro, `helpers/macro_cq12t.py`: (1) `helpers/mixpad.py` opens CQ MixPad on the MacBook Pro screen (Rectangle), chooses
the CQ12T in "Choose Unit", clicks Connect, CONFIG › USB/SD (an icon tab, clicked at its place in the window) › Stream
Mode Multitrack; CoreAudio must then show 16 × 16; (2) Live's devices from Log.txt and Ext. In/Out mono 1…N from
AbletonOSC, else Live's Settings opened and Marko asked by voice, polled 3 min; (3) track N → Ext. Out N / Ext. In N,
each selected alone, the whole set read back. OSC goes through the router on 11002 when the app holds 11001.
The window is in tabs since v8 (Umbrella.tab, kept in live-actions.json), MACROS first.
