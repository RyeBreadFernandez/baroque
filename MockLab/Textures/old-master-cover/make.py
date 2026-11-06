#!/usr/bin/env python3
"""Old Master Cover textures: the Old Master paintings recomposed as magazine covers, painted in depth layers so a
giant gilt numeral (or opening quotation mark) can stand inside the picture, behind the Matterhorn.

Each canvas is painted with Old Master's own brush (MockLab/Textures/old-master/make.py, imported from its path, not
copied: sky_field, cumulus, mountain, firs, crest and the stroke passes of scripts/make_textures.py) as one value study,
in depth order:

    sky and cloud  ->  [the hero glyph, drawn by SwiftUI]  ->  drifting puff, the Matterhorn, foreground and firs

and the front of that order is also written out as an alpha mask. The widget draws the tinted painting, then the
hero glyph, then the same tinted painting again through the front mask, so the mountain's flank and shoulder, the firs
and a small puff of cloud pass in front of the glyph's foot (the magazine-cover overlap) while the summit and its hook
stand clear in open sky beside it. The lower part of every canvas (or the right half on medium) is the painting's own
dark ground, quiet enough to carry type.

Paintings (1 px per point, the widget's own size), for each <name>:
  <name>-lo.png, <name>-hi.png   alpha = the lower and upper half of the painted value; tinted at run time as an exact
                                 three-stop gradient map (shadow, warm mid, light), as in Old Master.
  <name>-glow.png                alpha = the brightest lights (cloud tops, lit snow), glazed in the colour of the sun.
  <name>-front.png               alpha = what stands in front of the hero glyph (mountain, foreground, firs, puff).
  names: day-large 348x365, day-medium 348x164, day-small 164x164,
         quote-large 348x365, quote-medium 348x164, quote-small 164x164
Other textures:
  gilt.png    348x365  alpha = brushed hollows in the gilt of the hero glyph (multiplied in, faintly)
  veil.png    348x220  rain: Old Master's veil() re-run here, so the variant owns its files
Data:
  matterhorn.json   ~8 KB  the mountain: the Matterhorn's skyline from the Riffelsee, traced from a photograph and
                    normalised (see "The Matterhorn, traced from a photograph" below), with its attribution. Every
                    canvas's mountain is this line at one scale, framed per canvas (FRAMES).

The hero glyph geometry is fixed per canvas (HEROES below) and repeated in Swift, in OCCanvas.hero (MockLab) and
CoverCanvas.hero (Shared/CoverPainting.swift); Baskerville's digits are lining and tabular (0.655 em tall, 0.5 em
advance), its italic opening quote 0.265 em tall.

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/old-master-cover/make.py [names...]
Add --preview <folder> to also write day-palette composites with the hero glyph placed ("3", "28", "11").
Rebuild matterhorn.json from the full trace:  python3 .../make.py --trace <matterhorn_riffelsee_skyline.json>
(the trace: {"width", "height", "summit_x", "y": [the skyline's row for every column of the photograph]}).
"""
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True  # importing Old Master's make.py (and through it scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, map_coordinates, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("om_make", os.path.join(os.path.dirname(HERE), "old-master", "make.py"))
om = importlib.util.module_from_spec(spec)
spec.loader.exec_module(om)
mt = om.mt
SS = om.SS
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix

BASKERVILLE = "/System/Library/Fonts/Supplemental/Baskerville.ttc"


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


# MARK: The Matterhorn, traced from a photograph
# The mountain in every canvas is the Matterhorn (4,478 m / 14,692 ft) in its classic view from the Riffelsee above
# Zermatt, looking southwest: the hooked summit pyramid, the steep left face and the long shoulder on the right. 30 m
# terrain data rounded the summit and put it 126 m low, so the skyline was traced from a photograph instead:
# File:Matterhorn_Riffelsee_2005-06-11.jpg on Wikimedia Commons (1352 x 2048 px; for every column, the first row that is
# not sky, smoothed over 5 px). matterhorn.json keeps that line, normalised and decimated, with its attribution; only
# the line is used, never the photograph's pixels. Units: the summit at (0, 0), x to the right and y down, in pyramid
# heights (the drop from the summit to the foot of the steep left face, 348.6 px of the photograph).
# Every canvas scales the line uniformly (no exaggeration); FRAMES only places and sizes it.
# `make.py --trace <matterhorn_riffelsee_skyline.json>` rebuilds matterhorn.json from the full trace.

PROFILE = os.path.join(HERE, "matterhorn.json")
TRACE_STEP = (6, 2)  # columns of the trace per stored point: on the lower ridges, and on the pyramid and shoulder
TRACE_FOOT = 440     # the trace column where the steep left face meets the lower ridges
TRACE_NOTCH = 820    # the notch at the head of the shoulder (the Hornli ridge starts down from it)
TRACE_SHOULDER = 1100  # where the shoulder runs out onto the glacier


def profile_from_trace(path):
    """Normalises and decimates the traced skyline and writes matterhorn.json."""
    with open(path) as f:
        trace = json.load(f)
    y = np.asarray(trace["y"], dtype=np.float64)
    top = int(trace["summit_x"])
    assert top == int(np.argmin(y)), "the summit is the highest point of the trace"
    unit = y[TRACE_FOOT] - y[top]
    lo, hi = TRACE_FOOT - 40, TRACE_SHOULDER + 40
    coarse, fine = TRACE_STEP
    cols = sorted(set(range(0, lo, coarse)) | set(range(lo, hi + 1, fine)) | set(range(hi, len(y), coarse))
                  | {len(y) - 1})
    assert top in cols
    data = {
        "peak": {"name": "Matterhorn", "elevation_m": 4478, "elevation_ft": 14692},
        "view": "from the Riffelsee above Zermatt (about 2,760 m), looking southwest",
        "source": {
            "photo": "File:Matterhorn_Riffelsee_2005-06-11.jpg, Wikimedia Commons",
            "url": "https://commons.wikimedia.org/wiki/File:Matterhorn_Riffelsee_2005-06-11.jpg",
            "credit": "the photographer and licence are those given on the file page (not re-checked offline)",
            "use": "skyline only: for each column the first row that is not sky, smoothed over 5 px; no pixels kept",
        },
        "trace": {"width": int(trace["width"]), "height": int(trace["height"]), "summit": [top, round(float(y[top]), 1)],
                  "foot": [TRACE_FOOT, round(float(y[TRACE_FOOT]), 1)],
                  "step": f"every {fine} columns from {lo} to {hi}, every {coarse} outside"},
        "units": "summit at (0, 0), x right and y down, in pyramid heights (summit to the foot of the left face)",
        "foot": [round((TRACE_FOOT - top) / unit, 4), 1.0],
        "notch": [round((TRACE_NOTCH - top) / unit, 4), round(float(y[TRACE_NOTCH] - y[top]) / unit, 4)],
        "shoulder": [round((TRACE_SHOULDER - top) / unit, 4), round(float(y[TRACE_SHOULDER] - y[top]) / unit, 4)],
        "x": [round((c - top) / unit, 4) for c in cols],
        "y": [round(float(y[c] - y[top]) / unit, 4) for c in cols],
    }
    with open(PROFILE, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    print(f"matterhorn.json: {len(cols)} points, pyramid {unit:.1f} px of {trace['width']}")


_PROFILE_CACHE = {}


def profile():
    """matterhorn.json, read once."""
    if not _PROFILE_CACHE:
        with open(PROFILE) as f:
            _PROFILE_CACHE.update(json.load(f))
    return _PROFILE_CACHE


def skyline():
    """The Matterhorn's skyline as (x, y) in pyramid heights from the summit, y down."""
    return np.array(profile()["x"]), np.array(profile()["y"])


def view_crest(w, h, sx, sy, height):
    """The skyline as the crest of a range on a canvas w x h px: the summit at (sx, sy) (fractions) and the pyramid
    `height` px tall, at one scale across and down. Past the traced width the ends run on level."""
    x, y = skyline()
    u = ((np.arange(w) + 0.5) - sx * w) / height
    return sy * h + np.interp(u, x, y) * height


def flanks():
    """The pyramid's two edges as functions of depth: (depths, left x, right x), all in pyramid heights. The left edge
    follows the steep face to its foot and then runs on down under the lower ridges; the right edge follows the
    summit ridge, the shoulder and its foot (the notch is filled, so the edge only ever widens)."""
    x, y = skyline()
    fx, fy = profile()["foot"]
    left = (x <= 0) & (x >= fx)
    lx, ly = x[left][::-1], np.maximum.accumulate(y[left][::-1])
    right = (x >= 0) & (x <= profile()["shoulder"][0])
    rx, ry = x[right], np.maximum.accumulate(y[right])
    depth = np.linspace(0, 2.5, 501)
    ul = np.where(depth <= fy, np.interp(depth, ly, lx), fx - 0.45 * (depth - fy))
    ur = np.where(depth <= ry[-1], np.interp(depth, ry, rx), rx[-1] + 1.2 * (depth - ry[-1]))
    return depth, ul, ur


def sheared_noise(h, w, rng, base, stretch, shear, y0, octaves=4, persistence=0.55):
    """fbm streaked along a slant: features drawn out by `stretch` and leaning `shear` px across per px down from
    row y0 (positive leans down-left)."""
    g = fbm(h, w, rng, base=base, octaves=octaves, persistence=persistence, stretch=stretch)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return map_coordinates(g, [yy, np.clip(xx + shear * (yy - y0), 0, w - 1)], order=1, mode="nearest")


def matterhorn(w, h, rng, cy, sx, sy, height, light=(0.55, -0.6, 0.6), haze_v=0.62, mist=(0.8, 1.3, 0.5)):
    """The Matterhorn on a canvas w x h px (summit at sx, sy fractions; the pyramid `height` px tall), lit as in the
    photograph: a dark horn of rock at the summit; the left face in shadow; the east face in front lit, its snow in
    long streaks down the fall line and along the ledges, more of it lower down; a band of dark rock under the summit
    ridge that runs on from the notch down to the right as the Hornli ridge, its crest catching the light down to the
    notch; the lit snow of the north face beyond it, under the shoulder; mist at the foot. The lower ridges either side
    are Old Master's range, lit from the same side.
    Returns value, coverage, lit snow, stroke lean and the lines to keep crisp (0..1)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    X, Y = sx * w, sy * h
    u = (xx - X) / height                       # pyramid heights right of the summit
    v = (yy - Y) / height                       # and below it
    k = max(w, h) / height                      # noise cells per pyramid height -> per canvas
    # The lower ridges and glaciers either side, and the base under everything.
    base, cover, base_snow, base_nx = om.mountain(w, h, rng, cy, 0.42, light, snowline=sy + 1.5 * height / h,
                                                  gully=0.6, snow_v=(0.5, 0.96))
    depth, ul, ur = flanks()
    uR = np.interp(v, depth, ur)
    soft = 0.012
    pyramid = (smoothstep(-soft, soft, u - np.interp(v, depth, ul)) * smoothstep(soft, -soft, u - uR)
               * smoothstep(-0.06, -0.02, v))
    # The lines the pyramid is built on (pyramid heights), each wandering a little so none is ruled.
    wander = fbm(h, w, rng, base=3 * k, octaves=3) * 0.012
    nx_, ny_ = profile()["notch"]
    u_shadow = 0.03 - 0.33 * v + wander                                     # edge of the left face
    horn = 0.16 + 0.035 * fbm(h, w, rng, base=5 * k, octaves=2)              # foot of the summit's horn of rock
    # The dark band: under the summit ridge (sw wide) to the notch, then the Hornli ridge (bw either side of it).
    sw = np.interp(v, [0.0, 0.12, 0.35, ny_], [0.0, 0.03, 0.06, 0.07])
    u_h = np.interp(v, [ny_, 0.825, 1.026, 1.226, 1.6], [nx_ - 0.02, 0.579, 0.723, 0.838, 1.1]) + wander
    bw = np.interp(v, [ny_, 0.9, 1.3], [0.05, 0.035, 0.03])
    above = v <= ny_
    inner = np.where(above, uR - sw, u_h - bw) + wander * 0.5
    outer = np.where(above, uR + 1, u_h + bw)
    shadow_face = smoothstep(0.005, -0.005, u - u_shadow)
    band = smoothstep(-0.005, 0.005, u - inner) * smoothstep(0.005, -0.005, u - outer) * smoothstep(0.06, 0.12, v)
    north_face = smoothstep(-0.005, 0.005, u - outer) * (1 - above)
    horn_rock = smoothstep(0.012, -0.012, v - horn)
    east_face = (1 - shadow_face) * (1 - band) * (1 - north_face)

    # Streaks: noise smeared down each face's fall line (left face and east face down to the left, the band and the
    # north face down to the right), and ledges across the faces.
    lean_face = 0.6 * shadow_face + 0.4 * east_face - 0.3 * band - 0.6 * north_face
    angle = np.pi / 2 + 0.95 * lean_face
    streak = mt.lic(fbm(h, w, rng, base=60 * k, octaves=2), angle, max(8, int(0.22 * height)), step=1.0)
    streak = (streak - streak.mean()) / (streak.std() + 1e-9)
    ledge = sheared_noise(h, w, rng, 7 * k, 4.0, -0.15, Y, octaves=3)
    grain = fbm(h, w, rng, base=30 * k, octaves=3)

    s_east = smoothstep(0.34, 0.5, 0.5 + 0.3 * streak + 0.14 * ledge + 0.45 * (v - 0.3) + 0.04 * grain)
    east = 0.58 + 0.04 * grain + (0.94 - 0.58) * s_east - 0.06 * smoothstep(0.08, 0.0, u - u_shadow)
    s_left = smoothstep(0.62, 0.8, 0.5 + 0.28 * ledge + 0.22 * streak + 0.3 * (v - 0.55))
    left = 0.19 + 0.03 * grain + 0.03 * v + (0.34 - 0.19) * s_left
    s_band = smoothstep(0.66, 0.84, 0.5 + 0.3 * streak + 0.2 * ledge + 0.2 * (v - 0.5))
    band_v = 0.36 + 0.04 * grain + (0.56 - 0.36) * s_band
    # The crest of the summit ridge catches the light: a lit edge along the skyline down to the notch.
    rim = max(0.015, 1.6 * SS / height)                                     # at least 1.6 pt wide
    crest_rim = smoothstep(rim * 1.5, rim * 0.5, uR - u) * smoothstep(0.02, 0.06, v) * smoothstep(ny_ + 0.03, ny_ - 0.02, v)
    band_v = band_v + (0.74 + 0.04 * grain - band_v) * crest_rim
    s_north = smoothstep(0.34, 0.52, 0.5 + 0.28 * streak + 0.14 * ledge + 0.4 * (v - 0.72))
    north = 0.6 + 0.03 * grain + (0.95 - 0.6) * s_north
    face = east * east_face + left * shadow_face + band_v * band + north * north_face
    s_horn = smoothstep(0.7, 0.86, 0.5 + 0.3 * ledge + 0.25 * streak)
    horn_v = np.where(u > u_shadow, 0.64, 0.2) + 0.04 * grain + 0.12 * s_horn * (u > u_shadow)
    horn_v = horn_v + (0.78 - horn_v) * smoothstep(rim * 1.5, rim * 0.5, uR - u) * (u > u_shadow)
    face = face + (horn_v - face) * horn_rock
    snow_lit = (s_east * east_face + s_north * north_face) * (1 - horn_rock)
    value = base + (face - base) * pyramid
    snow_out = base_snow + (snow_lit - base_snow) * pyramid
    # Mist gathers at the foot of the pyramid.
    if mist is not None:
        d0, d1, amount = mist
        m = amount * smoothstep(d0, d1, v) * (0.75 + 0.25 * fbm(h, w, rng, base=4 * k, octaves=3, stretch=3.0))
        value = value + (haze_v - value) * m
        snow_out *= 1 - m
    lean = base_nx + (lean_face - base_nx) * pyramid
    # Crisp: the edge of the shadow and the edges of the dark band (the skyline is kept crisp by the land mask).
    line = max(0.014, 1.4 * SS / height)                                    # at least 1.4 pt either side
    edge = lambda d: smoothstep(line, 0.0, np.abs(d))
    keep = (edge(u - u_shadow) * smoothstep(0.0, 0.04, v) * (v < 0.95)
            + edge(u - inner) * smoothstep(0.1, 0.16, v) * (v < 1.15)
            + edge(u - outer) * (1 - above) * (v < 1.15)) * pyramid
    return value, cover, snow_out * cover, lean, np.clip(keep, 0, 1)


# MARK: Hero geometry (points; mirrored in OCCanvas.hero and CoverCanvas.hero)
# Each glyph stands beside the summit, its foot behind the Matterhorn's flank or shoulder.
# kind: "digits" -> (center x of the advance box, baseline y, font size for one digit, font size for two);
#       "quote"  -> (left x of the ink, top y of the ink, font size)

HEROES = {
    "day-large": ("digits", 248, 192, 212, 168),
    "day-medium": ("digits", 118, 104, 112, 84),
    "day-small": ("digits", 116, 102, 110, 82),
    "quote-large": ("quote", 14, 24, 400),
    "quote-medium": ("quote", 14, 20, 176),
    "quote-small": ("quote", 10, 12, 170),
}


def hero_mask(name, w, h, text):
    """The hero glyph as SwiftUI places it, for previews (1 px per point)."""
    kind = HEROES[name]
    if kind[0] == "digits":
        _, cx, base, f1, f2 = kind
        size, index = (f1 if len(text) == 1 else f2), 0
        x = cx - 0.25 * size * len(text)   # tabular digits: half an em each, centred on cx
        y = base
    else:
        _, left, top, size = kind
        index, text = 2, "“"
        x = left - 0.14 * size   # the italic quote's ink starts 0.14 em in
        y = top + 0.66 * size    # and rises 0.66 em above the baseline
    img = Image.new("L", (w * 4, h * 4), 0)
    big = ImageFont.truetype(BASKERVILLE, size * 4, index=index)
    ImageDraw.Draw(img).text((x * 4, y * 4), text, font=big, fill=255, anchor="ls")
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


# MARK: Layers

def puff(w, h, rng, cx, cy, width, height, sun):
    """A small flattened cumulus drifting in front of the hero (painted at SS): a low dome of billows lit from the
    sun, its ragged edge thinning to vapour. Returns value, coverage (0..1), lit and stroke angle."""
    value, cover, lit, tangent, _ = om.cumulus(w, h, rng, [(cx, cy, width, height, 34)], sun, billow=0.8, flow=3.0)
    cover = cover * smoothstep(-0.8, 0.6, fbm(h, w, rng, base=14, octaves=3, stretch=2.0) + 1.4 * cover - 0.3)
    return np.clip(value + 0.06, 0, 1), cover, lit, tangent


def cover_painting(name, w, h, seed, sun, horizon, clouds, back, drifts, front, foreground, trees, sky=None,
                   contrast=1.3, ground_dark=(0.62, 1.0, 0.35), forest=None):
    """A value study in depth layers at SS times the widget's size, painted and filtered to 1 px per point.
    back: ranges behind the hero; front: ranges in front of it (dicts for Old Master's mountain(), with crest keys, or
    {"matterhorn": (sx, sy, height pt)} for the traced Matterhorn); foreground: the near range that becomes the dark
    ground; trees: [(range index into back+front+[foreground], height pt, spacing pt, coverage,
    value)], in front when their range is; forest: (x0, x1) fractions of a dark fir wall filling the right side.
    Returns value, glow, front mask (0..1)."""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    V, angle = om.sky_field(w, h, rng, sun, horizon, **(sky or {}))
    glow = np.zeros((h, w))
    for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
        if not layer:
            continue
        cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, sun)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit * 0.9
        angle = np.where(ccover > 0.3, ctan, angle)

    land = np.zeros((h, w))
    lean = np.zeros((h, w))
    fmask = np.zeros((h, w))
    keep = np.zeros((h, w))
    crests = []
    ranges = [(r, False) for r in back] + [(r, True) for r in front] + [(foreground, True)]
    for i, (r, is_front) in enumerate(ranges):
        r = dict(r)
        if "matterhorn" in r:
            sx, sy, height = r.pop("matterhorn")
            cy = view_crest(w, h, sx, sy, height * SS)
        else:
            cy = om.crest(r.pop("keys"), r.pop("seed"), w, h, r.pop("roughness", 0.22))
        crests.append(cy)
        if i == len(back):
            # The drifting puffs hang between the hero and the mountain: in front of the glyph, behind the land.
            for d in drifts:
                dv, dcover, dlit, dtan = puff(w, h, rng, *d[:4], sun=sun)
                alpha = d[4]
                V = V + (dv - V) * dcover
                glow = glow * (1 - dcover) + dlit * dcover * 0.6
                angle = np.where(dcover > 0.3, dtan, angle)
                fmask = np.maximum(fmask, dcover * alpha)
        if "tone" in r:
            v, cover, snow_lit, nx = om.mountain(w, h, rng, cy, r.pop("tone"), r.pop("light", (-0.55, -0.6, 0.6)), **r)
            keep *= 1 - cover  # a nearer range covers the lines it passes in front of
        else:
            v, cover, snow_lit, nx, crisp = matterhorn(w, h, rng, cy, sx, sy, height * SS, **r)
            keep = np.maximum(keep * (1 - cover), crisp)
        V = V + (v - V) * cover
        glow = glow * (1 - cover) + snow_lit * cover
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + nx * cover
        fmask = fmask * (1 - cover) + (cover if is_front else 0)
        ground = cover
    # The ground: the foreground deepens toward the bottom of the canvas, so type rests on a quiet dark passage.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    g0, g1, amount = ground_dark
    V = V * (1 - amount * smoothstep(g0 * h, g1 * h, yy) * land)

    tree_mask = np.zeros((h, w))
    for which, height, spacing, coverage, tone in trees:
        m = om.firs(w, h, rng, crests[which], height, spacing, coverage)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        V = V + (tone - V) * m + 0.10 * rimlight * (1 - m * 0.5)
        glow *= 1 - m
        land = np.maximum(land, m)
        tree_mask = np.maximum(tree_mask, m)
        if ranges[which][1]:
            fmask = np.maximum(fmask, m)

    if forest is not None:
        fm, fv = fir_wall(w, h, rng, *forest)
        V = V + (fv - V) * fm
        glow *= 1 - fm
        land = np.maximum(land, fm)
        tree_mask = np.maximum(tree_mask, fm * smoothstep(0.9, 1.0, fm))
        fmask = np.maximum(fmask, fm)
        lean = lean * (1 - fm)

    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    k = pw * ph / (348 * 365)
    s = SS
    # Each pass loads its brush from its own side of the skyline (the other side filled in from nearby values), so
    # dark sky is never dragged across a snowy crest, nor snow into the sky.
    solid = (land > 0.5).astype(np.float64)
    sky_field = within(V, 1 - solid, 6 * SS)
    land_field = within(V, solid, 6 * SS)
    field = np.stack([sky_field] * 3, axis=2)
    sky_out = mt.paint(field, angle, rng, [(int(380 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                                           (int(1300 * k), (3 * s, 5.5 * s), (7 * s, 18 * s)),
                                           (int(2400 * k), (1.4 * s, 2.6 * s), (4 * s, 9 * s)),
                                           (int(3200 * k), (0.7 * s, 1.2 * s), (3 * s, 7 * s))], 0.03)
    field = np.stack([land_field] * 3, axis=2)
    land_out = mt.paint(field, angle, rng, [(int(500 * k), (4 * s, 8 * s), (6 * s, 14 * s)),
                                            (int(1600 * k), (2 * s, 4 * s), (4 * s, 9 * s)),
                                            (int(2400 * k), (1.2 * s, 2.2 * s), (2.5 * s, 6 * s)),
                                            (int(2600 * k), (0.7 * s, 1.1 * s), (2 * s, 4 * s))], 0.04)
    out = sky_out * (1 - land[..., None]) + land_out * land[..., None]
    out = gaussian_filter(out[..., 0], 0.4 * s)
    # The Matterhorn's drawing (the edge of its shadow, the Hornli ridge) laid back over the strokes, crisp.
    out = out + (gaussian_filter(V, 0.5 * s) - out) * gaussian_filter(keep, 0.5 * s) * 0.85
    out = out + (np.minimum(out, V) - out) * gaussian_filter(tree_mask, 0.5 * s) * 0.7
    # The near ground keeps its darkness: no light stroke from the peak above lands on it.
    out = out + (np.minimum(out, V + 0.04) - out) * gaussian_filter(ground, 0.5 * s)
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
    fmask = gaussian_filter(fmask, 0.35 * s)
    return om.down(out), om.down(glow), om.down(fmask)


def within(V, mask, sigma):
    """V inside the mask; outside it, the mask's nearby values (a normalised blur), so strokes loaded there carry the
    colour of the region they belong to."""
    num = gaussian_filter(V * mask, sigma)
    den = gaussian_filter(mask, sigma)
    far = gaussian_filter(V * mask, sigma * 6) / np.maximum(gaussian_filter(mask, sigma * 6), 1e-6)
    fill = np.where(den > 0.02, num / np.maximum(den, 1e-6), far)
    return V * mask + fill * (1 - mask)


def fir_wall(w, h, rng, x0, x1):
    """A wall of near firs filling the canvas right of an edge that wanders between x0 and x1 (fractions): three
    ranks of tall spires climbing a steep slope, the outer rank hazed and rim-lit against the sky, the inner ranks
    darker until they merge into the dark wood the type is set on. Returns mask, value."""
    # x of the edge for every row: a crest turned on its side.
    edge = om.crest([(0, x0), (0.3, x1), (0.6, x0 + 0.4 * (x1 - x0)), (1, x1)], int(rng.integers(1000)), h, w, 0.18)
    xx = np.mgrid[0:h, 0:w][1].astype(np.float64)
    mask = np.zeros((h, w))
    value = np.zeros((h, w))
    unit = h / (164 * SS)  # tree sizes in points of a 164 pt tall canvas
    for rank, (tone, inset, size) in enumerate([(0.3, -6, (50, 80)), (0.16, 12, (70, 110)), (0.08, 30, (90, 140))]):
        img = Image.new("L", (w * 2, h * 2), 0)
        d = ImageDraw.Draw(img)
        y = -60.0 * SS * unit
        while y < h:
            hh = rng.uniform(*size) * SS * unit
            base = y + hh
            row = int(np.clip(base - hh * 0.5, 0, h - 1))
            x = edge[row] + (inset + rng.uniform(-4, 6)) * SS * unit + hh * 0.12
            d.polygon([(px * 2, py * 2) for px, py in om.fir(x, base, hh, rng)], fill=255)
            y += hh * rng.uniform(0.28, 0.42)
        m = np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
        solid = smoothstep(edge[:, None] + (inset + 16) * SS * unit, edge[:, None] + (inset + 26) * SS * unit, xx)
        m = np.maximum(m, solid)
        rim = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)
        tex = 0.012 * fbm(h, w, rng, base=10, octaves=3, stretch=0.4)
        value = value * (1 - m) + (tone + tex + 0.16 * rim * (1 - rank / 2)) * m
        mask = np.maximum(mask, m)
    return mask, value


def gilt(w, h, seed):
    """Brushed hollows for the gilt of the hero glyph: long soft strokes on a slight diagonal, faint bristle marks."""
    rng = np.random.default_rng(seed)
    angle = -0.5 + 0.25 * fbm(h, w, rng, base=2, octaves=2)
    tone = 0.5 + 0.18 * fbm(h, w, rng, base=4, octaves=4, persistence=0.5)
    out = mt.paint(np.stack([tone] * 3, axis=2), angle, rng, [(900, (6, 12), (20, 50)), (2200, (2, 5), (10, 26))], 0.06)
    out = gaussian_filter(out[..., 0], 0.7)
    out = out + mt.bristles(h, w, rng, angle, 0.035)
    a = np.clip((0.56 - out) * 3.0, 0, 1)
    return a


# MARK: The canvases (fractions of the widget)

def p(x, y):
    return (x, y)


LIGHT = (0.55, -0.6, 0.6)   # from the upper right, as on the Matterhorn in the photograph
MID = dict(tone=0.24, haze=0.05, haze_v=0.62, roughness=0.3, contrast=1.0, light=LIGHT)
NEAR = dict(tone=0.13, contrast=0.45, roughness=0.3, gully=0.2, light=LIGHT)


def r_(d, **kw):
    out = dict(d)
    out.update(kw)
    return out


# How the Matterhorn is framed on each canvas: its summit at (x, y) (fractions of the widget) and the height of the
# pyramid in points (summit to the foot of the left face). The traced skyline keeps its shape at one scale; only these
# three numbers are chosen. The summit and its hook stand in open sky, beside the hero glyph, and the shoulder runs
# down in front of the glyph's foot.
FRAMES = {
    "day-large": (0.3, 0.125, 145),
    "day-medium": (0.12, 0.25, 70),
    "day-small": (0.25, 0.22, 62),
    "quote-large": (0.56, 0.1, 140),
    "quote-medium": (0.25, 0.25, 70),
    "quote-small": (0.58, 0.07, 66),
}


def matterhorn_ranges(name, mid, seed):
    """The Matterhorn and, in front of its foot, a lower ridge (keys) wading in the mist; nothing behind the hero but
    sky, so the peak stands alone as it does above Zermatt."""
    return [], [dict(matterhorn=FRAMES[name]), r_(MID, keys=mid, seed=seed, mist=(6, 20, 0.3))]


def day_large():
    # The Matterhorn left of centre, its summit high in open sky; the numeral stands on the right, 168..212 pt, its
    # foot behind the shoulder; a dark bank behind the numeral and the lit ridge, pale sky behind the shadowed face.
    back, front = matterhorn_ranges("day-large", [p(0, 0.545), p(0.2, 0.55), p(0.45, 0.565), p(0.7, 0.57),
                                                  p(1, 0.56)], 23)
    return cover_painting("day-large", 348, 365, 501, sun=(0.86, 0.02), horizon=0.56,
                          sky=dict(dark_top=0.22, bright=0.74, low=0.64),
                          clouds=[(0.0, 0.1, 0.4, 0.1, 34, 0.6), (1.0, 0.1, 0.5, 0.12, 34, 0.55),
                                  (0.7, 0.56, 0.66, 0.42, 100, 0.5),
                                  (0.04, 0.46, 0.3, 0.18, 40), (0.97, 0.5, 0.2, 0.12, 30)],
                          back=back, drifts=[(0.86, 0.24, 0.2, 0.05, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.585), p(0.12, 0.59), p(0.3, 0.595), p(0.5, 0.6),
                                                    p(0.7, 0.595), p(0.9, 0.59), p(1, 0.585)], seed=31),
                          trees=[(2, (7, 16), 5.5, 0.5, 0.07)], ground_dark=(0.59, 1.0, 0.4))


def day_medium():
    # Left half: the Matterhorn at the left edge, the numeral right of its summit with its foot behind the shoulder,
    # the weather line on the dark strip below. Right half: a wall of dark firs, the ground the tasks are set on.
    back, front = matterhorn_ranges("day-medium", [p(0, 0.76), p(0.15, 0.77), p(0.3, 0.79), p(0.5, 0.8),
                                                   p(1, 0.8)], 41)
    return cover_painting("day-medium", 348, 164, 503, sun=(0.46, -0.04), horizon=0.7,
                          sky=dict(dark_top=0.14, bright=0.66, low=0.64),
                          clouds=[(0.37, 0.74, 0.3, 0.62, 70, 0.55), (0.0, 0.66, 0.16, 0.2, 24)],
                          back=back, drifts=[(0.44, 0.22, 0.12, 0.08, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.82), p(0.06, 0.84), p(0.16, 0.85), p(0.3, 0.84),
                                                    p(0.42, 0.85), p(1, 0.84)], seed=47),
                          trees=[(2, (8, 16), 5.5, 0.5, 0.07)], forest=(0.47, 0.5), ground_dark=(0.8, 1.0, 0.35))


def day_small():
    # The Matterhorn on the left, the numeral beside its summit on the right, its foot behind the shoulder; "NOV" and
    # the temperature in the dark upper corners; the dark ground from 0.71 down carries the first task.
    back, front = matterhorn_ranges("day-small", [p(0, 0.62), p(0.3, 0.64), p(0.6, 0.66), p(1, 0.66)], 53)
    return cover_painting("day-small", 164, 164, 505, sun=(0.82, -0.04), horizon=0.62,
                          sky=dict(dark_top=0.14, bright=0.68, low=0.64),
                          clouds=[(0.0, 0.1, 0.3, 0.1, 24, 0.6), (1.0, 0.12, 0.44, 0.16, 26, 0.55),
                                  (0.74, 0.66, 0.6, 0.5, 60, 0.5), (0.02, 0.58, 0.2, 0.14, 26)],
                          back=back, drifts=[(0.9, 0.3, 0.26, 0.08, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.71), p(0.2, 0.72), p(0.5, 0.725), p(0.8, 0.72), p(1, 0.71)],
                                        seed=57),
                          trees=[(2, (6, 12), 5.0, 0.5, 0.07)], ground_dark=(0.7, 1.0, 0.4))


def quote_large():
    # The opening quote hangs top left; the Matterhorn rises right of it, its left face crossing the second mark's
    # foot and its shoulder running out at the right edge; the headline runs on the dark ground below 0.5.
    back, front = matterhorn_ranges("quote-large", [p(0, 0.45), p(0.3, 0.46), p(0.6, 0.475), p(1, 0.47)], 61)
    return cover_painting("quote-large", 348, 365, 507, sun=(0.86, 0.06), horizon=0.46,
                          sky=dict(dark_top=0.2, bright=0.78, low=0.56),
                          clouds=[(0.0, 0.12, 0.6, 0.14, 44, 0.55), (0.3, 0.44, 0.62, 0.3, 90, 0.45),
                                  (0.98, 0.42, 0.3, 0.2, 60, 0.5), (0.98, 0.2, 0.2, 0.08, 24)],
                          back=back, drifts=[(0.36, 0.2, 0.26, 0.05, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.47), p(0.14, 0.485), p(0.3, 0.495), p(0.5, 0.5), p(0.7, 0.495),
                                                    p(0.86, 0.485), p(1, 0.475)], seed=71),
                          trees=[(2, (10, 22), 6.0, 0.5, 0.07)], ground_dark=(0.5, 0.95, 0.42))


def quote_medium():
    # Left: the opening quote, the Matterhorn rising past its second mark. Right: the fir wall under the headline.
    back, front = matterhorn_ranges("quote-medium", [p(0, 0.8), p(0.15, 0.81), p(0.3, 0.83), p(1, 0.83)], 83)
    return cover_painting("quote-medium", 348, 164, 509, sun=(0.12, -0.1), horizon=0.7,
                          sky=dict(dark_top=0.12, bright=0.6, low=0.64),
                          clouds=[(0.0, 0.1, 0.24, 0.12, 22, 0.55), (0.4, 0.62, 0.3, 0.3, 40, 0.5),
                                  (0.02, 0.7, 0.14, 0.2, 24)],
                          back=back, drifts=[(0.1, 0.44, 0.14, 0.07, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.86), p(0.1, 0.88), p(0.22, 0.87), p(0.36, 0.88), p(1, 0.87)],
                                        seed=87),
                          trees=[(2, (8, 16), 5.5, 0.5, 0.07)], forest=(0.43, 0.46), ground_dark=(0.8, 1.0, 0.35))


def quote_small():
    # The opening quote top left, the Matterhorn's summit right of its second mark; the quote on the dark ground
    # below 0.5.
    back, front = matterhorn_ranges("quote-small", [p(0, 0.45), p(0.4, 0.46), p(1, 0.47)], 93)
    return cover_painting("quote-small", 164, 164, 511, sun=(0.92, 0.0), horizon=0.46,
                          sky=dict(dark_top=0.14, bright=0.7, low=0.64),
                          clouds=[(0.0, 0.12, 0.5, 0.16, 26, 0.5), (0.98, 0.42, 0.4, 0.3, 40, 0.5)],
                          back=back, drifts=[(0.24, 0.37, 0.3, 0.06, 0.5)], front=front,
                          foreground=r_(NEAR, keys=[p(0, 0.5), p(0.2, 0.515), p(0.5, 0.52), p(0.8, 0.515), p(1, 0.5)],
                                        seed=97),
                          trees=[(2, (7, 15), 5.0, 0.5, 0.07)], ground_dark=(0.5, 0.95, 0.4))


# MARK: Preview

def preview(folder, name, value, glow, front):
    """Day-palette composite: painting, the hero glyph in gilt, the painting again through the front mask."""
    h, w = value.shape
    c0, c1, c2 = hexrgb(0x24170F), hexrgb(0xEEDDC2), hexrgb(0xF6CF98)

    def tint(v, g):
        rgb = mix(np.ones(v.shape + (3,)) * c0, np.ones(v.shape + (3,)) * c1, v)
        return mix(rgb, np.ones(v.shape + (3,)) * c2, g * 0.6)

    base = tint(value, glow)
    tiles = []
    texts = ["3", "28", "11"] if HEROES[name][0] == "digits" else ["“"]
    for text in texts:
        m = hero_mask(name, w, h, text)
        yy = np.mgrid[0:h, 0:w][0] / h
        gold = mix(np.ones((h, w, 3)) * hexrgb(0xF6E7CB), np.ones((h, w, 3)) * hexrgb(0xC99A66), np.clip(yy * 1.6, 0, 1))
        halo = gaussian_filter(m, 4)
        img = base * (1 - 0.45 * halo[..., None])
        img = mix(img, gold, m)
        img = mix(img, base, front)
        tiles.append(img)
    out = np.concatenate(tiles, axis=1)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize((out.shape[1] * 2, out.shape[0] * 2),
                                                                          Image.BICUBIC).save(os.path.join(folder, f"pv-{name}.png"))


def main():
    if "--trace" in sys.argv:
        profile_from_trace(sys.argv[sys.argv.index("--trace") + 1])
        return
    pv = None
    if "--preview" in sys.argv:
        pv = sys.argv[sys.argv.index("--preview") + 1]
    only = [a for a in sys.argv[1:] if not a.startswith("--") and a != pv]
    jobs = {"day-large": day_large, "day-medium": day_medium, "day-small": day_small,
            "quote-large": quote_large, "quote-medium": quote_medium, "quote-small": quote_small}
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
    if not only or "gilt" in only:
        save_alpha("gilt", gilt(348, 365, 521))
    if not only or "veil" in only:
        save_alpha("veil", om.veil(348, 220, 523))


if __name__ == "__main__":
    main()
