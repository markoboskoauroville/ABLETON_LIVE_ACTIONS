# LESSONS

1. (13.10.2026) Inherited from DAVINCI_RESOLVE_ACTIONS: status items after launch; helpers leave when their parent dies; pkill -x by executable name.

2. (24.10.2026) AbletonOSC sends every answer to port 11001 of the asker's host, never to the asker's port (osc_server.py `response_addr = (remote_hostname, self._response_port)`). One port, one listener: other apps sent orders blind. The router on 11002 inside the app that holds 11001 is the fix; a client that can't bind 11001 talks to 11002.

## 25.10.2026
- **A fixed-width SwiftUI page is cut on both sides by one row wider than it**: the VStack takes the widest child, the
  frame centres it. Give the page the window's width (GeometryReader) and clip; never a fixed width
  (MANTRA_MANIFEST swift-apps.md "Never cut text").
