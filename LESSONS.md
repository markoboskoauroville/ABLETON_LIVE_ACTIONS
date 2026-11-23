# LESSONS

**THE RULE (Marko, 21.9.2026 and 22.11.2026): Space never moves the playhead or the insert point by itself: stopped = play from the insert point, always.**
(Loop on or off, markers ticked or not, the insert point anywhere. "Play from the loop's start" is a separate command with its own row in CUSTOM SHORTCUTS and no key.)

**Cause of the v21 to v30 bug (found 22.11.2026):** a stopped Space took the `playIntoLoop` branch whenever a loop was ON and the insert point lay outside it (`A1Engine.spaceDecide`, `Transport.decide`): it set the playhead to the loop's start. His I/O keys (v28: the first O turns the loop on) made a far-away loop common, so a click in the last song played from the previous one. It had nothing to do with the length of the timeline.
**The process lesson:** "existing behaviour" is not a reason to keep a branch that contradicts the owner's stated rule. When his rule is written down, every branch that departs from it is listed for him to decide, never kept silently; and a test that encodes behaviour he did not ask for is a liability (the old test "stopped outside the loop: plays from the loop's start" passed while the app did the wrong thing). A new key that changes state (O switching the loop on) must be checked against every command that reads that state.


1. (13.10.2026) Inherited from DAVINCI_RESOLVE_ACTIONS: status items after launch; helpers leave when their parent dies; pkill -x by executable name.

2. (24.10.2026) AbletonOSC sends every answer to port 11001 of the asker's host, never to the asker's port (osc_server.py `response_addr = (remote_hostname, self._response_port)`). One port, one listener: other apps sent orders blind. The router on 11002 inside the app that holds 11001 is the fix; a client that can't bind 11001 talks to 11002.

## 25.10.2026
- **A fixed-width SwiftUI page is cut on both sides by one row wider than it**: the VStack takes the widest child, the
  frame centres it. Give the page the window's width (GeometryReader) and clip; never a fixed width
  (MANTRA_MANIFEST swift-apps.md "Never cut text").

## 27.10.2026 (MACROS, Map Channels to Allen & Heath CQ12T)
- **Several tracks selected in Live → a routing change through AbletonOSC lands on all of them.** The first run read
  each track back as right, and the set ended with every track on Ext. Out/In 10. Select the one track
  (`/live/view/set/selected_track t`) before routing it, and read the whole set back at the end, never only per track.
- **A late OSC answer is taken for the next question** unless the answer's first argument (the track) is checked.
- **CQ MixPad has no accessibility tree, but Vision reads it**: photograph the window (`screencapture -l`), OCR, click a
  word's centre; a pair's chosen one is the green word (`helpers/mixpad.py lit`). A full-screen space that is not showing
  photographs grey: MixPad leaves full screen and goes to the MacBook Pro screen by Rectangle first.
- Live keeps the audio device and Input/Output Config per device in its own settings: asked of Marko once, never again.
- **A check right after Apply reads MixPad before it redraws**: poll a few times (a rename that worked was reported failed).
- **Store, don't click**: the CQ scene keeps names and input sources; one recall replaces about twenty clicks (30 s for
  the whole macro). Names written to the CQ must overwrite the scene, or the next recall brings the old ones back.
- **A factory reset**: MixPad says "Connection lost" (Ok, Connect again), Stream Mode stays Multitrack, inputs go
  Analogue, names Ip1…, scenes empty, and Live's audio device falls to No Device until the USB comes back.

## 7.11.2026 — Sync Track 2 to Track 1 (v19, v20)
- Two recorders of one concert: onset envelope of the whole files finds them (140 σ); waveform every 20 s to the sample.
- A recorder that LOST sound makes the offset step; that recorder must PAUSE for the step (silence), never a 20 s slur
  (an echo in a 50/50 mix) and never sound played twice. The step is found by a change point over 100 ms windows, each
  window free to find its best within ±2 ms (0.4 ms off at 5 kHz is two cycles: a fixed offset misplaced it by 0.3 s).
- Live: warp markers carry the same map (clip beat, file seconds), Re-Pitch; the pause needs ≥ 30 ms of audio in Live,
  so a marker 1 s later puts it back exactly. Each output WAV keeps its source's channels (the camera is mono).
- Check every 20 s after writing: median 0.39 ms, 95 % within 5.2 ms on the embassy take (room mic against the desk).

## 13.11.2026

- 13.11.2026: an action that moved to Swift must be opened from the star as an app row, with the old Lua trigger deleted.

## Lesson: hover card and pipes (16.11.2026)
Poll the mouse (macOS draws a status item once per display, only one copy owns the button, so a tracking area misses the other display). The panel needs `titleVisibility = .hidden` for the one-title guard. A non-activating NSPanel at statusBar+1 never takes focus. Pipes for text items: attributed title; for icon items: pipedIcon + rightPipe; for view items: drawPipes or PipesView.

## 22.11.2026: Space after a click on the waveform (v21)
- **Continue Playback is not Play.** Shift+Space starts at the position where Live last stopped; a plain Space starts at
  the insert point. A key that always sends Continue Playback ignores every click of his on the waveform while stopped.
  The insert point is the master (his measurement of 21.9.2026): stopped means plain Space, nothing remembered, nothing
  planted afterwards; only a STOP plants the insert point on the playhead.
- A cached "is Live playing" is up to a second old: ask Live afresh before the decision, never trust an old reading.
- Keep the decision a pure function (`Transport.decide`) so the workflow can test it without Live.
- A rename keeps the bundle id (permissions), the App struct name (SwiftUI's saved window frame) and any folder other
  programs import by path.

## Round 1: 7 of 10 (Fable, 22.11.2026, v21) and what changed in v22
Missed: the fix unproven in real Live (Marko's hand), the interface (the title twice, the app ON / OFF still there, the version
twice, tabs not explained), the updater never seen running. v22: one title enforced in every state; app ON / OFF removed, ✕ quits;
version once; the MIDI tabs identified as live copies and the double-grab risk written down; a log file under ~/Library/Logs so
the updater and the Space decisions can be seen; pins and a mutation test. Lesson: an app with no log file cannot show that its
updater ran; give every app one from its first version, and write the "kept on purpose" list into a test, not only a document.

## 22.11.2026 (v23): fix one half, ask for the other
Marko's first description ("stopped, I click, then play starts from the old place") was one case; his second ("while it plays I click and
the assistant does not register it") was the one that mattered, and it is the same rule seen from the other side: the insert point
is the master, so nothing the assistant does (a stop, a plant, a file write) may overwrite a place he chose by hand. Before
fixing a bug from a first description, list every state of the transport (playing, stopped) and every way he can move the
insert point in each (click, key, MIDI), and ask about the one not named.

## Round 2 (22.11.2026): v23 and v24
v23: his click while Live plays is respected (the stop plants only when he is known not to have clicked), with a tap-and-hit-test
signal. Installed 22.11.2026 05:15 (AX quit of v21, v23 in, started with `open -g`). v24: the hit-test rule rewritten from a read-only
Accessibility probe of Live (1600 points): plain groups (transport, status, Device Detail, track headers) are not controls by role,
so "not a control" was a wrong rule; an allow-list (the arrangement canvas) is the right one. Lesson: probe the real UI before writing a
rule about what is under the pointer; Live's AX tree is rich (Arrangement, Track Headers, Loop Brace, Device Detail, Status).

## 22.11.2026, v25: confirmed
"Ableton Live is working. Thank" (Marko, after the v24 test). The log proved each click (role, group above it, counted) and each Space decision.
An app that must be checked at widths and states needs its own off-screen render (`--studio-shot`) from its first version: the window
was on another Space and Accessibility could not see it. A hidden second instance must be started by its executable, take no focus
(activation policy prohibited) and start no engine.

## Round 3: 10 of 10 (Fable, 22.11.2026, v25)
Scored 10 of 10 for the rename and the Space fix: v25 installed and running, release Latest, the log shows the tap installed and the updater line, the 640 render has one title, no ON / OFF, the version once and the tabs on two lines. His test matches the decision table.

## 22.11.2026 (v26): shared MIDI modules
See MANTRA_MIDI_MODULES LESSONS. In this app: A1's E16 reader (A1MIDI) opens a second input port on the same sources: it only shows incoming MIDI, so it is harmless
(two readers of one source, one action).

## 22.11.2026 (v27): a key filter must ask WHO has the keyboard, not who is in front
A non-activating panel (a launcher, Spotlight) takes the keys while the previous app stays frontmost; asking only the front app's own focus
eats the letters. Ask the system-wide focus and its owner at the moment of the key (about 2 ms), fall back to the floating windows of other
apps, and when unsure let the key through: a command that does not fire is small, a letter that cannot be typed is the bug.

## 22.11.2026 (v28 to v30): custom shortcuts, I and O, the Launcher
- A tab of many words must be rendered at the minimum width before it is called done: with six tabs the two-line layout still cut the second line; v30 has a
  three-line layout. The off-screen render (`--studio-shot <png> --width N --tab <id>`) is the check.
- An editing program's I and O are "where I am now": while Live plays that is the playhead at the press, which has to be read from Live and corrected by
  half the round trip; the log line says the round trip in milliseconds so the precision is read from his own use, not guessed.
- Keys of an app's own defaults must be overrides, not edits: his key per row lives in its own file by physical key code, the defaults stay in the code.
- A repository that is private cannot be built by GitHub; making it public rewrites its history (author address) and needs Marko's leave: the Launcher's v6 is only source until then.

## 23.11.2026 (v32): AbletonOSC on 11010/11011
AbletonOSC moved to UDP 11010 (listen) / 11011 (reply) on 23.11.2026; Suno Bridge owns 11000. The shared/MackieIO.swift copy (MANTRA_MIDI_MODULES) still has the old 11000 for its Log.txt probe until that repo is updated.

- v33: shared/ moved to a4bb302, the Mackie probe now uses AbletonOSC 11010 (23.11.2026)
