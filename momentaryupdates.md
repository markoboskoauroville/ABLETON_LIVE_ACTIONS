# Ableton Live Actions: momentary updates

Every request from Marko, word for word, before any code. Each item has a Status line.

## 13.10.2026: everything Ableton under one roof

> now you can make a replacement for Luastar with Swiftstar, and then under that umbrella you do what's left to do. Same principle as Davinci Resolve: we need to create Ableton Live actions. Right now everything what's related to Ableton Live can be under the same roof

Under it (inventory 13.10.2026):
- Ableton Assistant A1 (MANTRA_STAR apps/a1.lua + a1_blob, a1_e16blob, a1_osc, a1_pick .lua; a1_ears.py, a1_transients.py; page :8849).
- MIDI to MK Control (engine MANTRA_MACKIE mackie.lua + mcu, live, rules, blob, page .lua; window MANTRA_CONTROLS; :8855).
- MIDI to Key Stroke (engine MIDI_TO_KEYSTROKE midikeys.lua + rules, e16led, volume, midiwatch, tablekeep, page .lua; window MANTRA_CONTROLS; :8853).
- Later: ABLETON_COMMAND_GUIDE, ABLETON_TEACHER (out of the star since 26.9.2026).

**Status:** saved; the shell first, then the three engines ported to Swift modules.
**Status A1 (13.10.2026):** ported to Swift (app/A1*.swift, helpers/a1_transients.py, commit 21f653b): every key override
with its tick, Space continues, the insert point beside the set, open the last set, markers / loop / transients / tracks,
the time blob and the E16 blob, Live's whole menu for ADD A MAPPING, the same ~/.config/ableton-assistant-a1.json. The
AbletonOSC wire is native (tested against a stand-in AbletonOSC: tempo, cue points, the 32-bit rounding, timeouts). The
window section is drawn and checked. Not yet tried with Live and his hands. The module is OFF in live-actions.json until
Marko turns the Lua A1 off in the star and the module on; it needs Accessibility for "Ableton Live Actions (Mantra)".

- **MIDI to Key Stroke** (13.10.2026): ported to Swift as the MidiKeys module (app/MidiKeys.swift, MidiKeysEngine.swift,
  MidiKeysRules.swift; helpers/midikeys_e16colour.py; tests/midikeys_rules_test.swift, 49 checks pass). CoreMIDI on every
  source, DETECT / LEARN / key capture, KEY and VOLUME rows (the Mac's own blob), the E16 rings and colours, UNDO / REDO /
  DELETE, the activity LEDs, the incoming monitor, the same ~/.config/midi-to-keystroke.json. No server: :8853 and the
  MANTRA_CONTROLS window are replaced by the module's section. Verified in a dry run (listens, presses nothing).
  **Status:** built, OFF until Marko switches it over (the Lua engine still runs).
- **MIDI to MK Control** (13.10.2026): ported to Swift as the Mackie module (app/Mackie.swift, MackieMCU.swift,
  MackieRules.swift, MackieIO.swift, MackieBlob.swift, MackieEngine.swift; MK-prefixed). The 121 commands and the rule book
  pass all 235 checks of MANTRA_MACKIE's own Lua tests; his ~/.config/midi-to-mk.json reads back unchanged. CoreMIDI on
  every source, out to IAC Driver / Bus 1, the paced 20 ms queue, spins, PLAY / STOP from the insert point (Live's Log.txt
  + AbletonOSC questions), HOLD rows, the Mac's volume keys and blob, the E16 rings and colours, the command blob, DETECT /
  LEARN / TRY, UNDO / REDO / DELETE, the activity LEDs, the incoming monitor. No server: :8855 and the MANTRA_CONTROLS
  window are replaced by the module's section. Verified: rendered from his file, MIDI opened read-only, nothing sent.
  **Status:** built, OFF until Marko switches it over (the Lua engine still runs).

