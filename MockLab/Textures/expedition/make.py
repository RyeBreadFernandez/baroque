#!/usr/bin/env python3
"""Expedition textures: the materials of a 1970s stop-motion field-station miniature.

  felt.png        360x380 RGBA  felt fibres (light and dark, alpha carries strength), laid over any coloured felt piece
  grain.png       360x380 RGBA  film grain (light and dark speckle), laid over the whole widget
  sky.png         360x260 RGB   painted muslin backdrop, faded Kodachrome cyan to warm haze at the bottom
  card.png        320x280 RGB   cream card stock for typed labels, index and catalog cards
  walnut.png      360x200 RGB   walnut veneer for the plinth and the clipboard
  stampwear.png   160x60  RGBA  rubber-stamp ink wear (alpha mask: opaque ink, speckled holes)
  wall.png       1560x1610 RGB  striped knit wallpaper for the comparison board (not a widget, so full size)

Widget textures stay near 1 px per point (WidgetKit refuses widgets with oversized images).
Run from anywhere:  python3 MockLab/Textures/expedition/make.py   (deterministic, fixed seeds)
"""
import os
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))


def field(rng, h, w, sigma, mode="wrap"):
    n = gaussian_filter(rng.standard_normal((h, w)), sigma, mode=mode)
    return n / (n.std() + 1e-9)


def aniso(rng, h, w, sy, sx):
    n = gaussian_filter(rng.standard_normal((h, w)), (sy, sx), mode="wrap")
    return n / (n.std() + 1e-9)


def signed_rgba(s, light=(255, 248, 232), dark=(38, 22, 12), gain=1.0, cap=0.6):
    """Signed shading -> RGBA: positive values become light fibres, negative dark, alpha = |s|."""
    h, w = s.shape
    out = np.zeros((h, w, 4), np.float32)
    pos = s > 0
    out[pos, :3] = light
    out[~pos, :3] = dark
    out[..., 3] = np.clip(np.abs(s) * gain, 0, cap)
    out[..., 3] *= 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def draw_fibres(rng, h, w, count, ss=3, curl=0.25, length=(3, 10), width=(0.35, 0.8)):
    """Supersampled curly fibres, returned as a float field in [0, 1]."""
    H, W = h * ss, w * ss
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.uniform(-10, W + 10), rng.uniform(-10, H + 10)
        L = rng.uniform(*length) * ss
        a = rng.uniform(0, 2 * np.pi)
        bend = rng.uniform(-curl, curl)
        pts = [(x, y)]
        steps = 7
        for _s in range(steps):
            a += bend
            x += np.cos(a) * L / steps
            y += np.sin(a) * L / steps
            pts.append((x, y))
        d.line(pts, fill=int(rng.uniform(90, 255)), width=max(1, int(rng.uniform(*width) * ss)))
    small = img.resize((w, h), Image.LANCZOS)
    return np.asarray(small, np.float32) / 255


def felt(w, h, seed):
    rng = np.random.default_rng(seed)
    a = draw_fibres(rng, h, w, int(w * h / 3.2), curl=0.35, length=(2.5, 8))
    b = draw_fibres(rng, h, w, int(w * h / 6.0), curl=0.2, length=(4, 12), width=(0.3, 0.6))
    # Felt is pressed unevenly: cloudy density at a few points, plus fine pilling.
    cloud = 0.6 * field(rng, h, w, 7) + 0.4 * field(rng, h, w, 2.5)
    pill = field(rng, h, w, 0.7)
    hgt = a * 0.9 + b * 0.6 + cloud * 0.18
    gy, gx = np.gradient(gaussian_filter(hgt, 0.5))
    emboss = -(gx * 0.8 + gy * 0.6)
    emboss /= np.abs(emboss).std() + 1e-9
    s = 0.24 * emboss + 0.36 * (a - a.mean()) / (a.std() + 1e-9) + 0.08 * cloud + 0.10 * pill
    s = s / (np.abs(s).std() + 1e-9)
    return signed_rgba(s * 0.17, gain=1.0, cap=0.55)


def grain(w, h, seed):
    rng = np.random.default_rng(seed)
    g = gaussian_filter(rng.standard_normal((h, w)), 0.55, mode="wrap")
    g /= g.std() + 1e-9
    clump = np.clip(0.75 + 0.35 * field(rng, h, w, 3), 0.3, 1.4)
    return signed_rgba(g * clump * 0.16, light=(255, 244, 222), dark=(30, 16, 6), cap=0.5)


def sky(w, h, seed):
    """Painted muslin: faded Kodachrome cyan up top, warming through pale aqua to a peach-cream haze."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = yy / (h - 1)
    stops = [(0.0, (74, 150, 166)), (0.35, (122, 182, 182)), (0.68, (196, 214, 190)), (0.88, (238, 217, 170)), (1.0, (243, 204, 150))]
    img = np.zeros((h, w, 3), np.float32)
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        m = (t >= t0) & (t <= t1)
        u = ((t - t0) / (t1 - t0))[m]
        img[m] = np.array(c0) * (1 - u[:, None]) + np.array(c1) * u[:, None]
    # Broad horizontal brush strokes (scene-painter's backdrop), plus a few warmer patches.
    strokes = 0.6 * aniso(rng, h, w, 2.2, 26) + 0.4 * aniso(rng, h, w, 1.0, 9)
    img += strokes[..., None] * np.array([5.0, 5.0, 4.0])
    warm = np.clip(field(rng, h, w, 30), 0, None)
    img += warm[..., None] * np.array([6, 2, -4])
    # Canvas weave: fine warp and weft.
    weave = 0.5 * np.sin(xx * 2.1 + field(rng, h, w, 3) * 0.6) + 0.5 * np.sin(yy * 2.3 + field(rng, h, w, 3) * 0.6)
    img += weave[..., None] * 2.2
    img += rng.standard_normal((h, w, 1)) * 1.6
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def card(w, h, seed):
    rng = np.random.default_rng(seed)
    img = np.ones((h, w, 3), np.float32) * np.array([244, 232, 203], np.float32)
    mott = 0.6 * field(rng, h, w, 18) + 0.4 * field(rng, h, w, 5)
    img += mott[..., None] * np.array([2.4, 2.8, 4.0])
    f = draw_fibres(rng, h, w, int(w * h / 40), curl=0.08, length=(3, 9), width=(0.25, 0.5))
    img -= f[..., None] * np.array([13, 13, 16]) * (rng.uniform(size=(h, w, 1)) < 0.6)
    tooth = field(rng, h, w, 0.8)
    gy, gx = np.gradient(gaussian_filter(tooth, 0.6))
    img += (-(gx * 0.8 + gy * 0.6))[..., None] * 9
    img += rng.standard_normal((h, w, 1)) * 1.2
    # Age: a faint tan toward the edges.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = xx / (w - 1) * 2 - 1, yy / (h - 1) * 2 - 1
    edge = np.clip(np.maximum(np.abs(nx) ** 8, np.abs(ny) ** 8) + 0.2 * (nx ** 2 + ny ** 2), 0, 1.2)
    img -= edge[..., None] * np.array([8, 14, 26])
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def walnut(w, h, seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Long, gently drifting grain: the warp varies slowly along the board and a little across it.
    warp = aniso(rng, h, w, 10, 70) * 7 + aniso(rng, h, w, 3, 20) * 1.4
    rings = np.sin((yy + warp) * 0.42) * 0.5 + 0.5
    rings = rings ** 3
    fine = aniso(rng, h, w, 0.35, 22)
    pores = (aniso(rng, h, w, 0.45, 4) > 2.1).astype(np.float32)
    base = np.array([104, 67, 39], np.float32)
    dark = np.array([60, 35, 19], np.float32)
    img = base * (1 - rings[..., None] * 0.5) + dark * rings[..., None] * 0.5
    img += fine[..., None] * np.array([8, 5, 3])
    img -= pores[..., None] * np.array([16, 11, 7])
    figure = aniso(rng, h, w, 20, 50)
    img += figure[..., None] * np.array([10, 7, 4])
    img += rng.standard_normal((h, w, 1)) * 1.3
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def stampwear(w, h, seed):
    rng = np.random.default_rng(seed)
    a = 0.8 * field(rng, h, w, 1.2) + 0.5 * field(rng, h, w, 5)
    ink = np.clip(1.6 - np.clip(a - 0.6, 0, None) * 1.8, 0, 1)
    speck = rng.uniform(size=(h, w)) < 0.035
    ink[speck] *= 0.25
    ink = gaussian_filter(ink, 0.35)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 0
    rgba[..., 3] = (np.clip(ink, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def knit(w, h, seed):
    """Stockinette stripes: columns of V stitches, each V two plump yarn legs that meet at the bottom,
    overlapping the row below, shaded from the upper left."""
    rng = np.random.default_rng(seed)
    cw, ch = 24.0, 20.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    i = np.floor(xx / cw)
    j0 = np.floor(yy / ch)
    best = np.zeros((h, w), np.float32)
    best_row = j0.astype(int).copy()
    tilt = 0.40
    for dj in (-1, 0, 1):
        j = j0 + dj
        for side, cx in ((-1, 0.30), (1, 0.70)):
            a = -side * tilt
            dx = xx - (i * cw + cx * cw)
            dy = yy - (j * ch + 0.62 * ch)
            along = dx * np.sin(a) + dy * np.cos(a)
            across = dx * np.cos(a) - dy * np.sin(a)
            d = (across / (cw * 0.19)) ** 2 + (along / (ch * 0.66)) ** 2
            leg = np.clip(1 - d, 0, 1) ** 0.55
            # The lower leg of a stitch tucks under the stitch below it.
            m = leg > best
            best = np.where(m, leg, best)
            best_row = np.where(m, j.astype(int), best_row)
    hgt = best
    yarn = field(rng, h, w, 0.6) * 0.10 + aniso(rng, h, w, 2.0, 0.5) * 0.08
    hgt = hgt + yarn * (hgt > 0.05)
    gy, gx = np.gradient(gaussian_filter(hgt, 0.9))
    light = -(gx * 0.7 + gy * 0.9) * 3.2
    palette = {
        "mustard": (214, 160, 52), "cream": (238, 223, 188), "tomato": (196, 66, 46),
        "teal": (46, 104, 108), "khaki": (176, 154, 104), "burnt": (192, 98, 44), "prussian": (34, 58, 84),
    }
    pattern = (["mustard"] * 5 + ["cream"] * 2 + ["tomato"] * 3 + ["cream"] * 2 + ["teal"] * 5 +
               ["khaki"] * 2 + ["burnt"] * 3 + ["khaki"] * 2 + ["prussian"] * 2 + ["cream"] * 1)
    rows = np.clip(best_row, 0, None)
    cols = np.array([palette[pattern[r % len(pattern)]] for r in range(rows.max() + 1)], np.float32)
    base = cols[rows]
    shade = (0.42 + 0.68 * hgt)[..., None]
    img = base * shade + light[..., None] * 34
    img += rng.standard_normal((h, w, 1)) * 3
    fuzz = draw_fibres(rng, h, w, int(w * h / 110), ss=1, curl=0.5, length=(3, 8), width=(1, 1))
    img = img * (1 - fuzz[..., None] * 0.22) + 245 * fuzz[..., None] * 0.22
    nx, ny = xx / (w - 1) * 2 - 1, yy / (h - 1) * 2 - 1
    vig = np.clip(1 - 0.28 * (nx ** 2 + ny ** 2), 0.55, 1)
    img *= vig[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def main():
    felt(360, 380, 1).save(os.path.join(HERE, "felt.png"), optimize=True)
    grain(360, 380, 2).save(os.path.join(HERE, "grain.png"), optimize=True)
    sky(360, 260, 3).save(os.path.join(HERE, "sky.png"), optimize=True)
    card(320, 280, 4).save(os.path.join(HERE, "card.png"), optimize=True)
    walnut(360, 200, 5).save(os.path.join(HERE, "walnut.png"), optimize=True)
    stampwear(160, 60, 6).save(os.path.join(HERE, "stampwear.png"), optimize=True)
    knit(1560, 1610, 7).save(os.path.join(HERE, "wall.png"), optimize=True)
    print("textures written to", HERE)


if __name__ == "__main__":
    main()
