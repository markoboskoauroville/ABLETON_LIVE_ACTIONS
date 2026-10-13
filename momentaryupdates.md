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
- **MIDI to Key Stroke** (13.10.2026): ported to Swift as the MidiKeys module (app/MidiKeys.swift, MidiKeysEngine.swift,
  MidiKeysRules.swift; helpers/midikeys_e16colour.py; tests/midikeys_rules_test.swift, 49 checks pass). CoreMIDI on every
  source, DETECT / LEARN / key capture, KEY and VOLUME rows (the Mac's own blob), the E16 rings and colours, UNDO / REDO /
  DELETE, the activity LEDs, the incoming monitor, the same ~/.config/midi-to-keystroke.json. No server: :8853 and the
  MANTRA_CONTROLS window are replaced by the module's section. Verified in a dry run (listens, presses nothing).
  **Status:** built, OFF until Marko switches it over (the Lua engine still runs).

