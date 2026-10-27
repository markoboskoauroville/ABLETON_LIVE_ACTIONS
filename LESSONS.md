# LESSONS

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
