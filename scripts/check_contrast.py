#!/usr/bin/env python3
"""Measures the widgets' inks against the limestone as it renders, not only against its flat colour.

The slab lays painted brushwork and a light-to-shade gradient over the flat stone (RococoSlab), so the stone behind a
line of text is often darker than #DCD1BB. This reads the stone in MockLab's README renders, takes its median and its
5th and 2nd percentiles of luminance, and gives each ink's WCAG contrast against them. Every ink must reach 4.5:1
against the 5th percentile of every render (2026-11-10 review, F25).

The inks and the stone come from the current theme in Shared/RococoStyle.swift (`RococoTheme.current`), so the check
follows the code. The stone is what's left of each render after taking out its pictures (the still life panel and
band), a 12 point border (every layout keeps 14 points clear of the edge, and the slab's shaded lip lives there), and
anything that isn't stone-coloured (text, carved lines, the sun) with a two-pixel fringe round it.

Run:  cd MockLab && README=1 swift run --scratch-path .build-smalls RSmalls
      python3 scripts/check_contrast.py [renders folder] [--theme Quiet] [--suggest]
--suggest also prints, for an ink that falls short, the same colour darkened just enough (in linear light, which keeps
its hue) to reach the target against the darkest render's 5th percentile. Exits 1 if any ink falls short.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STYLE = os.path.join(ROOT, "Shared", "RococoStyle.swift")
RENDERS = os.path.join(ROOT, "MockLab", "out", "readme")
TARGET = 4.5
BORDER_PT = 12

# The README renders drawn on the stone, each with its design size (points) and the pictures on it (x, y, w, h in
# points). Everything else in the folder is a photograph or a painting.
STONE = {
    "today-small": ((164, 164), []),
    "today-medium": ((348, 164), [(188, 8, 152, 148)]),
    "today-large": ((348, 365), [(10, 10, 328, 82)]),
    "check-today-large-short": ((348, 365), [(10, 10, 328, 82)]),
    "check-today-large-error": ((348, 365), [(10, 10, 328, 82)]),
    "day-small": ((164, 164), []),
    "day-medium": ((348, 164), []),
    "battery-small": ((164, 164), []),
    "phone-day-small": ((164, 164), []),
    "phone-today-small": ((164, 164), []),
}


def theme_colours(name=None):
    """{"stone": "#DCD1BB", "ink": ..., "inkSoft": ..., "terracotta": ...} for the named theme, or the current one."""
    src = open(STYLE, encoding="utf-8").read()
    themes = {}
    for m in re.finditer(r"static let (\w+) = RococoTheme\((.*?)\)\n", src, re.S):
        body = m.group(2)
        title = re.search(r'name: "([^"]+)"', body).group(1)
        cols = dict(re.findall(r"(\w+): Color\(hex: 0x([0-9A-Fa-f]{6})\)", body))
        themes[m.group(1)] = (title, {k: "#" + v.upper() for k, v in cols.items()})
    if name is None:
        current = re.search(r"static var current = (\w+)", src).group(1)
        return themes[current]
    for key, (title, cols) in themes.items():
        if name.lower() in (key.lower(), title.lower()):
            return title, cols
    sys.exit(f"No theme {name!r} in {STYLE}: {', '.join(t for t, _ in themes.values())}")


def srgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


def linear(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    lin = linear(rgb)
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def contrast(y1, y2):
    hi, lo = max(y1, y2), min(y1, y2)
    return (hi + 0.05) / (lo + 0.05)


def lab(rgb):
    """CIE Lab (D65) of sRGB values, for telling stone from everything else."""
    lin = linear(rgb)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def dilate(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return out


def stone_pixels(path, design, pictures, stone_hex):
    img = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    h, w = img.shape[:2]
    px = w / design[0]
    rgb, alpha = img[..., :3], img[..., 3]
    keep = alpha >= 255
    b = int(round(BORDER_PT * px))
    keep[:b, :] = keep[-b:, :] = False
    keep[:, :b] = keep[:, -b:] = False
    for x, y, pw, ph in pictures:
        keep[int(y * px):int((y + ph) * px), int(x * px):int((x + pw) * px)] = False
    # Stone-coloured: near the flat stone in Lab, allowing for the brushwork and the light-to-shade gradient.
    d = lab(rgb) - lab(srgb(stone_hex))
    near = (np.abs(d[..., 0]) < 14) & (np.hypot(d[..., 1], d[..., 2]) < 9)
    other = dilate(~near, 2)
    return luminance(rgb[keep & ~other])


def darkened(hexstr, stone_y, target):
    """The ink scaled down in linear light just far enough to reach `target` against a stone of luminance stone_y."""
    lin = linear(srgb(hexstr))
    y = float(lin @ np.array([0.2126, 0.7152, 0.0722]))
    want = (stone_y + 0.05) / target - 0.05
    if y <= want:
        return hexstr
    k = want / y
    while True:
        out = lin * k
        c = np.where(out <= 0.0031308, out * 12.92, 1.055 * out ** (1 / 2.4) - 0.055)
        rgb = np.clip(np.floor(c * 255), 0, 255).astype(int)
        hx = "#%02X%02X%02X" % tuple(rgb)
        if contrast(float(luminance(srgb(hx))), stone_y) >= target:
            return hx
        k *= 0.995


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    folder = args[0] if args else RENDERS
    theme_name = None
    if "--theme" in sys.argv:
        theme_name = sys.argv[sys.argv.index("--theme") + 1]
        args = [a for a in args if a != theme_name]
        folder = args[0] if args else RENDERS
    title, cols = theme_colours(theme_name)
    inks = {k: cols[k] for k in ("ink", "inkSoft", "terracotta")}
    print(f"Theme {title}: stone {cols['stone']}, " + ", ".join(f"{k} {v}" for k, v in inks.items()))
    print(f"Renders: {folder}\n")

    rows, worst = [], None
    for name, (design, pictures) in STONE.items():
        path = os.path.join(folder, name + ".png")
        if not os.path.exists(path):
            print(f"  {name}: no render")
            continue
        ys = stone_pixels(path, design, pictures, cols["stone"])
        p50, p5, p2 = (float(np.percentile(ys, q)) for q in (50, 5, 2))
        rows.append((name, len(ys), p50, p5, p2))
        if worst is None or p5 < worst[1]:
            worst = (name, p5)

    if not rows:
        sys.exit("No stone renders found. Run: cd MockLab && README=1 swift run --scratch-path .build-smalls RSmalls")

    head = f"  {'render':26} {'stone px':>9}   " + "   ".join(f"{k:>23}" for k in inks)
    print(head)
    print(f"  {'':26} {'':>9}   " + "   ".join(f"{'median   5th    2nd':>23}" for _ in inks))
    failed = False
    for name, n, p50, p5, p2 in rows:
        cells = []
        for k, v in inks.items():
            iy = float(luminance(srgb(v)))
            c50, c5, c2 = (contrast(iy, s) for s in (p50, p5, p2))
            mark = " " if c5 >= TARGET else "!"
            failed |= c5 < TARGET
            cells.append(f"{c50:6.2f} {c5:6.2f}{mark} {c2:5.2f}")
        print(f"  {name:26} {n:9d}   " + "   ".join(f"{c:>23}" for c in cells))

    print(f"\nDarkest stone (5th percentile): {worst[0]}, luminance {worst[1]:.3f}"
          f" (flat stone {float(luminance(srgb(cols['stone']))):.3f})")
    for k, v in inks.items():
        c = contrast(float(luminance(srgb(v))), worst[1])
        verdict = "ok" if c >= TARGET else f"below {TARGET}:1"
        line = f"  {k:10} {v}  {c:.2f}:1 against it, {verdict}"
        if "--suggest" in sys.argv and c < TARGET:
            line += f"; darkened to reach it: {darkened(v, worst[1], TARGET)}"
        print(line)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
