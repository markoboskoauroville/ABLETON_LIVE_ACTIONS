"""THE EYE AND THE HAND FOR CQ MIXPAD (Marko, 27.10.2026: "actions should be able to open CQ Mixpad and change settings
in the mixer, in this case multi-track streaming, and anything else we need in the future").

MixPad (Qt/QML) draws its own buttons: no accessibility tree (MANTRA_MANIFEST cq-mixer-virtual-soundcheck.md). So the
eye photographs MixPad's window (screencapture -l, the window only) and reads every word on it with macOS Vision; the
hand clicks a word's centre (a Quartz click, the pointer put back where it was). Every macro that touches the mixer
goes through here.

    python3 mixpad.py open            MixPad running, its window id and frame
    python3 mixpad.py words           every word seen, with its point on the screen
    python3 mixpad.py click <word>    click the first word that matches (case not minded)
    python3 mixpad.py shot <file>     the window's picture
"""
import os, subprocess, sys, time

import Quartz
import Vision
from Foundation import NSURL

APP = "CQ MixPad 1.2.2"
OWNER = "CQ MixPad"


def window():
    """MixPad's main window, the one named "CQMixpad": (id, x, y, w, h) in screen points, or None. (Beside it MixPad
    keeps unnamed full-screen and menu-bar windows of the same owner: never those.)"""
    for w in Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID) or []:
        if str(w.get("kCGWindowOwnerName", "")).startswith(OWNER) and w.get("kCGWindowName") == "CQMixpad":
            b = w["kCGWindowBounds"]
            return (w["kCGWindowNumber"], b["X"], b["Y"], b["Width"], b["Height"])
    return None


def macbook():
    """the MacBook Pro's own screen in Quartz points (x, y, w, h): the built-in display, never the BenQ
    (Marko, 27.10.2026: "Please do all your testing now on the MacBook Pro screen, not on the BenQ")"""
    ids = Quartz.CGGetActiveDisplayList(16, None, None)[1]
    for d in ids:
        if Quartz.CGDisplayIsBuiltin(d):
            b = Quartz.CGDisplayBounds(d)
            return b.origin.x, b.origin.y, b.size.width, b.size.height
    b = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
    return b.origin.x, b.origin.y, b.size.width, b.size.height


def on_macbook(w=None):
    w = w or window()
    x, y, mw, mh = macbook()
    return bool(w) and x <= w[1] + w[3] / 2 < x + mw


def rectangle(action):
    """a Rectangle action on the window in front (Marko, 27.10.2026: "Please don't drag ... windows through the
    screens. You can snap everything very quickly. Use this as much as you can. Rectangle.")"""
    subprocess.run(["/usr/bin/open", "-g", f"rectangle://execute-action?name={action}"], capture_output=True)
    time.sleep(0.9)


def place():
    """MixPad on the MacBook Pro screen, maximized by Rectangle, so the eye can see it. Native full screen is left
    first (Rectangle cannot snap a full-screen space; a space that is not showing photographs empty)."""
    front()
    subprocess.run(["/usr/bin/osascript", "-e", f'''tell application "System Events" to tell process "{APP}"
  if (count of windows) > 0 then
    if value of attribute "AXFullScreen" of window 1 then set value of attribute "AXFullScreen" of window 1 to false
  end if
end tell'''], capture_output=True)
    time.sleep(0.5)
    for _ in range(3):
        if on_macbook():
            break
        front(); rectangle("next-display")
    front(); rectangle("maximize")
    return window()


def running():
    return subprocess.run(["/usr/bin/pgrep", "-f", APP + ".app/Contents/MacOS"], capture_output=True).returncode == 0


def open_app(wait=20):
    if not running() or not window():
        subprocess.run(["/usr/bin/open", "/Applications/" + APP + ".app"])
    end = time.time() + wait
    while time.time() < end:
        w = window()
        if w:
            time.sleep(1.5)       # the QML page draws a moment after the window appears
            return place()
        time.sleep(0.5)
    return None


def front():
    subprocess.run(["/usr/bin/osascript", "-e", f'tell application "/Applications/{APP}.app" to activate'], capture_output=True)
    time.sleep(0.6)


def shot(path=None):
    w = window()
    if not w:
        return None, None
    path = path or os.path.join(os.environ.get("TMPDIR", "/tmp"), f"mixpad-{os.getpid()}.png")
    subprocess.run(["/usr/sbin/screencapture", "-x", "-o", "-l", str(w[0]), path], capture_output=True)
    return (path if os.path.exists(path) else None), w


def read(keep=False):
    """[(text, x, y, box)]: each line Vision reads, its centre in screen points, and its box in the picture
    (0..1, origin top left); keep=True also gives the picture's path (the caller removes it)"""
    path, w = shot()
    if not path:
        return ([], None) if keep else []
    req = Vision.VNRecognizeTextRequest.alloc().init()
    req.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    req.setUsesLanguageCorrection_(False)
    h = Vision.VNImageRequestHandler.alloc().initWithURL_options_(NSURL.fileURLWithPath_(path), None)
    h.performRequests_error_([req], None)
    out = []
    for r in req.results() or []:
        c = r.topCandidates_(1)[0]
        bb = r.boundingBox()          # 0..1, origin bottom left
        box = (bb.origin.x, 1 - bb.origin.y - bb.size.height, bb.size.width, bb.size.height)
        x = w[1] + (box[0] + box[2] / 2) * w[3]
        y = w[2] + (box[1] + box[3] / 2) * w[4]
        out.append((str(c.string()), round(x), round(y), box))
    if keep:
        return out, path
    os.remove(path)
    return out


def words():
    return [s[:3] for s in read()]


def lit(text):
    """True when the word is drawn in MixPad's green (the chosen one of a pair: Stereo / Multitrack, 48 / 96 kHz),
    False when it is grey or white, None when the word is not seen"""
    seen, path = read(keep=True)
    if not path:
        return None
    try:
        s = find(text, seen)
        if not s:
            return None
        from AppKit import NSBitmapImageRep
        rep = NSBitmapImageRep.imageRepWithContentsOfFile_(path)
        W, H = rep.pixelsWide(), rep.pixelsHigh()
        bx, by, bw, bh = s[3]
        green = ink = 0
        for i in range(24):
            for j in range(8):
                c = rep.colorAtX_y_(int((bx + bw * (i + .5) / 24) * W), int((by + bh * (j + .5) / 8) * H))
                r, g, b = c.redComponent(), c.greenComponent(), c.blueComponent()
                if max(r, g, b) < 0.35:
                    continue                      # the background, not the letters
                ink += 1
                if g > r + 0.2 and g > b - 0.05:
                    green += 1
        return ink > 0 and green / ink > 0.4
    finally:
        os.remove(path)


def find(text, seen=None):
    t = text.lower()
    seen = words() if seen is None else seen
    exact = [s for s in seen if s[0].strip().lower() == t]
    return (exact or [s for s in seen if t in s[0].lower()] or [None])[0]


def click_at(x, y):
    back = Quartz.CGEventGetLocation(Quartz.CGEventCreate(None))
    for kind in (Quartz.kCGEventLeftMouseDown, Quartz.kCGEventLeftMouseUp):
        e = Quartz.CGEventCreateMouseEvent(None, kind, (x, y), Quartz.kCGMouseButtonLeft)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, e)
        time.sleep(0.06)
    time.sleep(0.1)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventMouseMoved, back, 0))


def click(text, seen=None):
    """front, find, click; True when the word was there"""
    front()
    s = find(text, seen)
    if not s:
        return False
    click_at(s[1], s[2])
    time.sleep(1.2)
    return True


# MARK: the steps a macro takes (each returns words for the macro's log; found 27.10.2026 on MixPad 1.2.2, CQ-12T)

def connect(unit="CQ12T", wait=20):
    """MixPad open on the MacBook Pro screen and connected. On its "Choose Unit" page: the mixer must be in the list
    (CQ12T_2225 here), it is chosen and Connect clicked. Returns (True, words) or (False, why)."""
    if not open_app():
        return False, "CQ MixPad did not open"
    seen = read()
    if find("CONFIG", seen) and find("HOME", seen):
        return True, "CQ MixPad: already connected"
    if not find("Choose Unit", seen):
        return False, "CQ MixPad shows neither its unit list nor the mixer"
    u = find(unit, seen)
    if not u:
        time.sleep(3)        # MixPad finds mixers on the network by itself: one more look after a moment
        seen = read(); u = find(unit, seen)
        if not u:
            return False, f"no {unit} in CQ MixPad's list (same network? the mixer on?)"
    front(); click_at(u[1], u[2]); time.sleep(0.6)
    if not click("Connect"):
        return False, "CQ MixPad's Connect button was not seen"
    end = time.time() + wait
    while time.time() < end:
        time.sleep(1.5)
        seen = read()
        if find("CONFIG", seen) and find("HOME", seen):
            return True, f"CQ MixPad: {u[0]} in the list, Connect clicked, connected"
    return False, "CQ MixPad: Connect clicked, but the mixer's pages never came"


USB_TAB = (0.4525, 0.143)      # CONFIG's third tab is three icons (USB, SD, Bluetooth), no words: its place in the window


def usb_page():
    """CONFIG › USB / SD; True when its "Stream Mode" is seen"""
    if not click("CONFIG"):
        return False
    time.sleep(1)
    w = window(); front(); click_at(w[1] + USB_TAB[0] * w[3], w[2] + USB_TAB[1] * w[4]); time.sleep(1.2)
    return bool(find("Stream Mode"))


def stream_mode(want="Multitrack"):
    """CONFIG › USB / SD › Stream Mode: (was, now). "Multitrack" is 16 × 16 on USB; "Stereo" is two."""
    if not usb_page():
        return None, None
    other = "Stereo" if want == "Multitrack" else "Multitrack"
    was = want if lit(want) else other if lit(other) else None
    if was != want:
        click(want); time.sleep(1.5)
    return was, (want if lit(want) else other if lit(other) else None)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "words"
    if cmd == "open":
        print(open_app() or "MixPad did not open")
    elif cmd == "words":
        for s in words():
            print(f"{s[1]:5} {s[2]:5}  {s[0]}")
    elif cmd == "click":
        print("clicked" if click(" ".join(sys.argv[2:])) else "not seen: " + " ".join(sys.argv[2:]))
    elif cmd == "connect":
        print(connect()[1])
    elif cmd == "stream":
        print(stream_mode(sys.argv[2] if len(sys.argv) > 2 else "Multitrack"))
    elif cmd == "lit":
        print(lit(" ".join(sys.argv[2:])))
    elif cmd == "shot":
        print(shot(sys.argv[2] if len(sys.argv) > 2 else None)[0])
