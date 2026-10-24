# Ableton Live Actions (Mantra)

**One app for everything that fits Ableton Live to Marko's hands.** Marko, 13.10.2026: *"Same principle as Davinci
Resolve: we need to create Ableton Live actions. Right now everything what's related to Ableton Live can be under the
same roof."*

`/Applications/Ableton Live Actions (Mantra).app`, signed "Mantra Apps", built by `./build.sh`; the star opens it. A `LIVE` item in the menu bar reaches every module; the window has a section per module with ON / OFF.

| Module | From | What it does |
|---|---|---|
| ABLETON ASSISTANT A1 | MANTRA_STAR `apps/a1.lua` + `a1_*.lua`, `a1_ears.py`, `a1_transients.py` | Space continues, markers, the loop on transients, the clock blob of the insert point |
| MIDI TO MK CONTROL | MANTRA_MACKIE (`mackie.lua`, `mcu.lua`, `live.lua`, `rules.lua`) | a knob on a MIDI controller becomes a Mackie Control command in Live |
| MIDI TO KEY STROKE | MIDI_TO_KEYSTROKE (`midikeys.lua`, …) | a knob's CC or a key's note becomes a key stroke, or the Mac's volume |

**ON / OFF and ✕ (v3, 19.10.2026).** The first row of the window is ABLETON LIVE ACTIONS ON / OFF, the version, and ✕
at the far upper right (Marko: "In the top of every user interface, there will now be an on/off switch"; "It's far
upper right corner. There is X to close the dialog in every dialog"). Running is ON; OFF stops every module and quits.
✕ (and the title bar's close) closes the window only: the app stays on, and the star's open or Settings… brings it back.
The colour palettes and the `--midikeys-dry` window have the same ✕.

Each module is one Swift file family under `app/` implementing `LiveModule` (`app/Module.swift`); hot keys are armed
only while Live is in front. Python helpers (audio analysis, AbletonOSC) live in `helpers/` and travel inside the app.
Module on/off: `~/.config/live-actions.json`.

**The OSC router (v4, 24.10.2026).** AbletonOSC answers only to UDP 11001, so only one app could ever hear Live. A1's
wire holds 11001 and now also listens on **127.0.0.1:11002**: any other app sends its OSC there (not to 11000), the
router passes it to Live from the 11001 socket, and every answer is given to A1 and copied to every app heard from in
the last two minutes. The window's A1 line says how many apps it serves. The router runs while A1 is on. A client:
bind any port, send to 11002, read the answers for your own addresses (SANTOSHI_CONCERT_MIX `tools/osc.py`).
