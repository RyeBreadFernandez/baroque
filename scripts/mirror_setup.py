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
- Dropping a widget on another of the same size makes a stack, and an icon on an icon makes a folder. But a widget
  dragged out of the widget gallery and dropped on one doesn't: it takes that widget's place and pushes it to a new page
  (on the phone and in the simulator, 2026-11-09). Two large widgets never fit on one page, so stacking them means
  carrying one across pages: about half a second at the screen's edge flips one page, and a widget held anywhere over
  the other page makes it reflow (the target slides away), so it has to go straight onto the target.
- A page swipe that lands inside an app swipes across whatever row is there, and a full swipe deletes it (an alarm in
  Clock, 2026-11-09). swipe_left()/swipe_right() now check for the home screen first.
- Mirroring ends whenever the phone is unlocked; lock it and tap Connect.
- The phone's keyboard never shows: the Mac's keyboard types into the phone. A focused text field shows only its caret.

What it checks before it touches anything (each check raises and the run stops, rather than tapping blind):
- The window: at its actual size (View > Actual Size) when it starts, and before every tap, hold, drag or keystroke,
  still where it was, the same size, and iPhone Mirroring the front app (check_window).
- Page swipes and adding a widget happen only on the home screen: its centred Search pill, or Edit and Done at the top
  in edit mode (is_home_screen).
- The widget gallery: after each dot it taps, the preview's title and size must be the widget it wants (gallery_shows).
- In Shortcuts and the file picker, each target is read before it is tapped: the Search fields, the shortcut card's
  "..." with no other card in the way (card_menu), the editor's title, Image, and the icon file whose name is exactly
  "Baroque <app>" below the search field (icon_file). Text is cleared only when a caret shows in the field (caret_in),
  except Spotlight's, opened from the home screen, which keeps its last search selected.

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
WINDOW_W = SCREEN_W + 2 * INSET_X + 1                  # the window's width at View > Actual Size


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


def plain(text):
    """A word as read, lowercased, without the magnifier OCR reads as "Q" and the trailing marks of menus and links."""
    return re.sub(r"^[q⌕]\s+", "", text.strip().lower()).strip(" .…>›⌄")


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
    def window(self):
        """iPhone Mirroring now: (frontmost, x, y, width, height), its window in the Mac's points."""
        out = osa(f'tell application "System Events" to tell process "{APP}" to '
                  'return {frontmost} & (position of window 1) & (size of window 1)')
        front, *rest = [v.strip() for v in out.split(",")]
        x, y, w, h = (int(float(v)) for v in rest)
        return front == "true", x, y, w, h

    def focus(self):
        """Brings iPhone Mirroring to the front and notes where its window is. Stops unless it's at its actual size,
        the size every point in this script was measured at."""
        run("open", "-a", APP)
        for _ in range(20):
            try:
                _, self.wx, self.wy, self.ww, self.wh = self.window()
                break
            except (subprocess.CalledProcessError, ValueError):
                time.sleep(1)
        else:
            sys.exit("iPhone Mirroring didn't open a window: lock the phone, keep it nearby, and open iPhone Mirroring once by hand.")
        if not actual_size(self.ww, self.wh):
            sys.exit(f"iPhone Mirroring's window is {self.ww} x {self.wh} points, not its actual size ({WINDOW_W} wide): "
                     "choose View > Actual Size in iPhone Mirroring, leave the window where it is, and run this again.")
        time.sleep(0.5)

    def check_window(self):
        """Before every touch and keystroke: iPhone Mirroring must be the front app, with its window where focus()
        found it and the same size. Otherwise a click lands off target or in another Mac window, while the
        screenshots (taken of the window alone) still look fine."""
        try:
            front, x, y, w, h = self.window()
        except (subprocess.CalledProcessError, ValueError):
            raise RuntimeError("iPhone Mirroring has no window any more (the phone was unlocked?), so nothing is touched.")
        if not front:
            raise RuntimeError("iPhone Mirroring isn't the front app, so nothing is touched: another window would get "
                               "the clicks. Bring it to the front and call focus() (or run this again).")
        if (x, y, w, h) != (self.wx, self.wy, self.ww, self.wh):
            raise RuntimeError(f"iPhone Mirroring's window moved or changed size ({self.wx},{self.wy} {self.ww}x{self.wh} "
                               f"-> {x},{y} {w}x{h}), so nothing is touched: call focus() (or run this again).")

    def menu(self, item):
        """View > Home Screen, App Switcher or Spotlight."""
        osa(f'tell application "System Events" to tell process "{APP}" to click menu item "{item}" of menu 1 of menu bar item "View" of menu bar 1')
        time.sleep(1.2)

    def to_global(self, x, y):
        return int(self.wx + INSET_X + x), int(self.wy + INSET_TOP + y)

    # Seeing
    def capture(self, name="look"):
        """Photographs the phone's screen and returns the picture's path (also self.last)."""
        self.step += 1
        name = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:28]
        path = os.path.join(SHOTS, f"{time.strftime('%H%M%S')}-{self.step:03d}-{name}.png")
        # The window alone (screencapture -l), so nothing lying over it ends up in the picture; then the screen part.
        if not os.path.exists(WINID):
            run("swiftc", "-O", os.path.join(ROOT, "scripts/mirror/winid.swift"), "-o", WINID)
        run("screencapture", "-x", "-o", f"-l{run(WINID)}", path)
        from PIL import Image
        im = Image.open(path)
        k = im.width / WINDOW_W
        im.crop((round(INSET_X * k), round(INSET_TOP * k), round((INSET_X + SCREEN_W) * k), round((INSET_TOP + SCREEN_H) * k))).save(path)
        self.last = path
        return path

    def look(self, name="look"):
        """Photographs the screen and reads it: the words, top to bottom."""
        path = self.capture(name)
        words = [Word(json.loads(line)) for line in run(OCR, path).splitlines() if line.strip()]
        return sorted(words, key=lambda w: (round(w.y / 8), w.x))

    def find(self, label, exact=True, words=None, below=0, above=SCREEN_H):
        words = words if words is not None else self.look(label)
        return find_word(words, label, exact, below, above)

    def wait(self, label, timeout=10, **kw):
        end = time.time() + timeout
        while True:
            w = self.find(label, **kw)
            if w or time.time() > end:
                return w
            time.sleep(0.8)

    # Touching (each touch and keystroke checks the window first)
    def tap_at(self, x, y, pause=1.0):
        self.check_window()
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
        self.check_window()
        gx, gy = self.to_global(x, y)
        run("cliclick", f"dd:{gx},{gy}", f"w:{int(seconds * 1000)}", f"du:{gx},{gy}")
        time.sleep(0.8)

    def drag(self, x1, y1, x2, y2, hold=0.0, steps=12, step_ms=16, dwell=0.0):
        """A finger drag. Through iPhone Mirroring a drag that starts on an icon or widget picks it up at once, and one
        that starts on bare wallpaper swipes the page. hold: a pause before moving; dwell: a pause before letting go."""
        self.check_window()
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
        self.on_home_screen()
        self.drag(330, SWIPE_Y, 50, SWIPE_Y, steps=20, step_ms=12)
        self.release(50, SWIPE_Y)

    def swipe_right(self):   # to the previous page
        self.on_home_screen()
        self.drag(60, SWIPE_Y, 340, SWIPE_Y, steps=20, step_ms=12)
        self.release(340, SWIPE_Y)

    def on_home_screen(self, words=None, doing="swipe"):
        """Stops unless the home screen is showing (is_home_screen). Inside an app a page swipe is a full swipe across a
        list row, which deletes it: on 2026-11-09 one landed in Clock and deleted an alarm."""
        words = words if words is not None else self.look(f"before-{doing}")
        if not is_home_screen(words):
            raise RuntimeError(f"Not on the home screen, so no {doing} (see {self.last})")

    def wait_home(self, doing, tries=3):
        """on_home_screen, allowing the home screen a moment to settle after View > Home Screen."""
        for i in range(tries):
            words = self.look(f"before-{doing}")
            if is_home_screen(words) or i == tries - 1:
                return self.on_home_screen(words, doing)
            time.sleep(0.8)

    def release(self, x, y):
        """A second finger-up: now and then the phone misses a swipe's release and stops between two pages."""
        self.check_window()
        gx, gy = self.to_global(x, y)
        run("cliclick", f"du:{gx},{gy}")
        time.sleep(1.2)

    def type(self, text):
        self.check_window()
        run("cliclick", f"t:{text}")
        time.sleep(0.5)

    def focused(self, field, tries=3):
        """True once a caret shows in the text field round `field` (a Word read in it). The caret blinks, so this looks
        up to `tries` times; iPhone Mirroring never shows the phone's keyboard, so the caret is the only sign."""
        for i in range(tries):
            if caret_in(self.capture(f"caret-{i}"), field):
                return True
            time.sleep(0.35)
        return False

    def clear_field(self, field):
        """Selects all in the text field round `field` (a Word read in it) and deletes it. Raises unless a caret shows
        there: with no field focused, Command-A and Delete would act on whatever the app has selected."""
        if not self.focused(field):
            raise RuntimeError(f"No caret in the field at {field!r}, so nothing is deleted (see {self.last})")
        self.select_all_and_delete()

    def select_all_and_delete(self):
        """Command-A, then Delete. Only where a field is known to have the focus (clear_field, open_app)."""
        self.check_window()
        osa(f'tell application "{APP}" to activate')
        osa('tell application "System Events" to keystroke "a" using command down')
        time.sleep(0.3)
        self.key("delete")

    def key(self, name):
        """return, enter, escape, delete or tab. cliclick's key presses don't reach the phone; System Events' do."""
        codes = {"return": 36, "enter": 76, "escape": 53, "delete": 51, "tab": 48}
        self.check_window()
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
        self.wait_home(doing="Spotlight")
        self.menu("Spotlight")
        words = self.look("spotlight")
        field = next((w for w in words if SPOTLIGHT_FIELD[0] <= w.center[1] <= SPOTLIGHT_FIELD[1] and w.center[0] < 300), None)
        if not field or is_home_screen(words):
            raise LookupError(f"Spotlight didn't open (see {self.last})")
        # Spotlight keeps the last search, selected, so it shows no caret for clear_field to find. Its field has the
        # focus whenever it's open, and from the home screen these keys reach either it or the home screen, where they
        # do nothing.
        self.select_all_and_delete()
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


# Checks on what the screen shows: pure functions of the words read (Word) or of a saved screenshot, so they can be
# tried on the pictures in build/mirror-shots without the phone.
SPOTLIGHT_FIELD = (770, 815)                           # Spotlight's search field (y), at the bottom of the screen


def find_word(words, label, exact=True, below=0, above=SCREEN_H):
    want = label.lower()
    for w in words:
        got = w.text.lower().strip(" .…>›")
        if (got == want if exact else want in got) and below <= w.center[1] <= above:
            return w
    return None


def actual_size(w, h):
    """The window is at View > Actual Size: as wide as measured, and tall enough for the whole screen."""
    return abs(w - WINDOW_W) <= 2 and h >= INSET_TOP + SCREEN_H - 2


def is_home_screen(words):
    """The home screen is showing: its Search pill, the word alone (the magnifier aside), centred above the dock; or, in
    edit mode, Edit at the top left and Done at the top right. Apps have Search fields and Done buttons too, but not
    in those places together."""
    pill = any(plain(w.text) == "search" and abs(w.center[0] - SCREEN_W / 2) < 45 and 670 <= w.center[1] <= 735
               for w in words)
    edit = any(plain(w.text) == "edit" and w.center[0] < 130 and w.center[1] < 60 for w in words)
    done = any(plain(w.text) == "done" and w.center[0] > 260 and w.center[1] < 60 for w in words)
    return pill or (edit and done)


def search_field(words, below, above, left_of=SCREEN_W):
    """An empty search field: its placeholder "Search" (OCR reads the magnifier as "Q") between `below` and `above`."""
    return next((w for w in words if plain(w.text) == "search" and below <= w.center[1] <= above
                 and w.center[0] < left_of), None)


def caret_in(path, field, pad=8):
    """True when the screenshot shows a text caret in the field round `field` (a Word read in that field): at the
    start or the end of its words, a bar at most 2 pt wide that stands out from the field's ground and runs the
    height of the line (an l or a k runs about 60 percent of it). Any colour: Files and Shortcuts draw it blue."""
    import numpy as np
    from PIL import Image
    im = Image.open(path).convert("RGB")
    k = im.width / SCREEN_W
    top, bottom = max(0, field.y - pad), min(SCREEN_H, field.y + field.h + pad)
    band = np.asarray(im.crop((0, round(top * k), im.width, round(bottom * k))), dtype=np.float32) / 255
    ground = np.median(band.reshape(-1, 3), axis=0)
    on = np.abs(band - ground).max(axis=2) > 0.3
    # The longest run of "on" pixels down each column.
    longest = np.zeros(on.shape[1], dtype=int)
    run_now = np.zeros(on.shape[1], dtype=int)
    for row in on:
        run_now = np.where(row, run_now + 1, 0)
        longest = np.maximum(longest, run_now)
    tall = max(field.h * 0.85, 12) * k
    side = round(2.5 * k)
    first, last = max(side, round((field.x - 8) * k)), min(on.shape[1] - side - 1, round((field.x + field.w + 8) * k))
    for x in range(first, last + 1):
        if tall <= longest[x] <= (bottom - top) * k:
            if longest[x - side] < longest[x] * 0.6 and longest[x + side] < longest[x] * 0.6:
                return True
    return False


def card_menu(words, card):
    """Where to tap the "..." of the shortcut card whose label is `card`: 58 pt above the label, at the card's right.
    Raises unless the label sits where a card's label does and no other card's label is between it and that point,
    so a shifted grid can't turn the tap into running some other shortcut (the card itself runs it)."""
    left = card.center[0] < SCREEN_W / 2
    x, y = (160, card.center[1] - 58) if left else (346, card.center[1] - 58)
    if abs(card.x - (32 if left else 218)) > 14 or y < 215:
        raise LookupError(f"{card!r} isn't where a shortcut card's name sits, so its ... isn't tapped")
    ellipsis = lambda w: re.fullmatch(r"[.•·…o0]+", w.text.strip().lower()) is not None
    for w in words:                                    # between the card's top row (icon, ...) and its name
        if w is not card and (w.center[0] < SCREEN_W / 2) == left and y + 14 < w.center[1] < card.center[1] - 8:
            raise LookupError(f"{w!r} sits between {card!r} and its ..., so the card isn't the one expected")
    dots = next((w for w in words if ellipsis(w) and abs(w.center[0] - x) < 25 and abs(w.center[1] - y) < 25), None)
    return dots.center if dots else (x, y)


def title_word(words, title=None):
    """The editor's title at the top centre: the shortcut's name (`title`, if given), which opens its menu."""
    for w in words:
        if abs(w.center[0] - SCREEN_W / 2) < 90 and 60 <= w.center[1] <= 105:
            got = plain(w.text)
            if (got == title.lower() or got.startswith(title.lower() + " ")) if title else got not in ("", "done", "cancel", "<"):
                return w
    return None


def icon_file(words, app, below):
    """The file picker's result named exactly "Baroque <app>" (with or without .png), below `below`: the first line of
    its name under the file's icon, which the grid wraps ("Baroque App" over "Store"). None if there's no such file:
    the search field and its "Name Contains" row hold the same words, so they never count."""
    want = f"baroque {app}".lower()
    for w in words:
        if w.center[1] <= below or not w.text.strip().lower().startswith("baroque"):
            continue
        text, last = w.text.strip(), w
        while text.lower() not in (want, want + ".png") and len(text) < len(want) + 4:
            more = next((v for v in words if 10 < v.center[1] - last.center[1] < 26
                         and abs(v.center[0] - w.center[0]) < 25), None)
            if not more:
                break
            text, last = f"{text} {more.text.strip()}", more
        if text.lower() in (want, want + ".png"):
            return w
    return None


# Baroque's widgets in the gallery, in the order of its page dots, and their display names (BaroqueWidgets.swift).
GALLERY = ["Day small", "Day medium", "Day large", "Today small", "Today medium", "Today large",
           "Quote small", "Quote medium", "Quote large", "Battery small", "Still Life small", "Still Life large",
           "Photograph small"]
WIDGET_NAMES = ["Day", "Today", "Quote", "Battery", "Still Life", "Photograph"]
# The dots sit centred under the preview, 16.6 pt apart (measured with nine of them on 2026-11-05). The gallery shows
# at most ten, shrinking the last ones, so only the first eight can be tapped where expected (2026-11-09); past those
# add_widget steps one page at a time.
GALLERY_DOTS_Y, GALLERY_DOT_STEP, GALLERY_TAPPABLE = 726, 16.6, 8
GALLERY_DOT0_X = 196 - (min(len(GALLERY), 10) - 1) / 2 * GALLERY_DOT_STEP


def gallery_title_word(words):
    """The gallery page's title, "Baroque <widget>", centred above the preview, as read."""
    return next((w for w in words if re.fullmatch(r"baroque .+", plain(w.text))
                 and abs(w.center[0] - SCREEN_W / 2) < 60 and 170 <= w.center[1] <= 300), None)


def gallery_title(words):
    """The widget the gallery page is titled with ("Baroque Day" -> "Day")."""
    w = gallery_title_word(words)
    return next((n for n in WIDGET_NAMES if w and plain(w.text) == f"baroque {n.lower()}"), None)


def _runs(mask):
    """(start, end) of each run of True in a 1-D array."""
    import numpy as np
    d = np.diff(np.concatenate([[0], mask.astype(np.int8), [0]]))
    return list(zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]))


def _close(mask, gap):
    """The mask with every gap of at most `gap` between two runs of True filled."""
    out = mask.copy()
    spans = _runs(mask)
    for (_, e), (s, _) in zip(spans, spans[1:]):
        if s - e <= gap:
            out[e:s] = True
    return out


def preview_box(path, words=(), bottom=GALLERY_DOTS_Y - 14):
    """The gallery preview's frame (left, top, right, bottom in points): below the title and its description, the
    area round the screen's centre that differs from the sheet (its flat colour, taken beside the page dots). None if
    nothing is there."""
    import numpy as np
    from PIL import Image
    top = 170
    title = gallery_title_word(words)
    if title:                                           # the description: lines right under the title
        top = title.y + title.h
        for w in sorted(words, key=lambda w: w.y):
            if w.y > title.y and w.y - top < 30 and abs(w.center[0] - SCREEN_W / 2) < 150:
                top = max(top, w.y + w.h)
        top += 6
    im = Image.open(path).convert("RGB")
    k = im.width / SCREEN_W
    a = np.asarray(im, dtype=np.float32) / 255
    y0, y1 = round((GALLERY_DOTS_Y - 8) * k), round((GALLERY_DOTS_Y + 8) * k)
    sheet = np.median(np.concatenate([a[y0:y1, round(20 * k):round(90 * k)].reshape(-1, 3),
                                      a[y0:y1, round(302 * k):round(372 * k)].reshape(-1, 3)]), axis=0)
    t, b = round(top * k), round(bottom * k)
    diff = np.abs(a[t:b] - sheet).max(axis=2) > 0.05
    # Columns where the preview is, then its rows; dark paint can match the sheet here and there, so short gaps close.
    c = round(SCREEN_W / 2 * k)
    across = _runs(_close(diff.mean(axis=0) > 0.1, round(8 * k)))
    left, right = next(((s, e) for s, e in across if s <= c < e), (None, None))
    if left is None:
        return None
    down = _runs(_close(diff[:, left:right].mean(axis=1) > 0.3, round(12 * k)))
    if not down:
        return None
    s, e = max(down, key=lambda r: r[1] - r[0])
    return left / k, (t + s) / k, right / k, (t + e) / k


def preview_size(box):
    """small, medium or large from the preview's frame (its shape, and its width beside the screen's), or None."""
    if not box:
        return None
    w, h = box[2] - box[0], box[3] - box[1]
    if w < 80 or h < 60:
        return None
    if w / h > 1.6:
        return "medium"
    if not 0.7 < w / h < 1.4:
        return None
    return "small" if w < SCREEN_W * 0.62 else "large"


def gallery_shows(path, words):
    """What the gallery page shows, as in GALLERY ("Quote medium"), from its title and its preview; None if unsure."""
    name, size = gallery_title(words), preview_size(preview_box(path, words))
    return f"{name} {size}" if name and size else None


def current_dot_x(path):
    """x of the gallery's current page dot: of the dots in a row, the one that stands out most from the sheet."""
    import numpy as np
    from PIL import Image
    im = Image.open(path).convert("RGB")
    k = im.width / SCREEN_W
    band = np.asarray(im.crop((round(30 * k), round((GALLERY_DOTS_Y - 6) * k), round((SCREEN_W - 30) * k),
                               round((GALLERY_DOTS_Y + 6) * k))), dtype=np.float32) / 255
    ground = np.median(band.reshape(-1, 3), axis=0)
    contrast = np.abs(band - ground).max(axis=2).max(axis=0)
    peaks = sorted(((float(contrast[s:e].max()), (s + e) / 2) for s, e in _runs(contrast > 0.12)), reverse=True)
    if not peaks or (len(peaks) > 1 and peaks[0][0] < peaks[1][0] * 1.25):
        return None
    return 30 + peaks[0][1] / k


def gallery_check(phone, want):
    """Reads the gallery page; raises unless it shows `want`. Returns what it shows."""
    words = phone.look(f"gallery-{want}")
    shown = gallery_shows(phone.last, words)
    if shown != want:
        raise LookupError(f"The gallery shows {shown or 'a page it cannot read'}, not {want}, so nothing is added "
                          f"(see {phone.last})")
    return shown


def add_widget(phone, which):
    """Adds one of Baroque's widgets to the top of the current page (the page is in edit mode or gets put in it).
    Only from the home screen or the widget gallery, and only once the gallery shows that widget at that size."""
    want = GALLERY.index(which)
    words = phone.look("before-add-widget")
    if not phone.find("Search Widgets", words=words, exact=False):
        menu = phone.find("Add Widget", words=words, exact=False, above=150)   # edit mode's menu, already open
        if not (menu and phone.find("Done", words=words, above=60)):
            phone.on_home_screen(words, doing="widget added")
        if not menu:
            if not phone.find("Edit", words=words, above=60):
                phone.hold(196, SWIPE_Y, 1.5)              # long press on bare wallpaper: edit mode
            phone.tap("Edit", timeout=4, above=60)
        phone.tap("Add Widget", timeout=4, exact=False, above=150)   # the menu's item ("Add Widget" with its icon)
        time.sleep(1.2)
    field = phone.tap("Search Widgets", timeout=4, exact=False)
    phone.clear_field(field)
    phone.type("Baroque")
    time.sleep(1.5)
    words = phone.look("gallery-search")
    hit = next((w for w in words if w.text.strip() == "Baroque" and w.center[1] > 190), None)
    if not hit:
        raise LookupError(f"The gallery found no Baroque widgets (see {phone.last})")
    phone.tap_at(*hit.center, pause=2)
    # The first eight dots are where they should be; past those, one page at a time from the current dot, checking
    # each page, since the dots shrink and shift.
    first = min(want, GALLERY_TAPPABLE - 1)
    phone.tap_at(GALLERY_DOT0_X + GALLERY_DOT_STEP * first, GALLERY_DOTS_Y, pause=1.2)
    gallery_check(phone, GALLERY[first])
    for i in range(first + 1, want + 1):
        x = current_dot_x(phone.last)
        if x is None:
            raise LookupError(f"Couldn't tell which gallery dot is the current one (see {phone.last})")
        phone.tap_at(x + GALLERY_DOT_STEP * 0.5, GALLERY_DOTS_Y, pause=1.2)
        gallery_check(phone, GALLERY[i])
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
    """Opens the user's shortcut for `app` in the editor if one exists and its action is Open <app>. Returns the
    shortcut's name if it did, None if not."""
    for name in SHORTCUT_NAMES.get(app, [app]):
        words = shortcuts_library(phone)
        for _ in range(3):                                 # the search field, under All Shortcuts; typing lands once it's active
            field = search_field(words, 150, 230)
            if not field:
                raise LookupError(f"No empty Search field under All Shortcuts (see {phone.last})")
            phone.tap_at(*field.center, pause=1.2)
            if not phone.focused(field):
                words = phone.look(f"search-field-{name}")
                continue
            phone.clear_field(field)
            phone.type(name)
            time.sleep(1.5)
            words = phone.look(f"search-{name}")
            typed = next((w for w in words if name.lower() in w.text.lower() and w.center[1] < 230), None)
            if typed:
                break
        else:
            raise LookupError(f"Typing {name!r} didn't reach the search field (see {phone.last})")
        card = next((w for w in words if w.text.strip().lower() == name.lower() and w.center[1] > 220), None)
        if not card:
            phone.clear_field(typed)                       # no such shortcut: empty the search for the next name
            continue
        phone.tap_at(*card_menu(words, card), pause=2)     # the card's "..." opens the editor (the card runs it)
        words = phone.look(f"editor-{name}")
        text = " ".join(w.text for w in words)
        if "Open" in text and APP_NAMES.get(app, app).split()[0].lower() in text.lower():
            return name
        print(f"  {name}: not an Open {app} shortcut ({text[:80]})")
    return None


def create_shortcut(phone, app):
    """A new shortcut: Open <app>, named after the app."""
    words = shortcuts_library(phone)
    for _ in range(3):
        plus = next((w for w in words if w.text.strip() == "+" and w.center[0] > 320 and w.center[1] < 110), None)
        if not plus:
            raise LookupError(f"No + at the top right of All Shortcuts (see {phone.last})")
        phone.tap_at(*plus.center, pause=2)
        if phone.wait("Search Actions", timeout=3, exact=False):
            break
        words = phone.look("shortcuts-plus")
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


def tap_title(phone, title=None):
    """Taps the editor's title (the shortcut's name, `title` if known), which opens its menu. Raises if it isn't there."""
    words = phone.look("editor-title")
    word = title_word(words, title)
    if not word:
        raise LookupError(f"No title {title or ''!r} at the top of the shortcut's editor (see {phone.last})")
    phone.tap_at(*word.center, pause=1.2)


def rename_to(phone, name):
    """Title menu > Rename, then the name typed over the old one: cleared first if a caret shows; with none, the old
    name is selected and typing replaces it. add_to_home_screen reads the title back before it goes on."""
    tap_title(phone)
    phone.tap("Rename", timeout=3, exact=False)
    field = title_word(phone.look("renaming"))
    if not field:
        raise LookupError(f"The title didn't turn into a field (see {phone.last})")
    if phone.focused(field):
        phone.clear_field(field)
    phone.type(name)
    phone.key("return")
    time.sleep(1)


def name_shortcut(phone, app):
    """Renames the shortcut in the editor after the app. Returns the name it got."""
    rename_to(phone, app)
    if phone.find("already have a shortcut", exact=False):    # the user has one by that name that does something else
        phone.tap("OK", timeout=3)
        rename_to(phone, f"Open {app}")
        return f"Open {app}"
    return app


def add_to_home_screen(phone, app, title=None):
    """From the shortcut's editor (titled `title`): Add to Home Screen with Baroque's icon file for `app`. Each target
    is read before it is tapped."""
    tap_title(phone, title)                                # the title's menu
    phone.tap("Add to Home Screen", timeout=3, exact=False)
    time.sleep(2)
    phone.tap("Image", timeout=3, below=320, above=400)    # Image, beside Symbol, under the preview
    phone.tap("Choose File", timeout=3)
    time.sleep(2.5)
    words = phone.look("file-picker")
    field = search_field(words, 120, 200, left_of=SCREEN_W / 2)
    if not field:
        raise LookupError(f"No Search field at the top of the file picker (see {phone.last})")
    phone.tap_at(*field.center, pause=1)
    phone.clear_field(field)
    phone.type(f"Baroque {app}")
    time.sleep(2.5)
    words = phone.look(f"file-{app}")
    hit = icon_file(words, app, below=field.center[1] + 80)
    if not hit:
        raise LookupError(f"No icon file for {app} (see {phone.last})")
    phone.tap_at(*hit.center, pause=2.5)
    words = phone.look(f"home-sheet-{app}")
    if not phone.find("Home Screen", words=words):
        raise LookupError(f"The Home Screen sheet didn't come back (see {phone.last})")
    phone.tap("Add", timeout=3, above=140)
    time.sleep(2)


def make_icon(phone, app):
    """One home screen icon that opens `app` directly: its shortcut (the user's own, or a new one) with Baroque's icon."""
    title = open_existing_shortcut(phone, app)
    reused = title is not None
    if not reused:
        create_shortcut(phone, app)
        title = name_shortcut(phone, app)
    add_to_home_screen(phone, app, title)
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
    """The icon at (x, y) on a screenshot, or None. A real icon matches its own picture at least 1.3 times better than
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
