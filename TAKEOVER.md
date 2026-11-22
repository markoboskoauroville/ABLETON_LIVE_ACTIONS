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

**27.10.2026, v11–v12.** AUTO (Macro.auto, `macroAuto` in live-actions.json): the module polls Live's main window
title every 3 s by accessibility; a new title = a set opened → 4 s later `--auto` (MixPad only when the Mac does not see
16 × 16, tracks already right untouched). AUTO cannot see the CQ's input sources without MixPad: after a factory reset
press RUN. v12: RUN sets the CQ's inputs 1–10 to USB (`mixpad.set_input_source`), connect() answers "Connection lost".

**27.10.2026, v13.** The mixer side is a CQ scene: `mixpad.recall_scene` / `store_scene` ("Live Multitrack", HOME ›
SCENES; Recall asks Continue? → OK; Store New in the first empty row, then Rename). RUN recalls it, or sets inputs
1–10 to USB and stores it when missing; macro_names LIVE → MIXER overwrites it. Stream Mode is a system setting, still
read and set apart.

## v18, 31.10.2026: TOP

TOP on the first row between the version and PERMISSIONS / ✕ (UserDefaults "onTop", NSWindow.level .floating). `Word`
(Common.swift) is an Accessibility button; give it `id:` only on the first row (`off`, `top`), never in a module, so a
build's relaunch presses the app's OFF and not a module's. ✕ is `close`, PERMISSIONS `permissions`.


## From the former README (9.11.2026)

# Ableton Live Assistant (Mantra) (until 22.11.2026: Ableton Live Actions (Mantra))

**One app for everything that fits Ableton Live to Marko's hands.** Marko, 13.10.2026: *"Same principle as Davinci
Resolve: we need to create Ableton Live actions. Right now everything what's related to Ableton Live can be under the
same roof."*

`/Applications/Ableton Live Assistant (Mantra).app`, signed "Mantra Apps", built by `./build.sh`; the star opens it. A `LIVE` item in the menu bar reaches every module; the window has a section per module with ON / OFF.

| Module | From | What it does |
|---|---|---|
| ABLETON ASSISTANT A1 | MANTRA_STAR `apps/a1.lua` + `a1_*.lua`, `a1_ears.py`, `a1_transients.py` | Space continues, markers, the loop on transients, the clock blob of the insert point |
| MIDI TO MK CONTROL | MANTRA_MACKIE (`mackie.lua`, `mcu.lua`, `live.lua`, `rules.lua`) | a knob on a MIDI controller becomes a Mackie Control command in Live |
| MIDI TO KEY STROKE | MIDI_TO_KEYSTROKE (`midikeys.lua`, …) | a knob's CC or a key's note becomes a key stroke, or the Mac's volume |
| MACROS (v6–v13, 27.10.2026; the first tab since v8) | `app/Macros.swift` + `helpers/macro_*.py` | pre-recorded runs, a name and RUN (CHECK only looks). The first: **Map Channels to Allen & Heath CQ12T**: the CQ on USB in multitrack (16 × 16 in CoreAudio), Live's audio in/out the CQ12T (Log.txt; if not, Live's Settings opened and Marko asked by voice), then the CQ scene "Live Multitrack" recalled (names, inputs 1–10 from USB; stored by itself when missing), then track N → Ext. Out N and Ext. In N for 1–16, each track selected alone and the whole set read back; AUTO runs it when a set opens |
| AUDIO (v19, 7.11.2026) | `app/AudioActions.swift` (the MACROS module, a second list) + `helpers/audio_sync.py` | a new category of actions on audio. The first: **Sync Track 2 to Track 1**: the same music from two recorders, track 1 the master; found by the onset envelope of the whole files (Shazam-like), then measured to the sample every 20 s, audio 2 stretched onto track 1's clock (a dropout becomes a hard cut), and exported: two WAVs of exactly the same length in "<track 1 file> SYNC". RUN also puts the synced audio 2 on a new track at track 1's place and switches the old clip off; CHECK only measures. Without Live: `python3 helpers/audio_sync.py --a A.wav --b B.wav --out DIR` |
| MACROS: Names between Live and the CQ12T (v10) | `helpers/macro_names.py`, `helpers/mixpad.py` | MIXER → LIVE (CQ MixPad CONFIG › INPUTS names → track names) or LIVE → MIXER (track names → each input's Name/Colour, 6 characters); CHECK lists both |

**ON / OFF and ✕ (v3, 19.10.2026).** The first row of the window is ABLETON LIVE ASSISTANT ON / OFF (ABLETON LIVE ACTIONS until v20), the version, and ✕
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

**13.11.2026, A1 off Hammerspoon.** The star's row `a1` opens this app (A1 tab; STAR_SWIFT rows.json kind app). MANTRA_STAR apps/a1.lua is no longer loaded (the star's LUA_ROWS) and is switched off in the running Hammerspoon; the page :8849 is the A1 tab. Only one program may hold A1's key filter: never run the Lua A1 and this module together.

## State at close, 13.11.2026

13.11.2026: A1 is off Hammerspoon; the star row opens this app.

## Menu-bar hover card and pipes (v21, 16.11.2026)
Marko: "with all my apps on the menu bar, make a comprehensive pop-up menu. When I hover over, I want to see what is it and what is it doing." and "for my apps always make a pipes before and after so I know where one app ends and other begins." `app/HoverCard.swift` is the shared kit file (MANTRA_MANIFEST kits/menubar-hover, rule modules/menubar-hover.md): hovering the item about 0.4 s shows a card with name, what it is, state and live lines; a thin grey pipe stands before and after the visible title. The app supplies its lines in the `HoverCard.attach(...)` closure. Test without a mouse: launch with `--hovercard-shot`. Change the lines in the app; change the module only in the kit.

## v21, 22.11.2026: renamed to Ableton Live Assistant (Mantra), and the insert-point bug

Marko, 22.11.2026 (momentaryupdates.md): rename to Ableton Live Assistant; stopped, he clicks the waveform to move the
insert point and presses play: it starts from the OLD place.

**Renamed:** app bundle, display name, window title, ON / OFF row, menu-bar tooltip and hover card, permission texts,
build.sh, the workflow's APP. **Kept on purpose:** bundle id `community.auroville.abletonliveactions` and the signature
"Mantra Apps" (Accessibility stays granted, UserDefaults stay); the executable `AbletonLiveActions` and the App struct
of that name (SwiftUI saves the window frame under it, `pkill -x` scripts use it); `~/.config/live-actions.json` and
`ableton-assistant-a1.json` (his settings); the repo `ABLETON_LIVE_ACTIONS` and the folder
`~/Developer/ABLETON_LIVE_ACTIONS` (ABLETON_TEACHER, Queen's ableton.py and the SANTOSHI tools import
`~/Developer/ABLETON_LIVE_ACTIONS/helpers/liveosc.py` by that path); the module names (ABLETON ASSISTANT A1 ...).
v20 has no updater, so it cannot find v21: install v21 once from the release; from v21 on the app asks at start
(`app/Updater.swift`, kit mac-updater, repo ABLETON_LIVE_ACTIONS, asset app.zip).

**The bug:** `A1Engine.filter` turned every Space into Shift+Space (Continue Playback) followed by Cmd+Shift+Space. Continue
Playback starts where Live last stopped, so a stopped Live ignored the insert point he had just clicked. Now
`Transport.decide` (`app/Transport.swift`): playing -> Shift+Space stops, then the insert point is planted on the playhead
(unchanged); stopped -> a plain Space (Live starts at the insert point wherever it is now, nothing planted after);
loop case kept (the playhead goes to the loop's start, then Continue Playback). "Is Live playing" is asked of Live afresh
at every Space (0.3 s); no answer: the cached reading only while it is under 1.5 s old; else a plain Space.
Tests: `tests/transport_test.swift`, run by the workflow before the build (a model of Live's transport, not Live).

## v22, 22.11.2026: round 1 corrections (Fable scored v21 7 of 10)

- **One title only:** `enforceOneTitle()` / `watchOneTitle()` (Common.swift) hide the system title in every state (key, resign,
  resize, full screen, minimise, TOP); `tests/pins.sh` guards it.
- **No app ON / OFF** (modules/no-on-off-button.md): the first row has no ON / OFF. The old OFF did nothing but
  `NSApp.terminate` (applicationWillTerminate switches every module off), so nothing is lost: ✕ now quits the app, refused
  with a line in the window while a macro or action runs. The window's red button and the title bar close only the window.
  The per-module ON / OFF and the green dots on the tabs stay (features). There is no login item and no auto-start in the
  app (the AUTO of a macro is per macro: it runs when a set opens, and stops when the app quits). A relaunch quits the app
  by its menu Quit (`macro ax-quit`), no longer by the first row's OFF.
- **Version once** (first row, tap = releases page).
- **MIDI TO MK CONTROL and MIDI TO KEY STROKE tabs are LIVE copies**, not links: the same sources as MANTRA_MIDI_TOOLS (diff
  4 to 16 lines per file), ON in `~/.config/live-actions.json`. Both apps read and write the same files
  `~/.config/midi-to-mk.json` and `midi-to-keystroke.json`, open the same MIDI sources and each installs its own key tap. With both
  running and a module ON in both, one knob would fire twice (two Mackie commands, two keystrokes). Nothing guards it
  (neither app looks for the other). MIDI Tools' own modules are OFF in `~/.config/midi-tools.json` and the app is not
  running today. Nothing was removed (no downgrades); decide later which app keeps them.
- **The app's log:** `~/Library/Logs/Ableton Live Assistant (Mantra)/app.log` (AppLog): start, quit, "[Updater] ..." lines, A1's
  "Space: ..." decisions, refused quits. v21 wrote no file (NSLog only, nothing found in `log show`): the silent-failure finding.
- **Hands:** on 22.11.2026 I edited `~/.config/star-rows.json` (the live copy of STAR_SWIFT rows.json, which the star reloads by
  itself) and removed `/Applications/Ableton Live Actions (Mantra).app` with `rm -rf` of that one bundle, by hand, because the
  rename needed one star row with the new name and no second copy; no Queen route or macro exists for either. `star apps`
  lists the app once, running, and `star open` answers "running".
- **Pins:** `tests/pins.sh` (display name, bundle id, executable, settings file names, App struct, repo of the updater,
  one-title guard, no app OFF, version once) and a workflow step that mutates `Transport.decide` back to Continue Playback and
  requires `transport_test` to FAIL.

## v23, 22.11.2026: his click while Live plays

Marko (momentaryupdates.md, 22.11.2026): while the playhead runs he clicks on the waveform and the assistant does not
register the new place. The v21 fix (stopped: plain Space) was real but it was only the other half: stopped + play.
The case he means: PLAYING, he clicks (the insert point moves, Live plays on), Space: v21 stopped and planted the insert
point on the playhead (Shift+Space, Cmd+Shift+Space) and threw his click away. Now `Transport.decide(..., userMovedWhilePlaying:)`:
plant only when he is known NOT to have clicked since this play began; moved or unknown, stop only. Live gives no reading of
the insert point while playing (AbletonOSC's `current_song_time` is the playhead; the insert point is not among its properties),
so the signal is the mouse-down the key tap already receives (`A1Engine.noteClick`: left button, Live in front, inside Live's
window, not on a control by Accessibility role; `Transport.clickCounts`). After a stop that planted nothing the playhead is
not his insert point: `stopHold` keeps `sample()` from writing the stop position into the file beside the set until he moves
it. Not built: a jump of the playback to the click (the pointer cannot be turned into beats); the log lines
"click in Live while playing: role ..." in ~/Library/Logs/Ableton Live Assistant (Mantra)/app.log show what each click was.
