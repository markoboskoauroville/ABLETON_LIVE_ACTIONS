"""MACRO: Map Channels to Allen & Heath CQ12T (Marko, 27.10.2026: "When you do that, you need to make sure my mixer is
in multi-track mode ... Inside Ableton Live, you need to change the input and output source to that mixer. You need to
assign the first channel to the last channel external output 1 and external output 2, and the same for input. It's
automatic mapping one by one to the mixer.")

The run, one line printed per step (the app shows every line; the last one is the verdict):
  1. the CQ12T in multitrack, its inputs 1–10 from USB: CQ MixPad opened on the MacBook Pro screen (Rectangle), the mixer chosen in its list
     and Connect clicked, CONFIG › USB / SD › Stream Mode read and set to Multitrack (helpers/mixpad.py, Marko:
     "once you open the CQ Mixpad, you must be able to locate its Connect button"); then CoreAudio must see
     "CQ12T - Audio" with 16 in and 16 out. The app in front before is given back.
  2. Live's audio input and output device are the CQ12T: read in Live's own Log.txt ("Audio In Out: Input Device:");
     if not, Live's Settings is opened and Marko is asked by voice to choose CQ12T; the log is watched for 3 minutes
     (Live's binary Preferences.cfg is never patched: MANTRA_MANIFEST ableton-live-audio.md)
  3. track 1 → Ext. Out 1 and Ext. In 1, track 2 → 2, ... up to 16, one by one over AbletonOSC, each read back
Run: python3 macro_cq12t.py [--dry | --auto]   (--dry: checks and reports, changes nothing; --auto: the app's own run
when a set opens, MixPad only if the Mac does not see 16 × 16, tracks already right left alone)
"""
import glob, json, os, socket, struct, subprocess, sys, time, urllib.request

DRY = "--dry" in sys.argv
# AUTO: started by the app when a set opens (Marko, 27.10.2026). Quiet: CQ MixPad is opened only when the Mac does not
# see 16 × 16 already (that is multitrack), a track already on its channel is not touched, and a set with nothing to
# change says so in one line.
AUTO = "--auto" in sys.argv
CQ = "CQ12T"
CHANNELS = 16
VOICE = "http://127.0.0.1:8837/speak"


def say(s):
    print(s, flush=True)


def speak(text):
    try:
        r = urllib.request.Request(VOICE, json.dumps({"text": text}).encode(), {"Content-Type": "application/json"})
        urllib.request.urlopen(r, timeout=3).read()
    except Exception:
        say("  (the voice at :8837 is not on: read this here)")


# MARK: OSC, the same few lines as SANTOSHI_CONCERT_MIX tools/osc.py

def pad(b):
    return b + b"\0" * (4 - len(b) % 4)


def enc(addr, *args):
    tags = "," + "".join("i" if isinstance(a, int) else "f" if isinstance(a, float) else "s" for a in args)
    out = pad(addr.encode()) + pad(tags.encode())
    for a in args:
        out += struct.pack(">i", a) if isinstance(a, int) else struct.pack(">f", a) if isinstance(a, float) else pad(a.encode())
    return out


def dec(b):
    def rs(i):
        j = b.index(b"\0", i)
        return b[i:j].decode(errors="replace"), (j // 4 + 1) * 4
    addr, i = rs(0)
    tags, i = rs(i)
    args = []
    for t in tags[1:]:
        if t == "i": args.append(struct.unpack(">i", b[i:i + 4])[0]); i += 4
        elif t == "f": args.append(struct.unpack(">f", b[i:i + 4])[0]); i += 4
        elif t == "s": s, i = rs(i); args.append(s)
        elif t in "TF": args.append(t == "T")
        elif t == "N": args.append(None)
    return addr, args


# USE, LET GO (Marko, 31.10.2026): a question takes the shared turn on Live's answer port and lets it go
# (helpers/liveosc.py); this script no longer keeps 11001 while it runs. LIVE stays for the callers' messages.
import liveosc
LIVE = liveosc.LIVE


def q(addr, *args):
    """the answer to this address (for a track question, to this track), or None"""
    try:
        return liveosc.ask(addr, *args, wait=2.0)
    except (TimeoutError, OSError) as e:
        print(f"OSC: {e}", file=sys.stderr); return None


def send(addr, *args):
    liveosc.tell(addr, *args)
    time.sleep(0.15)


def holder():
    out = subprocess.run(["/usr/sbin/lsof", "-nP", "-iUDP:11001", "-Fc"], capture_output=True, text=True).stdout
    return ", ".join(l[1:] for l in out.splitlines() if l.startswith("c")) or "nobody"


# MARK: the steps

def mixer():
    out = subprocess.run(["/usr/sbin/system_profiler", "SPAudioDataType", "-json"], capture_output=True, text=True).stdout
    for d in json.loads(out or "{}").get("SPAudioDataType", [{}])[0].get("_items", []):
        if CQ in d.get("_name", ""):
            return d["_name"], d.get("coreaudio_device_input", 0), d.get("coreaudio_device_output", 0)
    return None


def live_devices():
    logs = sorted(glob.glob(os.path.expanduser("~/Library/Preferences/Ableton/Live */Log.txt")), key=os.path.getmtime)
    if not logs:
        return None, None
    inp = outp = None
    with open(logs[-1], errors="replace") as f:
        for l in f:
            if "Audio In Out: Input Device:" in l: inp = l.split("Input Device:", 1)[1].strip()
            if "Audio In Out: Output Device:" in l: outp = l.split("Output Device:", 1)[1].strip()
    return inp, outp


def open_live_settings():
    subprocess.run(["/usr/bin/open", "-a", "Ableton Live 12 Suite"], capture_output=True)
    script = ('tell application "System Events" to tell (first process whose bundle identifier is "com.ableton.live") '
              'to click (first menu item of menu 1 of menu bar item 2 of menu bar 1 whose name starts with "Settings")')
    return subprocess.run(["/usr/bin/osascript", "-e", script], capture_output=True, text=True).returncode == 0


def pick(options, want):
    # Live names a mono channel "1", or "1" plus the device's label ("15/16 Msdter OUT" is a pair); never a pair here
    for o in options:
        if o == want or (o.split(" ")[0] == want and "/" not in o.split(" ")[0]):
            return o
    return None


def route(t, kind, typ, n):
    """track t (0-based) → its Ext. Out / Ext. In channel n; returns the channel's name, or why not"""
    types = q(f"/live/track/get/available_{kind}_routing_types", t)
    if not types or typ not in types[1:]:
        return None, f"no {typ} on this track" + (" (Live's input device is not set)" if kind == "input" else "")
    now_t = q(f"/live/track/get/{kind}_routing_type", t)
    now_c = q(f"/live/track/get/{kind}_routing_channel", t)
    if now_t and now_c and now_t[1] == typ and pick([now_c[1]], str(n)):
        return now_c[1], None              # already on its channel: not touched (no selection changed)
    if not DRY:
        # one track selected, this one: with several selected, Live gives the change to all of them (27.10.2026: the
        # first run left every track on 10)
        send("/live/view/set/selected_track", t)
        send(f"/live/track/set/{kind}_routing_type", t, typ)
    chans = (q(f"/live/track/get/available_{kind}_routing_channels", t) or [t])[1:]
    c = pick(chans, str(n))
    if not c:
        return None, f"{typ} has no single channel {n} (Live's {'Output' if kind == 'output' else 'Input'} Config: make {n} mono)"
    if DRY:
        return c, None
    send(f"/live/track/set/{kind}_routing_channel", t, c)
    got = q(f"/live/track/get/{kind}_routing_channel", t)
    gtype = q(f"/live/track/get/{kind}_routing_type", t)
    if not got or got[1] != c or not gtype or gtype[1] != typ:
        return None, f"set, but Live reads back {gtype[1:] if gtype else '?'} {got[1:] if got else '?'}"
    return c, None


def main():
    say("MACRO Map Channels to Allen & Heath CQ12T" + ("  (dry: nothing is changed)" if DRY else ""))

    # 1. the mixer in multitrack: CQ MixPad says so (and is made to), CoreAudio confirms 16 × 16
    import mixpad
    m = mixer()
    if AUTO and m and m[1] >= CHANNELS and m[2] >= CHANNELS:
        say(f"1 THE MIXER: {m[0]}, {m[1]} in, {m[2]} out: multitrack ✓ (CQ MixPad not needed)")
        return rest()
    if AUTO and not m:
        say("STOPPED: no CQ12T on USB (nothing done)"); return 1
    was_front = subprocess.run(["/usr/bin/osascript", "-e", 'tell application "System Events" to get bundle identifier '
                                'of first process whose frontmost is true'], capture_output=True, text=True).stdout.strip()
    try:
        ok, words = mixpad.connect()
        say("1 THE MIXER: " + words)
        if not ok:
            say("STOPPED: " + words); return 1
        was, now = mixpad.stream_mode("Multitrack" if not DRY else ("Multitrack" if mixpad.lit("Multitrack") else "Stereo"))
        if now is None:
            say("STOPPED: CQ MixPad's CONFIG › USB / SD › Stream Mode was not found"); return 1
        say(f"  CONFIG › USB / SD › Stream Mode: {was}" + (f" → {now}" if was != now else "") + (" ✓" if now == "Multitrack" else ""))
        if now != "Multitrack":
            say("STOPPED: the CQ12T is not in multitrack" + (" (dry: not changed)" if DRY else "")); return 1
        # digital in: the CQ's inputs 1–10 play what Live sends them (Marko, 27.10.2026: "to be digital in and out for
        # Ableton"). Stored once in the mixer's scene "Live Multitrack" and recalled after that ("store this
        # configuration and load it instead of clicking every time"); set by hand and stored only when the scene is
        # not there (a factory reset empties the scenes).
        r = None if DRY else mixpad.recall_scene()
        if r:
            say(f"  HOME › SCENES: \"{mixpad.SCENE}\" recalled (names and inputs 1–{mixpad.CQ_INPUTS} from USB) ✓")
        elif mixpad.inputs_page():
            if DRY:
                mixpad.scenes_page()
                say(f"  HOME › SCENES: \"{mixpad.SCENE}\" " + ("is there: RUN recalls it" if mixpad.scene_row(mixpad.SCENE) else "is not there: RUN sets the inputs and stores it"))
                mixpad.inputs_page()
            bad = []
            for i in range(1, mixpad.CQ_INPUTS + 1):
                if DRY:
                    mixpad.front(); mixpad.click_at(*mixpad.input_point(i)); time.sleep(0.6)
                    if mixpad.lit("Analogue"): bad.append(i)
                elif not mixpad.set_input_source(i, usb=True):
                    bad.append(i)
            say(f"  CONFIG › INPUTS › Input Source: inputs 1–{mixpad.CQ_INPUTS} " +
                ("from USB ✓" if not bad else ("still Analogue: " if DRY else "✗ not set to USB: ") + ", ".join(map(str, bad))))
            if not DRY and not bad:
                ok = mixpad.store_scene()
                say(f"  HOME › SCENES: stored as \"{mixpad.SCENE}\"" + (" ✓ (next time one recall)" if ok else " ✗ (not stored)"))
        else:
            say("  ✗ CQ MixPad's CONFIG › INPUTS was not found: the input sources are not checked")
    finally:
        if was_front and was_front != "com.allenheath.CQ.MixPad":
            subprocess.run(["/usr/bin/open", "-b", was_front], capture_output=True)
    end = time.time() + 20
    while True:
        m = mixer()
        if m and m[1] >= CHANNELS and m[2] >= CHANNELS:
            break
        if time.time() > end:
            say(f"STOPPED: the Mac sees {m[0] + f' with {m[1]} in, {m[2]} out' if m else 'no CQ12T on USB'} (USB-B to the Mac?)")
            return 1
        time.sleep(1)       # the CQ comes back on USB with its new channel count
    say(f"  the Mac: {m[0]}, {m[1]} in, {m[2]} out ✓")
    return rest()


def rest():

    # Live must be running and AbletonOSC must answer
    if subprocess.run(["/usr/bin/pgrep", "-x", "Live"], capture_output=True).returncode != 0:
        say("STOPPED: Ableton Live is not running"); return 1
    try:
        n = q("/live/song/get/num_tracks")
    except RuntimeError as e:
        n = None; say(f"  AbletonOSC: {e}")
    if not n:
        why = (f"port 11001 is held by {holder()} without the router on 11002: switch Ableton Live Actions' A1 on, "
               f"or stop the other listener") if LIVE[1] == 11002 else "is AbletonOSC Live's Control Surface?"
        say(f"STOPPED: Live did not answer ({why})"); return 1
    tracks = n[0]

    # 2. Live's audio device
    inp, outp = live_devices()
    if not (inp and CQ in inp and outp and CQ in outp):
        say(f"2 LIVE'S AUDIO: input {inp or '?'}, output {outp or '?'}: not the CQ12T")
        if DRY:
            say("  (dry: Live's Settings would be opened and Marko asked to choose CQ12T)")
        if not DRY:
            open_live_settings()
            want = " and ".join(w for w, d in (("Audio Input Device", inp), ("Audio Output Device", outp)) if not (d and CQ in d))
            speak(f"Marko, Live's Settings is open. On the Audio tab, set {want} to CQ12T.")
            say(f"  Live's Settings is open: Audio tab, {want} → CQ12T (waiting up to 3 minutes)")
            end = time.time() + 180
            while time.time() < end:
                time.sleep(2)
                inp, outp = live_devices()
                if inp and CQ in inp and outp and CQ in outp:
                    break
            else:
                say("STOPPED: Live's audio is still not the CQ12T"); return 1
    if inp and CQ in inp and outp and CQ in outp:
        say(f"2 LIVE'S AUDIO: input {inp}, output {outp} ✓")

    # 2b. Live's Input Config and Output Config: a single (mono) channel for every track to map, 1 … N
    need = min(tracks, CHANNELS)
    def missing():
        gone = {}
        for kind, typ in (("input", "Ext. In"), ("output", "Ext. Out")):
            types = q(f"/live/track/get/available_{kind}_routing_types", 0) or []
            if typ not in types[1:]:
                gone[kind] = list(range(1, need + 1)); continue
            if not DRY:
                send(f"/live/track/set/{kind}_routing_type", 0, typ)
            chans = (q(f"/live/track/get/available_{kind}_routing_channels", 0) or [0])[1:]
            gone[kind] = [n for n in range(1, need + 1) if not pick(chans, str(n))]
        return {k: v for k, v in gone.items() if v}
    gone = missing()
    if gone:
        what = " and ".join(f"{'Input' if k == 'input' else 'Output'} Config: {v[0]} to {v[-1]} as mono" for k, v in gone.items())
        say(f"2 LIVE'S CHANNELS: not switched on in Live: {what}")
        if DRY:
            say("  (dry: Marko would be asked)")
        else:
            open_live_settings()
            speak(f"Marko, in Live's Settings, Audio tab, open {what.replace(' as mono', '')}, and switch them on as mono channels. Then OK.")
            say(f"  Live's Settings is open: {what} (waiting up to 3 minutes)")
            end = time.time() + 180
            while gone and time.time() < end:
                time.sleep(3); gone = missing()
            if gone:
                say("STOPPED: Live's channels are still not switched on"); return 1
    if not gone:
        say(f"2 LIVE'S CHANNELS: Ext. In and Ext. Out 1–{need} as mono ✓")

    # 3. one by one: track N → Ext. Out N and Ext. In N
    say(f"3 THE CHANNELS: {tracks} tracks in the set, {min(tracks, CHANNELS)} mapped to the CQ's 16")
    done, problems = 0, []
    for t in range(min(tracks, CHANNELS)):
        tname = (q("/live/track/get/name", t) or [t, "?"])[1]
        o, why_o = route(t, "output", "Ext. Out", t + 1)
        i, why_i = route(t, "input", "Ext. In", t + 1)
        say(f"  {t + 1:2} {tname[:24]:24}  out {('Ext. Out ' + o) if o else '✗ ' + why_o}   in {('Ext. In ' + i) if i else '✗ ' + why_i}")
        if o and i: done += 1
        else: problems.append(t + 1)
    # the whole set read back once more at the end: a change that spilled onto another track shows here
    if not DRY:
        time.sleep(0.5)
        for t in range(min(tracks, CHANNELS)):
            o = (q("/live/track/get/output_routing_channel", t) or [t, "?"])[1]
            i = (q("/live/track/get/input_routing_channel", t) or [t, "?"])[1]
            if pick([o], str(t + 1)) is None or pick([i], str(t + 1)) is None:
                say(f"  ✗ read back at the end: track {t + 1} is on out {o}, in {i}")
                if t + 1 not in problems: problems.append(t + 1); done -= 1
        if not problems:
            say(f"  the whole set read back: tracks 1–{min(tracks, CHANNELS)} each on its own channel ✓")
    if tracks > CHANNELS:
        say(f"  tracks {CHANNELS + 1}–{tracks} left as they were: the CQ12T has {CHANNELS} channels")
    verdict = (f"DONE: {done} of {min(tracks, CHANNELS)} tracks on their CQ12T channel" +
               (f"; not complete: track {', '.join(map(str, problems))}" if problems else "") + (" (dry)" if DRY else ""))
    say(verdict)
    return 0 if not problems else 2


if __name__ == "__main__":
    sys.exit(main())
