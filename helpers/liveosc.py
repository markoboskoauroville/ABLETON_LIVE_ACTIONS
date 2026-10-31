#!/usr/bin/env python3
"""liveosc.py: Live's OSC, shared by every program on this Mac. USE, LET GO.

Marko, 31.10.2026: "if there are two sessions accessing at the same time, one cannot block the other. If one is not
using it, you can use it. It's not permanent block. You use it and you let go. Always like this. Use, let go."

AbletonOSC (Live's Control Surface) takes questions on UDP 11000 and answers to port 11001, always 11001. Until today a
program bound 11001 and kept it while it lived (MANTRA_STAR a1_ears.py, Ableton Live Actions' wire), and every other
program got no answers. Now nobody keeps it:

  * a QUESTION (an address with /get/, or /live/test) takes the turn (an exclusive flock on ~/.config/liveosc.lock),
    binds 11001, asks, reads its own answer, closes the port and lets the turn go: tens of milliseconds, at most WAIT;
  * an ORDER (set, play, stop ...) has no answer: it goes out from any socket, no turn, no port.

A program waiting for its turn waits at most TURN seconds; a turn is never longer than WAIT, so nobody waits long.
Datagrams that are not this question's answer (a listener's push, another program's late answer) are dropped.

    from liveosc import ask, tell
    ask("/live/song/get/tempo")              -> [120.0]   (None if Live did not answer)
    ask("/live/track/get/name", 0)           -> [0, "Gabrijela Adobe"]
    tell("/live/song/set/tempo", 100.0)

    python3 liveosc.py /live/song/get/tempo            (a question from the shell; prints the answer as JSON)
"""
import fcntl
import json
import os
import socket
import struct
import sys
import time

LIVE = ("127.0.0.1", 11000)
ANSWER = 11001
LOCK = os.path.expanduser("~/.config/liveosc.lock")
WAIT = 1.5          # the longest a turn is held: one question and its answer
TURN = 6.0          # the longest a program waits for its turn


def pad(b):
    return b + b"\0" * (4 - len(b) % 4)


def encode(address, args):
    tags, body = b",", b""
    for a in args:
        if isinstance(a, bool):
            tags += b"T" if a else b"F"
        elif isinstance(a, int):
            tags += b"i"; body += struct.pack(">i", a)
        elif isinstance(a, float):
            tags += b"f"; body += struct.pack(">f", a)
        else:
            tags += b"s"; body += pad(str(a).encode("utf-8"))
    return pad(address.encode("utf-8")) + pad(tags) + body


def decode(data):
    """(address, [args]); address None when it is not an OSC message"""
    if not data.startswith(b"/"):
        return None, []
    z = data.find(b"\0")
    address = data[:z].decode("utf-8", "replace")
    p = (z // 4 + 1) * 4
    if p >= len(data) or data[p:p + 1] != b",":
        return address, []
    z2 = data.find(b"\0", p)
    tags = data[p + 1:z2].decode("ascii", "replace")
    p = (z2 // 4 + 1) * 4
    out = []
    for t in tags:
        if t == "f": out.append(struct.unpack(">f", data[p:p + 4])[0]); p += 4
        elif t == "i": out.append(struct.unpack(">i", data[p:p + 4])[0]); p += 4
        elif t == "d": out.append(struct.unpack(">d", data[p:p + 8])[0]); p += 8
        elif t == "s":
            e = data.find(b"\0", p); e = len(data) if e < 0 else e
            out.append(data[p:e].decode("utf-8", "replace")); p = (e // 4 + 1) * 4
        elif t == "T": out.append(True)
        elif t == "F": out.append(False)
        else: break
    return address, out


def is_question(address):
    return "/get/" in address or address == "/live/test"


def holder():
    """who has 11001 bound right now (a program from before USE, LET GO keeps it)"""
    try:
        import subprocess
        out = subprocess.run(["/usr/sbin/lsof", "-nP", "-iUDP:%d" % ANSWER, "-Fpc"], capture_output=True, text=True).stdout
        return ", ".join(l[1:] for l in out.splitlines() if l.startswith("c")) or "nobody"
    except Exception:
        return "unknown"


class Turn:
    """the exclusive turn on Live's answer port, for one question"""
    def __enter__(self):
        os.makedirs(os.path.dirname(LOCK), exist_ok=True)
        self.f = open(LOCK, "a+")
        end = time.time() + TURN
        while True:
            try:
                fcntl.flock(self.f, fcntl.LOCK_EX | fcntl.LOCK_NB); break
            except OSError:
                if time.time() > end:
                    self.f.close(); raise TimeoutError("no turn on Live's OSC in %.0f s" % TURN)
                time.sleep(0.01)
        self.s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        end = time.time() + WAIT
        while True:
            try:
                self.s.bind(("127.0.0.1", ANSWER)); break
            except OSError:
                # a program from before USE, LET GO still keeps 11001
                if time.time() > end:
                    self.s.close(); fcntl.flock(self.f, fcntl.LOCK_UN); self.f.close()
                    raise OSError("port %d is kept by %s (an old version: it must let go)" % (ANSWER, holder()))
                time.sleep(0.05)
        return self.s

    def __exit__(self, *exc):
        self.s.close()                                   # let go: the port first, then the turn
        fcntl.flock(self.f, fcntl.LOCK_UN); self.f.close()


def ask(address, *args, wait=WAIT):
    """a question to Live; its answer's arguments, or None when Live did not answer in time"""
    with Turn() as s:
        s.settimeout(0.05)
        s.sendto(encode(address, args), LIVE)
        end = time.time() + wait
        while time.time() < end:
            try:
                data = s.recv(65536)
            except socket.timeout:
                continue
            a, r = decode(data)
            if a == "/live/error":
                raise RuntimeError(" ".join(map(str, r)))
            # a question about a track or a clip is answered with its index first: only this one's answer counts
            if a == address and (not args or not isinstance(args[0], int) or (r and r[0] == args[0])):
                return r
    return None


_spare = None


def tell(address, *args):
    """an order to Live: no answer, so no turn and no port"""
    global _spare
    if _spare is None:
        _spare = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    _spare.sendto(encode(address, args), LIVE)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(2)
    def arg(x):
        try: return json.loads(x)
        except ValueError: return x
    a = [arg(x) for x in sys.argv[2:]]
    if is_question(sys.argv[1]):
        print(json.dumps(ask(sys.argv[1], *a)))
    else:
        tell(sys.argv[1], *a); print("sent")
