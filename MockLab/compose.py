#!/usr/bin/env python3
"""Builds the MockLab comparison sheets from the rendered mocks.

Run each mock first (swift run ... <Target>), then: python3 MockLab/compose.py
Writes, under MockLab/out/:
  painted-night/      the shipped look, copied from screenshots/renders (402-*-demo) with a board like the mocks'
  compare-boards.png  every aesthetic's board side by side
  compare-<widget>.png  one widget across every aesthetic (day-large, day-medium, day-small, quote-large, quote-medium, quote-small)
  layouts/compare-boards.png, layouts/compare-<widget>.png  the same for the painted layout experiments
    (the shipped layout is the Current target, rendered on macOS like the rest)
  films/compare-boards.png, films/compare-<widget>.png  the film looks (Wong Kar-wai and Wes Anderson), with the
    shipped layout first for reference
"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LAB = Path(__file__).resolve().parent
OUT = LAB / "out"
TERRA = LAB.parent
ORDER = ["painted-night", "field-journal", "topo", "woodblock", "stained-glass", "paper-diorama", "pixel-quest"]
LAYOUT_ORDER = ["layout-current", "layout-panorama", "layout-next-up", "layout-bento", "layout-medallion", "layout-trail", "layout-plate"]
FILM_ORDER = ["layout-current", "old-master", "old-master-inscribed", "old-master-folio", "old-master-cover", "grand-hotel", "grand-hotel-quiet", "grand-hotel-spare", "alpine-hotel", "neon-rain", "crimson-hours", "expedition"]
WIDGETS = ["day-large", "day-medium", "day-small", "quote-large", "quote-medium", "quote-small"]
HN = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size, bold=False):
    return ImageFont.truetype(HN, size, index=1 if bold else 0)


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + ([line] if line else [])


def hexrgb(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def painted_baseline():
    """The current widgets at the same layout as MockBoard (points x2): 28 pt gaps, 348 pt columns."""
    d = OUT / "painted-night"
    d.mkdir(parents=True, exist_ok=True)
    for w in WIDGETS:
        shutil.copy(TERRA / f"screenshots/renders/402-{w}-demo.png", d / f"{w}.png")
    (d / "meta.json").write_text(json.dumps({
        "name": "Painted Night", "slug": "painted-night",
        "tagline": "The shipped look: brushwork night sky, espresso slabs, copper and gold leaf."}, indent=2))

    s, g = 2, 28
    W, H = (28 + 348 + 28 + 348 + 28) * s, (28 + 365 + 28 + 164 + 28 + 164 + 28) * s
    # Wallpaper: the app's painted sky relief over the night gradient.
    top, bottom = np.array(hexrgb(0x0D1519), float), np.array(hexrgb(0x26363A), float)
    t = np.linspace(0, 1, H)[:, None, None]
    base = Image.fromarray((top * (1 - t) + bottom * t).repeat(W, axis=1).astype(np.uint8), "RGB").convert("RGBA")
    relief = Image.open(TERRA / "Baroque/Assets.xcassets/AppSky.imageset/AppSky.png").convert("RGBA")
    relief = relief.resize((W, int(relief.height * W / relief.width)), Image.LANCZOS).crop((0, 0, W, H))
    board = Image.alpha_composite(base, relief)

    def place(name, x, y):
        im = Image.open(d / f"{name}.png").convert("RGBA")
        im = im.resize((im.width * s // 3, im.height * s // 3), Image.LANCZOS)
        board.alpha_composite(im, (x * s, y * s))

    x0, x1 = g, g + 348 + g
    y0, y1, y2 = g, g + 365 + g, g + 365 + g + 164 + g
    place("day-large", x0, y0); place("quote-large", x1, y0)
    place("day-medium", x0, y1); place("quote-medium", x1, y1)
    place("day-small", x0, y2); place("quote-small", x0 + 164 + 20, y2)

    card = Image.new("RGBA", (348 * s, 164 * s), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius=22 * s, fill=(0, 0, 0, 168))
    meta = json.loads((d / "meta.json").read_text())
    lines = wrap(cd, meta["tagline"], font(13 * s), card.width - 36 * s)
    y = card.height - 18 * s - len(lines) * 17 * s
    cd.text((18 * s, y - 38 * s), meta["name"], font=font(26 * s, True), fill="white")
    for i, line in enumerate(lines):
        cd.text((18 * s, y + i * 17 * s), line, font=font(13 * s), fill=(255, 255, 255, 217))
    board.alpha_composite(card, (x1 * s, y2 * s))
    board.convert("RGB").save(d / "board.png")


def looks(order=ORDER):
    out = []
    for slug in order:
        meta = OUT / slug / "meta.json"
        if meta.exists():
            out.append(json.loads(meta.read_text()))
        else:
            print(f"skipping {slug}: not rendered yet")
    return out


def sheet(cells, cols, cell_w, cell_h, label_h, bg=(24, 24, 27), pad=48):
    rows = (len(cells) + cols - 1) // cols
    W = pad + cols * (cell_w + pad)
    H = pad + rows * (cell_h + label_h + pad)
    im = Image.new("RGB", (W, H), bg)
    dr = ImageDraw.Draw(im)
    for i, (img, title, sub) in enumerate(cells):
        c, r = i % cols, i // cols
        x, y = pad + c * (cell_w + pad), pad + r * (cell_h + label_h + pad)
        fitted = img.copy()
        fitted.thumbnail((cell_w, cell_h), Image.LANCZOS)
        im.paste(fitted, (x + (cell_w - fitted.width) // 2, y + (cell_h - fitted.height) // 2), fitted if fitted.mode == "RGBA" else None)
        dr.text((x, y + cell_h + 14), title, font=font(30, True), fill=(240, 240, 240))
        if sub:
            for k, line in enumerate(wrap(dr, sub, font(20), cell_w)[:2]):
                dr.text((x, y + cell_h + 52 + k * 26), line, font=font(20), fill=(170, 170, 175))
    return im


def compare(all_looks, dest=OUT):
    dest.mkdir(parents=True, exist_ok=True)
    boards = [(Image.open(OUT / m["slug"] / "board.png").convert("RGBA"), m["name"], m["tagline"]) for m in all_looks]
    sheet(boards, 4, 780, 805, 110).save(dest / "compare-boards.png")
    for w in WIDGETS:
        first = Image.open(OUT / all_looks[0]["slug"] / f"{w}.png")
        cw, ch = first.width * 2 // 3, first.height * 2 // 3
        cells = [(Image.open(OUT / m["slug"] / f"{w}.png").convert("RGBA"), m["name"], None) for m in all_looks]
        sheet(cells, 4 if w.endswith("small") or w.endswith("large") else 3, cw, ch, 60).save(dest / f"compare-{w}.png")


if __name__ == "__main__":
    painted_baseline()
    found = looks()
    compare(found)
    print("Composed", ", ".join(m["name"] for m in found), "into", OUT)
    layouts = looks(LAYOUT_ORDER)
    if layouts:
        compare(layouts, OUT / "layouts")
        print("Composed", ", ".join(m["name"] for m in layouts), "into", OUT / "layouts")
    films = looks(FILM_ORDER)
    if len(films) > 1:
        compare(films, OUT / "films")
        print("Composed", ", ".join(m["name"] for m in films), "into", OUT / "films")
