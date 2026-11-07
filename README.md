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
| MACROS (v6–v13, 27.10.2026; the first tab since v8) | `app/Macros.swift` + `helpers/macro_*.py` | pre-recorded runs, a name and RUN (CHECK only looks). The first: **Map Channels to Allen & Heath CQ12T**: the CQ on USB in multitrack (16 × 16 in CoreAudio), Live's audio in/out the CQ12T (Log.txt; if not, Live's Settings opened and Marko asked by voice), then the CQ scene "Live Multitrack" recalled (names, inputs 1–10 from USB; stored by itself when missing), then track N → Ext. Out N and Ext. In N for 1–16, each track selected alone and the whole set read back; AUTO runs it when a set opens |
| AUDIO (v19, 7.11.2026) | `app/AudioActions.swift` (the MACROS module, a second list) + `helpers/audio_sync.py` | a new category of actions on audio. The first: **Sync Track 2 to Track 1**: the same music from two recorders, track 1 the master; found by the onset envelope of the whole files (Shazam-like), then measured to the sample every 20 s, audio 2 stretched onto track 1's clock (a dropout becomes a hard cut), and exported: two WAVs of exactly the same length in "<track 1 file> SYNC". RUN also puts the synced audio 2 on a new track at track 1's place and switches the old clip off; CHECK only measures. Without Live: `python3 helpers/audio_sync.py --a A.wav --b B.wav --out DIR` |
| MACROS: Names between Live and the CQ12T (v10) | `helpers/macro_names.py`, `helpers/mixpad.py` | MIXER → LIVE (CQ MixPad CONFIG › INPUTS names → track names) or LIVE → MIXER (track names → each input's Name/Colour, 6 characters); CHECK lists both |

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

## Live's OSC: USE, LET GO (v17, 31.10.2026)

The OSC router on 11002 (v4) is gone. Marko: *"You use it and you let go. Always like this."* No program keeps Live's
answer port 11001: a question takes the shared turn (flock `~/.config/liveosc.lock`), binds 11001, reads its answer and
lets go; orders go straight to 11000. The code: `app/LiveTurn.swift` (copied into every Swift app that talks to Live),
`helpers/liveosc.py` (Python), MANTRA_STAR `a1_ears.py` (Lua through Hammerspoon). `tests/fake_abletonosc.py` stands in
for Live when it is closed. Proven: with this app and A1's ears running, two more programs asked 50 questions each at
once, all 100 answered, nothing on 11001 at rest. Converted the same day: CQ MixPad Tutorial v23, Opening and Closing
v11, OXI v30, the Teacher, the Command Guide, the Santoshi tools; already sharing: Mantra Mackie and Stem Separation
(they never bound it).

## Building (v19, 7.11.2026)

Compiled only by GitHub (MANTRA_MANIFEST compile-on-github.md): `.github/workflows/build.yml` (the manifest's
mac-swift.yml) builds on every push to main and releases `app.zip` as Latest. On the Mac:
`gh release download --repo markoboskoauroville/ABLETON_LIVE_ACTIONS --pattern app.zip -D /tmp/x --clobber`, then
`ditto -x -k /tmp/x/app.zip /Applications` and `codesign --force -s "Mantra Apps"` on the app.
