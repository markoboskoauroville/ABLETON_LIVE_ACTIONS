#!/usr/bin/env python3
"""fake_abletonosc.py: Live's OSC without Live, for testing the programs that talk to it (31.10.2026).

AbletonOSC listens on UDP 11000 and answers to the asker's address on port 11001. This does the same with made-up
values, so USE, LET GO (helpers/liveosc.py, manifest ableton-live-audio.md) can be tested with Live closed:

    /live/test                         -> ["ok"]
    /live/song/get/num_tracks          -> [3]
    /live/song/get/tempo               -> [120.0]
    /live/song/get/is_playing          -> [False]
    /live/track/get/<what> t           -> [t, "Track t" / 0 / False]   (the index first, as AbletonOSC does)
    any other /get/                    -> [args..., 0]
    /live/song/start_listen/is_playing -> pushes /live/song/get/is_playing [False] to 11001 every second (a listener)

It refuses to start while Live (or anything) holds 11000. Every message it hears is printed.

    python3 fake_abletonosc.py
"""
import socket, struct, sys, threading, time

sys.path.insert(0, __file__.rsplit("/tests/", 1)[0] + "/helpers")
from liveosc import encode, decode   # noqa: E402

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.bind(("127.0.0.1", 11000))
except OSError:
    sys.exit("11000 is held (Live is running?): the fake does not start")
listeners = set()


def reply(host, address, args):
    s.sendto(encode(address, args), (host, 11001))


def pusher():
    while True:
        time.sleep(1)
        for host in list(listeners):
            reply(host, "/live/song/get/is_playing", [False])


threading.Thread(target=pusher, daemon=True).start()
print("fake AbletonOSC on 11000, answers to 11001", flush=True)
while True:
    data, (host, port) = s.recvfrom(65536)
    a, args = decode(data)
    if a is None:
        continue
    print("heard", a, args, flush=True)
    if a == "/live/test":
        reply(host, a, ["ok"])
    elif a.startswith("/live/song/start_listen/"):
        listeners.add(host)
    elif a == "/live/song/get/num_tracks":
        reply(host, a, [3])
    elif a == "/live/song/get/tempo":
        reply(host, a, [120.0])
    elif a == "/live/song/get/is_playing":
        reply(host, a, [False])
    elif a.startswith("/live/track/get/") and args and isinstance(args[0], int):
        t = args[0]
        what = a.rsplit("/", 1)[1]
        reply(host, a, [t, f"Track {t}" if what == "name" else (False if what in ("mute", "solo") else 0)])
    elif "/get/" in a:
        reply(host, a, list(args) + [0])
