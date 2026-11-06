#!/usr/bin/env python3
"""Giant Numeral textures: the Matterhorn in mist over a spruce forest, painted as a value study in depth layers so a
huge ultra-thin temperature numeral can stand in the fog between the peak and the trees.

Painted with Old Master's brush (MockLab/Textures/old-master/make.py: sky_field, cumulus, mountain, firs, fir, crest,
veil) and Old Master Cover's traced Matterhorn (MockLab/Textures/old-master-cover/make.py: matterhorn, view_crest,
within), both imported from their paths, not copied. Depth order on every weather canvas:

    moody sky, soft cloud  ->  the Matterhorn, its foot in cloud  ->  far misty ridge and firs
        ->  [the numeral, drawn by SwiftUI]  ->  a drifting fog bank, the near ridges of spruce, tall spires at the edges

and the part in front of the numeral is also written out as an alpha mask (fog banks at their own thinness), so the
numeral's foot sinks into the fog and the spruce tops cross it, while its head stands clear in the sky beside the peak.

Weather canvases (1 px per point, the widget's own size), for each <name>:
  <name>-lo.png, <name>-hi.png   alpha = the lower and upper half of the painted value; tinted at run time as a
                                 three-stop gradient map (forest shadow, olive-sage, fog), so one canvas serves day,
                                 dusk, night and grey weather.
  <name>-glow.png                alpha = the brightest lights (lit snow, cloud tops), glazed soft gold or moonlight.
  <name>-front.png               alpha = what stands in front of the numeral (fog banks, near ridges, spruce).
  names: weather-large 348x365, weather-medium 348x164, weather-small 164x164
Other textures:
  frost.png      348x365  alpha = painted mist on glass: soft level strokes and a fine grain (the frosted strip and
                          the to-do card), tinted fog-white at run time
  veil.png       348x220  rain: Old Master's veil() re-run here, so this look owns its files
  wallpaper.jpg  780x805  the board's home screen (not a widget texture): spruce ranks receding in fog under a ghost
                          of the Matterhorn, olive, sage and fog grey

The numeral geometry (left edge, baseline and size in points, SF ultralight condensed) is fixed per canvas in
NUMERALS below and repeated in Swift (GNCanvas.numeral).

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-numeral/make.py [names...]
Add --preview <folder> to also write day-palette previews with the numeral's box marked.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing the Old Master painters (and through them scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("oc_make", os.path.join(os.path.dirname(HERE), "old-master-cover", "make.py"))
oc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oc)
om, mt, SS = oc.om, oc.mt, oc.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def save_rgb(name, rgb, quality=86):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=quality, subsampling=0)
    print(f"{name}.jpg: {rgb.shape[1]}x{rgb.shape[0]}")


LIGHT = (0.55, -0.6, 0.6)  # from the upper right, as on the Matterhorn in the photograph
FOG = 0.74                 # the value of fog


# MARK: Fog and spruce

def fog_bank(w, h, rng, y, thick, amount, x0=-0.2, x1=1.2, tilt=0.0):
    """A drifting bank of fog: a soft level band centred on y and `thick` deep (fractions), wandering a little up and
    down along its length and torn into long wisps, densest along its middle. Returns alpha (0..amount)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    wander = fbm(1, w, rng, base=3, octaves=3)[0] * thick * h * 0.35
    centre = y * h + wander[None, :] + tilt * (xx - w / 2)
    d = (yy - centre) / (thick * h)
    body = np.exp(-2.2 * d * d)
    tear = fbm(h, w, rng, base=5, octaves=4, stretch=5.0)
    a = body * smoothstep(-1.0, 0.7, tear + 1.3 * body - 0.7)
    a *= smoothstep(x0 - 0.15, x0 + 0.15, xx / w) * smoothstep(x1 + 0.15, x1 - 0.15, xx / w)
    return np.clip(a * amount, 0, 1), d


def spires(w, h, rng, items):
    """Tall single spruces (Old Master's fir), each (x, base y, height pt): a 0..1 mask drawn at 2x for soft edges."""
    k = 2
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    for x, base, height in items:
        poly = om.fir(x * w, base * h, height * SS, rng)
        d.polygon([(px * k, py * k) for px, py in poly], fill=255)
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


def scene(pw, ph, seed, sun, horizon, sky, clouds, peak, layers, contrast=1.15, ground=(0.85, 1.0, 0.3), skyfog=()):
    """A value study at SS times the widget's size, painted and filtered to 1 px per point.
    skyfog: fog banks (dicts as below) drifting in the sky behind the peak: the moody streaks of cloud.
    peak: (summit x, summit y, pyramid height pt) for the traced Matterhorn.
    layers, back to front (once one is marked front=True, all after it are too):
      {"kind": "fog", y, thick, amount, [value, x0, x1, tilt]}
      {"kind": "ridge", keys, seed, tone, [haze, mist (d0 pt, d1 pt, amount), trees (heights pt, spacing pt,
        coverage, tone), roughness, contrast]}
      {"kind": "spires", items [(x, base, height pt)], tone}
    Returns value, glow, front mask (0..1)."""
    w, h = pw * SS, ph * SS
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    V, angle = om.sky_field(w, h, rng, sun, horizon, **sky)
    glow = np.zeros((h, w))
    if clouds:
        for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
            if not layer:
                continue
            cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, sun, billow=0.75, flow=7.0)
            V = V + (cv - V) * ccover * 0.92
            glow = glow * (1 - ccover) + clit * 0.7
            angle = np.where(ccover > 0.3, ctan, angle)

    fogs = np.zeros((h, w))
    for L in skyfog:
        a, d = fog_bank(w, h, rng, L["y"], L["thick"], L["amount"], L.get("x0", -0.2), L.get("x1", 1.2), L.get("tilt", 0.0))
        fv = L.get("value", FOG) - 0.05 * np.clip(d, -1.5, 1.5) + 0.02 * fbm(h, w, rng, base=8, octaves=3, stretch=3.0)
        V = V + (fv - V) * a
        glow *= 1 - a
        fogs = fogs * (1 - a) + a

    # The Matterhorn, a little hazed by the air between, its foot lost in cloud.
    sx, sy, height = peak
    cy = oc.view_crest(w, h, sx, sy, height * SS)
    v, cover, snow, lean_m, crisp = oc.matterhorn(w, h, rng, cy, sx, sy, height * SS, light=LIGHT, haze_v=FOG,
                                                  mist=(0.55, 1.05, 0.9))
    v = v + (0.6 - v) * 0.1
    V = V + (v - V) * cover
    glow = glow * (1 - cover) + snow * cover
    land = cover.copy()
    lean = lean_m * cover
    keep = crisp.copy()
    fogs *= 1 - cover
    trees = np.zeros((h, w))
    fmask = np.zeros((h, w))
    near = np.zeros((h, w))
    in_front = False
    for L in layers:
        L = dict(L)
        front = L.pop("front", False)
        assert front or not in_front, "back layers come before front ones"
        in_front = in_front or front
        kind = L.pop("kind")
        if kind == "fog":
            a, d = fog_bank(w, h, rng, L["y"], L["thick"], L["amount"], L.get("x0", -0.2), L.get("x1", 1.2), L.get("tilt", 0.0))
            fv = L.get("value", FOG) - 0.05 * np.clip(d, -1.5, 1.5) + 0.02 * fbm(h, w, rng, base=8, octaves=3, stretch=3.0)
            V = V + (fv - V) * a
            glow *= 1 - a
            keep *= 1 - a
            trees *= 1 - a
            fogs = fogs * (1 - a) + a
            cov = a
        elif kind == "ridge":
            cy = om.crest(L["keys"], L["seed"], w, h, L.get("roughness", 0.2))
            mist = L.get("mist")
            v, cov, _, nx = om.mountain(w, h, rng, cy, L["tone"], LIGHT, gully=0.3, haze=L.get("haze", 0.0), haze_v=FOG,
                                        mist=mist, contrast=L.get("contrast", 0.6))
            if "trees" in L:
                heights, spacing, coverage, tone = L["trees"]
                m = om.firs(w, h, rng, cy, heights, spacing, coverage)
                depth = yy - cy[None, :]
                tv = tone + L.get("haze", 0.0) * (FOG - tone)
                if mist is not None:
                    tv = tv + (FOG - tv) * mist[2] * smoothstep(mist[0] * SS, mist[1] * SS, depth)
                rim = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
                v = v * (1 - m) + (tv + 0.06 * rim) * m
                trees = np.maximum(trees * (1 - cov), m)
                cov = np.maximum(cov, m)
            else:
                trees *= 1 - cov
            V = V + (v - V) * cov
            glow *= 1 - cov
            land = np.maximum(land, cov)
            lean = lean * (1 - cov) + nx * cov
            keep *= 1 - cov
            fogs *= 1 - cov
            if front:
                near = np.maximum(near, cov)
        elif kind == "spires":
            m = spires(w, h, rng, L["items"])
            rim = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
            V = V + (L["tone"] + 0.08 * rim - V) * m
            glow *= 1 - m
            land = np.maximum(land, m)
            trees = np.maximum(trees, m)
            fogs *= 1 - m
            keep *= 1 - m
            cov = m
        else:
            raise ValueError(kind)
        fmask = cov + fmask * (1 - cov) if front else fmask * (1 - cov)

    # The near forest deepens toward the foot of the canvas, so the strip rests on a quiet dark passage.
    g0, g1, amount = ground
    V = V * (1 - amount * smoothstep(g0 * h, g1 * h, yy) * near)

    # Strokes: round the billows in the sky, level through the fog, down the faces and the spruce on land.
    level = 0.02 * fbm(h, w, rng, base=3, octaves=2)
    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    angle = np.where(trees > 0.5, np.pi / 2 + 0.1 * fbm(h, w, rng, base=9, octaves=2), angle)
    angle = np.where(fogs > 0.3, level, angle)
    k = pw * ph / (348 * 365)
    s = SS
    solid = ((land > 0.5) & (fogs < 0.45)).astype(np.float64)
    sky_field = oc.within(V, 1 - solid, 6 * SS)
    land_field = oc.within(V, solid, 6 * SS)
    sky_out = mt.paint(np.stack([sky_field] * 3, axis=2), angle, rng,
                       [(int(420 * k), (6 * s, 12 * s), (18 * s, 40 * s)),
                        (int(1400 * k), (3 * s, 6 * s), (9 * s, 22 * s)),
                        (int(2600 * k), (1.4 * s, 2.6 * s), (5 * s, 11 * s)),
                        (int(3000 * k), (0.7 * s, 1.2 * s), (3 * s, 7 * s))], 0.025)
    land_out = mt.paint(np.stack([land_field] * 3, axis=2), angle, rng,
                        [(int(500 * k), (4 * s, 8 * s), (6 * s, 14 * s)),
                         (int(1600 * k), (2 * s, 4 * s), (4 * s, 9 * s)),
                         (int(2400 * k), (1.2 * s, 2.2 * s), (2.5 * s, 6 * s)),
                         (int(2600 * k), (0.7 * s, 1.1 * s), (2 * s, 4 * s))], 0.035)
    out = sky_out * (1 - solid[..., None]) + land_out * solid[..., None]
    out = gaussian_filter(out[..., 0], 0.45 * s)
    # The Matterhorn's drawing and the spruce silhouettes laid back over the strokes, crisp.
    out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(keep, 0.5 * s) * 0.85
    out = out + (np.minimum(out, V) - out) * gaussian_filter(trees, 0.5 * s) * 0.75
    # Fog stays soft: a breath more of the unpainted value where it lies.
    out = out + (gaussian_filter(V, 1.2 * s) - out) * gaussian_filter(fogs, 1.0 * s) * 0.35
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.016))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.05 * s
    out = 0.84 * out + 0.16 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.05
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.82, 0.98, out) * (1 - land) * 0.6), 0, 1)
    fmask = gaussian_filter(fmask, 0.4 * s)
    return om.down(out), om.down(glow), om.down(fmask)


# MARK: The numeral (points; mirrored in GNCanvas.numeral)
# (left edge of the text, baseline y, font size for a two-character temperature such as "64")

NUMERALS = {
    "weather-large": (14, 236, 200),
    "weather-medium": (12, 142, 148),
    "weather-small": (10, 116, 100),
}


def r(x, y):
    return (x, y)


# MARK: The canvases (fractions of the widget unless marked pt)

def weather_large():
    # The Matterhorn right of centre, summit high in the sky; the numeral on the left, its head against the dark sky
    # and the shadowed left face, its foot in the fog bank, the spruce tops crossing it; the strip on the dark forest.
    return scene(348, 365, 701, sun=(0.86, 0.03), horizon=0.6,
                 sky=dict(dark_top=0.28, bright=0.6, low=0.72),
                 clouds=[],
                 skyfog=[dict(y=0.1, thick=0.045, amount=0.55, value=0.5, x0=-0.3, x1=0.5, tilt=0.03),
                         dict(y=0.19, thick=0.035, amount=0.45, value=0.56, x0=0.78, x1=1.3),
                         dict(y=0.42, thick=0.05, amount=0.6, value=0.66, x0=-0.3, x1=0.35)],
                 peak=(0.69, 0.1, 150),
                 layers=[
                     dict(kind="fog", y=0.36, thick=0.03, amount=0.55, value=0.74, x0=0.74, x1=1.3, tilt=0.02),
                     dict(kind="fog", y=0.5, thick=0.07, amount=0.85, value=0.78),
                     dict(kind="ridge", keys=[r(0, 0.565), r(0.3, 0.55), r(0.62, 0.565), r(1, 0.555)], seed=11, tone=0.4,
                          haze=0.35, mist=(6, 24, 0.85), trees=((5, 11), 3.5, 0.85, 0.34), roughness=0.25),
                     dict(kind="fog", y=0.585, thick=0.045, amount=0.65, value=0.78),
                     dict(kind="fog", y=0.605, thick=0.055, amount=0.78, value=0.8, front=True),
                     dict(kind="ridge", keys=[r(0, 0.665), r(0.22, 0.675), r(0.5, 0.68), r(0.78, 0.67), r(1, 0.66)],
                          seed=13, tone=0.24, haze=0.18, mist=(14, 40, 0.65), trees=((14, 34), 6.0, 0.85, 0.2),
                          front=True),
                     dict(kind="fog", y=0.745, thick=0.05, amount=0.55, value=0.76, front=True),
                     dict(kind="ridge", keys=[r(0, 0.785), r(0.3, 0.8), r(0.6, 0.805), r(1, 0.785)], seed=17, tone=0.12,
                          haze=0.04, mist=(30, 70, 0.2), trees=((18, 40), 7.0, 0.9, 0.08), front=True),
                     dict(kind="spires", items=[(-0.01, 0.86, 168), (0.055, 0.88, 120), (0.975, 0.85, 176),
                                                (0.915, 0.87, 112)], tone=0.07, front=True),
                 ], ground=(0.8, 1.0, 0.35))


def weather_medium():
    # The numeral fills the left half, its foot in fog behind the spruce; the Matterhorn right of centre, its summit
    # high, the sky right of it open for the icon and the condition; the strip on the forest at the bottom right.
    return scene(348, 164, 703, sun=(0.92, -0.02), horizon=0.72,
                 sky=dict(dark_top=0.26, bright=0.6, low=0.72),
                 clouds=[],
                 skyfog=[dict(y=0.13, thick=0.07, amount=0.5, value=0.5, x0=-0.3, x1=0.45),
                         dict(y=0.4, thick=0.06, amount=0.45, value=0.62, x0=0.84, x1=1.3)],
                 peak=(0.67, 0.1, 92),
                 layers=[
                     dict(kind="fog", y=0.66, thick=0.08, amount=0.85, value=0.78),
                     dict(kind="ridge", keys=[r(0, 0.72), r(0.3, 0.71), r(0.6, 0.725), r(1, 0.715)], seed=21, tone=0.4,
                          haze=0.35, mist=(5, 18, 0.85), trees=((5, 10), 3.5, 0.85, 0.34), roughness=0.25),
                     dict(kind="fog", y=0.755, thick=0.07, amount=0.75, value=0.8, front=True),
                     dict(kind="ridge", keys=[r(0, 0.82), r(0.25, 0.83), r(0.5, 0.835), r(0.75, 0.83), r(1, 0.82)],
                          seed=23, tone=0.22, haze=0.15, mist=(10, 26, 0.55), trees=((10, 26), 5.5, 0.85, 0.18),
                          front=True),
                     dict(kind="ridge", keys=[r(0, 0.93), r(0.5, 0.94), r(1, 0.93)], seed=27, tone=0.1,
                          trees=((12, 24), 6.0, 0.9, 0.07), front=True),
                     dict(kind="spires", items=[(-0.012, 1.0, 104), (0.985, 0.98, 98)], tone=0.07, front=True),
                 ], ground=(0.85, 1.0, 0.3))


def weather_small():
    # The numeral across the lower left, its degree sign at the summit's shadowed face, its foot behind the spruce;
    # "NOVEMBER" in the dark sky above it and the icon over the summit; the strip on the forest at the foot.
    return scene(164, 164, 705, sun=(0.98, 0.0), horizon=0.62,
                 sky=dict(dark_top=0.26, bright=0.6, low=0.72),
                 clouds=[],
                 skyfog=[dict(y=0.13, thick=0.08, amount=0.5, value=0.5, x0=-0.3, x1=0.55)],
                 peak=(0.74, 0.2, 58),
                 layers=[
                     dict(kind="fog", y=0.52, thick=0.07, amount=0.85, value=0.78),
                     dict(kind="ridge", keys=[r(0, 0.585), r(0.4, 0.575), r(1, 0.585)], seed=31, tone=0.4, haze=0.35,
                          mist=(4, 14, 0.85), trees=((4, 8), 3.2, 0.85, 0.34), roughness=0.25),
                     dict(kind="fog", y=0.65, thick=0.06, amount=0.75, value=0.8, front=True),
                     dict(kind="ridge", keys=[r(0, 0.705), r(0.3, 0.715), r(0.7, 0.71), r(1, 0.7)], seed=33, tone=0.22,
                          haze=0.15, mist=(8, 20, 0.55), trees=((7, 18), 4.6, 0.85, 0.18), front=True),
                     dict(kind="ridge", keys=[r(0, 0.84), r(0.5, 0.85), r(1, 0.84)], seed=37, tone=0.1,
                          trees=((8, 16), 5.0, 0.9, 0.07), front=True),
                     dict(kind="spires", items=[(0.99, 0.98, 84)], tone=0.07, front=True),
                 ], ground=(0.85, 1.0, 0.3))


# MARK: Other textures

def frost(w, h, seed):
    """Painted mist on glass: long soft level strokes of varying density and a fine grain, as alpha."""
    rng = np.random.default_rng(seed)
    angle = 0.04 * fbm(h, w, rng, base=2, octaves=2) - 0.06
    tone = 0.5 + 0.2 * fbm(h, w, rng, base=3, octaves=4, persistence=0.5, stretch=3.0)
    out = mt.paint(np.stack([tone] * 3, axis=2), angle, rng,
                   [(700, (8, 16), (40, 110)), (1800, (3, 7), (20, 60)), (2600, (1, 2.5), (10, 30))], 0.06)
    out = gaussian_filter(out[..., 0], 0.8)
    out = out + mt.bristles(h, w, rng, angle, 0.03)
    grain = mt.speckle(h, w, rng, 0.02, (0.4, 0.9))
    a = np.clip((out - 0.38) * 1.6, 0, 1) * 0.85 + 0.25 * grain
    return np.clip(a, 0, 1)


WALL_STOPS = [(0.0, 0x10150F), (0.25, 0x2C3629), (0.48, 0x55624C), (0.68, 0x8C9783), (0.84, 0xB9BFAF),
              (1.0, 0xD7D9CD)]


def gradient_map(v, stops):
    rgb = np.zeros(v.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        t = np.clip((v - a0) / (a1 - a0), 0, 1)
        sel = (v >= a0) & (v <= a1)
        rgb[sel] = (hexrgb(c0) * (1 - t[..., None]) + hexrgb(c1) * t[..., None])[sel]
    return rgb


def wallpaper(w, h, seed):
    """The board's home screen: ranks of spruce receding into fog below a ghost of the Matterhorn, tall dark spires at
    both edges (the nature-glass home screens of the research, painted). Softer than the widgets; RGB."""
    value, glow, _ = scene(w, h, seed, sun=(0.7, 0.05), horizon=0.62,
                           sky=dict(dark_top=0.42, bright=0.72, low=0.76),
                           clouds=[(0.2, 0.2, 0.9, 0.08, 40, 0.3), (0.9, 0.36, 0.5, 0.08, 30)],
                           peak=(0.62, 0.16, 300),
                           layers=[
                               dict(kind="fog", y=0.42, thick=0.08, amount=0.9, value=0.78),
                               dict(kind="ridge", keys=[r(0, 0.5), r(0.3, 0.48), r(0.7, 0.5), r(1, 0.49)], seed=41,
                                    tone=0.45, haze=0.4, mist=(10, 50, 0.85), trees=((10, 22), 6.0, 0.85, 0.4)),
                               dict(kind="fog", y=0.56, thick=0.06, amount=0.7),
                               dict(kind="ridge", keys=[r(0, 0.6), r(0.35, 0.62), r(0.7, 0.6), r(1, 0.61)], seed=43,
                                    tone=0.3, haze=0.25, mist=(20, 70, 0.7), trees=((20, 46), 9.0, 0.85, 0.26)),
                               dict(kind="fog", y=0.7, thick=0.06, amount=0.6),
                               dict(kind="ridge", keys=[r(0, 0.74), r(0.4, 0.76), r(1, 0.745)], seed=47, tone=0.16,
                                    haze=0.1, mist=(40, 120, 0.45), trees=((34, 70), 12.0, 0.9, 0.13)),
                               dict(kind="fog", y=0.86, thick=0.07, amount=0.45),
                               dict(kind="spires", items=[(0.0, 1.0, 560), (0.07, 1.02, 420), (0.13, 1.05, 300),
                                                          (1.0, 0.98, 600), (0.93, 1.02, 430), (0.87, 1.05, 280)],
                                    tone=0.07),
                           ], contrast=1.05, ground=(0.85, 1.0, 0.2))
    value = gaussian_filter(value, 0.9)
    rgb = gradient_map(value, WALL_STOPS)
    rgb = mix(rgb, hexrgb(0xE2D3A6), 0.22 * glow)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    vign = np.hypot((xx / w - 0.5) * 1.2, (yy / h - 0.5) * 1.0)
    return mt.shade(rgb, -0.32 * smoothstep(0.35, 0.85, vign))


# MARK: Preview

DAY_STOPS = [(0.0, 0x12170F), (0.5, 0x5E6B4E), (1.0, 0xD8DACB)]


def preview(folder, name, value, glow, front):
    """Day-palette composite with the numeral ("64°" in Avenir Next Condensed UltraLight, close to the SF ultralight
    condensed the widget uses) between the back and the front of the painting."""
    h, w = value.shape
    base = gradient_map(value, DAY_STOPS)
    base = mix(base, hexrgb(0xEAD9A8), glow * 0.5)
    left, baseline, size = NUMERALS[name]
    img = Image.new("L", (w * 4, h * 4), 0)
    font = ImageFont.truetype("/System/Library/Fonts/Avenir Next Condensed.ttc", size * 4, index=10)
    ImageDraw.Draw(img).text((left * 4, baseline * 4), "64°", font=font, fill=255, anchor="ls")
    m = np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    out = mix(base, np.ones((h, w, 3)) * hexrgb(0xF4F2E8), m * 0.95)
    out = mix(out, base, front)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize((w * 2, h * 2), Image.BICUBIC).save(
        os.path.join(folder, f"pv-{name}.png"))
    Image.fromarray((np.clip(front, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, f"pv-{name}-front.png"))


def main():
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    jobs = {"weather-large": weather_large, "weather-medium": weather_medium, "weather-small": weather_small}
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        value, glow, front = fn()
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
        save_alpha(name + "-front", front)
        if pv:
            preview(pv, name, value, glow, front)
    if not only or "frost" in only:
        save_alpha("frost", frost(348, 365, 721))
    if not only or "veil" in only:
        save_alpha("veil", om.veil(348, 220, 723))
    if not only or "wallpaper" in only:
        save_rgb("wallpaper", wallpaper(780, 805, 725))


if __name__ == "__main__":
    main()
