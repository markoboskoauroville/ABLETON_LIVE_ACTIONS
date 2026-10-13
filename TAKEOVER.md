# TAKEOVER

- `app/Common.swift` (shared: words, JSONFile, Chord, HotKeys), `app/Module.swift` (the LiveModule protocol, MODULES), `app/Main.swift` (Umbrella: status item, menu, window), one file family per module (`A1*.swift`, `Mackie*.swift`, `MidiKeys*.swift`).
- A new module: a class implementing LiveModule, added to the list in Umbrella.init.
