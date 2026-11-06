#!/usr/bin/env python3
"""Storybook Night textures: a gouache picture-book plate of the Matterhorn above the Riffelsee, for the weather mocks.

Every Weather widget is one illustration: the Matterhorn in its true skyline (matterhorn.json, traced from a photograph
taken at the Riffelsee; Old Master Cover's matterhorn() paints its faces) standing over a still lake that mirrors it,
a far shore of small dark pines and a few amber larches, and dark pine banks framing the lower corners. It is painted
the way a gouache illustration is: flat opaque shapes in a few values, scumbled where the values meet, soft rounded
clouds lit on their tops, painted stars, horizontal strokes on the water and the grain of the paper showing through.

Each canvas is painted three times, in the same strokes and different paint: day, dusk and night. The widget lays the
nearer of day or night under the dusk plate and fades between them with SkyClock's twilight, so the picture follows
the time of day. The moon (tonight's phase), the sun and their glitter path on the water are drawn by SwiftUI, on an
arc kept in the open sky right of the summit; the cloud deck for grey weather is a tinted alpha overlay.

Plates (1 px per point, the widget's own size), for <size> in large 348x365, medium 348x164, small 164x164:
  <size>-day.png, <size>-dusk.png, <size>-night.png   RGB, the painted plate in each light
  <size>-deck.png       alpha = an overcast deck over the sky and its reflection (tinted at run time)
  <size>-deck-lit.png   alpha = the deck's lit billow tops
  <size>-scatter.png, <size>-scatter-lit.png   the same for the few clouds of a part-cloudy sky
  <size>-lake.png       alpha = the open water, where the glitter path and raindrop rings may fall
Other textures:
  ground.png      348x164  the deep forest-green gouache ground of the To-do widget
  page-medium.png 316x134  the To-do page: a deckle-edged parchment leaf (RGBA)
  page-small.png  136x136  the same leaf, cut for the small widget (RGBA)
  wallpaper.jpg   780x805  the board's home screen: a storybook night over a dark wood (not a widget texture)

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-storybook/make.py [names...]
Add --preview <folder> to also write the plates at 2x for review.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing Old Master Cover's make.py (and through it scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("omc_make", os.path.join(os.path.dirname(HERE), "old-master-cover", "make.py"))
omc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(omc)
om, mt = omc.om, omc.mt
SS = om.SS  # painted at 2x and reduced to 1 px per point
fbm, smoothstep, hexrgb = mt.fbm, mt.smoothstep, mt.hexrgb


# MARK: Files

def save_rgb(name, rgb):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    path = os.path.join(HERE, name)
    if name.endswith(".jpg"):
        img.save(path, quality=88, optimize=True)
    else:
        img.save(path, optimize=True)
    print(f"{name}: {rgb.shape[1]}x{rgb.shape[0]}")


def save_rgba(name, rgb, a):
    arr = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)[..., None]], axis=2)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(HERE, name), optimize=True)
    print(f"{name}: {rgb.shape[1]}x{rgb.shape[0]}")


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name), optimize=True)
    print(f"{name}: {a.shape[1]}x{a.shape[0]}")


def down(a):
    """Box-filters an SS-times canvas (2-D or RGB) to 1 px per point."""
    if a.ndim == 3:
        return np.stack([om.down(a[..., i]) for i in range(a.shape[2])], axis=2)
    return om.down(a)


# MARK: Paint

def ramp(v, stops):
    """Colour for every value: piecewise linear through [(value, 0xRRGGBB), ...]."""
    ts = [t for t, _ in stops]
    cols = np.array([hexrgb(c) for _, c in stops])
    return np.stack([np.interp(v, ts, cols[:, i]) for i in range(3)], axis=2)


def tint(mask, color):
    return mask[..., None] * hexrgb(color)[None, None, :]


def over(base, color, alpha):
    """Lays opaque paint (an RGB field or one colour) over base where alpha is."""
    if np.ndim(color) == 1:
        color = color[None, None, :]
    return base + (color - base) * alpha[..., None]


def posterize(v, steps, scumble, soft=0.035):
    """A gouache value study: v pushed toward a few flat values, the step between two values broken by `scumble`
    (a noise field) the way a dry brush leaves the lower value showing through."""
    out = np.full_like(v, steps[0][1])
    for edge, value in steps[1:]:
        out = out + (value - out) * smoothstep(edge - soft, edge + soft, v + scumble)
    return out


def strokes(field, angle, rng, k, sizes, jitter=0.025):
    """Opaque gouache strokes over an RGB field (scripts/make_textures.py paint()), coarse to fine; `sizes` are
    (count per 348x365 pt, width pt, length pt) and are scaled to the canvas area k and to SS."""
    s = SS
    passes = [(max(8, int(c * k)), (w0 * s, w1 * s), (l0 * s, l1 * s)) for c, (w0, w1), (l0, l1) in sizes]
    return mt.paint(field, angle, rng, passes, jitter)


def within(rgb, mask, sigma):
    """rgb inside the mask; outside it, the mask's nearby colours, so a brush loaded near an edge never drags the
    colour across it (Old Master Cover's within(), per channel)."""
    return np.stack([omc.within(rgb[..., i], mask, sigma) for i in range(3)], axis=2)


def grain(h, w, rng):
    """The tooth of the paper: fine speckled grain plus a faint cold-press weave."""
    g = 0.6 * rng.standard_normal((h, w))
    g = gaussian_filter(g, 0.6) + 0.5 * fbm(h, w, rng, base=90, octaves=2)
    return g / (g.std() + 1e-9)


# MARK: Trees

def pine(x, base, h, rng, tiers=None, width=0.42):
    """A storybook spruce: a narrow spire of drooping tiers, each tier's tips flicked up a little."""
    tiers = tiers or int(rng.integers(9, 13))
    w = h * width * rng.uniform(0.9, 1.1)
    top = base - h
    right, left = [], []
    for i in range(1, tiers + 1):
        f = i / tiers
        y = top + h * 0.9 * f
        half = w / 2 * (0.1 + 0.9 * f ** 0.85) * rng.uniform(0.85, 1.12)
        droop = h * 0.025
        right += [(x + half * 0.42, y - h * 0.9 / tiers * 0.55), (x + half, y + droop * 0.4), (x + half * 0.55, y)]
        lh = half * rng.uniform(0.85, 1.12)
        left += [(x - lh * 0.42, y - h * 0.9 / tiers * 0.55), (x - lh, y + droop * 0.4), (x - lh * 0.55, y)]
    trunk = [(x + w * 0.05, base + h * 0.04), (x - w * 0.05, base + h * 0.04)]
    return [(x, top)] + right + trunk + list(reversed(left))


def larch(x, base, h, rng):
    """A larch in autumn: a narrow cone, its sides swelling a little at each tier of drooping branches, a little
    lopsided, on a thin trunk. Returns (outline, centre x, half width, top y, base y, tiers)."""
    w = h * rng.uniform(0.42, 0.5)
    top = base - h
    tiers = rng.uniform(5.5, 7.5)
    phase = rng.uniform(0, 2 * np.pi)
    lean = rng.uniform(-0.04, 0.04) * h
    right, left = [], []
    n = 48
    for i in range(n + 1):
        f = i / n
        y = top + h * 0.92 * f
        swell = 1 + 0.12 * np.sin(f * tiers * 2 * np.pi + phase) * f ** 0.5
        half = w / 2 * (0.06 + 0.94 * f ** 0.85) * swell
        cx = x + lean * (1 - f)
        right.append((cx + half, y))
        left.append((cx - half * rng.uniform(0.94, 1.0), y))
    trunk = [(x + w * 0.04, base + h * 0.04), (x - w * 0.04, base + h * 0.04)]
    return [(x + lean, top)] + right + trunk + list(reversed(left)), x, w / 2, top, base, tiers, phase


def tufted(w, h, trees, rng):
    """Larches: coverage (the cone's edge broken into clumps of needles), a value field (shaded from the far side to
    the lit side, a darker band under each tier of branches, dappled) and their trunks."""
    raw = polygons(w, h, [t[0] for t in trees])
    clumps = fbm(h, w, rng, base=110, octaves=2)
    cover = np.clip((gaussian_filter(raw, 0.9 * SS) - 0.5) * 2.6 + 0.5 + 0.3 * clumps, 0, 1) * (raw > 0.005)
    value = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    dapple = fbm(h, w, rng, base=80, octaves=3)
    for poly, cx, half, top, base, tiers, phase in trees:
        x0, x1 = int(max(0, cx - half * 1.3 - 4)), int(min(w, cx + half * 1.3 + 5))
        y0, y1 = int(max(0, top - 3)), int(min(h, base + 4))
        if x1 <= x0 or y1 <= y0:
            continue
        X, Y = xx[y0:y1, x0:x1], yy[y0:y1, x0:x1]
        f = np.clip((Y - top) / max(1.0, base - top), 0, 1)
        across = (X - cx) / (half * (0.1 + 0.9 * f ** 0.85) + 1e-6)
        tier = 0.5 + 0.5 * np.sin(f * tiers * 2 * np.pi + phase + 1.2 + 0.6 * across ** 2)
        v = 0.25 + 0.5 * smoothstep(-0.8, 0.9, across) + 0.12 * (1 - f) - 0.16 * tier + 0.14 * dapple[y0:y1, x0:x1]
        value[y0:y1, x0:x1] = np.maximum(value[y0:y1, x0:x1], np.clip(v, 0, 1) * (raw[y0:y1, x0:x1] > 0.005))
    trunks = []
    for poly, cx, half, top, base, tiers, phase in trees:
        hh = base - top
        trunks.append([(cx - hh * 0.014, base - hh * 0.5), (cx + hh * 0.014, base - hh * 0.5),
                       (cx + hh * 0.022, base + hh * 0.04), (cx - hh * 0.022, base + hh * 0.04)])
    return cover, value, polygons(w, h, trunks)


def polygons(w, h, polys):
    """A 0..1 mask of polygons drawn at 2x and reduced, for soft painted edges."""
    img = Image.new("L", (w * 2, h * 2), 0)
    d = ImageDraw.Draw(img)
    for poly in polys:
        d.polygon([(px * 2, py * 2) for px, py in poly], fill=255)
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


def rim(mask, dx):
    """The lit edge of a silhouette on the side the light comes from (dx > 0: from the right)."""
    g = gaussian_filter(mask, 0.5 * SS)
    shifted = np.roll(g, -int(round(dx)), axis=1) if dx > 0 else np.roll(g, int(round(-dx)), axis=1)
    return np.clip(g - shifted, 0, 1) * mask


# MARK: Clouds

def billows(w, h, rng, masses, light=(0.6, -0.8)):
    """Storybook clouds: each mass a row of round billows (spheres) heaped on a flat base, lit from `light`, a fine
    darker line where one billow lies over the next, the base in shadow. masses: [(cx, cy, width, height, count[, lift])]
    in fractions; a mass with more lift lies in front. Returns value 0..1, coverage, the stroke angle round each billow."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    zmax = np.full((h, w), -1.0)
    ids = np.full((h, w), -1.0)
    nxf = np.zeros((h, w))
    nyf = np.zeros((h, w))
    base_shade = np.zeros((h, w))
    k = 0
    for mass in masses:
        cx, cy, cw, ch, count = mass[:5]
        lift = mass[5] if len(mass) > 5 else 0.0
        X, Y, CW, CH = cx * w, cy * h, cw * w, ch * h
        base = Y + CH * 0.5
        spheres = []
        for i in range(count):
            t = (i + 0.5) / count
            hump = np.sin(np.pi * t) ** 0.8
            r = CH * (0.3 + 0.45 * hump) * rng.uniform(0.8, 1.12)
            bx = X + (t - 0.5) * CW * 0.92 + rng.uniform(-0.03, 0.03) * CW
            by = base - r * rng.uniform(0.35, 0.6) - CH * 0.3 * hump
            spheres.append((bx, by, r))
        for i in range(count + 1):          # a lower row of small billows along the base
            t = i / count
            r = CH * rng.uniform(0.2, 0.3)
            spheres.append((X + (t - 0.5) * CW, base - r * 0.55, r))
        for bx, by, r in spheres:
            d2 = (xx - bx) ** 2 + (yy - by) ** 2
            z = np.sqrt(np.clip(r * r - d2, 0, None)) / r + (base - by) / (CH + 1e-6) * 0.25 + lift
            take = (d2 < r * r) & (yy < base) & (z > zmax)
            nxf = np.where(take, (xx - bx) / r, nxf)
            nyf = np.where(take, (yy - by) / r, nyf)
            ids = np.where(take, float(k), ids)
            zmax = np.where(take, z, zmax)
            k += 1
        m = (ids >= 0) & (yy < base) & (np.abs(xx - X) < CW)
        base_shade = np.maximum(base_shade, smoothstep(base - CH * 0.3, base, yy) * m)
    cover = gaussian_filter((ids >= 0).astype(np.float64), 0.6 * SS)
    lx, ly = light
    lz = 0.5
    nz = np.sqrt(np.clip(1 - nxf ** 2 - nyf ** 2, 0, 1))
    lam = (nxf * lx + nyf * ly + nz * lz) / np.sqrt(lx * lx + ly * ly + lz * lz)
    value = np.clip(0.5 + 0.55 * lam, 0, 1) * (1 - 0.4 * base_shade)
    seams = (np.abs(np.diff(ids, axis=0, prepend=ids[:1])) > 0) | (np.abs(np.diff(ids, axis=1, prepend=ids[:, :1])) > 0)
    seams = gaussian_filter(seams.astype(np.float64), 0.5 * SS) * (ids >= 0)
    value = value * (1 - 0.22 * np.clip(seams * 2, 0, 1))
    angle = np.arctan2(nyf, nxf) + np.pi / 2
    return value, cover, angle


# MARK: Plates

def p(x, y):
    return (x, y)


# Each plate's design, in fractions of the widget unless noted. summit: where the Matterhorn's summit stands, height:
# the pyramid's height in points (the traced skyline at one scale). water: the far shore's waterline; squash: how far
# the reflection is compressed so the mirrored summit shows above the near bank; bank: the near bank's crest; clouds:
# billow masses; far: the far-shore trees (x, height pt, kind); near: the near trees (x, base, height pt, kind);
# dark: the upper-left passage darkened under the type (x1, y1).
PLATES = {
    "large": dict(
        size=(348, 365), seed=11, summit=(0.665, 0.245), height=96, water=0.6, squash=0.62,
        bank=[p(0, 0.815), p(0.1, 0.83), p(0.3, 0.855), p(0.55, 0.862), p(0.78, 0.85), p(0.92, 0.83), p(1, 0.81)],
        clouds=[(0.93, 0.36, 0.2, 0.05, 4), (0.57, 0.07, 0.2, 0.042, 4)],
        far=[(0.06, 9, "p"), (0.1, 12, "p"), (0.135, 8, "l"), (0.17, 11, "p"), (0.42, 7, "l"), (0.46, 10, "p"),
             (0.5, 8, "p"), (0.7, 9, "l"), (0.74, 12, "p"), (0.78, 8, "p"), (0.81, 10, "l"), (0.86, 13, "p"),
             (0.9, 9, "p")],
        near=[(-0.02, 0.86, 120, "p"), (0.045, 0.875, 138, "p"), (0.1, 0.88, 96, "p"), (0.155, 0.885, 70, "l"),
              (0.2, 0.875, 44, "p"), (1.02, 0.84, 150, "p"), (0.96, 0.855, 128, "p"), (0.905, 0.87, 92, "p"),
              (0.85, 0.88, 74, "l"), (0.8, 0.87, 40, "p")],
        dark=(0.5, 0.45), mist=(0.82, 1.25, 0.42),
        scatter=[(0.3, 15, 0.46, 0.62, 0.9), (0.62, 11, 0.86, 1.05, 1.0), (0.78, 9, 0.02, 0.3, 0.8)]),
    "medium": dict(
        size=(348, 164), seed=13, summit=(0.715, 0.15), height=60, water=0.66, squash=0.55,
        bank=[p(0, 0.72), p(0.12, 0.74), p(0.3, 0.8), p(0.45, 0.86), p(0.6, 0.89), p(0.8, 0.885), p(1, 0.86)],
        clouds=[(0.94, 0.5, 0.14, 0.08, 4)],
        far=[(0.48, 7, "p"), (0.51, 9, "l"), (0.545, 6, "p"), (0.62, 8, "p"), (0.66, 6, "l"), (0.78, 9, "p"),
             (0.81, 7, "l"), (0.85, 10, "p"), (0.89, 7, "p"), (0.95, 8, "l")],
        near=[(0.015, 0.8, 86, "p"), (0.995, 0.93, 84, "p"), (0.955, 0.94, 52, "l")],
        dark=(0.66, 0.8), mist=(0.82, 1.2, 0.42),
        scatter=[(0.22, 11, 0.6, 0.72, 1.0), (0.72, 8, 0.86, 1.05, 1.0)]),
    "small": dict(
        size=(164, 164), seed=17, summit=(0.665, 0.29), height=50, water=0.7, squash=0.5,
        bank=[p(0, 0.82), p(0.2, 0.845), p(0.45, 0.87), p(0.7, 0.865), p(0.9, 0.84), p(1, 0.82)],
        clouds=[(0.93, 0.55, 0.16, 0.06, 3)],
        far=[(0.08, 6, "p"), (0.13, 8, "l"), (0.4, 6, "p"), (0.6, 7, "l"), (0.66, 9, "p"), (0.78, 6, "p"),
             (0.84, 8, "l"), (0.92, 7, "p")],
        near=[(0.01, 0.9, 60, "p"), (0.07, 0.905, 40, "l"), (0.995, 0.88, 66, "p"), (0.94, 0.9, 42, "p")],
        dark=(0.6, 0.72), mist=(0.82, 1.2, 0.42),
        scatter=[(0.62, 8, 0.82, 1.05, 1.0), (0.12, 7, 0.48, 0.62, 1.0)]),
}

# The paint for each light: values to colours. sky: top to the waterline; cloud, rock: dark to light values;
# far and near: pine, pine lit edge, larch, larch lit; water: the lake's own colour and how much of it is mixed in.
LIGHTS = {
    "night": dict(
        sky=[(0, 0x0A141D), (0.35, 0x0F1F2C), (0.75, 0x1C3442), (1.0, 0x30505A)],
        star=0xE9E3C8, stars=1.0,
        cloud=[(0, 0x14222F), (0.45, 0x253A4A), (0.72, 0x4A6472), (0.9, 0x8DA3AA), (1, 0xB9C7C6)],
        rock=[(0, 0x0C1520), (0.25, 0x16212F), (0.45, 0x263447), (0.62, 0x485C70), (0.8, 0x8197A6), (1, 0xC2D2D6)],
        mist=0x2A4250,
        meadow=[(0, 0x0F1A18), (1, 0x203029)],
        pine=0x0B1714, pine_lit=0x2E4C47, pine_mid=0x1A2E2A, larch_shade=0x3A2414, larch=0x7A4A20, larch_lit=0xC08A40,
        water=0x0A1822, water_mix=0.36, water_dark=0.56, ripple=0x4E6E7A,
        ground=[(0, 0x070D0B), (1, 0x101C17)], grass=0x1A2A22,
        dark=0.28),
    "dusk": dict(
        sky=[(0, 0x1E2A48), (0.35, 0x3F4466), (0.7, 0x9A6E78), (0.88, 0xD99A72), (1.0, 0xF0BC7C)],
        star=0xF2E2C0, stars=0.35,
        cloud=[(0, 0x3A3550), (0.45, 0x6E5A72), (0.72, 0xB57F78), (0.9, 0xEDAE82), (1, 0xF8D6A8)],
        rock=[(0, 0x1F1D30), (0.25, 0x2E2B44), (0.45, 0x504462), (0.62, 0x9A6676), (0.8, 0xEE9672), (1, 0xFFCF9C)],
        mist=0x8A6A78,
        meadow=[(0, 0x2A2420), (1, 0x5A4630)],
        pine=0x1A1E1C, pine_lit=0x5E4A36, pine_mid=0x33302A, larch_shade=0x4A2416, larch=0xA85A22, larch_lit=0xF4AE4C,
        water=0x2A3048, water_mix=0.28, water_dark=0.78, ripple=0xF0C090,
        ground=[(0, 0x120F0D), (1, 0x261E18)], grass=0x34281E,
        dark=0.24),
    "day": dict(
        sky=[(0, 0x2B546C), (0.35, 0x426E88), (0.72, 0x7FA2AE), (1.0, 0xC9CDBD)],
        star=0xFFFFFF, stars=0.0,
        cloud=[(0, 0x7D8E98), (0.45, 0xA7B2B4), (0.72, 0xD6D3C6), (0.9, 0xF1E8D4), (1, 0xFBF5E6)],
        rock=[(0, 0x2B3442), (0.25, 0x3E4A5C), (0.45, 0x5E6A7C), (0.62, 0x8E98A4), (0.8, 0xD9D8D2), (1, 0xFBF7EC)],
        mist=0xB8C6C8,
        meadow=[(0, 0x4A5236), (1, 0x8A8A50)],
        pine=0x1E3328, pine_lit=0x4E6A48, pine_mid=0x2E4A36, larch_shade=0x6E3A16, larch=0xC0762A, larch_lit=0xF4BE5A,
        water=0x2E5868, water_mix=0.3, water_dark=0.8, ripple=0xE8F0EC,
        ground=[(0, 0x1A1E16), (1, 0x343A26)], grass=0x48502E,
        dark=0.3),
}


def plate_geometry(name):
    """Everything about a plate that does not depend on the light: masks, value fields, stroke angles. Painted at SS."""
    spec = PLATES[name]
    pw, ph = spec["size"]
    w, h = pw * SS, ph * SS
    rng = np.random.default_rng(spec["seed"])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    G = dict(w=w, h=h, pw=pw, ph=ph, spec=spec)
    water = spec["water"] * h
    G["water"] = water

    # Sky: the value runs from the top (0) to the waterline (1), wandering a little; strokes drift level and curl.
    sky_t = np.clip(yy / water, 0, 1.2) + 0.03 * fbm(h, w, rng, base=3, octaves=3)
    dx1, dy1 = spec["dark"]
    G["dark"] = smoothstep(1.0, 0.2, np.sqrt((xx / (dx1 * w)) ** 2 + (yy / (dy1 * h)) ** 2))
    G["sky_t"] = sky_t
    G["sky_angle"] = 0.18 * fbm(h, w, rng, base=2.5, octaves=2) + 0.08 * np.sin(yy / (14 * SS))
    G["mottle"] = fbm(h, w, rng, base=7, octaves=4)

    # Stars: points scattered over the upper sky, a few of them larger, a few crossed sparkles.
    star = Image.new("F", (w, h), 0.0)
    d = ImageDraw.Draw(star)
    n = int(pw * ph / 380)
    for _ in range(n):
        x, y = rng.uniform(0, w), (rng.uniform(0, 1) ** 1.5) * water * 0.8
        r = SS * (0.45 + 0.9 * rng.uniform() ** 4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=float(rng.uniform(0.45, 1.0)))
    for _ in range(max(2, n // 18)):
        x, y = rng.uniform(0.05, 0.95) * w, rng.uniform(0.05, 0.6) * water
        a = SS * rng.uniform(2.2, 3.4)
        d.line([(x - a, y), (x + a, y)], fill=0.9, width=max(1, SS // 2))
        d.line([(x, y - a), (x, y + a)], fill=0.9, width=max(1, SS // 2))
        d.ellipse([x - SS * 0.7, y - SS * 0.7, x + SS * 0.7, y + SS * 0.7], fill=1.0)
    G["stars"] = gaussian_filter(np.asarray(star, dtype=np.float64), 0.45 * SS)

    # Clouds.
    cv, ccover, cangle = billows(w, h, rng, spec["clouds"])
    edge = fbm(h, w, rng, base=30, octaves=2)
    ccover = ccover * smoothstep(0.1, 0.5, ccover + 0.18 * edge)
    G["cloud_v"] = posterize(cv, [(0, 0.3), (0.42, 0.55), (0.62, 0.78), (0.82, 0.95)], 0.05 * edge)
    G["cloud"] = ccover
    G["cloud_angle"] = cangle

    # The Matterhorn and its lower ridges (Old Master Cover's painter, lit from the upper right as in the photograph).
    sx, sy = spec["summit"]
    height = spec["height"] * SS
    cy = omc.view_crest(w, h, sx, sy, height)
    mv, mcover, msnow, mlean, mkeep = omc.matterhorn(w, h, rng, cy, sx, sy, height, mist=None)
    scum = 0.05 * fbm(h, w, rng, base=40, octaves=2, stretch=0.4)
    G["rock_v"] = posterize(mv, [(0, 0.12), (0.3, 0.3), (0.46, 0.48), (0.64, 0.64), (0.84, 0.84), (0.93, 1.0)], scum,
                            soft=0.03)
    G["rock_v"] = 0.75 * G["rock_v"] + 0.25 * mv
    G["land"] = mcover
    u, v = (xx - sx * w) / height, (yy - sy * h) / height
    depth, ul, ur = omc.flanks()
    pyr = smoothstep(-0.01, 0.01, u - np.interp(v, depth, ul)) * smoothstep(0.01, -0.01, u - np.interp(v, depth, ur))
    G["ridges"] = mcover * (1 - pyr * smoothstep(-0.06, -0.02, v))
    G["rock_keep"] = mkeep
    G["rock_angle"] = np.pi / 2 + 0.95 * np.clip(mlean, -1, 1)
    # Mist at the mountain's foot, settling on the far shore.
    d0, d1, amount = spec["mist"]
    v = (yy - sy * h) / height
    G["mist"] = amount * smoothstep(d0, d1, v) * (0.7 + 0.3 * fbm(h, w, rng, base=5, octaves=3, stretch=3.0))

    # The far shore: a strip of meadow along the waterline, small pines and larches standing on it.
    shore = water - (2.5 + 1.5 * fbm(1, w, rng, base=8, octaves=2)[0]) * SS
    G["meadow"] = smoothstep(shore[None, :] - 0.6 * SS, shore[None, :] + 0.6 * SS, yy) * (yy < water + SS)
    G["meadow_t"] = np.clip((yy - (water - 6 * SS)) / (6 * SS), 0, 1)
    pines, larches = [], []
    # Between the placed trees, a thin line of small spruce along the shore.
    filler = [(fx, fh * 0.6, "p") for fx in np.arange(0.02, 1.0, 0.035) + rng.uniform(-0.01, 0.01, 28)[:len(np.arange(0.02, 1.0, 0.035))]
              for fh in [rng.uniform(4, 7)] if rng.uniform() < 0.55]
    for fx, fh, kind in filler + list(spec["far"]):
        x = fx * w
        base = shore[int(np.clip(x, 0, w - 1))] + 1.0 * SS
        hh = fh * SS * rng.uniform(0.9, 1.1)
        if kind == "p":
            pines.append(pine(x, base, hh, rng, tiers=7))
        else:
            larches.append(larch(x, base, hh, rng))
    G["far_pine"] = polygons(w, h, pines)
    G["far_larch"], G["far_larch_v"], G["far_trunk"] = tufted(w, h, larches, rng)

    # The lake: from the waterline to the near bank.
    bank = om.crest(spec["bank"], spec["seed"] + 5, w, h, roughness=0.12, levels=4)
    G["bank_y"] = bank
    G["lake"] = smoothstep(water, water + 0.8 * SS, yy) * (yy < bank[None, :] + SS)
    G["ripple_noise"] = fbm(h, w, rng, base=40, octaves=3, stretch=8.0)
    G["ripple_wave"] = fbm(h, w, rng, base=6, octaves=2, stretch=6.0)

    # The near bank: dark ground with grass tufts along its crest, and the tall trees standing on it.
    tufts = Image.new("L", (w * 2, h * 2), 0)
    d = ImageDraw.Draw(tufts)
    for _ in range(int(w / SS * 1.4)):
        x = rng.uniform(0, w)
        by = bank[int(x)] + SS * 1.5
        hh = SS * rng.uniform(2, 6)
        lean = rng.uniform(-0.6, 0.6) * hh
        d.polygon([(2 * (x - SS * 0.7), 2 * by), (2 * (x + lean), 2 * (by - hh)), (2 * (x + SS * 0.7), 2 * by)], fill=255)
    tufts = np.asarray(tufts.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    G["ground"] = np.maximum(smoothstep(bank[None, :] - 0.5 * SS, bank[None, :] + 0.5 * SS, yy), tufts)
    G["ground_t"] = np.clip((yy - bank[None, :]) / (0.14 * h), 0, 1) + 0.12 * fbm(h, w, rng, base=6, octaves=3)
    G["ground_angle"] = -np.pi / 2 + 0.5 * fbm(h, w, rng, base=12, octaves=2)
    pines, larches = [], []
    for fx, fy, fh, kind in spec["near"]:
        x, base, hh = fx * w, fy * h, fh * SS * rng.uniform(0.95, 1.05)
        if kind == "p":
            pines.append(pine(x, base, hh, rng))
        else:
            larches.append(larch(x, base, hh, rng))
    raw = polygons(w, h, pines)
    # A ragged edge of needles: the outline broken by level streaks.
    streaks = fbm(h, w, rng, base=70, octaves=2, stretch=5.0)
    G["near_pine"] = np.clip((gaussian_filter(raw, 0.7 * SS) - 0.5) * 3.0 + 0.5 + 0.35 * streaks, 0, 1) * (raw > 0.01)
    G["needle_flecks"] = fbm(h, w, rng, base=90, octaves=2, stretch=4.0)
    G["near_larch"], G["near_larch_v"], G["near_trunk"] = tufted(w, h, larches, rng)
    # Boughs: each tier of a spruce darker under its own drooping edge (level bands, bent a little).
    G["boughs"] = 0.5 + 0.5 * np.sin(yy / (2.6 * SS) + 2.0 * fbm(h, w, rng, base=10, octaves=2))
    G["larch_dabs"] = fbm(h, w, rng, base=60, octaves=2)
    G["grain"] = grain(h, w, rng)
    G["rng_seed"] = spec["seed"] * 7 + 1
    return G


def larch_paint(value, dabs, L):
    """Larch tufts in amber: three flat values (shade, body, lit gold), needle dabs breaking the steps."""
    v = posterize(value, [(0, 0.0), (0.4, 0.5), (0.66, 1.0)], 0.06 * dabs, soft=0.05)
    return ramp(v, [(0, L["larch_shade"]), (0.5, L["larch"]), (1.0, L["larch_lit"])])


def paint_plate(G, light):
    """One plate in one light: RGB 0..1 at SS."""
    L = LIGHTS[light]
    w, h, water = G["w"], G["h"], G["water"]
    k = G["pw"] * G["ph"] / (348 * 365)
    rng = np.random.default_rng(G["rng_seed"])  # the same strokes in every light

    # Sky, darker in the upper left where the type stands.
    sky = ramp(G["sky_t"], L["sky"]) * (1 + 0.035 * G["mottle"][..., None])
    sky = sky * (1 - L["dark"] * G["dark"][..., None])
    sky = over(sky, ramp(G["cloud_v"], L["cloud"]), G["cloud"])
    angle = np.where(G["cloud"] > 0.3, G["cloud_angle"], G["sky_angle"])
    sky = strokes(sky, angle, rng, k, [(420, (5, 9), (14, 30)), (1500, (2.5, 4.5), (7, 16)),
                                        (2600, (1.2, 2.2), (4, 9))], 0.012)
    sky = gaussian_filter(sky, (0.5 * SS, 0.5 * SS, 0))
    if L["stars"] > 0:
        sky = over(sky, hexrgb(L["star"]), np.clip(G["stars"] * L["stars"], 0, 1) * (1 - G["cloud"]))

    # The Matterhorn, its faces in flat gouache values, mist at its foot.
    rock = ramp(G["rock_v"] * (1 - 0.3 * G["ridges"]), L["rock"])
    rock = over(rock, hexrgb(L["mist"]), np.clip(G["mist"] + 0.35 * G["ridges"], 0, 1))
    rock_field = within(rock, G["land"], 4 * SS)
    rock_p = strokes(rock_field, G["rock_angle"], rng, k, [(700, (3, 6), (5, 12)), (2200, (1.4, 2.6), (3, 8)),
                                                           (2600, (0.7, 1.2), (2, 5))], 0.03)
    keep = gaussian_filter(G["rock_keep"], 0.5 * SS)
    rock_p = rock_p + (rock - rock_p) * keep[..., None] * 0.8
    scene = over(sky, rock_p, G["land"])

    # The far shore and its trees.
    meadow = ramp(G["meadow_t"], L["meadow"])
    scene = over(scene, meadow, G["meadow"])
    col = over(tint(np.ones_like(G["far_pine"]), L["pine"]), hexrgb(L["pine_lit"]),
               np.clip(rim(G["far_pine"], 1.2 * SS) * 2.2, 0, 1))
    scene = over(scene, col, G["far_pine"])
    scene = over(scene, tint(np.ones_like(G["far_trunk"]), L["pine"]), G["far_trunk"])
    scene = over(scene, larch_paint(G["far_larch_v"], G["larch_dabs"], L), G["far_larch"])

    # The lake: the scene above the waterline mirrored (compressed by squash), broken by level ripples, darkened and
    # glazed with the water's colour, laid in with level strokes.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    squash = G["spec"]["squash"]
    src_y = water - (yy - water) / squash
    wob = 1.6 * SS * G["ripple_wave"]
    src_x = np.clip(xx + wob, 0, w - 1)
    refl = np.stack([map_coordinates(scene[..., i], [np.clip(src_y, 0, h - 1), src_x], order=1, mode="nearest")
                     for i in range(3)], axis=2)
    refl = gaussian_filter(refl, (0.5 * SS, 1.4 * SS, 0))
    refl = refl * L["water_dark"]
    refl = over(refl, hexrgb(L["water"]), np.full((h, w), L["water_mix"]))
    depth = np.clip((yy - water) / (h - water), 0, 1)
    refl = refl * (1 - 0.25 * depth[..., None])
    streak = smoothstep(0.9, 1.7, G["ripple_noise"]) * (0.35 + 0.65 * depth)
    refl = over(refl, hexrgb(L["ripple"]), streak * 0.22)
    # A thin bright line where the far shore meets the water.
    line = smoothstep(1.4 * SS, 0, np.abs(yy - water - 0.9 * SS)) * (0.4 + 0.3 * G["ripple_wave"])
    refl = over(refl, hexrgb(L["ripple"]), np.clip(line, 0, 1) * 0.35)
    lake_field = within(refl, G["lake"], 3 * SS)
    lake_p = strokes(lake_field, np.zeros((h, w)) + 0.02 * G["ripple_wave"], rng, k,
                     [(700, (1.6, 2.6), (12, 26)), (2400, (0.8, 1.4), (6, 14))], 0.012)
    scene = over(scene, lake_p, G["lake"])

    # The near bank and its tall trees.
    ground = ramp(np.clip(G["ground_t"], 0, 1), L["ground"][::-1])
    ground = over(ground, hexrgb(L["grass"]), smoothstep(0.3, 0.0, G["ground_t"]) * 0.7)
    ground = strokes(within(ground, G["ground"], 3 * SS), G["ground_angle"], rng, k,
                     [(900, (1.2, 2.2), (3, 8)), (1800, (0.6, 1.1), (2, 6))], 0.08)
    scene = over(scene, ground, G["ground"])
    pm = G["near_pine"]
    col = tint(np.ones_like(pm), L["pine"]) * (1 - 0.25 * G["boughs"][..., None])
    lit = np.clip(rim(pm, 3.0 * SS) * 1.4, 0, 1)
    flecks = smoothstep(0.6, 1.4, G["needle_flecks"]) * np.clip(rim(pm, 6.0 * SS) * 2.0, 0, 1)
    col = over(col, hexrgb(L["pine_mid"]), np.clip(flecks * 0.8, 0, 1))
    col = over(col, hexrgb(L["pine_lit"]), lit * 0.85)
    scene = over(scene, col, pm)
    scene = over(scene, tint(np.ones_like(pm), L["pine"]) * 0.7, G["near_trunk"])
    scene = over(scene, larch_paint(G["near_larch_v"], G["larch_dabs"], L), G["near_larch"])

    # Gouache: a soft blur across the stroke edges, the paper's tooth, a touch of chalk in the lights.
    scene = gaussian_filter(scene, (0.35 * SS, 0.35 * SS, 0))
    lum = scene.mean(axis=2, keepdims=True)
    scene = scene * (1 + 0.035 * G["grain"][..., None] * (0.4 + lum))
    return np.clip(scene, 0, 1)


def cloud_layer(G, rows, seed, ceiling=0.0):
    """A layer of cloud over the sky (and, dimmer, in its reflection), as two alphas for SwiftUI to tint: the body and
    its lit billow tops. rows: [(y as a fraction of the waterline, billow radius pt, x from, x to, coverage)]; the first
    rows lie in front. ceiling: the fraction of the sky (from the top) that is solid cloud behind the billows."""
    w, h, water = G["w"], G["h"], G["water"]
    rng = np.random.default_rng(seed)
    masses = []
    for k, (fy, r, x0, x1, keep) in enumerate(rows):
        R = r * SS
        step = R * 2.4
        x = x0 * w - rng.uniform(0, step)
        while x < x1 * w + step:
            if rng.uniform() < keep:
                cw = R * rng.uniform(2.6, 3.4)
                masses.append(((x + rng.uniform(-0.25, 0.25) * step) / w, (fy * water + rng.uniform(-0.3, 0.3) * R) / h,
                               cw / w, R * rng.uniform(1.3, 1.7) / h, 3, (len(rows) - k) * 0.6))
            x += step
    v, cover, angle = billows(w, h, rng, masses)
    yy = np.mgrid[0:h, 0:w][0].astype(np.float64)
    if ceiling > 0:
        solid = smoothstep(ceiling * water + 6 * SS, ceiling * water - 6 * SS, yy + 6 * SS * fbm(h, w, rng, base=6, octaves=2))
        v = np.where(cover > 0.5, v, 0.32 + 0.08 * fbm(h, w, rng, base=5, octaves=3))
        cover = np.maximum(cover, solid)
    # Gouache: the values laid in with strokes round the billows, then the lit tops picked out.
    field = mt.paint(np.stack([v] * 3, axis=2), angle, rng, [(int(900 * G["pw"] * G["ph"] / (348 * 365)) + 40,
                                                              (1.2 * SS, 2.4 * SS), (3 * SS, 8 * SS))], 0.03)[..., 0]
    field = gaussian_filter(field, 0.5 * SS)
    lit = smoothstep(0.6, 0.78, field) * cover
    body = cover * (0.92 + 0.08 * smoothstep(0.2, 0.5, field))
    open_sky = (1 - G["land"]) * (1 - G["meadow"]) * (1 - G["far_pine"]) * (1 - G["far_larch"])
    open_sky *= (1 - G["near_pine"]) * (1 - G["near_larch"]) * (1 - G["ground"]) * (1 - G["lake"])
    lake = G["lake"] * (1 - G["near_pine"]) * (1 - G["near_larch"]) * (1 - G["ground"])
    xx = np.mgrid[0:h, 0:w][1].astype(np.float64)
    src_y = np.clip(water - (yy - water) / G["spec"]["squash"], 0, h - 1)
    mirror = lambda a: map_coordinates(a, [src_y, xx], order=1, mode="nearest")
    body_sky, lit_sky = body * open_sky, lit * open_sky
    body_out = body_sky + 0.55 * mirror(body_sky) * lake
    lit_out = lit_sky + 0.35 * mirror(lit_sky) * lake
    return down(np.clip(body_out, 0, 1)), down(np.clip(lit_out, 0, 1))


def plate_masks(G):
    """The open water, the overcast deck and the scattered clouds of a part-cloudy day, at 1 px per point."""
    lake = G["lake"] * (1 - G["near_pine"]) * (1 - G["near_larch"]) * (1 - G["ground"])
    seed = G["spec"]["seed"]
    # The deck: near billows overhead, smaller and flatter rows toward the far shore, a ragged gap above the ridges.
    deck = cloud_layer(G, [(0.08, 34, -0.1, 1.1, 1.0), (0.4, 24, -0.1, 1.1, 1.0), (0.66, 15, -0.1, 1.1, 0.9),
                           (0.84, 9, -0.1, 1.1, 0.6)], seed + 101, ceiling=0.62)
    # Scattered fair-weather clouds, kept to the right of the type and clear of the summit.
    scatter = cloud_layer(G, G["spec"]["scatter"], seed + 103)
    return down(lake), deck, scatter


# MARK: To-do textures

def page(w, h, seed):
    """A parchment leaf with deckled edges, warm and a little foxed, darker toward its edges. Returns RGB, alpha."""
    W, H = w * SS, h * SS
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    m = 3.0 * SS
    deckle = 1.0 * SS * fbm(H, W, rng, base=30, octaves=3, persistence=0.45)
    dist = np.minimum.reduce([xx - m, W - 1 - m - xx, yy - m, H - 1 - m - yy]) + deckle
    alpha = smoothstep(-0.6 * SS, 0.6 * SS, dist)
    edge = smoothstep(14 * SS, 0, dist)
    fibre = fbm(H, W, rng, base=50, octaves=3, stretch=5.0)
    blotch = fbm(H, W, rng, base=5, octaves=4)
    rgb = ramp(0.5 + 0.06 * blotch + 0.02 * fibre, [(0, 0xD9C7A0), (0.5, 0xEADCBB), (1, 0xF3E8CC)])
    rgb = over(rgb, hexrgb(0xBE9C6C), np.clip(edge * 0.42 + 0.08 * smoothstep(1.2, 2.4, blotch), 0, 1))
    rgb = over(rgb, hexrgb(0x93704A), smoothstep(2.0 * SS, 0, dist) * 0.35)
    # Foxing: a few faint brown spots.
    fox = Image.new("F", (W, H), 0.0)
    d = ImageDraw.Draw(fox)
    for _ in range(int(w * h / 900)):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), SS * rng.uniform(0.6, 2.2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=float(rng.uniform(0.2, 0.6)))
    rgb = over(rgb, hexrgb(0xA77C4A), gaussian_filter(np.asarray(fox, dtype=np.float64), SS) * 0.5)
    rgb = rgb * (1 + 0.03 * grain(H, W, rng)[..., None])
    return down(rgb), down(alpha)


def ground(w, h, seed):
    """Deep forest green gouache, laid in with soft crossing strokes, darker at the edges."""
    W, H = w * SS, h * SS
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    v = 0.5 + 0.15 * fbm(H, W, rng, base=4, octaves=4)
    vign = np.sqrt(((xx / W) - 0.5) ** 2 * 1.2 + ((yy / H) - 0.45) ** 2 * 2.2)
    v = v - 0.35 * smoothstep(0.2, 0.75, vign)
    rgb = ramp(v, [(0, 0x0B1410), (0.5, 0x1A2C22), (1, 0x2C4434)])
    angle = 0.5 + 0.6 * fbm(H, W, rng, base=2, octaves=2)
    rgb = mt.paint(rgb, angle, rng, [(500, (6 * SS, 10 * SS), (14 * SS, 30 * SS)), (1600, (2 * SS, 4 * SS), (6 * SS, 14 * SS))],
                   0.04)
    rgb = gaussian_filter(rgb, (0.4 * SS, 0.4 * SS, 0))
    rgb = rgb * (1 + 0.04 * grain(H, W, rng)[..., None])
    return down(rgb)


def wallpaper(w, h, seed):
    """The board's home screen: a storybook night, soft clouds and stars over a dark wood with a few amber larches."""
    rng = np.random.default_rng(seed)
    W, H = w * SS, h * SS  # painted at 2x and reduced
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    L = LIGHTS["night"]
    t = np.clip(yy / (0.9 * H), 0, 1) + 0.04 * fbm(H, W, rng, base=3, octaves=3)
    sky = ramp(t, L["sky"])
    star = Image.new("F", (W, H), 0.0)
    d = ImageDraw.Draw(star)
    for _ in range(420):
        x, y = rng.uniform(0, W), rng.uniform(0, 0.75) ** 1.4 * H
        r = SS * (0.5 + 1.2 * rng.uniform() ** 5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=float(rng.uniform(0.3, 0.9)))
    sky = over(sky, hexrgb(L["star"]), gaussian_filter(np.asarray(star, dtype=np.float64), 0.5 * SS) * 0.9)
    cv, ccover, cangle = billows(W, H, rng, [(0.22, 0.2, 0.5, 0.08, 8), (0.8, 0.36, 0.5, 0.07, 7),
                                             (0.35, 0.56, 0.6, 0.08, 8), (0.86, 0.7, 0.4, 0.06, 6)])
    cv = posterize(cv, [(0, 0.3), (0.42, 0.55), (0.62, 0.78), (0.82, 0.95)], 0)
    sky = over(sky, ramp(cv * 0.85, L["cloud"]), ccover)
    angle = np.where(ccover > 0.3, cangle, 0.15 * fbm(H, W, rng, base=2.5, octaves=2))
    sky = mt.paint(sky, angle, rng, [(1500, (8 * SS, 14 * SS), (20 * SS, 44 * SS)), (4000, (3 * SS, 6 * SS), (8 * SS, 20 * SS))],
                   0.015)
    trees, larches = [], []
    x = -10.0
    while x < W + 10:
        hh = rng.uniform(90, 190) * SS
        base = H + 10
        if rng.uniform() < 0.08:
            larches.append(larch(x, base - rng.uniform(0, 20) * SS, hh * 0.5, rng))
        else:
            trees.append(pine(x, base, hh, rng, tiers=9))
        x += rng.uniform(16, 34) * SS
    pm = polygons(W, H, trees)
    lm, lv, lt = tufted(W, H, larches, rng)
    sky = over(sky, hexrgb(L["pine"]), pm)
    sky = over(sky, hexrgb(L["pine"]), lt)
    sky = over(sky, larch_paint(lv, fbm(H, W, rng, base=60, octaves=2), L) * 0.85, lm)
    sky = gaussian_filter(sky, (0.5 * SS, 0.5 * SS, 0)) * 0.82
    return down(np.clip(sky, 0, 1))


# MARK: Main

def preview(folder, name, rgb):
    os.makedirs(folder, exist_ok=True)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    img.resize((img.width * 2, img.height * 2), Image.LANCZOS).save(os.path.join(folder, name + ".png"))


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    for name in PLATES:
        if only and name not in only:
            continue
        G = plate_geometry(name)
        for light in ("day", "dusk", "night"):
            rgb = down(paint_plate(G, light))
            save_rgb(f"{name}-{light}.png", rgb)
            if pv:
                preview(pv, f"{name}-{light}", rgb)
        lake, deck, scatter = plate_masks(G)
        save_alpha(f"{name}-lake.png", lake)
        save_alpha(f"{name}-deck.png", deck[0])
        save_alpha(f"{name}-deck-lit.png", deck[1])
        save_alpha(f"{name}-scatter.png", scatter[0])
        save_alpha(f"{name}-scatter-lit.png", scatter[1])
    if not only or "ground" in only:
        save_rgb("ground.png", ground(348, 164, 301))
    if not only or "page" in only:
        rgb, a = page(316, 134, 303)
        save_rgba("page-medium.png", rgb, a)
        rgb, a = page(136, 136, 305)
        save_rgba("page-small.png", rgb, a)
    if not only or "wallpaper" in only:
        save_rgb("wallpaper.jpg", wallpaper(780, 805, 307))


if __name__ == "__main__":
    main()
