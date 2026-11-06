#!/usr/bin/env python3
"""Crimson Hours textures (all near 1 px per point of the widget that uses them).

  grain-{small,medium,large}.png   film grain for an overlay blend: mid grey (128) +/- clumped noise,
                                   a breath of low-frequency flicker, a few dust specks.
  wall-{small,medium,large}.png    age on the flocked wallpaper, drawn normally over the vector pattern:
                                   faded patches, water-stain tide lines, soot near the ceiling, paper fibre.
  paper.png                        cream onionskin letter paper for the task ledger (laid lines, fibres, foxing).
  paper-cal.png                    the tear-off calendar's cheap yellowed pad paper.

Run from anywhere:  python3 MockLab/Textures/crimson-hours/make.py   (deterministic, fixed seeds)
"""
import os
import numpy as np
from scipy.ndimage import gaussian_filter, binary_dilation
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = {"small": (164, 164), "medium": (348, 164), "large": (348, 365)}


def field(rng, h, w, sigma):
    n = gaussian_filter(rng.standard_normal((h, w)), sigma, mode="wrap")
    return n / (n.std() + 1e-9)


def grain(w, h, seed):
    rng = np.random.default_rng(seed)
    g = 0.75 * rng.standard_normal((h, w)) + 0.45 * field(rng, h, w, 0.7)
    g = g / g.std()
    flicker = 0.18 * field(rng, h, w, 30)
    v = 128 + 26 * g + 10 * flicker
    # dust: a few dark specks (dirt on the print) and fewer bright ones (scratches through the emulsion)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for _ in range(max(2, w * h // 9000)):
        cx, cy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.5, 1.3)
        d = np.exp(-(((xx - cx) ** 2 + ((yy - cy) * rng.uniform(0.6, 1.4)) ** 2) / (r * r)))
        v -= d * 70
    for _ in range(max(1, w * h // 20000)):
        cx, cy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.4, 0.9)
        d = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r)))
        v += d * 70
    v = np.clip(v, 0, 255).astype(np.uint8)
    rgba = np.dstack([v, v, v, np.full_like(v, 255)])
    return Image.fromarray(rgba, "RGBA")


def over(dst_rgb, dst_a, rgb, a):
    """Straight-alpha 'over' compositing of (rgb, a) onto (dst_rgb, dst_a)."""
    out_a = a + dst_a * (1 - a)
    out_rgb = (rgb * a[..., None] + dst_rgb * dst_a[..., None] * (1 - a[..., None])) / np.maximum(out_a[..., None], 1e-6)
    return out_rgb, out_a


def wall(w, h, seed):
    rng = np.random.default_rng(seed)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    # Faded patches where the sun once reached: pale rose, very low alpha.
    fade = np.clip(field(rng, h, w, 22) * 0.6 + field(rng, h, w, 7) * 0.25, 0, None)
    rgb, a = over(rgb, a, np.broadcast_to(np.array([236, 190, 168], np.float32), (h, w, 3)), np.clip(fade * 0.07, 0, 0.12))

    # Soot from the lamp and the ceiling: darkening toward the top edge.
    soot = np.clip(1 - yy / (h * 0.45), 0, 1) ** 2 * (0.5 + 0.5 * np.clip(field(rng, h, w, 12) * 0.5 + 0.5, 0, 1))
    rgb, a = over(rgb, a, np.broadcast_to(np.array([20, 8, 6], np.float32), (h, w, 3)), soot * 0.22)

    # Water stains: irregular blobs with a darker tide line.
    for _ in range(2 if w * h < 40000 else 3):
        cx, cy = rng.uniform(0.1, 0.9) * w, rng.uniform(0.15, 0.95) * h
        rx, ry = rng.uniform(14, 34), rng.uniform(18, 44)
        d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
        d = d + 0.35 * field(rng, h, w, 5) * 0.4 + 0.15 * field(rng, h, w, 2)
        inside = np.clip(1 - d, 0, 1) ** 0.6
        tide = np.exp(-((d - 1.0) / 0.06) ** 2)
        rgb, a = over(rgb, a, np.broadcast_to(np.array([40, 16, 10], np.float32), (h, w, 3)), inside * 0.10)
        rgb, a = over(rgb, a, np.broadcast_to(np.array([30, 12, 8], np.float32), (h, w, 3)), tide * 0.28)

    # Paper fibre and speckle of the wallpaper stock.
    n = rng.standard_normal((h, w))
    dark = np.clip(-n - 1.2, 0, None)
    light = np.clip(n - 1.4, 0, None)
    rgb, a = over(rgb, a, np.broadcast_to(np.array([12, 4, 4], np.float32), (h, w, 3)), np.clip(dark * 0.10, 0, 0.18))
    rgb, a = over(rgb, a, np.broadcast_to(np.array([250, 214, 190], np.float32), (h, w, 3)), np.clip(light * 0.07, 0, 0.12))

    out = np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def fibers(rng, h, w, count, ss=3):
    H, W = h * ss, w * ss
    dark = Image.new("L", (W, H), 0)
    light = Image.new("L", (W, H), 0)
    dd, ld = ImageDraw.Draw(dark), ImageDraw.Draw(light)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        length = rng.uniform(4, 16) * ss
        ang = rng.uniform(0, np.pi)
        bend = rng.uniform(-0.1, 0.1)
        pts = []
        for s in range(9):
            a = ang + bend * s
            x += np.cos(a) * length / 8
            y += np.sin(a) * length / 8
            pts.append((x, y))
        width = max(1, int(rng.uniform(0.3, 0.6) * ss))
        if rng.uniform() < 0.6:
            dd.line(pts, fill=int(rng.uniform(60, 150)), width=width)
        else:
            ld.line(pts, fill=int(rng.uniform(90, 200)), width=width)
    size = (w, h)
    return (np.asarray(dark.resize(size, Image.LANCZOS), np.float32) / 255,
            np.asarray(light.resize(size, Image.LANCZOS), np.float32) / 255)


def paper(w, h, seed, base, laid=True, foxing=5, age=1.0, coarse=1.0):
    rng = np.random.default_rng(seed)
    img = np.ones((h, w, 3), np.float32) * np.array(base, np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = 0.6 * field(rng, h, w, 18) + 0.4 * field(rng, h, w, 6)
    img += mott[..., None] * np.array([2.4, 2.8, 4.0], np.float32) * coarse
    img += rng.standard_normal((h, w, 1)).astype(np.float32) * 1.6 * coarse
    if laid:
        # laid lines (fine horizontal) and chain lines (every ~24 px) pressed into the sheet
        laid_l = 0.5 + 0.5 * np.cos(yy * 2 * np.pi / 1.6)
        chain = np.exp(-((np.mod(xx + 7, 24) - 12) / 0.7) ** 2)
        img -= (laid_l * 1.4 + chain * 3.0)[..., None]
    dark, light = fibers(rng, h, w, int(w * h / 70 * coarse))
    img -= dark[..., None] * np.array([22, 22, 26], np.float32)
    img += light[..., None] * np.array([10, 10, 8], np.float32)
    for _ in range(foxing):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1.0, 3.8)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        s = (np.exp(-(d / r) ** 2) * rng.uniform(0.15, 0.35) + np.exp(-((d - r * 1.3) / (r * 0.35)) ** 2) * 0.1)[..., None]
        img = img * (1 - s) + np.array([186, 136, 92], np.float32) * s
    nx, ny = (xx / (w - 1)) * 2 - 1, (yy / (h - 1)) * 2 - 1
    edge = np.clip(np.maximum(np.abs(nx) ** 8, np.abs(ny) ** 8) + 0.2 * (nx ** 2 + ny ** 2), 0, 1.2)
    edge = edge * (1 + 0.2 * field(rng, h, w, 10))
    img -= edge[..., None] * np.array([16, 26, 44], np.float32) * age
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def main():
    for i, (name, (w, h)) in enumerate(SIZES.items()):
        grain(w, h, 100 + i).save(os.path.join(HERE, f"grain-{name}.png"), optimize=True)
        wall(w, h, 200 + i).save(os.path.join(HERE, f"wall-{name}.png"), optimize=True)
    paper(330, 190, 301, base=(242, 233, 212), laid=True, foxing=6).save(os.path.join(HERE, "paper.png"), optimize=True)
    paper(130, 170, 302, base=(240, 228, 200), laid=False, foxing=4, age=1.4, coarse=1.3).save(os.path.join(HERE, "paper-cal.png"), optimize=True)
    print("textures written to", HERE)


if __name__ == "__main__":
    main()
