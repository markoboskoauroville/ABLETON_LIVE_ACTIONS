"""MACRO: Route Every Track to Main (In the Box). Marko, 27.10.2026: "Use our Ableton Actions application to set every
output to main from every channel" (mixing in the box: no mixer, Live's Main goes to the output device, BlackHole while
Claude measures, the ADAM when Marko mixes).

Every track: Audio To Main, Audio From No Input (nothing is recorded in a mixdown), one track selected at a time (with
several selected Live gives the change to all), then the whole set read back. (This AbletonOSC has no return-track commands; returns are set in Live.)
    python3 macro_main.py [--dry]
"""
import sys, time
from macro_cq12t import q, send, holder, LIVE, say

DRY = "--dry" in sys.argv


def main():
    say("MACRO Route Every Track to Main (In the Box)" + ("  (dry: nothing is changed)" if DRY else ""))
    n = q("/live/song/get/num_tracks")
    if not n:
        say("STOPPED: Live did not answer" + (f" (11001 held by {holder()})" if LIVE[1] == 11002 else "")); return 1
    tracks = n[0]
    for t in range(tracks):
        if DRY: continue
        send("/live/view/set/selected_track", t)
        send("/live/track/set/output_routing_type", t, "Main")
        types = (q("/live/track/get/available_input_routing_types", t) or [t])[1:]
        if "No Input" in types:
            send("/live/track/set/input_routing_type", t, "No Input")
    time.sleep(0.4)
    bad = []
    for t in range(tracks):
        name = (q("/live/track/get/name", t) or [t, "?"])[1]
        out = (q("/live/track/get/output_routing_type", t) or [t, "?"])[1]
        inp = (q("/live/track/get/input_routing_type", t) or [t, "?"])[1]
        ok = out == "Main"
        if not ok: bad.append(t + 1)
        say(f"  {t + 1:2} {name[:24]:24}  out {out}{' ✓' if ok else ' ✗'}   in {inp}")
    say(f"DONE: {tracks - len(bad)} of {tracks} tracks to Main" + (f"; not: {', '.join(map(str, bad))}" if bad else "") + (" (dry)" if DRY else ""))
    return 2 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
