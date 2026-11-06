#!/usr/bin/env python3
"""Drives the user's iPhone through iPhone Mirroring (macOS) to lay out the home screen: the steps no app may do itself.
Used on 2026-11-05 to build the author's home screen: each of the 24 icons as a Shortcuts "Open App" shortcut with
Baroque's icon file (make_icon), the dock, page one (Day large over eight icons) and page two (Day, Today and Quote
small among twelve icons).

How it works: it photographs the iPhone Mirroring window (screencapture), reads it with Vision (scripts/mirror/ocr.swift,
built to build/mirror-ocr), recognises the user's 24 icons by their pictures (the phone shows large icons without
names), and taps, drags and types with cliclick (Homebrew). Every look is saved to build/mirror-shots/.

What iPhone Mirroring does with synthetic input (learned the hard way):
- A click is a tap. Text typed with cliclick arrives; Return only arrives through System Events (key()).
- A drag that starts on an icon or widget picks it up at once (no long press), and one that starts on bare wallpaper
  swipes the page: page swipes run along SWIPE_Y, below the grid. Drags don't scroll lists inside apps, and
  synthetic scroll-wheel events are ignored, so app screens that need scrolling are reached another way: launch
  Baroque through devicectl with -scrollTo <section> (xcrun devicectl device process launch ... -- -scrollTo github).
- A widget released straight after moving is often missed; drag(dwell=) rests and nudges it before letting go.
- Dropping a widget on another of the same size makes a stack, and an icon on an icon makes a folder.
- Mirroring ends whenever the phone is unlocked; lock it and tap Connect.

Needs: iPhone Mirroring set up and the phone locked nearby; cliclick (brew install cliclick); Accessibility and Screen
Recording allowed for the app this runs in. It takes over the mouse while it runs. It never types the passcode or the
GitHub token, and never removes or deletes anything.

Run: python3 scripts/mirror_setup.py survey      (pages through the home screen and reads it; changes nothing)
Or from Python: Phone(), layout(phone) and show() to read a page, add_widget(phone, "Quote medium") to add one of
Baroque's widgets to the top of the current page, phone.drag(...) to move things.
"""
import json
import os
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OCR = os.path.join(ROOT, "build", "mirror-ocr")
WINID = os.path.join(ROOT, "build", "mirror-winid")
SHOTS = os.path.join(ROOT, "build", "mirror-shots")
APP = "iPhone Mirroring"
# The phone's screen inside the window, in points: the window is the screen plus a strip at the top for its toolbar.
INSET_X, INSET_TOP, SCREEN_W, SCREEN_H = 9, 39, 392, 852


# The home screen grid on the iPhone 15 Pro with large icons, in points: column and row centres, and the dock.
COLS = [56, 149, 243, 336]
ROWS = [117, 210, 303, 396, 490, 582]
DOCK_Y, DOCK_X = 785, [64, 152, 240, 328]
SWIPE_Y = 660
ICONS = os.path.join(ROOT, "Baroque", "Assets.xcassets", "HomeIcons")


def run(*args, check=True):
    return subprocess.run(args, capture_output=True, text=True, check=check).stdout.strip()


def osa(script):
    return run("osascript", "-e", script)


class Word:
    def __init__(self, d):
        self.text = d["text"]
        self.conf = d["conf"]
        self.x, self.y = d["x"] * SCREEN_W, d["y"] * SCREEN_H
        self.w, self.h = d["w"] * SCREEN_W, d["h"] * SCREEN_H

    @property
    def center(self):
        return self.x + self.w / 2, self.y + self.h / 2

    def __repr__(self):
        return f"{self.text!r}@({self.center[0]:.0f},{self.center[1]:.0f})"


class Phone:
    """The mirrored phone, addressed in the phone's own points (393 x 852 on the iPhone 15 Pro)."""

    def __init__(self):
        if not os.path.exists(OCR) or os.path.getmtime(OCR) < os.path.getmtime(os.path.join(ROOT, "scripts/mirror/ocr.swift")):
            os.makedirs(os.path.dirname(OCR), exist_ok=True)
            run("swiftc", "-O", os.path.join(ROOT, "scripts/mirror/ocr.swift"), "-o", OCR)
        os.makedirs(SHOTS, exist_ok=True)
        self.step = 0
        self.focus()

    # The window
    def focus(self):
        run("open", "-a", APP)
        for _ in range(20):
            try:
                pos = osa(f'tell application "System Events" to tell process "{APP}" to get position of window 1')
                self.wx, self.wy = (int(v) for v in pos.split(", "))
                time.sleep(0.5)
                return
            except (subprocess.CalledProcessError, ValueError):
                time.sleep(1)
        sys.exit("iPhone Mirroring didn't open a window: lock the phone, keep it nearby, and open iPhone Mirroring once by hand.")

    def menu(self, item):
        """View > Home Screen, App Switcher or Spotlight."""
        osa(f'tell application "System Events" to tell process "{APP}" to click menu item "{item}" of menu 1 of menu bar item "View" of menu bar 1')
        time.sleep(1.2)

    def to_global(self, x, y):
        return int(self.wx + INSET_X + x), int(self.wy + INSET_TOP + y)

    # Seeing
    def look(self, name="look"):
        """Photographs the screen and reads it: the words, top to bottom."""
        self.step += 1
        name = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:28]
        path = os.path.join(SHOTS, f"{time.strftime('%H%M%S')}-{self.step:03d}-{name}.png")
        # The window alone (screencapture -l), so nothing lying over it ends up in the picture; then the screen part.
        if not os.path.exists(WINID):
            run("swiftc", "-O", os.path.join(ROOT, "scripts/mirror/winid.swift"), "-o", WINID)
        run("screencapture", "-x", "-o", f"-l{run(WINID)}", path)
        from PIL import Image
        im = Image.open(path)
        k = im.width / (SCREEN_W + 2 * INSET_X + 1)
        im.crop((round(INSET_X * k), round(INSET_TOP * k), round((INSET_X + SCREEN_W) * k), round((INSET_TOP + SCREEN_H) * k))).save(path)
        words = [Word(json.loads(line)) for line in run(OCR, path).splitlines() if line.strip()]
        self.last = path
        return sorted(words, key=lambda w: (round(w.y / 8), w.x))

    def find(self, label, exact=True, words=None, below=0, above=SCREEN_H):
        words = words if words is not None else self.look(label)
        want = label.lower()
        for w in words:
            got = w.text.lower().strip(" .…>›")
            if (got == want if exact else want in got) and below <= w.center[1] <= above:
                return w
        return None

    def wait(self, label, timeout=10, **kw):
        end = time.time() + timeout
        while True:
            w = self.find(label, **kw)
            if w or time.time() > end:
                return w
            time.sleep(0.8)

    # Touching
    def tap_at(self, x, y, pause=1.0):
        gx, gy = self.to_global(x, y)
        run("cliclick", f"c:{gx},{gy}")
        time.sleep(pause)

    def tap(self, label, timeout=10, **kw):
        w = self.wait(label, timeout, **kw)
        if not w:
            raise LookupError(f"Couldn't find {label!r} on the screen (see {self.last})")
        self.tap_at(*w.center)
        return w

    def hold(self, x, y, seconds=1.2):
        gx, gy = self.to_global(x, y)
        run("cliclick", f"dd:{gx},{gy}", f"w:{int(seconds * 1000)}", f"du:{gx},{gy}")
        time.sleep(0.8)

    def drag(self, x1, y1, x2, y2, hold=0.0, steps=12, step_ms=16, dwell=0.0):
        """A finger drag. Through iPhone Mirroring a drag that starts on an icon or widget picks it up at once, and one
        that starts on bare wallpaper swipes the page. hold: a pause before moving; dwell: a pause before letting go."""
        a, b = self.to_global(x1, y1), self.to_global(x2, y2)
        cmds = [f"dd:{a[0]},{a[1]}"]
        if hold:
            cmds.append(f"w:{int(hold * 1000)}")
        for i in range(1, steps + 1):
            t = i / steps
            cmds += [f"dm:{int(a[0] + (b[0] - a[0]) * t)},{int(a[1] + (b[1] - a[1]) * t)}", f"w:{step_ms}"]
        if dwell:
            # Rest, nudge and rest again before letting go: a widget released straight after moving is often missed,
            # and a second release then cancels the move.
            cmds += [f"w:{int(dwell * 1000)}", f"dm:{b[0] + 3},{b[1] + 2}", "w:400", f"dm:{b[0]},{b[1]}", f"w:{int(dwell * 1000)}"]
        cmds.append(f"du:{b[0]},{b[1]}")
        run("cliclick", *cmds)
        time.sleep(0.8)

    # Page swipes run along the strip of wallpaper between the grid's last row and the page dots, where nothing sits.
    def swipe_left(self):    # to the next page
        self.drag(330, SWIPE_Y, 50, SWIPE_Y, steps=20, step_ms=12)
        self.release(50, SWIPE_Y)

    def swipe_right(self):   # to the previous page
        self.drag(60, SWIPE_Y, 340, SWIPE_Y, steps=20, step_ms=12)
        self.release(340, SWIPE_Y)

    def release(self, x, y):
        """A second finger-up: now and then the phone misses a swipe's release and stops between two pages."""
        gx, gy = self.to_global(x, y)
        run("cliclick", f"du:{gx},{gy}")
        time.sleep(1.2)

    def type(self, text):
        run("cliclick", f"t:{text}")
        time.sleep(0.5)

    def clear_field(self):
        """Select all in the focused text field and delete it (Spotlight keeps the last search)."""
        osa(f'tell application "{APP}" to activate')
        osa('tell application "System Events" to keystroke "a" using command down')
        time.sleep(0.3)
        self.key("delete")

    def key(self, name):
        """return, enter, escape, delete or tab. cliclick's key presses don't reach the phone; System Events' do."""
        codes = {"return": 36, "enter": 76, "escape": 53, "delete": 51, "tab": 48}
        osa(f'tell application "{APP}" to activate')
        osa(f'tell application "System Events" to key code {codes[name]}')
        time.sleep(0.6)

    # Places
    def home(self, page=1):
        """The home screen, on `page` (Home Screen twice lands on page one)."""
        self.menu("Home Screen")
        self.menu("Home Screen")
        for _ in range(page - 1):
            self.swipe_left()

    def open_app(self, name):
        """Spotlight (from the Home Screen: inside some apps the menu item does nothing), the app's name, its Top Hit."""
        self.menu("Home Screen")
        self.menu("Spotlight")
        self.clear_field()
        self.type(name)
        time.sleep(2)
        words = self.look(f"spotlight-{name}")
        top = self.find("Top Hit", words=words)
        hit = next((w for w in words if top and w.center[1] > top.center[1] and w.text.lower().startswith(name.lower())), None)
        if not hit:
            raise LookupError(f"Spotlight didn't offer {name} (see {self.last})")
        self.tap_at(*hit.center, pause=2.5)
        if self.find("Top Hit"):                           # still in Spotlight: the hit is a label under an icon
            self.tap_at(hit.center[0], hit.center[1] - 40, pause=2.5)


# Baroque's widgets in the gallery, in the order of its page dots (each dot jumps straight to its widget).
GALLERY = ["Day small", "Day medium", "Day large", "Today small", "Today medium",
           "Quote small", "Quote medium", "Quote large", "Battery small"]
GALLERY_DOTS_Y, GALLERY_DOT0_X, GALLERY_DOT_STEP = 726, 129.5, 16.6


def add_widget(phone, which):
    """Adds one of Baroque's widgets to the top of the current page (the page is in edit mode or gets put in it)."""
    words = phone.look("before-add-widget")
    if not phone.find("Search Widgets", words=words, exact=False):
        if not phone.find("Add Widget", words=words, exact=False, above=150):
            if not phone.find("Edit", words=words, above=60):
                phone.hold(196, SWIPE_Y, 1.5)              # long press on bare wallpaper: edit mode
            phone.tap("Edit", timeout=4, above=60)
        phone.tap("Add Widget", timeout=4, exact=False, above=150)   # the menu's item ("Add Widget" with its icon)
        time.sleep(1.2)
    phone.tap("Search Widgets", timeout=4, exact=False)
    phone.clear_field()
    phone.type("Baroque")
    time.sleep(1.5)
    words = phone.look("gallery-search")
    hit = next((w for w in words if w.text.strip() == "Baroque" and w.center[1] > 190), None)
    if not hit:
        raise LookupError(f"The gallery found no Baroque widgets (see {phone.last})")
    phone.tap_at(*hit.center, pause=2)
    phone.tap_at(GALLERY_DOT0_X + GALLERY_DOT_STEP * GALLERY.index(which), GALLERY_DOTS_Y, pause=1.2)
    phone.tap("Add Widget", timeout=4, below=700)
    time.sleep(2.5)


# The user's own shortcuts that already open these apps, by name (seen in their library on 2026-11-05).
SHORTCUT_NAMES = {"AllTrails": ["Trails", "AllTrails"], "YouTube": ["Watch", "YouTube"], "Messages": ["Texts", "Messages"]}
APP_NAMES = {"Equinox": "Equinox+"}                     # as Open App's app list names them, where that differs


def shortcuts_library(phone):
    """The Shortcuts app on All Shortcuts, scrolled to the top."""
    phone.open_app("Shortcuts")
    time.sleep(1)
    for _ in range(5):
        words = phone.look("shortcuts")
        row = phone.find("All Shortcuts", words=words)
        if phone.find("Share Sheet", words=words, exact=False) and row:   # the folder list: open All Shortcuts
            phone.tap_at(*row.center, pause=1.5)
            continue
        if phone.find("All Shortcuts", words=words, above=165):
            if phone.find("interrupted", words=words, exact=False):    # "Shortcuts was interrupted." OK
                phone.tap("OK", timeout=2)
            phone.tap_at(196, 8, pause=1.2)                # the status bar: back to the top, where Search is
            return phone.look("shortcuts-top")
        back = phone.find("<", words=words, above=110)
        phone.tap_at(*(back.center if back else (37, 81)), pause=1.2)
    raise LookupError(f"Couldn't get back to All Shortcuts (see {phone.last})")


def open_existing_shortcut(phone, app):
    """Opens the user's shortcut for `app` in the editor if one exists and its action is Open <app>. True if it did."""
    for name in SHORTCUT_NAMES.get(app, [app]):
        words = shortcuts_library(phone)
        for _ in range(3):                                 # the search field, under All Shortcuts; typing lands once it's active
            phone.tap_at(150, 187, pause=1.2)
            phone.clear_field()
            phone.type(name)
            time.sleep(1.5)
            words = phone.look(f"search-{name}")
            if any(name.lower() in w.text.lower() for w in words if w.center[1] < 230):
                break
        else:
            raise LookupError(f"Typing {name!r} didn't reach the search field (see {phone.last})")
        card = next((w for w in words if w.text.strip().lower() == name.lower() and w.center[1] > 220), None)
        if not card:
            phone.tap_at(355, 186, pause=1)                # the search field's X
            continue
        dots_x = 160 if card.center[0] < 196 else 346
        phone.tap_at(dots_x, card.center[1] - 58, pause=2)   # the card's "..." opens the editor (the card runs it)
        words = phone.look(f"editor-{name}")
        text = " ".join(w.text for w in words)
        if "Open" in text and APP_NAMES.get(app, app).split()[0].lower() in text.lower():
            return True
        print(f"  {name}: not an Open {app} shortcut ({text[:80]})")
    return False


def create_shortcut(phone, app):
    """A new shortcut: Open <app>, named after the app."""
    shortcuts_library(phone)
    for _ in range(3):
        phone.tap_at(355, 80, pause=2)                     # +
        if phone.wait("Search Actions", timeout=3, exact=False):
            break
    phone.tap("Search Actions", timeout=4, exact=False)
    phone.type("Open App")
    open_app_action(phone)
    phone.tap("App", timeout=4, below=120, above=400)      # the blue App placeholder
    time.sleep(1.2)
    pick_app(phone, app)


def open_app_action(phone):
    """Taps the Open App action once the action search has listed it (it can take a few seconds)."""
    for _ in range(8):
        time.sleep(1)
        words = phone.look("actions-open-app")
        hit = next((w for w in words if w.text.strip() == "Open App" and w.center[1] > 130), None)
        if hit:
            phone.tap_at(*hit.center, pause=1.5)
            return
    raise LookupError(f"No Open App action (see {phone.last})")


def pick_app(phone, app):
    """In Open App's app list: its search (at the bottom), the app's name, the app."""
    phone.tap("Search", timeout=4, exact=False, below=650)
    phone.type(APP_NAMES.get(app, app))
    time.sleep(1.5)
    words = phone.look(f"app-picker-{app}")
    hit = next((w for w in words if w.text.strip().lower() == APP_NAMES.get(app, app).lower() and 150 < w.center[1] < 700), None)
    if not hit:                                            # (the search field at the bottom holds the same words)
        raise LookupError(f"The app picker didn't list {app} (see {phone.last})")
    phone.tap_at(*hit.center, pause=1.5)


def name_shortcut(phone, app):
    """Renames the shortcut in the editor after the app."""
    phone.tap_at(198, 80, pause=1.2)
    phone.tap("Rename", timeout=3, exact=False)
    phone.clear_field()
    phone.type(app)
    phone.key("return")
    time.sleep(1)
    if phone.find("already have a shortcut", exact=False):    # the user has one by that name that does something else
        phone.tap("OK", timeout=3)
        phone.tap_at(198, 80, pause=1.2)
        phone.tap("Rename", timeout=3, exact=False)
        phone.clear_field()
        phone.type(f"Open {app}")
        phone.key("return")
        time.sleep(1)


def add_to_home_screen(phone, app):
    """From the shortcut's editor: Add to Home Screen with Baroque's icon file for `app`."""
    phone.tap_at(198, 80, pause=1.2)                       # the title's menu
    phone.tap("Add to Home Screen", timeout=3, exact=False)
    time.sleep(2)
    phone.tap_at(104, 358, pause=1.2)                      # Image
    phone.tap("Choose File", timeout=3)
    time.sleep(2.5)
    phone.tap_at(68, 160, pause=1)                         # the file picker's search
    phone.clear_field()
    phone.type(f"Baroque {app}")
    time.sleep(2.5)
    words = phone.look(f"file-{app}")
    if not phone.find(f"Baroque {app}", words=words, exact=False):
        raise LookupError(f"No icon file for {app} (see {phone.last})")
    phone.tap_at(66, 302, pause=2.5)                       # the one result
    words = phone.look(f"home-sheet-{app}")
    if not phone.find("Home Screen", words=words):
        raise LookupError(f"The Home Screen sheet didn't come back (see {phone.last})")
    phone.tap("Add", timeout=3, above=140)
    time.sleep(2)


def make_icon(phone, app):
    """One home screen icon that opens `app` directly: its shortcut (the user's own, or a new one) with Baroque's icon."""
    reused = open_existing_shortcut(phone, app)
    if not reused:
        create_shortcut(phone, app)
        name_shortcut(phone, app)
    add_to_home_screen(phone, app)
    print(f"{app}: {'reused the existing shortcut' if reused else 'new shortcut'}, added to the home screen")


_templates = None


def templates():
    """Each of the 24 icons' middle, small, for matching against the screen."""
    global _templates
    if _templates is None:
        import numpy as np
        from PIL import Image
        _templates = {}
        for d in sorted(os.listdir(ICONS)):
            if d.endswith(".imageset"):
                name = d[4:-9]
                im = Image.open(os.path.join(ICONS, d, f"Icon{name}.png")).convert("RGB")
                w = im.width
                _templates[name] = np.asarray(im.crop((w * .18, w * .18, w * .82, w * .82)).resize((20, 20)), float)
    return _templates


def identify(path, x, y, size=74):
    """The icon at (x, y) on a screenshot, or None. A real icon matches its own picture at least 1.5 times better than
    the runner-up; bare wallpaper, a widget or someone else's icon matches them all about equally (1.0 to 1.1)."""
    import numpy as np
    from PIL import Image
    im = Image.open(path).convert("RGB")
    k = im.width / SCREEN_W
    half = size * 0.32 * k
    crop = np.asarray(im.crop((x * k - half, y * k - half, x * k + half, y * k + half)).resize((20, 20)), float)
    scores = sorted((float(np.abs(crop - t).mean()), name) for name, t in templates().items())
    (d1, best), (d2, _) = scores[0], scores[1]
    return best if d1 < 35 and d2 / max(d1, 1e-6) > 1.3 else None


def layout(phone, name="layout"):
    """What sits in each grid slot and dock slot, as names (None for wallpaper, a widget or an unknown icon)."""
    phone.look(name)
    grid = [[identify(phone.last, x, y) for x in COLS] for y in ROWS]
    dock = [identify(phone.last, x, DOCK_Y) for x in DOCK_X]
    return grid, dock


def show(grid, dock):
    for row in grid:
        print("   " + " ".join(f"{(n or '·'):>9}" for n in row))
    print("dock " + " ".join(f"{(n or '·'):>9}" for n in dock))


def survey(phone):
    """Each home screen page's icons (by picture) and the dock, until the App Library. Changes nothing."""
    phone.home()
    for page in range(1, 10):
        grid, dock = layout(phone, f"page-{page}")
        if phone.find("App Library", exact=False):
            break
        print(f"page {page}   [{phone.last}]")
        show(grid, dock)
        phone.swipe_left()
        time.sleep(1.2)
    phone.home()


if __name__ == "__main__":
    steps = {"survey": survey}
    if len(sys.argv) < 2 or sys.argv[1] not in steps:
        sys.exit(f"usage: mirror_setup.py {'|'.join(steps)}")
    steps[sys.argv[1]](Phone())
