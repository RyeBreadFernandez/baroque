#!/usr/bin/env python3
"""Travel Poster textures (MockLab target WPoster): the print's paper and the grain of its inks.

The poster itself is vector SwiftUI (flat ink shapes, halftone screens, the live sun disc, the Matterhorn from its
traced skyline), so only the materials are rasters. Both tile, at 1 px per point:

  paper.png   256x256  L   the poster stock: mottled sizing, long pale and dark fibres, a few specks of dirt.
                           Multiplied over the whole widget (and the wallpaper), so every ink sits in the paper.
  litho.png   256x256  LA  alpha = where the ink starved: a dry, slightly streaked lithographic grain. The widget lays
                           the paper colour through it over the big ink fields (sky bands, mountain faces, the
                           foreground), so they read as pulled ink rather than flat fills.
  stamp.png   128x128  LA  alpha = a rubber stamp's broken ink: the To-do widget's count stamp is drawn through it.

It also writes Sources/WPoster/TPProfile.swift, the Matterhorn's skyline from the shared trace
(MockLab/Textures/old-master-cover/matterhorn.json, see its "source" for the attribution), as Swift literals, so the
SwiftUI poster (and a port into Shared/) can draw the true silhouette without reading JSON at run time.

Deterministic, no network. Run from anywhere:  python3 MockLab/Textures/weather-poster/make.py
"""
import json
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
MOCKLAB = os.path.dirname(os.path.dirname(HERE))
PROFILE = os.path.join(MOCKLAB, "Textures", "old-master-cover", "matterhorn.json")
SWIFT_OUT = os.path.join(MOCKLAB, "Sources", "WPoster", "TPProfile.swift")
TILE = 256


def noise(rng, n, sigma, stretch=(1.0, 1.0)):
    """Tileable smooth noise, zero mean and unit deviation: white noise blurred with wrap-around."""
    g = gaussian_filter(rng.standard_normal((n, n)), sigma=(sigma * stretch[0], sigma * stretch[1]), mode="wrap")
    return (g - g.mean()) / (g.std() + 1e-9)


def fbm(rng, n, sigmas, weights, stretch=(1.0, 1.0)):
    out = sum(w * noise(rng, n, s, stretch) for s, w in zip(sigmas, weights))
    return (out - out.mean()) / (out.std() + 1e-9)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def wrapped_lines(n, rng, count, length, width, value, draw_scale=4):
    """Short wandering fibres on a tile, drawn supersampled and wrapped at the edges. Returns 0..1 coverage."""
    S = n * draw_scale
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.uniform(0, S), rng.uniform(0, S)
        a = rng.uniform(0, np.pi)
        L = rng.uniform(*length) * draw_scale
        pts = []
        for i in range(9):
            t = i / 8
            a += rng.normal(0, 0.18)
            pts.append((x + np.cos(a) * L * t, y + np.sin(a) * L * t))
        w = max(1, int(round(rng.uniform(*width) * draw_scale)))
        v = int(255 * rng.uniform(*value))
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                d.line([(px + ox, py + oy) for px, py in pts], fill=v, width=w)
    a = np.asarray(img.resize((n, n), Image.LANCZOS), dtype=np.float64) / 255.0
    return a


def paper():
    rng = np.random.default_rng(1908)  # the year of Cardinaux's Zermatt poster, as a seed
    n = TILE
    mottle = fbm(rng, n, [18, 7, 2.5], [0.55, 0.3, 0.15])
    tooth = noise(rng, n, 0.6)
    dark_fibres = wrapped_lines(n, rng, 70, (6, 22), (0.35, 0.7), (0.4, 1.0))
    pale_fibres = wrapped_lines(n, rng, 50, (8, 26), (0.5, 0.9), (0.4, 1.0))
    # Specks of dirt in the stock: a few soft round dots, each its own darkness.
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    specks = np.zeros((n, n))
    for _ in range(26):
        cx, cy, r, v = rng.uniform(0, n), rng.uniform(0, n), rng.uniform(0.5, 1.2), rng.uniform(0.3, 1.0)
        dx = (xx - cx + n / 2) % n - n / 2
        dy = (yy - cy + n / 2) % n - n / 2
        specks = np.maximum(specks, v * smoothstep(r + 0.6, r - 0.3, np.hypot(dx, dy)))
    v = 0.955 + 0.022 * mottle + 0.012 * tooth
    v -= 0.07 * dark_fibres
    v += 0.03 * pale_fibres
    v -= 0.28 * specks
    v = np.clip(v, 0, 1)
    v = v / v.max()
    Image.fromarray((v * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(HERE, "paper.png"), optimize=True)
    print(f"paper.png: {n}x{n}  multiply {v.min():.2f}..{v.max():.2f}")


def litho():
    rng = np.random.default_rng(4478)
    n = TILE
    # Dry ink: blotches where the screen ran thin, drawn out slightly along the squeegee (left to right).
    blotch = fbm(rng, n, [11, 4.5, 1.6], [0.5, 0.32, 0.18], stretch=(0.7, 1.6))
    drag = fbm(rng, n, [0.8, 2.2], [0.6, 0.4], stretch=(0.35, 6.0))
    grit = noise(rng, n, 0.5)
    starve = 0.6 * blotch + 0.14 * drag + 0.3 * grit
    a = smoothstep(1.0, 2.3, starve) * 0.7 + smoothstep(1.7, 2.7, grit) * 0.4
    a = np.clip(a, 0, 1)
    a8 = (a * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, "litho.png"), optimize=True)
    print(f"litho.png: {n}x{n}  mean alpha {a.mean():.3f}")


def stamp():
    rng = np.random.default_rng(14692)
    n = 128
    blot = fbm(rng, n, [6, 2.2, 0.8], [0.45, 0.35, 0.2])
    rim = noise(rng, n, 0.5)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    # Rubber stamps print heavier on one side: a tilt of the pad from lower left to upper right.
    tilt = (xx - yy) / n
    a = 1 - smoothstep(0.55, 1.6, 0.6 * blot + 0.4 * rim - 0.7 * tilt)
    a = np.clip(0.18 + 0.82 * a, 0, 1)
    a8 = (a * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, "stamp.png"), optimize=True)
    print(f"stamp.png: {n}x{n}  mean alpha {a.mean():.3f}")


def swift_profile():
    with open(PROFILE) as f:
        d = json.load(f)
    xs = ", ".join(f"{v:g}" for v in d["x"])
    ys = ", ".join(f"{v:g}" for v in d["y"])

    def wrap(s, indent="        "):
        out, line = [], ""
        for part in s.split(", "):
            if len(line) + len(part) + 2 > 108:
                out.append(indent + line.rstrip())
                line = ""
            line += part + ", "
        out.append(indent + line.rstrip(", "))
        return "\n".join(out)

    src = f"""import CoreGraphics

// Generated by MockLab/Textures/weather-poster/make.py from MockLab/Textures/old-master-cover/matterhorn.json; do not
// edit. The Matterhorn's skyline from the Riffelsee above Zermatt, looking southwest, traced from
// {d['source']['photo']} ({d['source']['url']}); the line only, no pixels.
// Units: the summit at (0, 0), x right and y down, in pyramid heights (the drop from the summit to the foot of the
// steep left face).
enum TPProfile {{
    static let foot = CGPoint(x: {d['foot'][0]}, y: {d['foot'][1]})
    static let notch = CGPoint(x: {d['notch'][0]}, y: {d['notch'][1]})
    static let shoulder = CGPoint(x: {d['shoulder'][0]}, y: {d['shoulder'][1]})
    static let x: [CGFloat] = [
{wrap(xs)}
    ]
    static let y: [CGFloat] = [
{wrap(ys)}
    ]
}}
"""
    with open(SWIFT_OUT, "w") as f:
        f.write(src)
    print(f"TPProfile.swift: {len(d['x'])} points")


def main():
    paper()
    litho()
    stamp()
    swift_profile()


if __name__ == "__main__":
    main()
