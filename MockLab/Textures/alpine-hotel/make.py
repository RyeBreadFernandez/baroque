#!/usr/bin/env python3
"""Alpine Hotel textures. All three are grey-centred (128 = no change) so the Swift code lays them over painted
colour with a blend mode instead of baking colour in:

  gouache.png  348x365  broad, mostly horizontal brush strokes with bristle streaks (soft light over the matte painting)
  paper.png    348x365  card stock: mottling, fibres and tooth (soft light over cards, stamps, the ledger, the walls)
  grain.png    348x365  film grain, fine with a few clumps (overlay over the finished frame)

348x365 is the large widget at 1 px per point; smaller widgets draw them scaled down or tiled.
Run from anywhere:  python3 MockLab/Textures/alpine-hotel/make.py   (deterministic, fixed seeds)
"""
import os
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 348, 365


def field(rng, h, w, sigma):
    n = gaussian_filter(rng.standard_normal((h, w)), sigma, mode="wrap")
    return n / (n.std() + 1e-9)


def save_grey(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L").save(os.path.join(HERE, name), optimize=True)


def gouache(seed=3):
    """Overlapping flat-brush strokes. Each stroke carries its own value shift plus bristle streaks along its length."""
    rng = np.random.default_rng(seed)
    ss = 3
    w, h = W * ss, H * ss
    acc = np.zeros((h, w), np.float32)
    count = int(W * H / 70)
    for _ in range(count):
        length = rng.uniform(16, 52) * ss
        width = rng.uniform(4, 11) * ss
        ang = rng.normal(0, 0.10)
        cx, cy = rng.uniform(-20, w + 20), rng.uniform(-20, h + 20)
        shift = rng.normal(0, 11)
        # stroke footprint, drawn as a tapered polygon on a small canvas
        pad = int(length / 2 + width) + 4
        tile = Image.new("L", (2 * pad, 2 * pad), 0)
        d = ImageDraw.Draw(tile)
        ca, sa = np.cos(ang), np.sin(ang)
        pts_top, pts_bot = [], []
        steps = 12
        for s in range(steps + 1):
            t = s / steps
            x = (t - 0.5) * length
            taper = np.sin(np.pi * min(1, t * 1.6 + 0.08)) ** 0.5 if t < 0.6 else (1 - (t - 0.6) / 0.4 * 0.55)
            hw = width / 2 * max(0.25, taper) * (1 + 0.08 * np.sin(t * 9 + cx))
            pts_top.append((pad + x * ca - hw * sa, pad + x * sa + hw * ca))
            pts_bot.append((pad + x * ca + hw * sa, pad + x * sa - hw * ca))
        d.polygon(pts_top + pts_bot[::-1], fill=255)
        m = np.asarray(tile, np.float32) / 255
        x0, y0 = int(cx) - pad, int(cy) - pad
        xs0, ys0 = max(0, x0), max(0, y0)
        xs1, ys1 = min(w, x0 + 2 * pad), min(h, y0 + 2 * pad)
        if xs1 <= xs0 or ys1 <= ys0:
            continue
        sub = m[ys0 - y0:ys1 - y0, xs0 - x0:xs1 - x0]
        # paint over: strokes replace part of what is under them, like opaque gouache
        region = acc[ys0:ys1, xs0:xs1]
        acc[ys0:ys1, xs0:xs1] = region * (1 - 0.7 * sub) + shift * 0.7 * sub
    acc = gaussian_filter(acc, 0.8 * ss)
    img = Image.fromarray(np.clip(acc + 128, 0, 255).astype(np.uint8), "L").resize((W, H), Image.LANCZOS)
    base = np.asarray(img, np.float32)
    # bristle streaks, mostly horizontal
    streak = gaussian_filter(rng.standard_normal((H, W)), (0.35, 5.0), mode="wrap")
    streak /= streak.std() + 1e-9
    tooth = field(rng, H, W, 0.7)
    out = base + streak * 5.5 + tooth * 3.0
    save_grey(out, "gouache.png")


def paper(seed=5):
    rng = np.random.default_rng(seed)
    img = np.full((H, W), 128.0, np.float32)
    img += (0.6 * field(rng, H, W, 22) + 0.4 * field(rng, H, W, 7)) * 4.5
    hgt = 0.7 * field(rng, H, W, 1.2) + 0.3 * field(rng, H, W, 3.0)
    gy, gx = np.gradient(gaussian_filter(hgt, 0.5))
    shade = -(gx * 0.7 + gy * 0.7)
    img += shade / (np.abs(shade).std() + 1e-9) * 4.0
    img += rng.standard_normal((H, W)) * 1.6
    # fibres
    ss = 4
    fib = Image.new("L", (W * ss, H * ss), 128)
    d = ImageDraw.Draw(fib)
    for _ in range(int(W * H / 45)):
        x, y = rng.uniform(0, W * ss), rng.uniform(0, H * ss)
        L = rng.uniform(4, 16) * ss
        a = rng.uniform(0, np.pi)
        bend = rng.uniform(-0.1, 0.1)
        pts = []
        for s in range(9):
            aa = a + bend * s
            x += np.cos(aa) * L / 8
            y += np.sin(aa) * L / 8
            pts.append((x, y))
        v = 128 + (rng.uniform(-60, -20) if rng.uniform() < 0.55 else rng.uniform(20, 50))
        d.line(pts, fill=int(v), width=max(1, int(rng.uniform(0.25, 0.55) * ss)))
    fibres = np.asarray(fib.resize((W, H), Image.LANCZOS), np.float32) - 128
    img += fibres * 0.35
    save_grey(img, "paper.png")


def grain(seed=9):
    rng = np.random.default_rng(seed)
    fine = rng.standard_normal((H, W))
    clump = gaussian_filter(rng.standard_normal((H, W)), 0.9, mode="wrap")
    clump /= clump.std() + 1e-9
    g = 0.75 * fine + 0.55 * clump
    g /= g.std() + 1e-9
    save_grey(128 + g * 30, "grain.png")


def main():
    gouache()
    paper()
    grain()
    print("textures written to", HERE)


if __name__ == "__main__":
    main()
