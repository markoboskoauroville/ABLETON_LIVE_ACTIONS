"""MACRO: Names between Live and the CQ12T, the user chooses the way (Marko, 27.10.2026: "rename Mixer based on the
channels in Ableton ... in both directions, actually whatever user chooses"; "add button to transfer names in both
directions, from Mixer to Ableton or from Ableton to Mixer").

Track N ↔ CQ input N (1–10, the CQ12T's ten inputs; the mapping macro puts track N on Ext. Out N, which plays on input N).
    python3 macro_names.py --to-live     the CQ's names (CQ MixPad, CONFIG › INPUTS) become the track names in Live
    python3 macro_names.py --to-mixer    Live's track names go to the CQ, cut to 6 characters (mixpad.cq_name)
    python3 macro_names.py --dry         both lists side by side, nothing changed
"""
import subprocess, sys

import mixpad
from macro_cq12t import q, send, holder, LIVE

TO_LIVE = "--to-live" in sys.argv
TO_MIXER = "--to-mixer" in sys.argv


def say(s):
    print(s, flush=True)


def main():
    way = "MIXER → LIVE" if TO_LIVE else "LIVE → MIXER" if TO_MIXER else "CHECK"
    say(f"MACRO Names between Live and the CQ12T  ({way})")
    n = q("/live/song/get/num_tracks")
    if not n:
        say("STOPPED: Live did not answer" + (f" (11001 held by {holder()})" if LIVE[1] == 11002 else "")); return 1
    count = min(n[0], mixpad.CQ_INPUTS)
    live = {t + 1: (q("/live/track/get/name", t) or [t, ""])[1] for t in range(count)}

    was_front = subprocess.run(["/usr/bin/osascript", "-e", 'tell application "System Events" to get bundle identifier '
                                'of first process whose frontmost is true'], capture_output=True, text=True).stdout.strip()
    try:
        ok, words = mixpad.connect()
        say("  " + words)
        if not ok:
            say("STOPPED: " + words); return 1
        cq = mixpad.input_names()
        if cq is None:
            say("STOPPED: CQ MixPad's CONFIG › INPUTS was not found"); return 1
        changed, failed = 0, []
        for i in range(1, count + 1):
            if TO_LIVE:
                new = cq[i]
                if new and new != live[i]:
                    send("/live/track/set/name", i - 1, new)
                    got = (q("/live/track/get/name", i - 1) or [0, ""])[1]
                    if got == new: changed += 1
                    else: failed.append(i)
                say(f"  {i:2}  CQ {cq[i] or '—':8} → Live {live[i]!r}" + (f" → {new!r}" if new and new != live[i] else "  (same)"))
            elif TO_MIXER:
                new = mixpad.cq_name(live[i])
                if new and new != cq[i]:
                    if mixpad.set_input_name(i, new): changed += 1
                    else: failed.append(i)
                say(f"  {i:2}  Live {live[i]!r:18} → CQ {cq[i] or '—'}" + (f" → {new}" if new and new != cq[i] else "  (same)"))
            else:
                say(f"  {i:2}  Live {live[i]!r:18}  CQ {cq[i] or '—':8}  (to the CQ it would be {mixpad.cq_name(live[i])})")
    finally:
        if was_front and was_front != "com.allenheath.CQ.MixPad":
            subprocess.run(["/usr/bin/open", "-b", was_front], capture_output=True)
    if not (TO_LIVE or TO_MIXER):
        say(f"DONE: {count} names compared (check: nothing changed)"); return 0
    say(f"DONE: {changed} renamed, {count - changed - len(failed)} already the same" + (f"; not renamed: {', '.join(map(str, failed))}" if failed else ""))
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
