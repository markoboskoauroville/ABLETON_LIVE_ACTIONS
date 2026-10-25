# TAKEOVER

- `app/Common.swift` (shared: words, JSONFile, Chord, HotKeys), `app/Module.swift` (the LiveModule protocol, MODULES), `app/Main.swift` (Umbrella: status item, menu, window), one file family per module (`A1*.swift`, `Mackie*.swift`, `MidiKeys*.swift`).
- A new module: a class implementing LiveModule, added to the list in Umbrella.init.

**25.10.2026, v5.** Marko: "It's cutting the text." The window was `.frame(width: 640)` with `.contentSize`; the row of
marker and loop keys was wider, so SwiftUI widened and centred the whole page and every line lost both ends. Now: resizable
(min 640 × 480, first 820 × 820), the page in a GeometryReader at exactly the window's width less 2 × 24 and clipped, texts
wrap; the keys in two rows. Checked by a window screenshot. Restarting the app restarts the OSC router on 11002 (the CQ
MixPad Tutorial reconnected by itself).
