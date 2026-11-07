"""AUDIO: Sync Track 2 to Track 1 (Marko, 7.11.2026: "I can just put audio one on one track, audio two on the second
track and they are going to be aligned after I press the action ... and finish at the same time"; "it is going to
synchronize and then it's going to export two waves in the same length").

The same music heard by two recorders (a camera and the desk, two phones). Track 1's clip is the master clock.
  1. Rough: the onset envelope of both whole files (where new sound starts in each band: level- and EQ-free) slid one
     against the other with an FFT; the peak is how far apart they started.
  2. Fine: every 20 s the band-passed waveforms are cross-correlated at 48 kHz with a parabolic peak (sub-sample).
  3. Audio 2 is written on track 1's clock sample by sample: between the points the stretch is interpolated; a jump
     of more than 20 ms between neighbours (a recorder that dropped samples) is found to 0.5 s and made a hard cut.
  4. Two WAVs of exactly track 1's length (24 bit, 48 kHz): "<track 1 file> SYNC/1 <name>.wav" and "2 <name> synced.wav".
     RUN also puts the synced audio 2 on a new track under the master, at the master's place, unwarped, and switches
     the old track-2 clip off (deactivated, not deleted: the reference stays). CHECK (--dry) measures and reports only.
Room sound against a desk feed agrees to about ±3 ms (a metre of air); closer is not there to be measured.
    python3 audio_sync.py [--dry] [--a FILE --b FILE --out DIR]     (--a/--b: without Live, for tests)
"""
import sys, os, json, subprocess, tempfile, time
import numpy as np, soundfile as sf
from scipy.signal import stft, butter, sosfiltfilt, correlate

SR = 48000; ESR, HOP = 16000, 80           # envelope: 200 values a second
STEP = 20.0; JUMP = 0.020
DRY = "--dry" in sys.argv


def say(s):
    print(s, flush=True)


def arg(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def decode(path, sr, ch, out):
    """the whole file as Live plays it: every sample in a row (no timestamp gaps filled), float32"""
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-vn", "-ac", str(ch), "-ar", str(sr), "-f", "f32le", out], check=True)
    return np.memmap(out, np.float32, "r").reshape(-1, ch) if ch > 1 else np.memmap(out, np.float32, "r")


def envelope(x):
    _, _, Z = stft(x, ESR, nperseg=512, noverlap=512 - HOP)
    m = np.log1p(40 * np.abs(Z))
    flux = np.maximum(0, np.diff(m, axis=1)).sum(0)
    flux -= np.convolve(flux, np.ones(40) / 40, "same")
    return (flux - flux.mean()) / (flux.std() + 1e-9)


def rough(a16, b16):
    """seconds to add to a time in A to find the same moment in B, and the peak's height in standard deviations"""
    ea, eb = envelope(np.asarray(a16)), envelope(np.asarray(b16))
    n = 1 << int(np.ceil(np.log2(len(ea) + len(eb))))
    c = np.fft.irfft(np.fft.rfft(eb, n) * np.conj(np.fft.rfft(ea, n)), n)
    lags = np.concatenate([np.arange(0, len(eb)), np.arange(-len(ea) + 1, 0)])
    vals = np.concatenate([c[:len(eb)], c[n - len(ea) + 1:]])
    k = int(vals.argmax())
    return lags[k] / (ESR / HOP), float((vals[k] - vals.mean()) / vals.std())


SOS = butter(4, [150, 5000], btype="band", fs=SR, output="sos")


def fine(a, b, t, off, win=3.0, search=0.03):
    """B time = t + offset, to the sub-sample, from the band-passed waveforms; (offset, correlation)"""
    i = int(t * SR); j = int((t + off - search) * SR); n = int(win * SR); m = int(2 * search * SR)
    if i < 0 or j < 0 or i + n > len(a) or j + n + m > len(b):
        return None, 0.0
    x = sosfiltfilt(SOS, np.asarray(a[i:i + n])); y = sosfiltfilt(SOS, np.asarray(b[j:j + n + m]))
    c = correlate(y, x, mode="valid")
    c /= (np.linalg.norm(x) * np.sqrt(np.convolve(y ** 2, np.ones(n), "valid")) + 1e-12)
    k = int(c.argmax()); y0, y1, y2 = c[max(k - 1, 0)], c[k], c[min(k + 1, len(c) - 1)]
    d = y0 - 2 * y1 + y2
    sub = 0.5 * (y0 - y2) / d if d != 0 else 0.0
    return (j + k + sub) / SR - t, float(c[k])


def live_clips():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import liveosc
    def q(addr, *args):
        try: return liveosc.ask(addr, *args, wait=3.0)
        except (TimeoutError, OSError): return None
    out = []
    for t in (0, 1):
        r = q("/live/arrangement/clip_info", t)
        if not r or len(r) < 3 or not r[1]:
            return None, f"track {t + 1} has no audio clip on the timeline" + ("" if r else " (Live did not answer: is AbletonOSC loaded with the Mantra patch?)")
        out.append({"track": t, "file": r[1], "start": float(r[2]), "name": (q("/live/track/get/name", t) or [t, f"Track {t + 1}"])[1]})
    return out, liveosc


def main():
    say("AUDIO Sync Track 2 to Track 1" + ("  (check: nothing is written)" if DRY else ""))
    if arg("--a"):
        clips = [{"track": 0, "file": arg("--a"), "start": 0.0, "name": "1"}, {"track": 1, "file": arg("--b"), "start": 0.0, "name": "2"}]; osc = None
    else:
        clips, osc = live_clips()
        if clips is None:
            say("STOPPED: " + osc); return 1
    A, B = clips[0]["file"], clips[1]["file"]
    for c in clips:
        say(f"  track {c['track'] + 1}: {os.path.basename(c['file'])}")
        if not os.path.exists(c["file"]):
            say(f"STOPPED: the file of track {c['track'] + 1} is not on this Mac"); return 1
    tmp = tempfile.mkdtemp(prefix="audiosync_")
    try:
        a16, b16 = decode(A, ESR, 1, tmp + "/a16"), decode(B, ESR, 1, tmp + "/b16")
        off0, strength = rough(a16, b16)
        say(f"  the music found: audio 2 is {abs(off0):.3f} s {'ahead of' if off0 > 0 else 'behind'} audio 1 (peak {strength:.0f} σ)")
        if strength < 8:
            say("STOPPED: the two tracks do not hold the same music (no clear match)"); return 2
        a, b = decode(A, SR, 1, tmp + "/a48"), decode(B, SR, 1, tmp + "/b48")
        durA, durB = len(a) / SR, len(b) / SR
        pts = []; t = 4.0; last = off0
        while t + 3 < durA:
            o, c = fine(a, b, t, last, search=0.03)
            if o is None or c < 0.2:   # silence, or the jump: look wider around the rough offset
                o2, c2 = fine(a, b, t, off0, search=0.4)
                if o2 is not None and c2 >= 0.2: o, c = o2, c2
            if o is not None and c >= 0.2:
                pts.append((t, o, c)); last = o
            t += STEP
        if len(pts) < 2:
            say("STOPPED: too few points matched (under two)"); return 2
        tt = np.array([p[0] for p in pts]); oo = np.array([p[1] for p in pts])
        keep = np.ones(len(tt), bool)                      # a point far from both neighbours is noise
        for i in range(1, len(tt) - 1):
            if abs(oo[i] - oo[i - 1]) > 0.006 and abs(oo[i] - oo[i + 1]) > 0.006 and abs(oo[i - 1] - oo[i + 1]) < 0.006: keep[i] = False
        tt, oo = tt[keep], oo[keep]
        kt, ko = [tt[0]], [oo[0]]; jumps = []
        for i in range(1, len(tt)):
            if abs(oo[i] - oo[i - 1]) > JUMP:
                lo, hi = tt[i - 1], tt[i]
                while hi - lo > 0.5:
                    mid = (lo + hi) / 2; om, cm = fine(a, b, mid, (oo[i - 1] + oo[i]) / 2, win=1.0, search=abs(oo[i] - oo[i - 1]) + 0.01)
                    if om is None or abs(om - oo[i - 1]) < abs(om - oo[i]): lo = mid
                    else: hi = mid
                cut = (lo + hi) / 2; jumps.append((cut, oo[i] - oo[i - 1]))
                kt += [cut - 1e-6, cut]; ko += [np.interp(cut, [tt[i - 1], tt[i]], [oo[i - 1], oo[i - 1]]), oo[i]]
            kt.append(tt[i]); ko.append(oo[i])
        kt, ko = np.array(kt), np.array(ko)
        drift = (oo[-1] - oo[0]) - sum(j[1] for j in jumps)
        say(f"  {len(tt)} points every {STEP:.0f} s; drift {drift * 1000:+.1f} ms over {(tt[-1] - tt[0]) / 60:.0f} min"
            + "".join(f"; a dropout of {d * 1000:+.0f} ms at {int(c // 60)}:{c % 60:04.1f}" for c, d in jumps))
        if DRY:
            say("DONE (check): nothing written"); return 0
        # the two WAVs, track 1's length
        stem = os.path.splitext(os.path.basename(A))[0]
        outdir = arg("--out") or os.path.join(os.path.dirname(A), stem + " SYNC")
        os.makedirs(outdir, exist_ok=True)
        w1 = os.path.join(outdir, "1 " + stem + ".wav"); w2 = os.path.join(outdir, "2 " + os.path.splitext(os.path.basename(B))[0] + " synced.wav")
        a2 = decode(A, SR, 2, tmp + "/a2"); b2 = decode(B, SR, 2, tmp + "/b2")
        n = len(a2); chunk = SR * 30
        with sf.SoundFile(w1, "w", SR, 2, "PCM_24") as f1, sf.SoundFile(w2, "w", SR, 2, "PCM_24") as f2:
            for s0 in range(0, n, chunk):
                s1 = min(n, s0 + chunk); f1.write(np.asarray(a2[s0:s1]))
                ta = np.arange(s0, s1) / SR
                pos = (ta + np.interp(ta, kt, ko)) * SR
                i0 = np.floor(pos).astype(np.int64); fr = (pos - i0)[:, None]
                ok = (i0 >= 0) & (i0 + 1 < len(b2))
                y = np.zeros((s1 - s0, 2), np.float32)
                y[ok] = b2[i0[ok]] * (1 - fr[ok]) + b2[i0[ok] + 1] * fr[ok]
                f2.write(y)
        json.dump({"points": [[float(x) for x in p] for p in pts], "knots_t": kt.tolist(), "knots_o": ko.tolist()},
                  open(os.path.join(outdir, "sync map.json"), "w"), indent=1)
        # proof: the written pair measured again
        c1, c2 = sf.SoundFile(w1), sf.SoundFile(w2)
        same = c1.frames == c2.frames
        x1 = decode(w1, SR, 1, tmp + "/v1"); x2 = decode(w2, SR, 1, tmp + "/v2")
        # only where both hold sound: inside the measured stretch, and a clear match (silence after a recorder stopped is not a miss)
        lo, hi = max(10.0, kt[0]), min(durA - 10, kt[-1])
        res = [fine(x1, x2, t, 0.0, search=0.012) for t in np.linspace(lo, hi, 12)]
        res = [r[0] for r in res if r[0] is not None and r[1] >= 0.2]
        worst = max(abs(r) for r in res) * 1000 if res else float("nan")
        say(f"  written: {os.path.basename(w1)}, {os.path.basename(w2)} — both {c1.frames / SR:.3f} s{'' if same else ' ✗ NOT THE SAME LENGTH'}")
        say(f"  measured again at {len(res)} points: within ±{worst:.1f} ms ({worst * 48:.0f} samples)")
        if osc is not None:
            r = osc.ask("/live/arrangement/audio_clip", w2, "2 synced", clips[0]["start"], wait=8.0)
            osc.tell("/live/arrangement/clip_mute", 1, 1)
            say(f"  Live: the synced audio 2 on track {r[0] + 1 if r else '?'} at track 1's place; track 2's clip switched off")
        say(f"DONE: in sync within ±{worst:.1f} ms, two WAVs of {c1.frames / SR:.3f} s in \"{outdir}\"")
        return 0 if same else 2
    finally:
        for f in os.listdir(tmp): os.remove(os.path.join(tmp, f))
        os.rmdir(tmp)


if __name__ == "__main__":
    sys.exit(main())
