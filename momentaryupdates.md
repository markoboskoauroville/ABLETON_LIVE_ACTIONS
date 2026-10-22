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


## 19.10.2026: ON / OFF at the top of the window

Marko, 19.10.2026: *"When I select any of the apps, the user interface opens up. In the top of every user interface,
there will now be an on/off switch ... If I say on, I close it's on ... When I just switch the check mark, and that's
how I activate it. This is gone. Let's work like this. This is the workflow now."*

And, the same day: *"please unify the position of the close button on every application. It's far upper right corner.
There is X to close the dialog in every dialog, same."*

For Ableton Live Actions (Mantra): the first row of the window is ABLETON LIVE ACTIONS ON / OFF, with ✕ at the far
right of the same row. OFF stops every module and quits; ✕ closes the window only and the app stays on; the star's open
brings the window back. (MANTRA_MANIFEST modules/swift-apps.md, "ON / OFF at the top of every window".)

Status, 19.10.2026: built in v3. First row: ABLETON LIVE ACTIONS, ON (green, lit while it runs), OFF (`NSApp.terminate`;
applicationWillTerminate switches every module off), the version, and ✕ (SF Symbol xmark, grey, 28×28 hit area) at the
far right, which closes the window only. The reopen brings the window back (a new one from the WindowGroup if it was
closed); Settings… in the LIVE menu does the same. The LED colour palettes (MIDI TO MK CONTROL, MIDI TO KEY STROKE)
and the `--midikeys-dry` window carry the same ✕. Checked: built, opened once, screenshot shows the row with v3 and ✕,
quit again (it was not running). Seen in passing, not changed: the module sections below are wider than the 640-pt
window and are cut at both sides (the MIDI TO KEY STROKE table is drawn for 1040 pt). Marko to try OFF and ✕.

## 22.10.2026: a classical piece in Live, played by Pianoverse, looped

> please open Ableton Live application and write a MIDI song, any popular classical piece, as a MIDI file and play it with an iKey multimedia piano. Put it in the loop

> there is no project. You need to create it yourself

**Status:** saved; Bach Prelude in C (BWV 846) as a .mid file and as a clip in Live's Untitled set, IK Multimedia Pianoverse on the track, clip looping.

> everything you do always do in arrangement view. Never do in session view, the second view with the horizontal lines. Always switch to that one. And make my when my application starts switch to that view automatically. Please, I have application in the start menu starting and closing. So for starting Ableton Live, switching to the right view is mandatory

**Status:** saved; the Prelude goes in the Arrangement (clip on the timeline, arrangement loop); the star's Ableton start switches Live to Arrangement View.
