#!/usr/bin/env python3
"""Field Journal textures: cold-press watercolor paper (one per widget size, 1 px per point) and a
"tooth" mask that the Swift code tints with pigment so washes granulate into the paper's valleys.

Run from anywhere:  python3 MockLab/Textures/field-journal/make.py
Deterministic (fixed seeds).
"""
import os
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))


def field(rng, h, w, sigma):
    """Smooth zero-mean, unit-ish noise."""
    n = gaussian_filter(rng.standard_normal((h, w)), sigma, mode="wrap")
    return n / (n.std() + 1e-9)


def tooth_height(rng, h, w):
    """Cold-press paper relief: rounded bumps of a few points plus a finer felt texture."""
    return 0.65 * field(rng, h, w, 1.6) + 0.35 * field(rng, h, w, 0.8) + 0.25 * field(rng, h, w, 4.0)


def fibers(rng, h, w, count, ss=4):
    """Short curved fibres drawn supersampled, returned as (dark, light, color-rgba) layers in [0,1]."""
    H, W = h * ss, w * ss
    dark = Image.new("L", (W, H), 0)
    light = Image.new("L", (W, H), 0)
    color = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd, ld, cd = ImageDraw.Draw(dark), ImageDraw.Draw(light), ImageDraw.Draw(color)
    for i in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        length = rng.uniform(5, 22) * ss
        ang = rng.uniform(0, np.pi)
        bend = rng.uniform(-0.08, 0.08)
        pts = []
        steps = 10
        for s in range(steps + 1):
            t = s / steps
            a = ang + bend * s
            x += np.cos(a) * length / steps
            y += np.sin(a) * length / steps
            pts.append((x, y))
        width = max(1, int(rng.uniform(0.25, 0.6) * ss))
        r = rng.uniform()
        if r < 0.05:
            # rare coloured fibre (rag paper): faded red or blue
            c = (150, 60, 50, 110) if rng.uniform() < 0.5 else (60, 90, 140, 100)
            cd.line(pts, fill=c, width=width)
        elif r < 0.62:
            dd.line(pts, fill=int(rng.uniform(60, 150)), width=width)
        else:
            ld.line(pts, fill=int(rng.uniform(90, 200)), width=width)
    size = (w, h)
    return (np.asarray(dark.resize(size, Image.LANCZOS), dtype=np.float32) / 255,
            np.asarray(light.resize(size, Image.LANCZOS), dtype=np.float32) / 255,
            np.asarray(color.resize(size, Image.LANCZOS), dtype=np.float32) / 255)


def paper(w, h, seed, base=(244, 236, 217), vignette=0.06, foxing=4):
    rng = np.random.default_rng(seed)
    img = np.ones((h, w, 3), np.float32) * np.array(base, np.float32)

    # Low-frequency mottling: warmer where slightly darker, like sized rag paper.
    mott = 0.6 * field(rng, h, w, 26) + 0.4 * field(rng, h, w, 9)
    img += mott[..., None] * np.array([2.6, 3.0, 4.2], np.float32)

    # Tooth: emboss the relief, lit from the upper left.
    hgt = tooth_height(rng, h, w)
    gy, gx = np.gradient(gaussian_filter(hgt, 0.6))
    shade = -(gx * 0.8 + gy * 0.6)
    shade = shade / (np.abs(shade).std() + 1e-9)
    img += shade[..., None] * 3.6
    img += (hgt[..., None] * 1.6)

    # Fine grain.
    img += rng.standard_normal((h, w, 1)).astype(np.float32) * 1.3

    # Fibres.
    dark, light, col = fibers(rng, h, w, int(w * h / 55))
    img -= dark[..., None] * np.array([26, 26, 30], np.float32)
    img += light[..., None] * np.array([14, 14, 12], np.float32)
    a = col[..., 3:4]
    img = img * (1 - a * 0.5) + col[..., :3] * 255 * (a * 0.5)

    # Foxing: a few faint sienna spots.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for _ in range(foxing):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1.2, 4.5)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        spot = np.exp(-(d / r) ** 2) * rng.uniform(0.18, 0.4)
        ring = np.exp(-((d - r * 1.3) / (r * 0.35)) ** 2) * 0.12
        s = (spot + ring)[..., None]
        img = img * (1 - s) + np.array([196, 150, 104], np.float32) * s

    # Age toward the edges.
    nx, ny = (xx / (w - 1)) * 2 - 1, (yy / (h - 1)) * 2 - 1
    edge = np.clip(np.maximum(np.abs(nx) ** 6, np.abs(ny) ** 6) + 0.25 * (nx ** 2 + ny ** 2), 0, 1.2)
    edge = edge + 0.15 * field(rng, h, w, 14) * edge
    img -= edge[..., None] * np.array([18, 24, 38], np.float32) * vignette / 0.06

    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def tooth_mask(w, h, seed):
    """Alpha where the paper dips: pigment settles here. Black RGB, alpha carries the mask."""
    rng = np.random.default_rng(seed)
    hgt = tooth_height(rng, h, w)
    fine = field(rng, h, w, 0.55)
    valley = np.clip(-(hgt * 0.8 + fine * 0.35), 0, None)
    valley = valley / (np.percentile(valley, 99.5) + 1e-9)
    # clumped granules: multiply by a patchy field so some areas granulate more
    patch = np.clip(0.55 + 0.45 * field(rng, h, w, 6), 0.1, 1)
    alpha = np.clip(valley ** 1.15 * patch, 0, 1)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main():
    paper(164, 164, 11).save(os.path.join(HERE, "paper-small.png"), optimize=True)
    paper(348, 164, 12).save(os.path.join(HERE, "paper-medium.png"), optimize=True)
    paper(348, 365, 13).save(os.path.join(HERE, "paper-large.png"), optimize=True)
    # Smoother, whiter card stock for the taped weather card and the button disc.
    paper(140, 120, 21, base=(250, 246, 236), vignette=0.03, foxing=1).save(os.path.join(HERE, "card.png"), optimize=True)
    tooth_mask(350, 370, 31).save(os.path.join(HERE, "tooth.png"), optimize=True)
    # Wallpaper (not a widget, so it can be full board size).
    paper(780, 805, 41, base=(238, 229, 208), vignette=0.0, foxing=10).save(os.path.join(HERE, "wall.png"), optimize=True)
    print("textures written to", HERE)


if __name__ == "__main__":
    main()
