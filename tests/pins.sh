#!/bin/bash
# THE PINS: what must not change by accident. Fails when the display name, the bundle id, the executable, the settings file
# names, the App struct (saved window frame) or the one-title guard drift. Run by the workflow before the build.
cd "$(dirname "$0")/.." || exit 1
fail=0
need() { grep -q -F -- "$2" "$1" || { echo "FAIL $1 lacks: $2"; fail=1; }; }
need build.sh 'NAME="Ableton Live Assistant (Mantra)"'
need build.sh '<key>CFBundleIdentifier</key><string>community.auroville.abletonliveactions</string>'
need build.sh '<key>CFBundleExecutable</key><string>AbletonLiveActions</string>'
need build.sh '-o "$APP/Contents/MacOS/AbletonLiveActions"'
need app/Common.swift 'let APP_NAME = "Ableton Live Assistant (Mantra)"'
need app/Common.swift 'JSONFile("live-actions.json")'
need app/A1Engine.swift '/.config/ableton-assistant-a1.json'
need app/A1Engine.swift '/.config/live-keys.json'
need shared/MackieEngine.swift '/.config/midi-to-mk.json'
need shared/MidiKeysEngine.swift '/.config/midi-to-keystroke.json'
need app/Main.swift 'struct AbletonLiveActions: App'
need app/Main.swift '@main enum Launcher'
need build.sh 'shared/*.swift'
need shared.sha256 ''
need .gitmodules 'MANTRA_MIDI_MODULES'
need app/Main.swift '--studio-shot'
need app/Main.swift 'WindowGroup(APP_NAME)'
need app/Updater.swift 'static let repo = "markoboskoauroville/ABLETON_LIVE_ACTIONS"'
need .github/workflows/build.yml 'APP: "Ableton Live Assistant (Mantra)"'
# one title only: the guard of MANTRA_ROOM's check_one_title.sh, adapted to this app
need app/Common.swift 'func enforceOneTitle()'
need app/Common.swift 'w.titleVisibility = .hidden'
for n in didBecomeKeyNotification didResignKeyNotification didResizeNotification didEnterFullScreenNotification didExitFullScreenNotification; do need app/Common.swift "NSWindow.$n"; done
grep -q 'titleVisibility = .visible' app/*.swift && { echo "FAIL titleVisibility = .visible found"; fail=1; }
# no app-level ON / OFF word in the first row
grep -q 'id: "off"' app/Main.swift && { echo "FAIL the app-level OFF is back"; fail=1; }
# the version is drawn once in the window
[ "$(grep -c 'Text("v\\(VERSION)")' app/Main.swift)" = 1 ] || { echo "FAIL the version is not drawn exactly once in Main.swift"; fail=1; }
[ $fail = 0 ] && echo "pins: OK"
exit $fail
