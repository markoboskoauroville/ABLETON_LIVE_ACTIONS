# Ableton Live Actions (Mantra)

**One app for everything that fits Ableton Live to Marko's hands.** Marko, 13.10.2026: *"Same principle as Davinci
Resolve: we need to create Ableton Live actions. Right now everything what's related to Ableton Live can be under the
same roof."*

`/Applications/Ableton Live Actions (Mantra).app`, signed "Mantra Apps", built by `./build.sh`; the star opens and quits
it. A `LIVE` item in the menu bar reaches every module; the window has a section per module with ON / OFF.

| Module | From | What it does |
|---|---|---|
| ABLETON ASSISTANT A1 | MANTRA_STAR `apps/a1.lua` + `a1_*.lua`, `a1_ears.py`, `a1_transients.py` | Space continues, markers, the loop on transients, the clock blob of the insert point |
| MIDI TO MK CONTROL | MANTRA_MACKIE (`mackie.lua`, `mcu.lua`, `live.lua`, `rules.lua`) | a knob on a MIDI controller becomes a Mackie Control command in Live |
| MIDI TO KEY STROKE | MIDI_TO_KEYSTROKE (`midikeys.lua`, …) | a knob's CC or a key's note becomes a key stroke, or the Mac's volume |

Each module is one Swift file family under `app/` implementing `LiveModule` (`app/Module.swift`); hot keys are armed
only while Live is in front. Python helpers (audio analysis, AbletonOSC) live in `helpers/` and travel inside the app.
Module on/off: `~/.config/live-actions.json`.
