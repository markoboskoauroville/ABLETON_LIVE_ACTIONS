#!/usr/bin/env python3
"""a1_transients.py: the next transient to the right of where Marko stands, for Ableton Assistant A1.

Marko, 15.9.2026: "shift I jumps to the closest transient and marks the in-point for the loop, shift O
jumps to the closest transient and marks the out-point. Jumping means scanning from left to right, so the
first right transient is getting marked as a looping point."

Live has no word for a transient over OSC, and no menu item for one either (MEASURED 15.9.2026 in Live 12's
menu bar: there is no transient row anywhere). So A1 reads the set itself and listens to the audio:

  1. THE SET IS THE MAP. A .als is gzipped XML. Every arrangement audio clip is in it with its place in the
     arrangement (CurrentStart, CurrentEnd, in beats), the piece of the file it shows (Loop/LoopStart, in
     seconds when the clip is not warped, in beats when it is), its warp markers (SecTime <-> BeatTime) and
     the file it plays. So a beat in the arrangement becomes a second in a file on the disk, with no help
     from Live at all. MEASURED 15.9.2026 on "ashay lesson 1": three clips of 1_Lesson_1.mov on one audio
     track, two unwarped and one warped, and both kinds gave back the same seconds as Live's own clock.
  2. THE AUDIO IS THE TRUTH. ffmpeg decodes one window (thirty seconds by default, then longer if nothing is
     found) of that file from that second, mono at 22050, and the onsets in it are found by spectral flux:
     the rise, frame by frame, of a log-compressed spectrum, peaks picked above a moving median. numpy only,
     so it starts in a fifth of a second; the whole file is never read.
  3. THE FOOT, NOT THE FRAME. Marko, on the first build: "they are still not reaching the beginning of the
     transient. There is a gap before, so there is a miss." A flux frame is 1024 samples long and the attack
     is heard the moment it enters the window, so the frame's own beginning stands 23 ms before the sound
     (MEASURED on his lesson at 1920.749 s, where the room is quiet at 0.004 and the stroke jumps to 0.10).
     The frame's middle is the honest estimate, and from there the waveform itself is asked for the attack's
     foot, in steps of 0.7 ms. The mark then lands 2.5 ms inside the stroke instead of 30 ms before it.
  4. THE ZERO, NOT THE AMPLITUDE. Marko: "please make it mark my zero crossing waveform. The waveform must not
     be in some kind of amplitude. So at that point of transient, it needs to select the zero point of the
     waveform." A loop point that falls where the waveform stands at some amplitude steps from that amplitude
     to another at the seam, and the step is heard as a click. So the chosen transient, and it alone, is looked
     at once more in the file's OWN samples at its own rate (48000 here, asked of ffprobe once) and moved to the
     waveform's zero. But the wire had to be measured too: OSC carries every number as a 32-bit float, and at
     3841 beats that is a grid of 0.000244 beats - 122 us, 5.9 samples at 48 kHz. Live is not the one rounding
     (3841.504049 asked for, 3841.504150391 on the wire, 3841.504150391 back from Live, to the last digit), so
     the zero is chosen from the beats the wire can carry: every grid beat within six tenths of a millisecond of
     the attack's foot is looked at, and the one with the least waveform under it is taken, a rising one
     preferred on a tie. MEASURED on five of his transients: the mark moves by less than 0.6 ms and the waveform
     under it stands 43 to 65 dB below the stroke - as near to silence as the wire lets a seam be.

Used by apps/a1.lua through hs.task, and by hand:

    python3 a1_transients.py "<set>.als" <beat> --tempo 120 --track 0

It prints one JSON line: {"ok": true, "beat": ..., "sec": ..., "file": ..., "clip": ...} or
{"ok": false, "why": "..."}. The parts that need neither audio nor Live are pure and tested:
tests/test_a1_transients.py, run with python3 and nothing installed.
"""

import argparse
import gzip
import json
import math
import os
import struct
import subprocess
import sys
import tempfile
import wave
import xml.etree.ElementTree as ET

FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"
_rates = {}                       # a file's own sample rate, asked of ffprobe once
RATE = 22050                     # the window is decoded to mono at this rate
WINDOWS = (30.0, 120.0, 600.0)   # how far to the right to listen, in turn, until a transient is found


# ---------------------------------------------------------------- the set is the map (pure)
def _val(el, path, attr="Value"):
    c = el.find(path) if path else el
    return c.get(attr) if c is not None else None


def _num(el, path, default=None):
    v = _val(el, path)
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def clips(als_xml):
    """Every arrangement audio clip of a Live set, in the order its tracks stand.

    als_xml is the XML of a .als (already unzipped). One clip is a dict:
        track  the track's index among the set's tracks (Live's own order, MIDI tracks counted)
        name   the clip's name, path the audio file it plays
        start, end     where it stands in the arrangement, in beats
        warped         whether Live warps it
        loop_start     the point of the file the clip starts at: seconds when it is not warped, beats when it is
        markers        the warp markers, [(sec, beat), ...] sorted by beat; beat is counted from loop_start's zero
    """
    root = ET.fromstring(als_xml)
    tracks = root.find("./LiveSet/Tracks")
    out = []
    if tracks is None:
        return out
    for index, track in enumerate(list(tracks)):
        if track.tag != "AudioTrack":
            continue                                   # a MIDI track keeps its place in the count, holds no audio
        for clip in track.iter("AudioClip"):
            ref = clip.find(".//SampleRef/FileRef")
            path = _val(ref, "Path") if ref is not None else None
            start, end = _num(clip, "CurrentStart"), _num(clip, "CurrentEnd")
            if path is None or start is None or end is None:
                continue
            markers = []
            for m in clip.findall(".//WarpMarker"):
                try:
                    markers.append((float(m.get("SecTime")), float(m.get("BeatTime"))))
                except (TypeError, ValueError):
                    pass
            markers.sort(key=lambda p: p[1])
            out.append({
                "track": index,
                "name": _val(clip, "Name"),
                "path": path,
                "start": start,
                "end": end,
                "warped": (_val(clip, "IsWarped") == "true"),
                "loop_start": _num(clip, "Loop/LoopStart", 0.0),
                "markers": markers,
            })
    return out


def read_set(path):
    """The clips of a .als on the disk; a plain XML set (rare, but Live writes one when told) is read too."""
    with open(path, "rb") as f:
        head = f.read(2)
    data = gzip.open(path).read() if head == b"\x1f\x8b" else open(path, "rb").read()
    return clips(data)


def clip_at(all_clips, beat, track=None):
    """The clip that covers this beat of the arrangement: the one on `track` first, else the first there is."""
    covering = [c for c in all_clips if c["start"] <= beat < c["end"]]
    if not covering:
        return None
    if track is not None:
        mine = [c for c in covering if c["track"] == track]
        if mine:
            return mine[0]
    return covering[0]


def _interpolate(pairs, x, forward=True):
    """A piecewise-linear read of (x, y) pairs, the two nearest points carried on beyond the ends."""
    pts = [(a, b) if forward else (b, a) for a, b in pairs]
    pts.sort(key=lambda p: p[0])
    if not pts:
        return None
    if len(pts) == 1:
        return pts[0][1]
    if x <= pts[0][0]:
        (x0, y0), (x1, y1) = pts[0], pts[1]
    elif x >= pts[-1][0]:
        (x0, y0), (x1, y1) = pts[-2], pts[-1]
    else:
        i = 0
        while i < len(pts) - 2 and pts[i + 1][0] <= x:
            i += 1
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
    if x1 == x0:
        return y0
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def beat_to_sec(clip, beat, tempo):
    """A beat of the arrangement as a second of the clip's own audio file.

    A clip that is not warped plays the file at its own speed: the seconds run straight from Loop/LoopStart,
    which is itself in seconds. A warped clip is read through its warp markers, which say which second of the
    file stands at which beat of the clip; Loop/LoopStart is then in beats, and it is the clip's first beat.
    """
    if tempo is None or tempo <= 0:
        tempo = 120.0
    if not clip["warped"]:
        return clip["loop_start"] + (beat - clip["start"]) * 60.0 / tempo
    in_clip = (beat - clip["start"]) + clip["loop_start"]        # the beat counted the way the warp markers count
    got = _interpolate([(s, b) for s, b in clip["markers"]], in_clip, forward=False)
    if got is None:
        return clip["loop_start"] * 60.0 / tempo + (beat - clip["start"]) * 60.0 / tempo
    return got


def sec_to_beat(clip, sec, tempo):
    """A second of the clip's audio file back as a beat of the arrangement: beat_to_sec the other way round."""
    if tempo is None or tempo <= 0:
        tempo = 120.0
    if not clip["warped"]:
        return clip["start"] + (sec - clip["loop_start"]) * tempo / 60.0
    got = _interpolate([(s, b) for s, b in clip["markers"]], sec, forward=True)
    if got is None:
        return clip["start"] + (sec - clip["loop_start"] * 60.0 / tempo) * tempo / 60.0
    return clip["start"] + (got - clip["loop_start"])


def pick(onsets, at, direction="right", gap=0.02):
    """The first onset to the right of `at` (or to the left), the ones within `gap` of it passed over."""
    if direction == "left":
        before = [t for t in onsets if t < at - gap]
        return max(before) if before else None
    after = [t for t in onsets if t > at + gap]
    return min(after) if after else None


# ---------------------------------------------------------------- the audio is the truth
def decode(path, start, length, rate=RATE):
    """One window of a file as mono samples at `rate`: ffmpeg writes a wav, and it is read back as floats."""
    if not os.path.exists(FFMPEG):
        raise RuntimeError("ffmpeg is not at " + FFMPEG)
    if not os.path.exists(path):
        raise RuntimeError("the audio file is not there: " + path)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    try:
        cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", "%.6f" % max(0.0, start),
               "-t", "%.6f" % length, "-i", path, "-vn", "-ac", "1", "-ar", str(rate),
               "-f", "wav", "-acodec", "pcm_s16le", tmp.name, "-y"]
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode != 0:
            raise RuntimeError("ffmpeg: " + (r.stderr.decode("utf-8", "replace").strip().split("\n") or [""])[-1])
        with wave.open(tmp.name) as w:
            frames = w.readframes(w.getnframes())
        import numpy as np
        if not frames:
            return np.zeros(0, dtype="float32")
        return np.frombuffer(frames, dtype="<i2").astype("float32") / 32768.0
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass


def foot(samples, about, rate=RATE, back=0.10, ahead=0.06, fine=16, win=64):
    """The beginning of the attack a flux peak points at: where the sound actually starts to rise.

    Marko, 15.9.2026, on the first build: "they are still not reaching the beginning of the transient. There is
    a gap before, so there is a miss." MEASURED on his lesson at 1920.75 s: the flux peak is found in the right
    frame, but a frame is 1024 samples long and the attack is heard the moment it enters the window, so the
    frame's own beginning stands 23 ms before the sound - the gap he saw. The frame's middle is the honest
    estimate, and from there the waveform itself is asked: a fine loudness envelope (64 samples, stepped by 16,
    so 0.7 ms) over the hundred milliseconds around it; the body of the attack is its loudest point, and the
    foot is where the envelope last stood below a tenth of that body. On his hit that lands 2 ms inside the
    attack, where 23 ms of silence stood before.
    """
    import numpy as np
    p = int(about * rate)
    lo, hi = max(0, p - int(back * rate)), min(len(samples), p + int(ahead * rate))
    seg = samples[lo:hi]
    if len(seg) < win * 2:
        return about
    n = 1 + (len(seg) - win) // fine
    env = np.sqrt(np.array([(seg[i * fine:i * fine + win] ** 2).mean() for i in range(n)]))
    if not env.size or env.max() <= 0:
        return about
    body = int(np.argmax(env))
    floor = max(float(env[body]) * 0.10, float(env.min()) * 2.5)
    i = body
    while i > 0 and env[i - 1] > floor:
        i -= 1
    return (lo + i * fine + win / 2.0) / float(rate)


def onsets(samples, rate=RATE, frame=1024, hop=256, delta=0.25):
    """The onsets in a window of mono samples, in seconds from its start: spectral flux, then the attack's foot.

    The rise of a log-compressed spectrum from frame to frame (only what grew counts) is the flux; a peak is
    a local maximum that stands above the median of the half second around it by `delta` of the window's own
    scale. The peak says which frame; `foot` then says where in the waveform the sound begins, because the
    frame's own beginning is 23 ms too early (MEASURED). Two onsets closer than 30 ms are one. numpy alone.
    """
    import numpy as np
    if samples is None or len(samples) < frame * 2:
        return []
    window = np.hanning(frame).astype("float32")
    n = 1 + (len(samples) - frame) // hop
    frames = np.lib.stride_tricks.as_strided(
        samples, shape=(n, frame), strides=(samples.strides[0] * hop, samples.strides[0])) * window
    mag = np.abs(np.fft.rfft(frames, axis=1))
    spec = np.log1p(10.0 * mag)
    diff = np.diff(spec, axis=0)
    flux = np.maximum(diff, 0.0).sum(axis=1)
    if flux.size == 0 or flux.max() <= 0:
        return []
    flux = flux / flux.max()
    half = max(1, int(round(0.25 * rate / hop)))                  # the half second around a frame
    pad = np.pad(flux, half, mode="edge")
    window_med = np.lib.stride_tricks.as_strided(
        pad, shape=(flux.size, 2 * half + 1), strides=(pad.strides[0], pad.strides[0]))
    median = np.median(window_med, axis=1)
    threshold = median + delta
    out, last = [], -1e9
    for i in range(1, flux.size - 1):
        if flux[i] < threshold[i] or flux[i] < flux[i - 1] or flux[i] < flux[i + 1]:
            continue
        middle = ((i + 1) * hop + frame / 2.0) / float(rate)      # the flux at i is the rise into frame i+1, read at its middle
        t = foot(samples, middle, rate)
        if abs(t - middle) > 0.09:                                # a foot that ran away is not trusted
            t = middle
        if t - last < 0.03:
            continue
        out.append(t)
        last = t
    return out


def zero_cross(samples, about, rate=RATE, span=0.005, rising=True):
    """The zero crossing of the waveform nearest `about`, in seconds: the loop point that cannot click.

    Marko, 15.9.2026: "please make it mark my zero crossing waveform. The waveform must not be in some kind of
    amplitude. So at that point of transient, it needs to select the zero point of the waveform." A loop point
    that falls where the waveform stands at some amplitude steps from that amplitude to another at the seam,
    and that step is heard as a click; a point where the waveform crosses zero has nothing to step from. A
    crossing that RISES (from below zero to above it) is preferred to one that falls, so the loop's in and its
    out are cut the same way round and the seam keeps its direction as well as its level. The moment of the
    crossing is read between the two samples it lies between, so it is finer than a sample. With nothing to
    snap to inside `span`, `about` stands.

    Plain Python over any sequence of samples: it needs no numpy, and can be tested without one.
    """
    p = int(round(about * rate))
    lo, hi = max(1, p - int(span * rate)), min(len(samples), p + int(span * rate) + 1)
    best, best_kind, best_gap = None, 9, 0.0
    for i in range(lo, hi):
        a, b = samples[i - 1], samples[i]
        if a == 0.0:
            t, up = (i - 1) / float(rate), b > 0
        elif (a < 0) != (b < 0):
            total = abs(a) + abs(b)
            t, up = (i - 1 + (abs(a) / total if total else 0.0)) / float(rate), b > a
        else:
            continue
        kind = 0 if (up or not rising) else 1                      # a falling crossing is the second choice
        gap = abs(t - about)
        if best is None or (kind, gap) < (best_kind, best_gap):
            best, best_kind, best_gap = t, kind, gap
    return about if best is None else best


def sample_rate(path):
    """The audio's own sample rate, asked of ffprobe once; RATE when there is no ffprobe to ask."""
    if path in _rates:
        return _rates[path]
    rate = None
    if os.path.exists(FFPROBE):
        r = subprocess.run([FFPROBE, "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=sample_rate", "-of", "csv=p=0", path], capture_output=True)
        try:
            rate = int(r.stdout.decode().strip().split("\n")[0])
        except (ValueError, IndexError):
            rate = None
    _rates[path] = rate or RATE
    return _rates[path]


def float32(x):
    """A number as it comes out the other side of OSC, which carries every float in 32 bits."""
    return struct.unpack(">f", struct.pack(">f", x))[0]


def grid(beat):
    """The step between the beats a 32-bit float can hold here: 0.000244 beats at 3841, so 122 us at 120 bpm.

    MEASURED 15.9.2026: Live keeps a loop start exactly as it arrives - 3841.504049 was asked for, the wire
    made it 3841.504150391, and Live gave back 3841.504150391, to the last digit. So it is the wire, not Live,
    that says where a loop point may stand, and the zero crossing has to be chosen from the beats it can carry.
    """
    if not beat:
        return 2.0 ** -23
    return 2.0 ** (math.floor(math.log2(abs(beat))) - 23)


def interp(samples, x):
    """The waveform between its samples: `x` is a place in the list, not a whole one."""
    i = int(math.floor(x))
    if i < 0 or i + 1 >= len(samples):
        return None
    f = x - i
    return samples[i] * (1.0 - f) + samples[i + 1] * f


def snap(clip, at, tempo, span=0.0006):
    """The transient, moved to the waveform's zero - as near to it as the OSC wire can carry.

    The onsets are found in a window decoded to mono at 22050, which is enough to hear a stroke coming but not
    to say where the waveform is at zero: that is asked of the file at its own rate, once, for the one transient
    that was chosen. The true crossing is found first (`zero_cross`), and then every beat a 32-bit float can
    actually hold around it is looked at in turn and the one with the least waveform under it is taken - because
    a beat that is not on that grid is not where Live will put the loop. The search stays inside six tenths of a
    millisecond of the attack's foot: further out there is always some quieter place to hide, and hiding there
    would put the gap back that this whole thing is here to close.

    Returns the beat (already as the wire will carry it), the second it stands at, the waveform's value there,
    how far it moved from the attack's foot, how far the wire's grid forced it from the true crossing, and how
    far below the stroke itself the waveform there stands, in decibels - which is how loud a seam could ever be.
    """
    beat0 = float32(sec_to_beat(clip, at, tempo))
    plain = (beat0, at, None, 0.0, 0.0, 0.0)
    path = clip["path"]
    rate = sample_rate(path)
    reach = span + 0.002
    start = max(0.0, math.floor((at - reach) * rate) / float(rate))
    try:
        near = decode(path, start, 2 * reach, rate=rate)
    except Exception:
        return plain
    if len(near) < 8:
        return plain
    crossing = start + zero_cross(near, at - start, rate=rate)
    step = grid(beat0)
    steps = min(64, int(math.ceil(span / (step * 60.0 / (tempo or 120.0)))) + 1)
    best = None
    for k in range(-steps, steps + 1):
        b = float32(beat0 + k * step)
        sec = beat_to_sec(clip, b, tempo)
        if abs(sec - at) > span:
            continue
        where = (sec - start) * rate
        value = interp(near, where)
        if value is None:
            continue
        after = interp(near, where + 1)
        rising = after is not None and after > value
        key = (abs(value), 0 if rising else 1)
        if best is None or key < best[0]:
            best = (key, b, sec, value)
    if best is None:
        return plain
    _, b, sec, value = best
    body = max(abs(x) for x in near) or 1.0
    quiet = 20.0 * math.log10(max(abs(value), 1e-9) / body)      # how far the seam sits below the stroke itself
    return b, sec, value, sec - at, sec - crossing, quiet


def find(als, beat, tempo=120.0, track=None, direction="right", delta=0.25, windows=WINDOWS, zero=True):
    """The next transient to the right of `beat` in the arrangement: its beat, its second, and the file."""
    try:
        all_clips = read_set(als)
    except Exception as e:                                        # a set being written, a path gone
        return {"ok": False, "why": "the set could not be read: %s" % e}
    if not all_clips:
        return {"ok": False, "why": "no audio clip in the arrangement of this set"}
    clip = clip_at(all_clips, beat, track)
    if clip is None:
        return {"ok": False, "why": "no audio clip under the insert point"}
    here = beat_to_sec(clip, beat, tempo)
    end = beat_to_sec(clip, clip["end"], tempo)
    for span in windows:
        length = min(span, max(0.0, end - here)) if direction == "right" else min(span, max(0.0, here))
        if length <= 0.05:
            break
        start = here if direction == "right" else max(0.0, here - length)
        try:
            samples = decode(clip["path"], start, length)
        except Exception as e:
            return {"ok": False, "why": str(e)}
        found = [start + t for t in onsets(samples, delta=delta)]
        hit = pick(found, here, direction)
        if hit is not None:
            # the attack's foot, then the waveform's own zero on the grid the wire can carry (15.9.2026)
            if zero:
                b, at, value, moved, off, quiet = snap(clip, hit, tempo)
            else:
                b, at, value, moved, off, quiet = float32(sec_to_beat(clip, hit, tempo)), hit, None, 0.0, 0.0, 0.0
            return {"ok": True, "beat": b, "sec": at, "attack_sec": hit, "zero_ms": moved * 1000.0,
                    "zero_value": value, "zero_db": quiet, "crossing_ms": off * 1000.0, "from_sec": here,
                    "file": clip["path"], "clip": clip["name"], "track": clip["track"],
                    "listened": length, "found": len(found)}
        if length < span:
            break                                                 # the clip ended before the window did
    return {"ok": False, "why": "no transient found in this clip %s of the insert point" %
            ("to the right" if direction == "right" else "to the left")}


def main(argv):
    p = argparse.ArgumentParser(description="the next transient to the right of a beat of a Live set")
    p.add_argument("als")
    p.add_argument("beat", type=float)
    p.add_argument("--tempo", type=float, default=120.0)
    p.add_argument("--track", type=int, default=None)
    p.add_argument("--direction", default="right", choices=("right", "left"))
    p.add_argument("--delta", type=float, default=0.25)
    p.add_argument("--no-zero", action="store_true", help="do not snap to the waveform's zero crossing")
    a = p.parse_args(argv)
    print(json.dumps(find(a.als, a.beat, a.tempo, a.track, a.direction, a.delta, zero=not a.no_zero)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
