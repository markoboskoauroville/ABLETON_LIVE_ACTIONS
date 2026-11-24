# TAKEOVER

**THE RULE (Marko, 21.9.2026 and 22.11.2026): Space never moves the playhead or the insert point by itself: stopped = play from the insert point, always.**
(Loop on or off, markers ticked or not, the insert point anywhere. "Play from the loop's start" is a separate command with its own row in CUSTOM SHORTCUTS and no key.)

**Cause of the v21 to v30 bug (found 22.11.2026):** a stopped Space took the `playIntoLoop` branch whenever a loop was ON and the insert point lay outside it (`A1Engine.spaceDecide`, `Transport.decide`): it set the playhead to the loop's start. His I/O keys (v28: the first O turns the loop on) made a far-away loop common, so a click in the last song played from the previous one. It had nothing to do with the length of the timeline.
**The process lesson:** "existing behaviour" is not a reason to keep a branch that contradicts the owner's stated rule. When his rule is written down, every branch that departs from it is listed for him to decide, never kept silently; and a test that encodes behaviour he did not ask for is a liability (the old test "stopped outside the loop: plays from the loop's start" passed while the app did the wrong thing). A new key that changes state (O switching the loop on) must be checked against every command that reads that state.


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

## v24, 22.11.2026: what Live's Accessibility says under the pointer (read-only probe)

Probe: 1600 `AXUIElementCopyElementAtPosition` hit-tests on a 40 x 40 grid over Live 12's main window (set ETHNO_ORCHESTRA,
Arrangement view, browser closed), no clicks, no mouse move, no key. Results (element role, title; parents):
- **Arrangement timeline** (the waveform / clip area, half of all points): AXStaticText "Clip/Device Drop Area ..." under AXGroup
  "Arrangement". Clips and empty space answer the same. This is the only thing a click counts on.
- **Track headers** (names): AXRow / AXOutline "Track Headers". **Mixer strip beside them:** AXSlider "Track Volume" and
  "Track Pan", AXCheckBox "Track Activator" and "Solo/Cue", AXPopUpButton "Input Type / Input Channel / Output Channel",
  AXTextField "Return Track Title Bar", AXGroup per track. **Loop brace / ruler:** AXGroup "Loop Brace". **Arrangement Controls**, "Main",
  "Waveform Vertical Zoom Level" (AXSlider), "Optimize Arrangement Width" (AXCheckBox). **Transport bar and its buttons:** plain
  AXGroup without a title at the top of the window (no AXButton). **Status bar:** AXGroup "Status". **Device Detail:** AXGroup.
- Browser: not open in this layout, not probed.
- Consequence: v23 (any element that is not a control) would have counted the transport bar, the track headers, Device Detail
  and the status bar as moving the insert point, because they are plain groups. v24 counts only AXStaticText under "Arrangement"
  and not under "Track Headers", "Loop Brace" or "Device Detail" (`Transport.clickCounts`). Mixer faders, solo, popups, the
  transport and the track names are told apart from waveform clicks. A click on the timeline's ruler (the Loop Brace group)
  is not counted: it moves the playhead, so the plant after a stop is right. If Live changes its AX names, no click counts and
  the behaviour falls back to v21 (plant always); the log line "click in Live while playing: role ... above it ..." shows it.

## Open points (written 22.11.2026, not to do now)
1. A real reading of the insert point (a small AbletonOSC handler for the song's start / insert position) would replace the
   tap guess and also catch keyboard and MIDI moves. To try only when Live is idle and Marko agrees; first check that Live's
   API exposes it.
2. The jump-to-click question, still Marko's to answer: when he clicks during playback, should playback jump there at once?
3. The two MIDI modules (MIDI TO MK CONTROL, MIDI TO KEY STROKE) live in two apps (this one and MANTRA_MIDI_TOOLS), same settings
   files and the same MIDI sources: decide which app keeps them; nothing guards a double grab.
4. Window captures at the minimum width 640, after TOP, after a resize and full screen: the window sits on another Space while
   Live is full screen, Accessibility lists no window for it, and nothing was resized without taking his screen.
5. FIRST item of the next version: A1 writes no log line for its key tap. Log, with a time, when the tap is installed, when macOS
   disables it (tapDisabledByTimeout / ByUserInput) and when it is enabled again, so "the Space filter is active" is read from
   the log and not inferred from CGGetEventTapList.

v24 installed 22.11.2026 05:19 (AX quit of v23 pid 3184 at 05:19:28, v24 pid 10390 started 05:19:29 with `open -g`, tap enabled
when checked 6 s later, the updater line "v24 is the newest" at 05:19:33). v23 never saw a test: its log held only start and updater lines.

## Confirmed by Marko, 22.11.2026 (v24 tested; v25 installed 05:44, pid 34439)

Marko, 22.11.2026, after testing v24: "Ableton Live is working. Thank". Final decision table (Transport.decide):
| State | Result |
|---|---|
| playing, no click in the arrangement since the play began | Shift+Space stops, then Cmd+Shift+Space plants the insert point on the playhead |
| playing, clicked in the arrangement | Shift+Space stops, nothing planted, his place stays |
| playing, click unknown (key tap was off) | stop only |
| playing, follow switch off | stop only |
| stopped | a plain Space: Live plays from the insert point (loop case: the playhead to the loop start, then Continue Playback) |
| Live's state unknown | a plain Space, nothing planted |
The log of his test (05:25 to 05:40Z): 3 clicks seen, all AXStaticText under Arrangement and counted; each followed by "yes -> stop";
every stop without a click was "no -> stopAndPlant"; every stopped Space was "play from the insert point". No tap gap, no "unknown".
v25: `--studio-shot <png> --width N` renders the window off screen (rest, after TOP, after a resize; title hidden in all three, 640 wraps the
tab row to two lines, nothing cut) and the log has "key tap installed / disabled by macOS / re-enabled".
Open points still: a real insert-point reading from Live (AbletonOSC handler), the jump-to-click question (Marko's, unanswered), and the
two MIDI modules: decided 22.11.2026 to live in both apps as one shared module (being built).

## v26, 22.11.2026: the MIDI modules are shared with MIDI Tools (Mantra)

Marko, 22.11.2026: "All the MIDI modules should only be actually in both places. We are sharing the modules ... they also share the
settings. It's the same thing, just in different views." The two tabs MIDI TO MK CONTROL and MIDI TO KEY STROKE now come from the
public repo MANTRA_MIDI_MODULES (git submodule `shared/`, pinned by commit; `shared.sha256` is checked by the workflow, so this
app and MIDI Tools build from byte-identical sources). One on / off state, `~/.config/mantra-midi-modules.json` (made from the old
`live-actions.json` and `midi-tools.json` keys: ON); one engine: the owner lock `~/.config/mantra-midi-owner.lock`; the other app is
a view and says "runs in <name>". A1MIDI.swift (the E16 blob) stays here only: it shows incoming MIDI through its own input port, no action.
Log lines: "midi owner acquired / released", "<module> engine started / stopped here", "midi: runs in ...".

## v27, 22.11.2026: command mode or typing (Part 1 of his request)

Marko: "when I press control space to search some software in my computer, I still am not able to type these letters ... When I'm
inside the dialogue box ... it should be free ... Only when I'm in the command mode, then I have command keys."
**Cause:** `A1Engine.filter` acted on his keys whenever `NSWorkspace.frontmostApplication` was Live, and asked only Live's OWN focused
element (`focusRole()`, A1Engine.swift ~line 274 and 441): Launcher (Mantra)'s `BoxPanel` is a non-activating key panel (STAR_LAUNCHER
Sources/Box.swift), so Live stays the front app and its own focus is still the arrangement, therefore every 1, 2 and letter was eaten
(case a). Inside Live the check was a text role on Live's focus only and the `typing` flag set by Cmd+R and Cmd+F; dialogs, sheets,
other windows and Live's own fields that report no text role slipped through (case b).
**Now:** `KeyMode.decide` (app/KeyMode.swift, pure, tested in the workflow): a key is a command only when Live is in front, the focused
element (system-wide, `readFocus`) belongs to Live, is not a text role (AXTextField, AXTextArea, AXComboBox, AXSearchField) nor a settable
string, the focus is not in a dialog / sheet / a window of Live other than the main one, and the rename-or-search typing flag is off.
When the system-wide focus cannot be read, the floating windows of other apps are asked for a focused text field (`otherHolder`);
when nothing is known the key is free. Every decision is in app.log ("key 1: command" / "key 1: free: <reason>") and the A1 tab shows
COMMAND or TYPING with the reason. Tab now ends typing like Return and Escape.

## v28, 22.11.2026: CUSTOM SHORTCUTS with CAPTURE, I and O as in an editing program, the Launcher's announcement

**Custom shortcuts** (Marko: "capture any key to these commands I already predefined"): they were A1's key mappings (A1_DEFAULT_MAPS plus his own
in ~/.config/ableton-assistant-a1.json, the rows of THE KEYS in the A1 tab, which stay). The new tab CUSTOM SHORTCUTS (`app/ShortcutsTab.swift`) has a row
per mapping: the key, CAPTURE (the next key or combination, Esc cancels, 15 s), RESET, RESET ALL. His keys are overrides in
`~/.config/ableton-assistant-shortcuts.json` (schema 1, atomic, by physical key code with the layout's label; a missing file = the original keys; a bad one
= the originals and a note in the tab and the log). The model is pure (`app/Shortcuts.swift`, tests/shortcuts_test.swift): capture frees the old key,
clash with another of his keys offers SWAP, a Mac shortcut or a key of Live's menu (read from Live) is told first with SAVE ANYWAY / CANCEL. The capture
swallows the key (it never reaches Live) and `index()` uses the new key at once.
**I and O** (Marko: "I want to make them like in any editing software ... in English is I o"): `LoopMarks.decide` (app/LoopMarks.swift, pure, tested).
I = the loop brace's start where he is now, O = its end there and the loop on. Where he is now: `current_song_time` asked at the press; while playing
half of the round trip is taken back at the tempo (`LoopMarks.atPress`; the log says the round trip in ms and what was taken back), stopped = the insert
point. Rules: I keeps the OUT, O keeps the IN; the new mark wins: when it would cross the other end, the other end moves so the brace keeps its length
(a bar when there was none), never below 0; the first O turns the loop on, I leaves the switch alone; snapping is per key (SNAP OFF / BEAT / BAR in the
tab, default OFF); the ticked-marker loop and I / O: the last action wins (as before: I / O clear the ticks, ticking clears the marks). The transient
versions are ⇧I and ⇧O (free in Live's menus and in his map). The brace is set with the existing `sendBrace` (start 0, length, start). Not verified in Live:
what Live does with the playhead when the loop start moves while the playhead is outside the new loop.
**Launcher's box:** `com.mantra.launcher.box` (userInfo open, pid) read in `A1Engine.watchLauncher`: while open every key is free, ended by "closed", by a
click in Live, or after 60 s. STAR_LAUNCHER v6 posts it (source committed; it is a private repo and cannot be built on GitHub until it is made public).

## v31, 22.11.2026: Space never moves the playhead (the fix and the audit)
Every place that sets the song position or plants the insert point: (1) `spaceDecide` the plant after a STOP (Cmd+Shift+Space, only when he did not click: his rule a, kept); (2) `restoreTick` (put the insert point back at a start of Live, the "resume" feature, once at set open, never on Space); (3) `jumpToTransient` (his Up/Down arrows and Shift+I/O: deliberate commands); (4) `playLoopStart` (the old Space jump, now a command with no key); `sample()` writes the stopped position to the file beside the set only when it moved and `stopHold` keeps it from writing a stop position that is not his insert point; the file is read only at the start of a set (`restoreTick`), so it cannot feed an old position back during a session. Size of the timeline: nothing depends on it (positions are Double; OSC carries float32, whose step at 7200 beats is 1/2048 of a beat, about 0.25 ms at 120 BPM). The cause was the loop, not the length.

## v34, 24.11.2026: PHONE REMOTE module, and the playback mode is "follow"

- New module PHONE REMOTE (`app/RemoteModule.swift`, `RemoteLive.swift`, `RemoteServer.swift`, `RemotePeaks.swift`): the
  server of the Android app Ableton Live Remote (Mantra) moved here from the retired "Ableton Live Remote (Mantra).app".
  Port 8966 (HTTP + WebSocket; MANTRA_PORTS `ableton-live-remote`), Bonjour `_mantralive._tcp` (Info.plist now carries
  NSLocalNetworkUsageDescription: macOS asks once to allow the local network), adb reverse 8966 and 15900 → 5900,
  `/features` + order `c=feature&id=module:<id>|a1:<flag>&v=1|0`: the phone sees and switches the modules and A1's flags.
  It asks Live only while a phone is connected (the shared turn, one combined question per look).
- `PlaybackMode.swift`: the playback mode (`~/.config/mantra-live-playback-mode`, `return` | `continue`), acted on by the
  watcher in AbletonOSC's Mantra patch after ANY stop. A1's "follow" flag reads and writes it (follow = continue); its
  row in the A1 tab is now the two pictograms. The Space decision itself (Transport.swift) is unchanged.
