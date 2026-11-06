#!/usr/bin/env python3
"""Topo Survey terrain generator for the Topo mock.

For every widget sheet it builds one heightfield and derives from it, so raster and vector always agree:
  * Textures/topo/<sheet>.png   paper (fibres, mottling, foxing, fold creases, soiled edges), Swiss-style hillshade,
                                 woodland tint and lake fill, at 1 px per point (WidgetKit-safe sizes)
  * Sources/Topo/TopoData.swift  the crisp linework drawn in Canvas: contours (index every 5th), shoreline and
                                 water lining, streams, elevation labels, spot heights, woodland tree symbols
  * Textures/topo/wallpaper.png  a large olive relief model for the home-screen board (2 px per point)

Run: python3 make.py            (--no-wall skips the wallpaper; --preview writes 3x previews into $TOPO_PREVIEW)
Deterministic: every random draw comes from a seeded numpy Generator.
"""
import base64
import math
import os
import sys
from pathlib import Path

import contourpy
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
SWIFT_OUT = HERE.parent.parent / "Sources" / "Topo" / "TopoData.swift"
S = 2  # heightfield samples per point

# ----------------------------------------------------------------------------------------------------------------
# Sheets. Coordinates are points in the widget, origin top-left. `zones` are text areas: no labels or tree symbols
# are placed there and the Swift side softens the contours under them (a map's label knockout).
# ----------------------------------------------------------------------------------------------------------------
SHEETS = [
    dict(name="day-large", size=(348, 365), seed=7,
         features=[("peak", 176, 44, 1.00, 56), ("peak", 104, 14, 0.55, 40), ("peak", 276, 26, 0.66, 46),
                   ("ridge", 20, 40, 330, 50, 0.30, 52), ("ridge", 176, 44, 214, 150, 0.20, 26),
                   ("peak", 196, 262, 0.13, 30), ("peak", 84, 214, 0.08, 34),
                   ("tilt", 0.00, -0.18), ("basin", 244, 360, 0.34, 56)],
         base=0.10, rough=0.20, warp=12, lake=(244, 352, 0.05), e0=1180, escale=1500, ci=40,
         streams=[[(214, 92), (236, 160), (262, 236), (250, 296), (246, 330)]],
         woods=0.05, wood_band=(0.12, 0.62),
         zones=[(16, 14, 150, 112), (196, 14, 334, 118), (14, 122, 334, 164), (16, 166, 300, 346)],
         creases=[("v", 222), ("h", 176)], spots=2, labels=6),
    dict(name="day-medium", size=(348, 164), seed=21,
         features=[("peak", 108, 58, 1.00, 42), ("peak", 40, 4, 0.50, 34), ("ridge", 108, 58, 90, 160, 0.30, 26),
                   ("ridge", 10, 20, 200, 30, 0.30, 34), ("tilt", -0.25, -0.15), ("basin", 300, 158, 0.55, 36)],
         base=0.16, rough=0.20, warp=10, lake=(300, 150, 0.06), e0=1320, escale=1400, ci=40,
         streams=[[(124, 92), (176, 126), (230, 138), (276, 146)]],
         woods=0.0, wood_band=(0.10, 0.55),
         zones=[(14, 12, 98, 96), (14, 104, 122, 150), (122, 12, 334, 126)],
         creases=[("v", 238)], spots=1, labels=4),
    dict(name="day-small", size=(164, 164), seed=33,
         features=[("peak", 112, 52, 1.00, 38), ("peak", 150, 14, 0.55, 30), ("ridge", 112, 52, 24, 86, 0.30, 22),
                   ("tilt", 0.0, -0.20), ("basin", 154, 160, 0.25, 34)],
         base=0.14, rough=0.20, warp=8, lake=(158, 160, 0.03), e0=1260, escale=1300, ci=40,
         streams=[[(118, 78), (128, 118), (150, 150)]],
         woods=0.05, wood_band=(0.10, 0.50),
         zones=[(14, 12, 150, 66), (14, 92, 150, 150)],
         creases=[("h", 84)], spots=1, labels=2),
    dict(name="quote-large", size=(348, 365), seed=45,
         features=[("peak", 62, 22, 0.85, 46), ("peak", 180, 6, 1.00, 52), ("peak", 296, 30, 0.80, 46),
                   ("ridge", 0, 30, 348, 24, 0.35, 40), ("ridge", 300, 30, 340, 260, 0.30, 30),
                   ("ridge", 30, 40, 10, 250, 0.25, 26),
                   ("tilt", 0.0, -0.25), ("basin", 128, 360, 0.50, 62)],
         base=0.12, rough=0.20, warp=12, lake=(128, 350, 0.06), e0=1450, escale=1600, ci=40,
         streams=[[(336, 70), (334, 190), (318, 296), (240, 330), (176, 340), (146, 350)]],
         woods=0.1, wood_band=(0.10, 0.55),
         zones=[(24, 60, 324, 296), (296, 312, 340, 356)],
         creases=[("v", 128), ("h", 230)], spots=2, labels=6, profile=(20, 27, 328, 33, 72),
         avoid=[(10, 16, 340, 42)]),
    dict(name="quote-medium", size=(348, 164), seed=58,
         features=[("peak", 306, 46, 1.00, 40), ("peak", 250, 4, 0.55, 30), ("ridge", 306, 46, 348, 140, 0.30, 24),
                   ("ridge", 0, 10, 348, 0, 0.25, 30), ("tilt", 0.15, -0.20), ("basin", 296, 104, 0.30, 22)],
         base=0.12, rough=0.20, warp=10, lake=(296, 104, 0.03), e0=1380, escale=1400, ci=40,
         streams=[[(276, 30), (286, 70), (294, 98)]],
         woods=0.05, wood_band=(0.10, 0.55),
         zones=[(14, 14, 272, 150), (296, 112, 340, 156)],
         creases=[("v", 158)], spots=1, labels=3),
    dict(name="quote-small", size=(164, 164), seed=64,
         features=[("peak", 46, 10, 1.00, 36), ("peak", 140, 24, 0.70, 30), ("ridge", 0, 18, 164, 20, 0.30, 26),
                   ("tilt", 0.0, -0.25), ("basin", 150, 166, 0.30, 36)],
         base=0.12, rough=0.20, warp=8, lake=(152, 164, 0.03), e0=1240, escale=1300, ci=40,
         streams=[[(64, -4), (92, 24), (128, 33), (172, 40)]],
         woods=0.05, wood_band=(0.10, 0.50),
         zones=[(14, 40, 150, 134)],
         creases=[("v", 70)], spots=1, labels=2),
]

WALL = dict(name="wallpaper", size=(780, 805), seed=99,
            features=[("peak", 200, 160, 1.0, 120), ("peak", 560, 120, 0.9, 110), ("peak", 420, 520, 0.8, 120),
                      ("peak", 120, 640, 0.7, 100), ("ridge", 80, 260, 700, 200, 0.4, 90),
                      ("ridge", 420, 520, 720, 760, 0.35, 70), ("basin", 640, 520, 0.45, 110)],
            base=0.1, rough=0.26, warp=40, nscale=2.4, lake=(650, 520, 0.05), e0=900, escale=2600, ci=60,
            streams=[[(470, 300), (520, 420), (640, 520)], [(220, 420), (420, 470), (620, 540)]], woods=0.0, wood_band=(0.1, 0.5))

PAPER = np.array([236, 225, 197], float) / 255


# ----------------------------------------------------------------------------------------------------------------
# Noise and terrain
# ----------------------------------------------------------------------------------------------------------------
def vnoise(rng, h, w, period):
    gh, gw = int(h / period) + 4, int(w / period) + 4
    g = rng.standard_normal((gh, gw))
    ys = np.arange(h) / period + 1.0
    xs = np.arange(w) / period + 1.0
    yy, xx = np.meshgrid(ys, xs, indexing="ij")
    return ndimage.map_coordinates(g, [yy, xx], order=3, mode="nearest")


def fbm(rng, h, w, period, octaves=5, gain=0.5):
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for i in range(octaves):
        out += amp * vnoise(rng, h, w, max(period / (2 ** i), 2.0))
        tot += amp
        amp *= gain
    return out / tot


def seg_dist(x, y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(x - (x0 + t * dx), y - (y0 + t * dy))


def build_terrain(spec, rng, scale=S):
    W, H = spec["size"]
    h, w = H * scale, W * scale
    yy, xx = np.mgrid[0:h, 0:w] / scale
    warp = spec.get("warp", 10)
    ns = spec.get("nscale", 1.0) * scale  # noise periods scale with the sheet
    xw = xx + fbm(rng, h, w, 70 * ns, 3) * warp
    yw = yy + fbm(rng, h, w, 70 * ns, 3) * warp
    z = np.full((h, w), spec.get("base", 0.1))
    for f in spec["features"]:
        k = f[0]
        if k == "peak":
            _, px, py, ph, pr = f
            d = np.hypot(xw - px, yw - py) / pr
            z += ph * np.exp(-d ** 1.5)
        elif k == "ridge":
            _, x0, y0, x1, y1, ph, pr = f
            d = seg_dist(xw, yw, x0, y0, x1, y1) / pr
            z += ph * np.exp(-d ** 2)
        elif k == "basin":
            _, px, py, depth, pr = f
            d = np.hypot(xw - px, (yw - py) * 1.25) / pr
            z -= depth * np.exp(-d ** 2)
        elif k == "tilt":
            _, a, b = f
            z += a * xx / W + b * yy / H
    # ridged detail: spurs and gullies, stronger on the high ground
    ridged = 1 - np.abs(fbm(rng, h, w, 46 * ns, 4))
    hi = np.clip((z - z.min()) / (np.ptp(z) + 1e-9), 0, 1)
    z += spec.get("rough", 0.2) * (ridged ** 2 - 0.4) * (0.06 + 0.94 * hi ** 1.4)
    z += 0.025 * fbm(rng, h, w, 18 * ns, 3) * hi
    z += 0.05 * fbm(rng, h, w, 130 * ns, 2)  # gentle roll on the lowland
    return ndimage.gaussian_filter(z, 0.9 * scale)


def stream_path(ctrl, rng):
    """Catmull-Rom through the control points at about 1 pt steps, with a small seeded meander."""
    c = np.asarray(ctrl, float)
    c = np.vstack([c[:1] * 2 - c[1:2], c, c[-1:] * 2 - c[-2:-1]])
    pts = []
    for i in range(1, len(c) - 2):
        p0, p1, p2, p3 = c[i - 1], c[i], c[i + 1], c[i + 2]
        n = max(int(np.hypot(*(p2 - p1))), 2)
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            pts.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    pts.append(c[-2])
    p = np.array(pts)
    tang = np.gradient(p, axis=0)
    nrm = np.stack([-tang[:, 1], tang[:, 0]], 1) / (np.hypot(tang[:, 0], tang[:, 1])[:, None] + 1e-9)
    s = np.arange(len(p))
    wob = 1.6 * np.sin(s / 7.0 + rng.uniform(0, 6)) + 0.9 * np.sin(s / 3.1 + rng.uniform(0, 6))
    return p + nrm * wob[:, None] * np.clip(s / 12, 0, 1)[:, None]


# ----------------------------------------------------------------------------------------------------------------
# Polyline helpers
# ----------------------------------------------------------------------------------------------------------------
def chaikin(p, n=2, closed=False):
    for _ in range(n):
        if len(p) < 3:
            return p
        q = 0.75 * p[:-1] + 0.25 * p[1:]
        r = 0.25 * p[:-1] + 0.75 * p[1:]
        mid = np.empty((2 * len(q), 2))
        mid[0::2], mid[1::2] = q, r
        p = mid if closed else np.vstack([p[:1], mid, p[-1:]])
    return p


def simplify(p, tol):
    if len(p) < 3:
        return p
    keep = np.zeros(len(p), bool)
    keep[0] = keep[-1] = True
    stack = [(0, len(p) - 1)]
    while stack:
        a, b = stack.pop()
        if b <= a + 1:
            continue
        seg = p[b] - p[a]
        L = np.hypot(*seg)
        d = p[a + 1:b] - p[a]
        if L < 1e-9:
            dist = np.hypot(d[:, 0], d[:, 1])
        else:
            dist = np.abs(d[:, 0] * seg[1] - d[:, 1] * seg[0]) / L
        i = int(np.argmax(dist))
        if dist[i] > tol:
            m = a + 1 + i
            keep[m] = True
            stack += [(a, m), (m, b)]
    return p[keep]


def length(p):
    return float(np.sum(np.hypot(*np.diff(p, axis=0).T))) if len(p) > 1 else 0.0


def contour_lines(field, level, scale=S):
    h, w = field.shape
    gen = contourpy.contour_generator(x=np.arange(w) / scale, y=np.arange(h) / scale, z=field,
                                      line_type=contourpy.LineType.Separate)
    return gen.lines(level)


def in_zones(x, y, zones, pad=0):
    for (x0, y0, x1, y1) in zones:
        if x0 - pad <= x <= x1 + pad and y0 - pad <= y <= y1 + pad:
            return True
    return False


# ----------------------------------------------------------------------------------------------------------------
# One sheet
# ----------------------------------------------------------------------------------------------------------------
def make_sheet(spec):
    W, H = spec["size"]
    rng = np.random.default_rng(spec["seed"])
    z = build_terrain(spec, rng)
    E = spec["e0"] + z * spec["escale"]
    h, w = E.shape
    yy, xx = np.mgrid[0:h, 0:w] / S

    # lake: the low basin around the given point, filled to a level
    lx, ly, fill = spec["lake"]
    cx, cy = int(min(max(lx * S, 0), w - 1)), int(min(max(ly * S, 0), h - 1))
    wl = E[cy, cx] + fill * spec["escale"]
    lab, _ = ndimage.label(E < wl)
    lake = lab == lab[cy, cx] if E[cy, cx] < wl else np.zeros_like(E, bool)

    # streams, carved into the terrain so contours crenulate upstream
    streams = []
    srng = np.random.default_rng(spec["seed"] + 500)
    for ctrl in spec.get("streams", []):
        p = stream_path(ctrl, srng)
        streams.append(p)
        dist = np.full(E.shape, 1e9)
        for a, b in zip(p[:-1:3], p[3::3]):
            dist = np.minimum(dist, seg_dist(xx, yy, a[0], a[1], b[0], b[1]))
        E -= 0.045 * spec["escale"] * np.exp(-(dist / 5.0) ** 2)
    # re-flatten the lake after carving
    E = np.where(lake, np.minimum(E, wl - 1), E)
    E = np.where(~lake & (E < wl + 2), np.maximum(E, wl + 2), E) if lake.any() else E

    zones = spec.get("zones", [])
    ci = spec["ci"]
    lines = []  # (kind, points) kinds: 0 contour, 1 index contour, 2 shoreline, 3.. water lining, 9 stream
    first = math.ceil((wl + 3) / ci) * ci if lake.any() else math.ceil(E.min() / ci) * ci
    index_lines = []
    for lv in np.arange(first, E.max(), ci):
        is_index = int(round(lv)) % (5 * ci) == 0
        for seg in contour_lines(E, lv):
            if len(seg) < 3:
                continue
            seg = simplify(chaikin(seg, 1), 0.14)
            if length(seg) < 9:
                continue
            lines.append((1 if is_index else 0, seg))
            if is_index:
                index_lines.append((int(round(lv)), seg))

    # shoreline and water lining (lines parallel to the shore, wider apart toward open water)
    if lake.any():
        soft = ndimage.gaussian_filter(lake.astype(float), 1.2 * S)
        for seg in contour_lines(soft, 0.5):
            if len(seg) > 3:
                lines.append((2, simplify(chaikin(seg, 1), 0.1)))
        dt = ndimage.distance_transform_edt(soft > 0.5) / S
        dt = ndimage.gaussian_filter(dt, 0.8 * S)
        for i, d in enumerate([1.8, 3.4, 5.1, 7.0, 9.2, 11.8, 14.8, 18.2]):
            for seg in contour_lines(dt, d):
                if len(seg) > 3 and length(seg) > 8:
                    lines.append((3 + i, simplify(chaikin(seg, 1), 0.14)))
    for p in streams:
        lines.append((9, simplify(p, 0.06)))

    # elevation labels on index contours, upright, on straight runs, away from text and from each other
    labels = []
    cands = []
    for lv, seg in index_lines:
        d = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(seg, axis=0).T))])
        if d[-1] < 40:
            continue
        for s in np.arange(14, d[-1] - 14, 3.0):
            pa = np.array([np.interp(s - 10, d, seg[:, 0]), np.interp(s - 10, d, seg[:, 1])])
            pb = np.array([np.interp(s + 10, d, seg[:, 0]), np.interp(s + 10, d, seg[:, 1])])
            pm = np.array([np.interp(s, d, seg[:, 0]), np.interp(s, d, seg[:, 1])])
            chord = pb - pa
            straight = abs(chord[0] * (pm - pa)[1] - chord[1] * (pm - pa)[0]) / (np.hypot(*chord) + 1e-9)
            ang = math.degrees(math.atan2(chord[1], chord[0]))
            if ang > 90:
                ang -= 180
            if ang < -90:
                ang += 180
            x, y = pm
            if x < 20 or y < 16 or x > W - 20 or y > H - 16:
                continue
            if in_zones(x, y, zones + spec.get("avoid", []), pad=7) or straight > 0.9 or abs(ang) > 70:
                continue
            ix, iy = int(x * S), int(y * S)
            if lake[max(iy - 12, 0):iy + 12, max(ix - 12, 0):ix + 12].any():
                continue
            cands.append((straight + abs(ang) / 90, x, y, ang, lv))
    cands.sort()
    for c in cands:
        if len(labels) >= spec.get("labels", 4):
            break
        if all(math.hypot(c[1] - l[0], c[2] - l[1]) > 46 for l in labels):
            labels.append((c[1], c[2], c[3], c[4]))

    # spot heights: highest local maxima, outside text
    spots = []
    mx = ndimage.maximum_filter(E, size=30 * S)
    peaks = np.argwhere((E == mx) & (E > np.percentile(E, 80)))
    order = sorted(peaks.tolist(), key=lambda p: -E[p[0], p[1]])
    for iy, ix in order:
        x, y = ix / S, iy / S
        if len(spots) >= spec.get("spots", 1):
            break
        if x < 22 or x > W - 40 or y < 14 or y > H - 18 or any(in_zones(x + dx, y, zones + spec.get("avoid", []), pad=4) for dx in (0, 12, 26)):
            continue
        if all(math.hypot(x - s[0], y - s[1]) > 40 for s in spots):
            spots.append((x, y, int(round(E[iy, ix]))))

    # woodland: patchy cover on the lower and middle slopes, not in water
    en = (E - E.min()) / (np.ptp(E) + 1e-9)
    wn = fbm(rng, h, w, 56 * S, 3)
    lo, hi = spec.get("wood_band", (0.1, 0.55))
    band = np.clip((en - lo) / 0.06, 0, 1) * np.clip((hi - en) / 0.08, 0, 1)
    wood = ndimage.gaussian_filter(((wn + band * 0.4 - 0.6 + spec.get("woods", 0)) > 0).astype(float), 1.2 * S)
    wood *= ~ndimage.binary_dilation(lake, iterations=4 * S)
    wood = ndimage.gaussian_filter((wood > 0.5).astype(float), 0.35 * S)
    for seg in contour_lines(wood, 0.5):
        if len(seg) > 3 and length(seg) > 10:
            lines.append((10, simplify(chaikin(seg, 1), 0.14)))
    trees = []
    trng = np.random.default_rng(spec["seed"] + 1000)
    step = 6.5
    for gy_ in np.arange(8, H - 6, step):
        for gx_ in np.arange(8, W - 6, step):
            x = gx_ + trng.uniform(-2.2, 2.2) + (step / 2 if int(gy_ / step) % 2 else 0)
            y = gy_ + trng.uniform(-2.2, 2.2)
            if x >= W - 6:
                continue
            if wood[int(y * S), int(x * S)] > 0.7 and not in_zones(x, y, zones, pad=2) and trng.random() < 0.8:
                trees.append((x, y))

    print(f"  {spec['name']}: woodland {wood.mean():.0%}, lake {lake.mean():.0%}")
    profile = None
    if "profile" in spec:
        x0, y0, x1, y1, n = spec["profile"]
        xs, ys = np.linspace(x0, x1, n) * S, np.linspace(y0, y1, n) * S
        sm = ndimage.gaussian_filter(E, 1.5 * S)
        prof = ndimage.map_coordinates(sm, [ys, xs], order=1)
        lo, hi = math.floor(prof.min() / 200) * 200 - 200, math.ceil(prof.max() / 200) * 200
        profile = ((prof - lo) / (hi - lo), lo, hi)
    img = render_raster(spec, E, lake, wood, rng)
    return dict(spec=spec, E=E, lake=lake, lines=lines, labels=labels, spots=spots, trees=trees, image=img, wl=wl,
                profile=profile)


# ----------------------------------------------------------------------------------------------------------------
# Raster: paper, relief, tints
# ----------------------------------------------------------------------------------------------------------------
def hillshade(E, scale, exag, az=315, alt=42):
    gy, gx = np.gradient(E * exag, 1.0 / scale)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    a, al = math.radians(az), math.radians(alt)
    # light from the north-west: x right, y down
    lx, ly, lz = math.cos(al) * math.cos(math.radians(225)), math.cos(al) * math.sin(math.radians(225)), math.sin(al)
    nx, ny, nz = -gx, -gy, np.ones_like(gx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx * lx + ny * ly + nz * lz) / n


def paper_layer(rng, h, w, scale):
    """Tan survey paper: mottling, fibres, a few foxing spots. Values are RGB floats."""
    mott = fbm(rng, h, w, 90 * scale, 4)
    mott2 = fbm(rng, h, w, 24 * scale, 3)
    base = np.ones((h, w, 3)) * PAPER
    base *= (1 + 0.026 * mott[..., None] + 0.012 * mott2[..., None])
    base[..., 2] *= 1 - 0.02 * np.clip(mott, 0, None)  # yellower where the paper is warmer
    grain = rng.standard_normal((h, w))
    grain = ndimage.gaussian_filter(grain, 0.5)
    base *= (1 + 0.018 * grain[..., None])
    # fibres: short curved strokes, some lighter, some darker
    fib = Image.new("L", (w, h), 128)
    d = ImageDraw.Draw(fib)
    n = int(w * h / (scale * scale) / 9)
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        L = rng.uniform(3, 11) * scale
        a = rng.uniform(0, math.pi)
        bend = rng.uniform(-0.6, 0.6)
        pts = []
        for t in np.linspace(0, 1, 6):
            aa = a + bend * t
            pts.append((x + math.cos(aa) * L * t, y + math.sin(aa) * L * t))
        val = int(128 + rng.choice([-1, 1]) * rng.uniform(10, 26))
        d.line(pts, fill=val, width=1)
    fib = np.asarray(fib.filter(ImageFilter.GaussianBlur(0.35 * scale)), float) / 128 - 1
    base *= (1 + 0.55 * fib[..., None])
    # foxing: small soft rust spots
    fox = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(max(1, int(w * h / (scale * scale) / 9000))):
        fx, fy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(1.5, 5) * scale
        fox += np.exp(-(((xx - fx) ** 2 + (yy - fy) ** 2) / (r * r))) * rng.uniform(0.3, 0.8)
    fox = np.clip(fox, 0, 1)[..., None]
    base = base * (1 - 0.12 * fox) + np.array([0.70, 0.52, 0.32]) * 0.12 * fox
    return base


def render_raster(spec, E, lake, wood, rng, out_scale=1):
    W, H = spec["size"]
    h, w = E.shape
    col = paper_layer(rng, h, w, S)
    en = (E - E.min()) / (np.ptp(E) + 1e-9)
    # hypsometric hint: valleys a little greener-grey, summits a little lighter
    col *= (1 + np.stack([-0.02, 0.0, -0.03]) * (1 - en[..., None]))
    col = col + (1 - col) * 0.10 * en[..., None] ** 2
    # woodland tint with a fine stipple
    stip = (rng.random((h, w)) < 0.08).astype(float)
    stip = ndimage.gaussian_filter(stip, 0.5)
    wood_col = np.array([0.76, 0.86, 0.62])
    wa = (0.7 * wood)[..., None]
    col = col * (1 - wa) + col * wood_col * wa
    col *= 1 - (0.12 * stip * wood)[..., None]
    # Swiss-style relief shading: violet-brown shadows, warm cream lights
    shade = hillshade(E, S, exag=1 / 180)
    flat = math.sin(math.radians(42))
    rel = shade - flat
    rel = np.sign(rel) * np.maximum(np.abs(rel) - 0.02, 0)
    sh = np.clip(-rel * 2.4, 0, 1)[..., None] ** 0.9
    li = np.clip(rel * 2.6, 0, 1)[..., None]
    shadow = np.array([0.56, 0.49, 0.52])
    col = col * (1 - sh * (1 - shadow))
    col = col + (np.array([1.0, 0.975, 0.90]) - col) * li * 0.55
    # aerial softening of deep shadow with height (gives the 3D read)
    ao = ndimage.gaussian_filter(E, 10 * S) - E
    col *= (1 - np.clip(ao / 160, -0.03, 0.08))[..., None]
    # lake: blue with deeper tone toward the middle, plus a soft dark rim
    if lake.any():
        dt = ndimage.distance_transform_edt(lake) / S
        deep = np.clip(dt / 18, 0, 1)[..., None]
        water = np.array([0.66, 0.80, 0.87]) * (1 - 0.10 * deep) + np.array([0.0, 0.0, 0.02]) * deep
        lm = ndimage.gaussian_filter(lake.astype(float), 0.6 * S)[..., None]
        wcol = PAPER * water / PAPER.mean() * 0.94 * (1 + 0.6 * (col / PAPER - 1))
        col = col * (1 - lm) + wcol * lm
    # fold creases
    yy, xx = np.mgrid[0:h, 0:w] / S
    for kind, at in spec.get("creases", []):
        d = (xx - at) if kind == "v" else (yy - at)
        flank = np.where(d < 0, 1 - 0.05 * np.exp(d / 7.0), 1 + 0.025 * np.exp(-d / 5.0))
        col *= flank[..., None]
        col *= (1 - 0.16 * np.exp(-((d + 0.7) / 0.75) ** 2))[..., None]
        col += (0.22 * np.exp(-((d - 0.7) / 0.6) ** 2))[..., None] * (1 - col)
        wear = (rng.random((h, w)) < 0.3) * np.exp(-(d / 1.8) ** 2)
        col += (0.35 * ndimage.gaussian_filter(wear.astype(float), 0.5))[..., None] * (1 - col)
    # soiled, slightly darker edges
    ex = np.minimum(xx, W - xx)
    ey = np.minimum(yy, H - yy)
    edge = np.exp(-np.minimum(ex, ey) / 9.0)
    edge *= 0.7 + 0.3 * (fbm(rng, h, w, 30 * S, 3) + 0.5)
    col *= (1 - 0.10 * edge)[..., None]
    col = np.clip(col, 0, 1)
    img = Image.fromarray((col * 255).astype(np.uint8), "RGB")
    return img.resize((W * out_scale, H * out_scale), Image.LANCZOS)


# ----------------------------------------------------------------------------------------------------------------
# Wallpaper: an olive relief model with cream contour linework, rendered at 2 px per point
# ----------------------------------------------------------------------------------------------------------------
def make_wallpaper():
    spec = WALL
    W, H = spec["size"]
    sc = 2
    rng = np.random.default_rng(spec["seed"])
    z = build_terrain(spec, rng, scale=sc)
    E = spec["e0"] + z * spec["escale"]
    h, w = E.shape
    lx, ly, fill = spec["lake"]
    cy, cx = int(ly * sc), int(lx * sc)
    wl = E[cy, cx] + fill * spec["escale"]
    lab, _ = ndimage.label(E < wl)
    lake = lab == lab[cy, cx]
    E = np.where(lake, wl - 1, E)
    en = (E - E.min()) / (np.ptp(E) + 1e-9)
    low = np.array([0.20, 0.25, 0.20])
    high = np.array([0.42, 0.40, 0.31])
    col = low * (1 - en[..., None]) + high * en[..., None]
    shade = hillshade(E, sc, exag=1 / 55)
    rel = shade - math.sin(math.radians(42))
    col *= (1 + np.clip(rel * 1.5, -0.6, 0.75))[..., None]
    col += (np.array([0.95, 0.85, 0.62]) - col) * np.clip(rel * 0.5, 0, 0.18)[..., None]
    mott = fbm(rng, h, w, 120 * sc, 4)
    col *= (1 + 0.05 * mott[..., None])
    grain = ndimage.gaussian_filter(rng.standard_normal((h, w)), 0.6)
    col *= (1 + 0.03 * grain[..., None])
    dt = ndimage.distance_transform_edt(lake) / sc
    water = np.array([0.16, 0.26, 0.30]) * (1 - 0.25 * np.clip(dt / 60, 0, 1))[..., None]
    col = np.where(lake[..., None], water, col)
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    ci = spec["ci"]
    for lv in np.arange(math.ceil((wl + 3) / ci) * ci, E.max(), ci):
        idx = int(round(lv)) % (5 * ci) == 0
        for seg in contour_lines(E, lv, scale=sc):
            if len(seg) < 3:
                continue
            seg = chaikin(seg, 1) * sc
            d.line([tuple(p) for p in seg], fill=(236, 222, 186, 105 if idx else 40), width=2 if idx else 1)
    soft = ndimage.gaussian_filter(lake.astype(float), 1.5 * sc)
    dtl = ndimage.gaussian_filter(ndimage.distance_transform_edt(soft > 0.5) / sc, 1.0 * sc)
    for i, dd in enumerate([0.1, 3, 6.5, 10.5, 15, 20, 26, 33]):
        for seg in contour_lines(dtl if i else soft, dd if i else 0.5, scale=sc):
            if len(seg) > 3:
                d.line([tuple(p) for p in chaikin(seg, 1) * sc], fill=(180, 214, 222, 150 - i * 14), width=1)
    img = Image.alpha_composite(img, over)
    # grid
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for gx in range(0, W, 120):
        d.line([(gx * sc, 0), (gx * sc, H * sc)], fill=(236, 222, 186, 34), width=1)
    for gy in range(0, H, 120):
        d.line([(0, gy * sc), (W * sc, gy * sc)], fill=(236, 222, 186, 34), width=1)
    img = Image.alpha_composite(img, over).convert("RGB")
    # vignette
    arr = np.asarray(img, float) / 255
    yy, xx = np.mgrid[0:H * sc, 0:W * sc]
    r = np.hypot((xx / (W * sc) - 0.5) * 1.1, yy / (H * sc) - 0.5)
    arr *= (1 - 0.45 * np.clip(r - 0.25, 0, 1) ** 1.4)[..., None]
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB").save(HERE / "wallpaper.png", optimize=True)


# ----------------------------------------------------------------------------------------------------------------
# Swift output
# ----------------------------------------------------------------------------------------------------------------
def enc_lines(lines):
    out = []
    for kind, p in lines:
        q = np.round(np.asarray(p) * 10).astype(np.int16)
        out += [kind, len(q)]
        out += q.reshape(-1).tolist()
    return base64.b64encode(np.array(out, dtype="<i2").tobytes()).decode()


def enc_points(pts):
    q = np.round(np.asarray(pts, float).reshape(-1, 2) * 10).astype("<i2") if pts else np.zeros((0, 2), "<i2")
    return base64.b64encode(q.tobytes()).decode()


def swift_ident(name):
    a, b = name.split("-")
    return a + b.capitalize()


def wrap(s, n=120):
    body = "\n".join("        " + s[i:i + n] for i in range(0, len(s), n))
    return '        """\n' + body + '\n        """'


def write_swift(sheets):
    out = ["// Generated by MockLab/Textures/topo/make.py. Do not edit; rerun the script.",
           "// Linework for each sheet: Int16 little-endian, points in tenths of a point.",
           "import Foundation", "", "enum TopoData {"]
    for r in sheets:
        sp = r["spec"]
        W, H = sp["size"]
        lab = ", ".join(f"TopoLabel(x: {x:.1f}, y: {y:.1f}, angle: {a:.1f}, text: \"{t}\")" for x, y, a, t in r["labels"])
        spt = ", ".join(f"TopoSpot(x: {x:.1f}, y: {y:.1f}, elevation: {e})" for x, y, e in r["spots"])
        zn = ", ".join(f"CGRect(x: {x0}, y: {y0}, width: {x1 - x0}, height: {y1 - y0})" for x0, y0, x1, y1 in sp["zones"])
        out.append(f"    static let {swift_ident(sp['name'])} = TopoSheetData(")
        out.append(f"        width: {W}, height: {H}, texture: \"topo/{sp['name']}\",")
        out.append(f"        labels: [{lab}],")
        out.append(f"        spots: [{spt}],")
        out.append(f"        zones: [{zn}],")
        out.append("        trees: ")
        out.append(wrap(enc_points(r["trees"])) + ",")
        out.append("        lines: ")
        out.append(wrap(enc_lines(r["lines"])) + ("," if r["profile"] else ""))
        if r["profile"]:
            prof, lo, hi = r["profile"]
            out.append("        profile: [" + ", ".join(f"{v:.3f}" for v in prof) + "],")
            out.append(f"        profileLow: {lo}, profileHigh: {hi}")
        out.append("    )")
    out.append("}")
    SWIFT_OUT.write_text("\n".join(out) + "\n")


def preview(r, folder):
    """3x composite of the raster and the linework, for tuning terrain without a Swift build."""
    sp = r["spec"]
    W, H = sp["size"]
    k = 3
    img = r["image"].resize((W * k, H * k), Image.BICUBIC).convert("RGBA")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for kind, p in r["lines"]:
        pts = [tuple(q * k) for q in p]
        if kind == 0:
            d.line(pts, fill=(140, 90, 45, 150), width=1)
        elif kind == 1:
            d.line(pts, fill=(120, 70, 30, 220), width=3)
        elif kind == 2:
            d.line(pts, fill=(50, 100, 150, 230), width=2)
        elif kind == 9:
            d.line(pts, fill=(50, 110, 170, 230), width=3)
        else:
            d.line(pts, fill=(60, 110, 160, max(40, 190 - (kind - 3) * 20)), width=1)
    for x, y in r["trees"]:
        d.ellipse([x * k - 4, y * k - 4, x * k + 4, y * k + 4], outline=(70, 100, 50, 200), width=2)
    for x0, y0, x1, y1 in sp["zones"]:
        d.rectangle([x0 * k, y0 * k, x1 * k, y1 * k], outline=(200, 0, 0, 90))
    for x, y, a, t in r["labels"]:
        d.text((x * k, y * k), str(t), fill=(200, 0, 0, 255))
    Image.alpha_composite(img, over).save(Path(folder) / f"preview-{sp['name']}.png")


def main():
    results = []
    for sp in SHEETS:
        r = make_sheet(sp)
        r["image"].save(HERE / f"{sp['name']}.png", optimize=True)
        results.append(r)
        print(f"{sp['name']}: {sum(len(p) for _, p in r['lines'])} pts, {len(r['labels'])} labels, "
              f"{len(r['trees'])} trees, {len(r['spots'])} spots")
    write_swift(results)
    prng = np.random.default_rng(5)
    pw, ph = 300, 240
    pap = paper_layer(prng, ph * S, pw * S, S)
    pap = pap * 1.025 + 0.01
    Image.fromarray((np.clip(pap, 0, 1) * 255).astype(np.uint8), "RGB").resize((pw, ph), Image.LANCZOS).save(HERE / "paper.png", optimize=True)
    if "--preview" in sys.argv:
        folder = os.environ.get("TOPO_PREVIEW", "/tmp")
        for r in results:
            preview(r, folder)
    if "--no-wall" not in sys.argv:
        make_wallpaper()
    print("wrote", SWIFT_OUT)


if __name__ == "__main__":
    main()
