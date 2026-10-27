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
**Status (12:30):** done. The Bach Prelude became Pianoverse Demo Songs by Mantra (repo PIANOVERSE_DEMO_SONGS); the
Arrangement switch at Live's start is in Opening and Closing v6; the AbletonOSC additions are kept in abletonosc/.

## 24.10.2026: an OSC router, so every app can hear Live

> if our fifth app is occupying the OSC, that's the reason we need to solve this. You need to make an OSC router so both apps can use it. You can use it, and the app can use it. Please make this router

(Said while routing the Santoshi Venue Mix in Live: AbletonOSC answers only to UDP 11001, this app's A1 wire holds it, so Claude's tools could send orders but never read Live's answers.)

- The router inside this app: it keeps 11001 and opens 127.0.0.1:11002; any app sends its OSC to 11002, the router passes it to Live (11000) from the 11001 socket, and every answer that comes back is given to A1 and sent on to every app that spoke through the router in the last two minutes. **Status:** done, v4 built, installed, restarted (pid 1493 → 10501); lsof: 11001 and 127.0.0.1:11002 held by the app; tested from SANTOSHI_CONCERT_MIX tools/osc.py: tracks, markers, routing types and channels read back through 11002 while A1 kept its wire
- The tools that ask Live (SANTOSHI_CONCERT_MIX tools/osc.py first) talk through 11002 when the router is there. **Status:** Santoshi done; ABLETON_TEACHER live.py, ABLETON_COMMAND_GUIDE act.py and the Mackie Log.txt reader still the old way

## 25.10.2026, 07:33, session "ableton tutorials"

> Please, by the way. Fix Swift app for Ableton Live Actions. It's cutting the text. There is no margin between text and the window. Please fix this in future, and control if it's the case that this is happening often. You have some bug in your building that you are cutting the text. You don't give enough space for windows, and windows can be resizable.

**Status:** v5: the window resizable (minimum 640 × 480, first 820 × 820), the page takes the window's width and wraps; the row of marker and loop keys split in two (it was wider than 640 and pushed the page past both edges).

## 27.10.2026: MACROS, a new category; the first one maps Live's channels to the CQ12T

> please build the process in my Ableton Actions program. We have a new category, which is kind of a pre-recorded macro. There will be a macro name and then the run. This macro name is called "Map Channels to Allen and Heat CQ12T." When you do that, you need to make sure my mixer is in multi-track mode. You can confirm that by connecting and opening the CQ Mixpad, connecting to it, and then seeing the settings. Inside Ableton Live, you need to change the input and output source to that mixer. You need to assign the first channel to the last channel external output 1 and external output 2, and the same for input. It's automatic mapping one by one to the mixer. Please make that action now

**Status:** v6 built and installed: the MACROS section, RUN and CHECK; step 1 (CQ12T 16 × 16, multitrack) checked on the real mixer; steps 2–3 wait for Live's answers (Hammerspoon's Lua A1 holds 11001).

> once you open the CQ Mixpad, you must be able to locate its Connect button. So two checks: if the mixer is listed there in the list, then you can just click Connect and connect to the mixer automatically

**Status:** saved, before code.

> actions should be able to open CQ Mixpad and change settings in the mixer, in this case multi-track streaming, and anything else we need in the future

**Status:** saved, before code. Plan: `helpers/mixpad.py`, an eye and a hand for CQ MixPad (it draws its own buttons, no accessibility tree): open it, photograph its window, read every word with macOS Vision text recognition, click a word; macros use it (first: connect, then multitrack streaming).

> Please do all your testing now on the MacBook Pro screen, not on the BenQ. Run everything on that side, please.

> I have application on my computer called Rectangle. And it it is a window manager. Please don't drag and uh manually windows through the screens. You can snap everything very quickly. Use this as much as you can. Rectangle.

**Status:** saved. MixPad is placed on the MacBook Pro screen by Rectangle (its rectangle:// actions), never moved by hand.

> Another action to build after this action is to rename Mixer based on the channels in Ableton. Minisynchronizing names between Ableton and Mixer in both directions, actually whatever user chooses.

**Status:** saved; next macro after the mapping: names Live → CQ or CQ → Live, the user chooses the direction (CQ keeps 6 characters, no "_": MANTRA_MANIFEST cq-mixer-virtual-soundcheck.md).

> please, in general fix the port clashing. There must be some kind of automatic assignment of the port as central service for all my star applications so there is no clashing of the ports never

**Status:** saved (27.10.2026, said while the Lua A1 in Hammerspoon held 11001 against this app). A system-wide piece, beyond this repo: a central port service for every star app; planned after this macro.

> please put macros at the top because this is something I'm going to use. Or even better, organize the whole user interface in tabs, please

**Status:** v8: tabs under the first row, one per module (a dot: on or off), MACROS first, the tab last chosen comes back; checked by a window screenshot at 640 wide on the MacBook Pro screen.
