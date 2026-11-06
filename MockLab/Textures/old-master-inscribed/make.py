#!/usr/bin/env python3
"""Old Master Inscribed paint textures: sepia mountain paintings composed for the words that are lettered on them.

There is no panel in this look. Each painting is planned in three values, the old masters' chiaroscuro, and the
layout lives in its darks:
  a low-key cloud ceiling      the date and the weather (day), or the quote itself (quote widgets);
  the light                    the luminous break in the sky, the snowy peaks and the sun's path (the dial);
  a deep umber ground          a still dark lake or a shadowed slope of firs, for the tasks, the week, the author.
The strokes, clouds, ranges and firs are Old Master's own: MockLab/Textures/old-master/make.py is imported from its
path (its main() is guarded) and its painting pieces are composed here with a few additions of this look:
  ceiling   the upper sky glazed down so cream type reads on it, keeping the cloud forms;
  lake      still water under a shoreline: dark, a faint reflection of the light near the shore, level ripples;
  bank      a low dark near bank in front of the lake, for the quote's signature and button;
  darks     soft oval glazes where a block of type sits (painted in, so the brushwork runs over them);
  lights    soft oval lifts that open the light where the composition needs it;
  lift      a lift of the lights only after the S-curve, so the snow sings while the darks stay umber.

Outputs (alpha-only PNGs, 1 px per point, tinted at run time exactly as Old Master's):
  <name>-lo.png, <name>-hi.png   the lower and upper half of the value (shadow > warm mid > light)
  <name>-glow.png                the brightest lights (cloud rims, lit snow), glazed in the sun's or moon's colour
Paintings: day-large 348x365, day-medium 348x164, day-small 164x164,
           quote-large 348x365, quote-medium 348x164, quote-small 164x164
Other:     veil.png 348x220 (rain, Old Master's veil() repainted here so the look is self-contained)

Run from anywhere (deterministic):  python3 MockLab/Textures/old-master-inscribed/make.py [names] [--preview DIR]
--preview also writes day-palette colour previews with the type zones outlined, and prints the value under each
zone (the 95th percentile must stay under about 0.36 for cream type to hold 4.5:1 on the day glaze).
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing Old Master's make.py (and through it scripts/make_textures.py) leaves no cache

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("om_make", os.path.join(os.path.dirname(HERE), "old-master", "make.py"))
om = importlib.util.module_from_spec(spec)
spec.loader.exec_module(om)
mt = om.mt
SS = om.SS
smoothstep, fbm, hexrgb, mix = mt.smoothstep, mt.fbm, mt.hexrgb, mt.mix


def save_alpha(name, a):
    """White with the given alpha, written to this folder (the widgets render these as template images)."""
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"),
                                                                             optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def oval(xx, yy, w, h, cx, cy, rx, ry, soft=0.55):
    """A soft oval mask (1 inside, fading to 0 at the rim); cx..ry are fractions of the painting."""
    r = np.hypot((xx - cx * w) / (rx * w), (yy - cy * h) / (ry * h))
    return smoothstep(1.0, soft, r)


# MARK: A composed painting

def composed(w, h, seed, sun, horizon, clouds, ranges, foreground=None, trees=(), lake=None, bank=None, ceiling=None,
             darks=(), lights=(), sky=None, contrast=1.3, lift=0.0, name="", preview=None, zones=()):
    """Old Master's painting(), composed for type: the same sky, cumulus, ranges, firs and strokes, plus a glazed
    cloud ceiling, a still lake, and soft darks and lights placed under the type. Returns (value, glow) at
    1 px per point.
      ceiling: (y0, y1, amount)   the sky above y0 glazed down by `amount`, fading out by y1
      lake:    dict(keys, seed, far, near, reflect, fade, ripple)  water below a shoreline crest
      bank:    a near range painted in front of the lake (a dark bank to sign on)
      trees:   [(range index, height pt, spacing pt, coverage, value[, (x0, x1)])], optionally only between x0..x1
      darks / lights: [(cx, cy, rx, ry, amount)]
      lift:    raises the lights after the S-curve (snow and cloud tops sing; the darks are left alone)"""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    V, angle = om.sky_field(w, h, rng, sun, horizon, **(sky or {}))
    glow = np.zeros((h, w))
    for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
        if not layer:
            continue
        cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, sun)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit * 0.9
        angle = np.where(ccover > 0.3, ctan, angle)
    if ceiling:
        y0, y1, amount = ceiling
        lid = amount * smoothstep(y1 * h, y0 * h, yy)
        V = V * (1 - lid)
        glow = glow * (1 - smoothstep(0.1, 0.4, lid))
    land = np.zeros((h, w))
    lean = np.zeros((h, w))
    crests = []
    allr = list(ranges) + ([foreground] if foreground else [])
    for r in allr:
        r = dict(r)
        cy = om.crest(r.pop("keys"), r.pop("seed"), w, h, r.pop("roughness", 0.22))
        crests.append(cy)
        v, cover, snow_lit, nx = om.mountain(w, h, rng, cy, r.pop("tone"), r.pop("light", (-0.55, -0.6, 0.6)), **r)
        V = V + (v - V) * cover
        glow = glow * (1 - cover) + snow_lit * cover
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + nx * cover
    tree_mask = np.zeros((h, w))
    for tree in trees:
        which, height, spacing, coverage, tone = tree[:5]
        m = om.firs(w, h, rng, crests[which], height, spacing, coverage)
        if len(tree) > 5:
            x0, x1 = tree[5]
            m *= smoothstep((x0 - 0.03) * w, (x0 + 0.03) * w, xx) * smoothstep((x1 + 0.03) * w, (x1 - 0.03) * w, xx)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        V = V + (tone - V) * m + 0.10 * rimlight * (1 - m * 0.5)
        glow *= 1 - m
        land = np.maximum(land, m)
        tree_mask = np.maximum(tree_mask, m)
    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    water = np.zeros((h, w))
    if lake:
        L = dict(lake)
        shore = om.crest(L["keys"], L["seed"], w, h, L.get("roughness", 0.04), levels=4)
        depth = yy - shore[None, :]
        water = smoothstep(-0.6 * SS, 0.6 * SS, depth) * (1 - tree_mask * smoothstep(2 * SS, 0, depth))
        if "x" in L:  # water only between these fractions (a slope may come down to it from one side)
            x0, x1 = L["x"]
            water *= smoothstep((x0 - 0.02) * w, (x0 + 0.02) * w, xx) * smoothstep((x1 + 0.02) * w, (x1 - 0.02) * w, xx)
        t = np.clip(depth / (h - shore[None, :] + 1e-6), 0, 1)
        base = L["far"] + (L["near"] - L["far"]) * smoothstep(0, 1, t ** 0.6)
        # The light above, laid in the water as painters do: the band of sky and snow above the fir shore (`skip`
        # higher) mirrored and squeezed `squash` times into a strip under the shore, strongest there, gone within
        # `fade`, broken by level ripples.
        ripple = fbm(h, w, rng, base=5, octaves=3, persistence=0.5, stretch=6.0)
        skip, squash = L.get("skip", 0.0) * h, L.get("squash", 1.0)
        mirror_y = np.clip(shore[None, :] - skip - np.clip(depth, 0, None) * squash, 0, h - 1)
        mirrored = V[mirror_y.astype(int), xx.astype(int)]
        fade = L["fade"] * h
        refl = L["reflect"] * np.exp(-np.clip(depth, 0, None) / fade) * (0.7 + 0.3 * np.tanh(ripple * 2))
        wv = base + refl * np.clip(mirrored - base, 0, None)
        # Level ripples, a few glints where they catch the light, and the bright lip of the far shore.
        wv += L.get("ripple", 0.03) * np.tanh(ripple * 1.5) * (1 - 0.6 * t)
        wv += L.get("glint", 0.0) * smoothstep(1.3, 2.4, ripple) * np.exp(-np.clip(depth, 0, None) / (3 * fade))
        wv += L.get("lip", 0.16) * smoothstep(0, 0.8 * SS, depth) * (1 - smoothstep(0.8 * SS, 2.6 * SS, depth))
        V = V + (wv - V) * water
        glow *= 1 - water
        angle = np.where(water > 0.5, 0.0 + 0.04 * ripple, angle)
        land = np.maximum(land, water)
    if bank:
        r = dict(bank)
        cy = om.crest(r.pop("keys"), r.pop("seed"), w, h, r.pop("roughness", 0.22))
        v, cover, _, nx = om.mountain(w, h, rng, cy, r.pop("tone"), r.pop("light", (-0.55, -0.6, 0.6)), **r)
        V = V + (v - V) * cover
        glow *= 1 - cover
        water *= 1 - cover
        land = np.maximum(land, cover)
        angle = np.where(cover > 0.5, np.pi / 2 + 0.95 * np.clip(nx, -1, 1), angle)
    for cx, cy, rx, ry, amount in darks:
        V = V * (1 - amount * oval(xx, yy, w, h, cx, cy, rx, ry))
    for cx, cy, rx, ry, amount in lights:
        V = V + (1 - V) * amount * oval(xx, yy, w, h, cx, cy, rx, ry, soft=0.0)
    k = pw * ph / (348 * 365)
    s = SS
    field = np.stack([V, V, V], axis=2)
    sky_out = mt.paint(field, angle, rng, [(int(380 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                                           (int(1300 * k), (3 * s, 5.5 * s), (7 * s, 18 * s)),
                                           (int(2400 * k), (1.4 * s, 2.6 * s), (4 * s, 9 * s)),
                                           (int(3200 * k), (0.7 * s, 1.2 * s), (3 * s, 7 * s))], 0.03)
    land_out = mt.paint(field, angle, rng, [(int(500 * k), (4 * s, 8 * s), (6 * s, 14 * s)),
                                            (int(1600 * k), (2 * s, 4 * s), (4 * s, 9 * s)),
                                            (int(2400 * k), (1.2 * s, 2.2 * s), (2.5 * s, 6 * s)),
                                            (int(2600 * k), (0.7 * s, 1.1 * s), (2 * s, 4 * s))], 0.04)
    # Water: long level strokes, laid thin.
    water_out = mt.paint(field, angle, rng, [(int(700 * k), (2 * s, 4 * s), (16 * s, 40 * s)),
                                             (int(1600 * k), (0.8 * s, 1.6 * s), (10 * s, 26 * s))], 0.05)
    out = sky_out * (1 - land[..., None]) + land_out * land[..., None]
    out = out * (1 - water[..., None]) + water_out * water[..., None]
    out = gaussian_filter(out[..., 0], 0.4 * s)
    out = out + (np.minimum(out, V) - out) * gaussian_filter(tree_mask, 0.5 * s) * 0.7
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
    out = out + lift * smoothstep(0.42, 0.92, out) * (1 - out)
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
    # No glaze of light where type sits.
    for cx, cy, rx, ry, amount in darks:
        glow *= 1 - smoothstep(0.0, 0.3, amount) * oval(xx, yy, w, h, cx, cy, rx * 1.15, ry * 1.15)
    out, glow = om.down(out), om.down(glow)
    if preview:
        write_preview(preview, name, out, glow, zones)
    return out, glow


def tinted(value, glow):
    """The day glaze, exactly as the widget lays it: shadow, then the lower half in the warm mid, then the upper half
    in the light, then the brightest lights in the sun's colour."""
    s0, m0, l0, g0 = hexrgb(0x2C1810), hexrgb(0x8A5F47), hexrgb(0xEBD1B2), hexrgb(0xF7CDA0)
    lo = np.clip(value * 2, 0, 1)[..., None]
    hi = np.clip(value * 2 - 1, 0, 1)[..., None]
    rgb = s0 * (1 - lo) + m0 * lo
    rgb = rgb * (1 - hi) + l0 * hi
    return rgb * (1 - 0.6 * glow[..., None]) + g0 * 0.6 * glow[..., None]


def write_preview(folder, name, value, glow, zones):
    """Colour preview at 2x with the type zones outlined, plus the value under each zone."""
    os.makedirs(folder, exist_ok=True)
    rgb = tinted(value, glow)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize(
        (value.shape[1] * 2, value.shape[0] * 2), Image.BICUBIC)
    d = ImageDraw.Draw(img)
    for label, x0, y0, x1, y1 in zones:
        d.rectangle([x0 * 2, y0 * 2, x1 * 2, y1 * 2], outline=(120, 220, 255))
        patch = value[int(y0):int(y1), int(x0):int(x1)]
        print(f"  {name:13s} {label:12s} p95 {np.percentile(patch, 95):.2f}  max {patch.max():.2f}")
    img.save(os.path.join(folder, f"pv-{name}.png"))


# MARK: The paintings
# Fractions of the widget. Type zones (points) are listed with each painting for the preview check; they match the
# layouts in OIDay.swift and OIQuote.swift.

def p(x, y):
    return (x, y)


FAR = dict(tone=0.4, snow_v=(0.36, 0.98), haze=0.04, haze_v=0.66, rim=0.14)
MID = dict(tone=0.3, haze=0.05, haze_v=0.62, roughness=0.3, contrast=1.0)
# The grounds that carry type: a deep umber that still shows its brushwork (about 0.18 to 0.32 once glazed).
NEAR = dict(tone=0.27, contrast=0.55, roughness=0.35)
FIR = 0.1


def rr(d, **kw):
    out = dict(d)
    out.update(kw)
    return out


def day_large(pv):
    # Ceiling (date left, weather right) over a luminous break where one massif stands under the sun's arc; a
    # dark fir shore (the week) and a still dark lake (the tasks) below.
    return composed(
        348, 365, 501, sun=(0.5, 0.33), horizon=0.42, sky=dict(dark_top=0.26, bright=0.84, low=0.6),
        clouds=[(0.08, 0.12, 0.56, 0.13, 50, 0.45), (0.94, 0.12, 0.5, 0.13, 46, 0.45), (0.5, 0.05, 0.5, 0.08, 30, 0.4),
                (0.02, 0.38, 0.22, 0.13, 34, 0.5), (0.98, 0.37, 0.22, 0.13, 34, 0.5),
                (0.74, 0.29, 0.2, 0.09, 40)],
        ceiling=(0.13, 0.24, 0.26),
        ranges=[
            rr(FAR, keys=[p(0, 0.41), p(0.12, 0.395), p(0.22, 0.36), p(0.32, 0.3), p(0.4, 0.25), p(0.47, 0.215),
                          p(0.53, 0.205), p(0.58, 0.225), p(0.65, 0.27), p(0.74, 0.32), p(0.84, 0.37), p(0.93, 0.395),
                          p(1, 0.41)], seed=11, snowline=0.315, mist=(30, 70, 0.6)),
            rr(MID, keys=[p(0, 0.425), p(0.12, 0.418), p(0.25, 0.432), p(0.4, 0.42), p(0.55, 0.436), p(0.7, 0.422),
                          p(0.85, 0.434), p(1, 0.424)], seed=23, mist=(8, 26, 0.5)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.462), p(0.15, 0.47), p(0.3, 0.478), p(0.5, 0.482), p(0.7, 0.477),
                                  p(0.85, 0.469), p(1, 0.46)], seed=31, tone=0.2),
        trees=[(2, (9, 20), 5.0, 0.6, FIR)],
        lake=dict(keys=[p(0, 0.546), p(0.5, 0.55), p(1, 0.545)], seed=37, far=0.38, near=0.25, reflect=0.8,
                  fade=0.022, ripple=0.06, lip=0.2, skip=0.15, squash=3.0, glint=0.12),
        darks=[(0.2, 0.1, 0.3, 0.12, 0.36), (0.82, 0.1, 0.28, 0.12, 0.36), (0.5, 0.5, 0.6, 0.032, 0.2),
               (0.06, 0.37, 0.12, 0.06, 0.45), (0.94, 0.37, 0.12, 0.06, 0.45),
               (0.09, 0.442, 0.09, 0.03, 0.4), (0.91, 0.442, 0.09, 0.03, 0.4)],
        contrast=1.2, lift=0.22, name="day-large", preview=pv,
        zones=[("date", 16, 14, 130, 70), ("weather", 222, 16, 332, 66), ("rise", 20, 156, 46, 167),
               ("set", 302, 156, 328, 167), ("week", 16, 172, 332, 196), ("tasks", 16, 210, 332, 350)])


def day_medium(pv):
    # The large one's plan in a band: the date and the weather in the cloud ceiling either side of one high peak
    # standing in the light under the sun's arc, a thin fir shore, and the tasks on the still water below.
    return composed(
        348, 164, 503, sun=(0.5, 0.36), horizon=0.41, sky=dict(dark_top=0.26, bright=0.86, low=0.62),
        clouds=[(0.1, 0.2, 0.5, 0.32, 46, 0.45), (0.92, 0.2, 0.46, 0.32, 44, 0.45),
                (0.69, 0.36, 0.13, 0.11, 26), (0.31, 0.37, 0.1, 0.08, 20)],
        ceiling=(0.2, 0.34, 0.26),
        ranges=[
            rr(FAR, keys=[p(0, 0.39), p(0.18, 0.38), p(0.3, 0.335), p(0.38, 0.26), p(0.44, 0.18), p(0.49, 0.125),
                          p(0.54, 0.155), p(0.6, 0.225), p(0.68, 0.3), p(0.8, 0.365), p(1, 0.385)], seed=41,
               snowline=0.275, mist=(14, 34, 0.6)),
            rr(MID, keys=[p(0, 0.4), p(0.25, 0.392), p(0.5, 0.402), p(0.75, 0.39), p(1, 0.398)], seed=43,
               mist=(4, 12, 0.45)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.412), p(0.3, 0.418), p(0.6, 0.415), p(1, 0.41)], seed=47, tone=0.2,
                      roughness=0.2),
        trees=[(2, (5, 11), 4.0, 0.6, FIR)],
        lake=dict(keys=[p(0, 0.438), p(0.5, 0.44), p(1, 0.437)], seed=49, far=0.38, near=0.26, reflect=0.8,
                  fade=0.03, ripple=0.06, lip=0.2, skip=0.07, squash=2.5, glint=0.12),
        darks=[(0.17, 0.16, 0.26, 0.19, 0.36), (0.86, 0.16, 0.2, 0.19, 0.36)],
        contrast=1.2, lift=0.3, name="day-medium", preview=pv,
        zones=[("date", 16, 10, 116, 50), ("temp", 262, 10, 332, 46), ("tasks", 16, 77, 332, 148)])


def day_small(pv):
    # The date and temperature in the dark upper corners, the light in the middle under a small arc, the first task
    # on the dark fir slope below.
    return composed(
        164, 164, 505, sun=(0.5, 0.48), horizon=0.58, sky=dict(dark_top=0.24, bright=0.84, low=0.62),
        clouds=[(0.0, 0.22, 0.66, 0.3, 44, 0.55), (1.0, 0.2, 0.62, 0.26, 40, 0.55), (0.84, 0.5, 0.26, 0.11, 22)],
        ceiling=(0.12, 0.3, 0.28),
        ranges=[
            rr(FAR, keys=[p(0, 0.56), p(0.2, 0.52), p(0.34, 0.44), p(0.44, 0.35), p(0.5, 0.31), p(0.57, 0.36),
                          p(0.68, 0.45), p(0.84, 0.52), p(1, 0.56)], seed=51, snowline=0.45, mist=(12, 28, 0.62)),
            rr(MID, keys=[p(0, 0.6), p(0.25, 0.585), p(0.5, 0.6), p(0.75, 0.58), p(1, 0.6)], seed=53,
               mist=(4, 14, 0.4)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.6), p(0.2, 0.62), p(0.5, 0.635), p(0.8, 0.62), p(1, 0.6)], seed=57,
                      tone=0.26),
        trees=[(2, (8, 15), 4.5, 0.6, FIR)],
        darks=[(0.17, 0.22, 0.24, 0.24, 0.45), (0.86, 0.15, 0.2, 0.16, 0.3)],
        contrast=1.2, lift=0.3, name="day-small", preview=pv,
        zones=[("date", 16, 12, 56, 62), ("temp", 116, 14, 148, 40), ("task", 16, 98, 148, 150)])


def quote_large(pv):
    # The quote is the sky: a heavy low-key cloud ceiling over the upper half. The light breaks over a snowy range
    # and lies mirrored in the lake below it; the author signs the dark near bank, bottom left, beside the button.
    return composed(
        348, 365, 507, sun=(0.56, 0.56), horizon=0.6, sky=dict(dark_top=0.24, bright=0.86, low=0.64),
        clouds=[(0.15, 0.2, 0.7, 0.2, 70, 0.4), (0.85, 0.22, 0.6, 0.2, 60, 0.4), (0.5, 0.08, 0.9, 0.1, 50, 0.45),
                (0.16, 0.52, 0.34, 0.07, 44), (0.9, 0.53, 0.3, 0.06, 34)],
        ceiling=(0.42, 0.52, 0.26),
        ranges=[
            rr(FAR, keys=[p(0, 0.6), p(0.12, 0.585), p(0.24, 0.555), p(0.34, 0.535), p(0.42, 0.55), p(0.52, 0.52),
                          p(0.6, 0.495), p(0.66, 0.52), p(0.76, 0.555), p(0.88, 0.58), p(1, 0.6)], seed=61,
               snowline=0.555, mist=(16, 40, 0.6)),
            rr(MID, keys=[p(0, 0.62), p(0.15, 0.61), p(0.3, 0.622), p(0.5, 0.614), p(0.7, 0.626), p(0.85, 0.612),
                          p(1, 0.62)], seed=67, mist=(5, 16, 0.5)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.632), p(0.2, 0.64), p(0.4, 0.645), p(0.6, 0.643), p(0.8, 0.638),
                                  p(1, 0.63)], seed=71, tone=0.2, roughness=0.25),
        trees=[(2, (6, 15), 4.5, 0.55, FIR)],
        lake=dict(keys=[p(0, 0.665), p(0.5, 0.668), p(1, 0.663)], seed=73, far=0.38, near=0.26, reflect=0.72,
                  fade=0.16, ripple=0.05, lip=0.16, skip=0.035, squash=1.0, glint=0.1),
        bank=rr(NEAR, keys=[p(0, 0.868), p(0.15, 0.876), p(0.35, 0.882), p(0.6, 0.88), p(0.8, 0.872), p(0.92, 0.862),
                            p(1, 0.856)], seed=79, tone=0.22, roughness=0.05, contrast=0.4),
        darks=[(0.5, 0.22, 0.56, 0.24, 0.32)],
        contrast=1.2, lift=0.3, name="quote-large", preview=pv,
        zones=[("quote", 16, 18, 332, 166), ("author", 16, 334, 230, 350), ("button", 300, 322, 332, 350)])


def quote_medium(pv):
    # The quote across a dark sky, the light low on the horizon behind a snowy range, the author signing the dark
    # foreground beside the button.
    return composed(
        348, 164, 509, sun=(0.56, 0.74), horizon=0.76, sky=dict(dark_top=0.24, bright=0.86, low=0.62),
        clouds=[(0.2, 0.3, 0.7, 0.32, 60, 0.4), (0.85, 0.28, 0.56, 0.3, 50, 0.4), (0.22, 0.66, 0.3, 0.1, 30),
                (0.82, 0.66, 0.24, 0.08, 22)],
        ceiling=(0.54, 0.64, 0.26),
        ranges=[
            rr(FAR, keys=[p(0, 0.76), p(0.15, 0.72), p(0.3, 0.68), p(0.42, 0.63), p(0.5, 0.6), p(0.56, 0.63),
                          p(0.68, 0.69), p(0.8, 0.73), p(1, 0.76)], seed=81, snowline=0.69, mist=(10, 26, 0.62)),
            rr(MID, keys=[p(0, 0.79), p(0.2, 0.775), p(0.45, 0.79), p(0.7, 0.77), p(1, 0.785)], seed=83,
               mist=(4, 14, 0.4)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.8), p(0.2, 0.81), p(0.5, 0.815), p(0.72, 0.8), p(0.84, 0.74), p(0.92, 0.72),
                                  p(1, 0.71)], seed=87, tone=0.22),
        trees=[(2, (8, 18), 5.0, 0.6, FIR, (0.74, 1.05))],
        darks=[(0.5, 0.3, 0.6, 0.36, 0.32), (0.3, 0.9, 0.42, 0.12, 0.35)],
        contrast=1.2, lift=0.3, name="quote-medium", preview=pv,
        zones=[("quote", 16, 14, 332, 92), ("author", 16, 138, 220, 150), ("button", 302, 124, 332, 150)])


def quote_small(pv):
    # The quote in the dark sky, one snowy peak in the light below it, the author signing the dark slope.
    return composed(
        164, 164, 511, sun=(0.42, 0.62), horizon=0.66, sky=dict(dark_top=0.24, bright=0.86, low=0.62),
        clouds=[(0.1, 0.28, 0.8, 0.3, 40, 0.42), (0.95, 0.26, 0.6, 0.28, 36, 0.42), (0.86, 0.6, 0.3, 0.1, 22)],
        ceiling=(0.46, 0.58, 0.28),
        ranges=[
            rr(FAR, keys=[p(0, 0.68), p(0.2, 0.63), p(0.36, 0.56), p(0.48, 0.5), p(0.56, 0.53), p(0.7, 0.6),
                          p(0.85, 0.65), p(1, 0.68)], seed=91, snowline=0.61, mist=(10, 24, 0.6)),
            rr(MID, keys=[p(0, 0.72), p(0.3, 0.705), p(0.6, 0.72), p(1, 0.71)], seed=93, mist=(4, 12, 0.4)),
        ],
        foreground=rr(NEAR, keys=[p(0, 0.75), p(0.3, 0.765), p(0.6, 0.77), p(1, 0.755)], seed=97, tone=0.22),
        trees=[(2, (7, 14), 4.5, 0.6, FIR, (0.62, 1.05))],
        darks=[(0.5, 0.26, 0.62, 0.3, 0.32), (0.4, 0.93, 0.5, 0.08, 0.3)],
        contrast=1.2, lift=0.3, name="quote-small", preview=pv,
        zones=[("quote", 16, 14, 148, 76), ("author", 16, 138, 148, 150)])


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    jobs = {"day-large": day_large, "day-medium": day_medium, "day-small": day_small,
            "quote-large": quote_large, "quote-medium": quote_medium, "quote-small": quote_small}
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        value, glow = fn(pv)
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
    if not only or "veil" in only:
        save_alpha("veil", om.veil(348, 220, 523))


if __name__ == "__main__":
    main()
