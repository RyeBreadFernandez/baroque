#!/usr/bin/env python3
"""Baroque wallpapers: the Matterhorn from the Riffelsee side, painted as Old Master Cover oils in sepia.

Every picture is painted the way the widgets are (MockLab/Textures/old-master-cover/make.py): one grey value study,
covered with the strokes of scripts/make_textures.py (opaque strokes that follow the form, coarse to fine, then
bristle marks and light on the stroke edges), and glazed with the widgets' own three-stop gradient map (OMLight /
CoverLight in Shared/CoverPainting.swift: shadow, warm mid, light, plus the glow of the sun or moon), yellowed varnish
and fine craquelure. Old Master's helpers (MockLab/Textures/old-master/make.py, imported from its path, not copied)
give the fir shapes and the shading maths. A wallpaper has no WidgetKit size limit, so each is painted at twice the
screen and filtered down.

The mountain is the real skyline, traced from Wikimedia Commons File:Matterhorn_Riffelsee_2005-06-11.jpg and kept in
matterhorn.json (the skyline row of every column of the 1352 x 2048 photo). It is used at true proportions (one
uniform scale; a picture may crop it); the low side ridges and the near ground are simplified. Its planes are lit as
in the photo: a narrow shaded face on the left, the broad face lit with snow on its ledges, a dark cliff band under the
ridge from the summit to the right shoulder, and the shoulder's snow beyond.

How it is painted, in order:
  sky study (half size): value gradient, the luminous break, cumulus masses lit from the upper left with shadowed
      bellies and dark crevices, and any banner cloud, lenticular cap or Milky Way;
  land study (full size): the massif's planes and strata, then the near ground (the tarn's hills, a meadow, a dark
      ridge, larch and pine), then fog and mist in front;
  brushwork: big blocking strokes in the broad passages, finer ones drawn along the edges and on the lights, each
      stroke as long as its form (curling round billows, down the gullies, flat on water); shadows glazed thin over
      the strokes, lights left thick;
  the tarn: the painted picture mirrored, rippled and darkened toward the viewer, repainted with level strokes;
  after the paint: stars, falling snow, shafts of light, glints;
  glaze: the gradient map for the time of day and the palette, glow, varnish; the moon; craquelure and canvas weave
      at the screen's pixels; a gilt frame and plate when a look asks for one.

Each picture is a look in LOOKS (framing, ground, sky, effects, time, palette). Layout of the defaults, in points of
the iPhone 17 screen (402 x 874; the Pro Max's 440 x 956 is the same picture):
  0 .. 140    storm cloud: dark for the status bar          140 .. 330  calm sky round the lock-screen clock
  300 .. 487  the Matterhorn (summit at 300); the tarn at 487   487 .. 730  the reflection    730 ..  dark shore

Writes:
  screenshots/wallpaper/baroque-matterhorn-{day,night}-{1206x2622,1320x2868}.png   the default pair
  screenshots/wallpaper/variants/NN-<slug>.png (1206 x 2622), contact-sheet.jpg, variants.json
  screenshots/wallpaper/preview-home.png, preview-lock.png   (the defaults with widgets / lock-screen clock)

Run from anywhere (deterministic, no network):
  python3 MockLab/Textures/wallpaper/make.py                     the default pair, then the previews
  python3 .../make.py --no-previews                             the default pair only
  python3 .../make.py --previews-only [home] [lock]             previews from the PNGs already written
  python3 .../make.py --variants [slug or number ...]           variants (all if none named), sheet and json
  options: --draft 0.4 (paint smaller, for trying things), --out <folder>
Refresh matterhorn.json from a new trace:  python3 .../make.py --trace <skyline.json>
"""
import importlib.util
import json
import math
import os
import sys
from types import SimpleNamespace

sys.dont_write_bytecode = True  # importing Old Master's make.py (and through it scripts/) leaves no __pycache__

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter, gaussian_filter1d, map_coordinates, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
spec = importlib.util.spec_from_file_location("om_make", os.path.join(os.path.dirname(HERE), "old-master", "make.py"))
om = importlib.util.module_from_spec(spec)
spec.loader.exec_module(om)
mt = om.mt
fbm, smoothstep, hexrgb = mt.fbm, mt.smoothstep, mt.hexrgb

OUT = os.path.join(ROOT, "screenshots", "wallpaper")
WIDGETS = os.path.join(ROOT, "MockLab", "out", "old-master-cover")
SKYLINE = os.path.join(HERE, "matterhorn.json")
SIZES = [(1206, 2622), (1320, 2868)]           # iPhone 17 / 17 Pro, 17 Pro Max (both 3x)
MASTER_W = 2640                                # the defaults: twice the Pro Max width
VARIANT_W = 2412                               # the variants: twice the iPhone 17 width
SFNS = "/System/Library/Fonts/SFNS.ttf"
BASKERVILLE = "/System/Library/Fonts/Supplemental/Baskerville.ttc"


# MARK: The skyline

def copy_trace(path):
    """Copies the traced skyline next to this script, rounded to a tenth of a pixel."""
    with open(path) as f:
        src = json.load(f)
    data = {"source": src.get("source", ""), "note": src.get("note", ""), "width": src["width"],
            "height": src["height"], "summit_x": src["summit_x"], "y": [round(float(v), 1) for v in src["y"]]}
    with open(SKYLINE, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print(f"matterhorn.json: {len(data['y'])} columns, summit at x {data['summit_x']}")


if not os.path.exists(SKYLINE) and "--trace" in sys.argv:
    copy_trace(sys.argv[sys.argv.index("--trace") + 1])
    sys.exit(0)
with open(SKYLINE) as _f:
    _SK = json.load(_f)
TRACE = np.array(_SK["y"], dtype=np.float64)
SXP = float(_SK["summit_x"])
SYP = float(TRACE[_SK["summit_x"]])

DW, DH = 402.0, 874.0          # the iPhone 17 screen in points

# The pyramid's planes, in photo pixels, as the light falls in the photo: a narrow shaded face on the left (left of
# LEFT_EDGE), the broad lit face, a dark cliff band under the ridge that runs from the summit down to the right
# shoulder (right of HORNLI, which then carries on down as the ridge's rock), and the lit snow of the shoulder right
# of NORTH. SUMMIT_CAP is the foot of the bare summit rock; FOOT the foot of the pyramid on the glacier.
LEFT_EDGE = [(640, 546), (624, 590), (606, 640), (592, 690), (577, 750), (556, 810), (530, 860), (498, 905),
             (460, 950)]
HORNLI = [(650, 532), (680, 575), (704, 612), (728, 650), (750, 690), (770, 728), (788, 762), (806, 815),
          (828, 880), (852, 950), (876, 1020)]
NORTH = [(806, 750), (836, 800), (868, 848), (905, 905), (950, 960), (990, 1010)]
SUMMIT_CAP = [(560, 600), (618, 597), (660, 592), (720, 588)]
FOOT = [(-300, 930), (300, 918), (430, 898), (520, 880), (600, 872), (700, 882), (780, 905), (850, 952),
        (950, 975), (1100, 992), (1700, 1010)]
# The tarn's near hills (photo pixels): the dark rock spur on the left, the long grassy bank on the right.
LEFT_HILL = [(-400, 790), (-70, 868), (0, 885), (40, 911), (80, 932), (125, 944), (190, 975), (240, 992),
             (275, 1030), (330, 1048), (380, 1080), (430, 1110), (500, 1146), (570, 1180)]
RIGHT_HILL = [(640, 1185), (700, 1164), (760, 1141), (820, 1128), (880, 1106), (930, 1083), (975, 1078),
              (1040, 1070), (1120, 1050), (1200, 1040), (1250, 1028), (1352, 1019), (1700, 995)]

# The picture being painted: set by use(look).
G = SimpleNamespace()


def use(look):
    """Makes `look` the current picture: its framing of the Matterhorn and the level of the mountain's foot."""
    G.look = look
    G.summit = look["summit"]
    G.scale = look["scale"]
    G.f = G.scale / 0.29                                   # the mountain's size against the default framing
    G.water = G.summit[1] + (1168.0 - SYP) * G.scale       # the tarn's level (or the foot, without the tarn)
    G.lake = look["ground"] == "lake"
    G.hs = G.water + 4.0 if G.lake else DH                 # how far down the sky study runs


def photo_x(x):
    return SXP + (x - G.summit[0]) / G.scale


def photo_y(y):
    return SYP + (y - G.summit[1]) / G.scale


def pt_y(py):
    return G.summit[1] + (py - SYP) * G.scale


def keyed(xs, keys):
    kx, ky = zip(*keys)
    return np.interp(xs, kx, ky)


def massif_crest(x):
    """The traced skyline (pt) for points x; beyond the photo the far ranges run on, a little lower."""
    px = photo_x(x)
    y = np.interp(px, np.arange(len(TRACE)), TRACE)
    # Left of column 135 the trace follows the near spur; behind it the far ridge carries on at its own height.
    far_left = np.interp(135, np.arange(len(TRACE)), TRACE)
    y = np.where(px < 135, far_left + 0.02 * np.clip(135 - px, 0, None), y)
    y = np.where(px > len(TRACE) - 1, TRACE[-1] + 0.03 * (px - len(TRACE) + 1), y)
    return pt_y(y)


# MARK: Helpers

def aniso(X, Y, angle, along, across, rng, octaves=3, persistence=0.55):
    """Smooth noise on point coordinates, drawn out `along` pt in the direction `angle` and `across` pt across it:
    ledges, gullies, rock ribs, ripples. Normalised to mean 0, deviation 1. Large grids are sampled at half size."""
    if X.ndim == 2 and X.size > 1_500_000:
        h, w = X.shape
        return resize(aniso(X[::2, ::2], Y[::2, ::2], angle, along, across, rng, octaves, persistence), w, h,
                      Image.BILINEAR)
    ca, sa = np.float32(np.cos(angle)), np.float32(np.sin(angle))
    U = X * ca + Y * sa
    V = Y * ca - X * sa
    out = np.zeros(X.shape, np.float32)
    amp = 1.0
    for _ in range(octaves):
        gu, gv = U / np.float32(along), V / np.float32(across)
        u0, v0 = np.floor(gu.min()) - 2, np.floor(gv.min()) - 2
        grid_ = rng.standard_normal((int(gv.max() - v0) + 5, int(gu.max() - u0) + 5)).astype(np.float32)
        out += np.float32(amp) * map_coordinates(grid_, [gv - v0, gu - u0], order=3, mode="nearest")
        amp *= persistence
        along, across = along / 2, across / 2
    out -= out.mean()
    return out / (out.std() + 1e-9)


def resize(a, w, h, method=Image.BICUBIC):
    return np.array(Image.fromarray(np.ascontiguousarray(a, dtype=np.float32), "F").resize((w, h), method))


def resize_angle(a, w, h):
    """Stroke directions are axial (a stroke has no head), so they are resampled as doubled-angle vectors."""
    c, s = resize(np.cos(2 * a), w, h), resize(np.sin(2 * a), w, h)
    return 0.5 * np.arctan2(s, c)


def edge(d, R):
    """Coverage from a signed distance in points, antialiased over about one master pixel."""
    return smoothstep(-0.6 / R, 0.6 / R, d).astype(np.float32)


def crest_cover(Y, crest, R):
    """Coverage below a crest line (pt per column), measured across the slope so steep flanks stay crisp."""
    slope = np.gradient(crest) * R
    return edge((Y - crest[None, :]) / np.sqrt(1 + slope[None, :] ** 2), R)


def roughen(n, rng, amount, corr):
    """A crest's rock: smooth random offsets (pt) with a correlation length of `corr` samples."""
    r = gaussian_filter1d(rng.standard_normal(n), corr, mode="nearest")
    return amount * r / (r.std() + 1e-9)


def within(V, mask, sigma):
    """V inside the mask; outside it, the mask's nearby values (Old Master Cover's fill), so a stroke loaded there
    carries the colour of the region it belongs to and no sky is dragged across a crest."""
    num = gaussian_filter(V * mask, sigma)
    den = gaussian_filter(mask, sigma)
    far = gaussian_filter(V * mask, sigma * 6) / np.maximum(gaussian_filter(mask, sigma * 6), 1e-6)
    fill = np.where(den > 0.02, num / np.maximum(den, 1e-6), far)
    return (V * mask + fill * (1 - mask)).astype(np.float32)


def grid(rows, W, R):
    """Point coordinates of master rows `rows` (a range) across W columns at R px per pt."""
    y = ((np.arange(rows.start, rows.stop) + 0.5) / R).astype(np.float32)
    x = ((np.arange(W) + 0.5) / R).astype(np.float32)
    X, Y = np.meshgrid(x, y)
    return x, X, Y


# MARK: The brush

def brush(field, angle, rng, R, passes, jitter=0.03, region=None, lengths=None, wobble=0.0):
    """The brush of scripts/make_textures.py (mt.paint) on a float value field with sizes in points: each stroke
    loads the value under its start (with a little jitter), is dragged along the angle field in 2 px steps and ends in
    round caps; passes run coarse to fine.
    passes: [(coverage, (min, max width), (min, max length), where)] in pt, where `where` places the pass: "mass" in
    the broad passages (blocking in), "edge" on the edges and the lights (drawing and highlights), "any" evenly.
    Strokes start where region > 0.5 (anywhere if None). `lengths` (a map) scales each stroke to the form it starts
    on; `wobble` (radians, a map or a number) turns each stroke a little off the field, so open passages are crossed
    rather than combed."""
    h, w = field.shape
    img = Image.fromarray(np.ascontiguousarray(field, dtype=np.float32), "F")
    d = ImageDraw.Draw(img)
    k = 4
    sub = field[::k, ::k]
    ok = np.ones(sub.shape, bool) if region is None else region[::k, ::k] > 0.5
    if not ok.any():
        return np.array(img, dtype=np.float32)
    g = gaussian_filter(sub, 0.5 * R / k)
    gm = np.hypot(sobel(g, axis=0), sobel(g, axis=1))
    detail = np.clip(gm / (np.percentile(gm[ok], 92) + 1e-6), 0, 1)
    detail = np.maximum(detail, smoothstep(0.72, 0.95, g))
    cy, cx = np.nonzero(ok)
    dsel = detail[cy, cx]
    place = {"any": None, "mass": 0.08 + (1 - dsel) ** 2, "edge": 0.04 + dsel ** 1.5}
    area = len(cy) * k * k
    wob_map = wobble if np.ndim(wobble) else None
    for coverage, (w0, w1), (l0, l1), where in passes:
        count = int(coverage * area / ((w0 + w1) / 2 * R * (l0 + l1) / 2 * R))
        p = place[where]
        idx = rng.choice(len(cy), size=count, p=None if p is None else p / p.sum())
        xs = cx[idx] * k + rng.uniform(0, k, count)
        ys = cy[idx] * k + rng.uniform(0, k, count)
        widths = rng.uniform(w0, w1, count) * R
        lens = rng.uniform(l0, l1, count) * R
        tints = 1 + rng.normal(0, jitter, count)
        turns = rng.normal(0, 1, count)
        for x, y, width, ln, tint, turn in zip(xs, ys, widths, lens, tints, turns):
            yi, xi = min(h - 1, int(y)), min(w - 1, int(x))
            c = float(field[yi, xi] * tint)
            if lengths is not None:
                ln *= lengths[yi, xi]
            off = float(turn * (wob_map[yi, xi] if wob_map is not None else wobble))
            pts = [(x, y)]
            px, py = x, y
            for _ in range(max(1, int(ln / 2))):
                a = float(angle[min(h - 1, max(0, int(py))), min(w - 1, max(0, int(px)))]) + off
                px += math.cos(a) * 2
                py += math.sin(a) * 2
                pts.append((px, py))
            d.line(pts, fill=c, width=max(1, int(round(width))), joint="curve")
            r = width / 2
            for ex, ey in (pts[0], pts[-1]):
                d.ellipse([ex - r, ey - r * 0.8, ex + r, ey + r * 0.8], fill=c)
    return np.array(img, dtype=np.float32)


# Brush passes: (coverage, width pt, length pt, where). Blocking in, laying in, drawing, highlights.
PASSES_SKY = [(0.55, (5, 9), (8, 16), "mass"), (0.5, (2.6, 4.6), (5, 11), "any"), (0.35, (1.3, 2.4), (3, 7), "edge"),
              (0.2, (0.6, 1.0), (2, 4.5), "edge"), (0.08, (0.32, 0.5), (1.4, 3), "edge")]
PASSES_LAND = [(0.45, (2.4, 4.4), (4, 9), "mass"), (0.45, (1.2, 2.2), (2.5, 6), "any"),
               (0.35, (0.6, 1.0), (1.6, 3.6), "edge"), (0.2, (0.3, 0.5), (1.0, 2.2), "edge")]
PASSES_WATER = [(0.4, (2.0, 4.0), (14, 34), "mass"), (0.4, (1.0, 2.0), (8, 20), "any"),
                (0.3, (0.5, 0.9), (4, 10), "edge"), (0.15, (0.3, 0.45), (2.5, 6), "edge")]
PASSES_GROUND = [(0.5, (1.8, 3.6), (3, 8), "mass"), (0.4, (0.9, 1.6), (2, 5), "any"),
                 (0.25, (0.4, 0.7), (1.2, 3), "edge")]


# MARK: Sky and cloud (the study is painted at half the master size; the strokes bring it to full)

def cumulus_mass(V, glow, angle, cloud, X, Y, rs, mass, rng, sun, belly=0.38):
    """One cumulus mass laid into a study (after Old Master's cumulus()): a dome filled with spherical billows of every
    size, the higher ones bulging further toward the viewer, its surface roughened, so it reads as one heaped form
    rather than a row of beads. Shaded from a broad, smoothed surface (the big masses) with the billows showing through
    at a third of the strength; lit half-Lambert from `sun`, darker in the crevices and in the flat belly, a silver edge
    where the outline turns to the light; the crown crisp on the lit side and melting on the shadow side, the base
    dissolving into the air. mass: (centre x, base, width, height, billows, tone) in pt; tone < 1 for a mass turned
    from the light or further off."""
    cx, base, width, height, n, tone = mass
    h, w = V.shape
    x0, x1 = max(0, int((cx - width / 2 - 0.4 * height) * rs)), min(w, int((cx + width / 2 + 0.4 * height) * rs) + 2)
    y0, y1 = max(0, int((base - 1.3 * height) * rs)), min(h, int((base + 0.25 * height + 4) * rs) + 2)
    if x1 - x0 < 4 or y1 - y0 < 4:                                      # off the canvas
        return
    xs, ys = X[y0:y1, x0:x1], Y[y0:y1, x0:x1]
    Z = np.full(xs.shape, -1.0, np.float32)
    big = min(0.36 * height, 44.0)                                      # no billow larger than this (pt)
    for _ in range(max(n, int(width * height / 150))):
        u = rng.uniform(-1, 1) * (0.75 if rng.uniform() < 0.25 else 1.0)
        top = height * (1 - u * u) ** 0.55 * rng.uniform(0.82, 1.0)
        r = math.exp(rng.uniform(math.log(0.14 * big), math.log(big))) * (0.5 + 0.5 * top / height)
        v = rng.uniform(0, 1) ** 0.45                                    # most billows high in the dome
        cy = base - max(r * 0.5, v * top - r * 0.6)
        r = max(r, 0.8)
        px = cx + u * width / 2
        z0 = 0.32 * (base - cy) + rng.uniform(0, 0.15) * height
        bx0, bx1 = max(0, int((px - r) * rs) - x0), min(x1 - x0, int((px + r) * rs) - x0 + 2)
        by0, by1 = max(0, int((cy - r) * rs) - y0), min(y1 - y0, int((cy + r) * rs) - y0 + 2)
        if bx1 <= bx0 or by1 <= by0:
            continue
        d2 = (xs[by0:by1, bx0:bx1] - px) ** 2 + (ys[by0:by1, bx0:bx1] - cy) ** 2
        z = np.where(d2 < r * r, np.sqrt(np.maximum(r * r - d2, 0)) + z0, -1.0)
        Z[by0:by1, bx0:bx1] = np.maximum(Z[by0:by1, bx0:bx1], z)
    inside = (Z >= 0).astype(np.float32)
    lumps = aniso(xs, ys, 0.4, 0.22 * height, 0.14 * height, rng, octaves=3)
    Zc = np.maximum(Z, 0) + inside * 0.05 * height * lumps
    lx, ly, lz = om.norm3(*sun)

    def lambert(sigma):
        gy, gx = np.gradient(gaussian_filter(Zc, sigma * rs))
        nx, ny, nz = om.norm3(-gx * rs, -gy * rs, np.full_like(Zc, 1.1))
        return nx * lx + ny * ly + nz * lz

    lam = 0.65 * lambert(0.09 * height) + 0.35 * lambert(0.025 * height + 0.3)
    diffuse = np.clip(0.5 + 0.5 * lam, 0, 1) ** 1.5
    ao = np.clip((gaussian_filter(Zc, 0.12 * height * rs) - Zc) / (0.14 * height), 0, 1) * inside
    under = smoothstep(base - 0.6 * height, base + 0.05 * height, ys)
    v = tone * (0.2 + 0.8 * diffuse) * (1 - 0.28 * ao) * (1 - belly * under * (1 - 0.5 * diffuse))
    v = v + 0.18 * tone * inside * (1 - smoothstep(0, 0.08 * height, Zc)) * smoothstep(0.15, 0.7, lam)
    crisp = gaussian_filter(inside, 0.4)
    melt = gaussian_filter(inside, max(0.5, 0.035 * height * rs))
    shadow_side = smoothstep(0.1, -0.35, gaussian_filter(lam, 0.05 * height * rs))
    cover = crisp * (1 - shadow_side) + np.minimum(crisp, melt) * shadow_side
    ragged = aniso(xs, ys, 0.0, min(0.3 * width, 3.0 * height), 0.06 * height, rng, octaves=3)
    cover *= smoothstep(base + 0.04 * height, base - 0.3 * height, ys + 0.12 * height * ragged)
    lit = cover * smoothstep(0.62, 0.9, diffuse) * (1 - under) * (1 - ao) * tone
    ty, tx = np.gradient(gaussian_filter(Zc, 0.06 * height * rs + 1))
    tangent = np.where(np.hypot(tx, ty) > 1e-3, np.arctan2(ty, tx) + np.pi / 2, 0.2)   # round the billows
    sl = (slice(y0, y1), slice(x0, x1))
    V[sl] = V[sl] + (v - V[sl]) * cover
    glow[sl] = glow[sl] * (1 - cover) + lit * 0.9
    angle[sl] = np.where(cover > 0.4, tangent, angle[sl])
    cloud[sl] = np.maximum(cloud[sl], cover)


def banner(V, glow, angle, cloud, X, Y, rng, length, lift):
    """The Matterhorn's banner cloud: a plume born on the lee side of the summit and streaming away to the right,
    swelling and thinning along its length, heaped and torn at its edges, streaked with the wind, lit on its upper
    side and shadowed beneath."""
    sx, sy = G.summit
    f = G.f
    u = (X - sx) / f                                                  # mountain units along the plume
    yc = sy + f * (7.0 + lift * u + 4.0 * np.sin(u / 50))
    th = f * (4.0 + 0.2 * np.clip(u, 0, None)) * (1 - 0.35 * smoothstep(0.5 * length, length, u))
    across = (Y - yc) / th
    heap = aniso(X / f, Y / f, lift, 22, 6, rng, octaves=3)
    streak = aniso(X / f, Y / f, lift, 50, 1.4, rng, octaves=2)
    edge_ = np.abs(across) - 0.28 * heap - 0.12 * streak
    dens = smoothstep(1.0, 0.45, edge_) * smoothstep(-3, 4, u)
    dens *= 1 - smoothstep(0.55 * length, length, u + 40 * aniso(X / f, Y / f, 1.5, 40, 25, rng, octaves=1))
    dens = np.clip(dens * (0.75 + 0.25 * smoothstep(-1.0, 1.0, streak)), 0, 1)
    val = 0.96 - 0.4 * smoothstep(-0.8, 0.9, across - 0.2 * heap) + 0.04 * streak
    V[:] = V + (val - V) * dens
    glow[:] = glow * (1 - dens) + dens * smoothstep(0.1, -0.7, across) * 0.85
    angle[:] = np.where(dens > 0.3, lift + 0.05 * streak, angle)
    cloud[:] = np.maximum(cloud, dens)


def lenticular(V, glow, angle, cloud, X, Y, rng):
    """A lenticular cap on the summit: a broad smooth lens, domed above and flat beneath, lying behind the summit so
    the dark hooked rock stands against it, and a thinner lens stacked above; lit on top, shadowed beneath, soft edged
    and faintly laminated."""
    sx, sy = G.summit
    f = G.f
    for dy, wd, ht, tone in ((10, 240, 32.0, 0.97), (-30, 160, 9.0, 0.9)):
        cx, cy = sx + 12 * f, sy + dy * f
        xn = (X - cx + 4 * f * aniso(X / f, Y / f, 0.0, 50, 12, rng, octaves=1)) / (wd * f / 2)
        prof = np.clip(1 - xn * xn, 0, 1) ** 0.6
        top_h = ht * f * prof + 1e-3                            # domed above
        bot_h = 0.35 * ht * f * prof + 1e-3                     # flat beneath
        dy_ = Y - cy
        dd = np.where(dy_ < 0, dy_ / top_h, dy_ / bot_h)
        m = smoothstep(1.0, 0.55, np.abs(dd)) * smoothstep(0.0, 0.1, prof)
        val = tone * (0.98 - 0.42 * smoothstep(-0.9, 1.0, dd)) + 0.02 * np.sin(dy_ / f * 1.3 + 2 * xn)
        V[:] = V + (val - V) * m
        glow[:] = glow * (1 - m) + m * smoothstep(0.0, -0.8, dd) * 0.9
        angle[:] = np.where(m > 0.4, 0.05 * xn, angle)
        cloud[:] = np.maximum(cloud, m)


def milky_way(V, X, Y, rng, amount):
    """The Milky Way: a clumped, diffuse band across the sky from upper left to lower right, split by dark lanes.
    Returns where the stars crowd."""
    p0, p1 = np.array([-60.0, 40.0]), np.array([470.0, 560.0])
    dvec = (p1 - p0) / np.linalg.norm(p1 - p0)
    s = (X - p0[0]) * -dvec[1] + (Y - p0[1]) * dvec[0]                # across the band
    band_angle = math.atan2(dvec[1], dvec[0])
    clumps = smoothstep(-1.2, 1.4, aniso(X, Y, band_angle, 50, 22, rng, octaves=3))
    lanes = smoothstep(0.2, 1.1, aniso(X, Y, band_angle + 0.15, 70, 7, rng, octaves=2)) * np.exp(-(s / 16) ** 2)
    core = np.exp(-(s / 44) ** 2) * (0.45 + 0.55 * clumps)
    halo = np.exp(-(s / 110) ** 2) * 0.35
    V += (amount * ((core + halo) * (1 - 0.45 * lanes))).astype(np.float32)
    return np.exp(-(s / 70) ** 2).astype(np.float32)


def sky_study(ws, hs, rs, rng):
    """Value, glow, stroke angle and cloud cover of the sky at rs px per pt: dark overhead, opening to a luminous break,
    calm in the middle (a faint mottle, strokes laid crosswise), the cumulus, and the look's cloud effects."""
    L = G.look
    y = ((np.arange(hs) + 0.5) / rs).astype(np.float32)
    x = ((np.arange(ws) + 0.5) / rs).astype(np.float32)
    X, Y = np.meshgrid(x, y)
    top, horizon = L["sky"]
    t = np.clip(Y / G.water, 0, 1)
    v = top + (horizon - top) * t ** 1.25
    lx, ly = L["light"]
    d = np.hypot(X - lx, (Y - ly) * 1.25)
    v += L["breakglow"] * (0.2 * np.exp(-(d / 150) ** 2) + 0.12 * np.exp(-(d / 42) ** 2))
    v -= L["deep_right"] * smoothstep(190, 400, X) * smoothstep(200, 470, Y)
    corner = np.hypot((X / DW - 0.5) * 1.4, Y / DH * 1.1)
    v -= 0.1 * smoothstep(0.45, 1.0, corner) * (1 - t)
    v += L["canopy"] * fbm(hs, ws, rng, base=5, octaves=3) * (1 - smoothstep(60, 200, Y))   # soft lumps overhead
    v += 0.012 * fbm(hs, ws, rng, base=9, octaves=2)
    v = v.astype(np.float32)
    band = None
    if "milkyway" in L["effects"]:
        band = milky_way(v, X, Y, rng, L["milkyway"])
    angle = np.clip(-0.05 + 0.45 * fbm(hs, ws, rng, base=2.5, octaves=2, persistence=0.5), -0.6, 0.5)
    angle = angle.astype(np.float32)
    glow = np.zeros((hs, ws), np.float32)
    cloud = np.zeros((hs, ws), np.float32)
    for mass in L["clouds"]:
        cumulus_mass(v, glow, angle, cloud, X, Y, rs, mass, rng, L["sun"])
    if "banner" in L["effects"]:
        banner(v, glow, angle, cloud, X, Y, rng, *L["banner"])
    if "lenticular" in L["effects"]:
        lenticular(v, glow, angle, cloud, X, Y, rng)
    return v, glow, angle, cloud, band


def fog_sea(ws, hs, rs, rng, top):
    """A sea of cloud from `top` (pt) down, seen from above at a low angle: its body laid in first, then rows of
    rounded heads from the far edge forward, each row overlapping the last, small and lit along their crowns far off,
    larger and deeper in shade toward the viewer. Returned premultiplied: value, coverage, glow, angle."""
    tone0 = G.look["fogtone"]
    y = ((np.arange(hs) + 0.5) / rs).astype(np.float32)
    x = ((np.arange(ws) + 0.5) / rs).astype(np.float32)
    X, Y = np.meshgrid(x, y)
    depth = smoothstep(top, DH, Y)
    rolls = aniso(X, Y, 0.0, 70, 9, rng, octaves=3)
    V = (tone0 * (0.78 - 0.36 * depth + 0.05 * rolls)).astype(np.float32)
    cover = smoothstep(top + 6, top + 22, Y).astype(np.float32)
    V *= cover
    glow = np.zeros_like(V)
    angle = (0.04 * rolls).astype(np.float32)
    base, k = top + 14, 0
    while base - 30 < DH + 30:
        height = 20 + 7 * k
        tone = tone0 * max(0.48, 0.98 - 0.075 * k)
        xpos = -60 + rng.uniform(0, 30)
        while xpos < DW + 60:
            wd = height * rng.uniform(2.4, 3.8)
            layer_v = np.zeros_like(V)
            layer_c = np.zeros_like(V)
            cumulus_mass(layer_v, glow, angle, layer_c, X, Y, rs,
                         (xpos + wd / 2, base + rng.uniform(-4, 4), wd, height * rng.uniform(0.8, 1.15),
                          int(80 + 2.5 * height), tone), rng, G.look["sun"], belly=0.12)
            V = V * (1 - layer_c) + layer_v * layer_c
            cover = np.maximum(cover, layer_c)
            xpos += wd * rng.uniform(0.45, 0.65)
        base += 0.5 * height + 4 * k
        k += 1
    return V, cover, glow, angle


def mist_veil(X, Y, rng, levels):
    """Low mist after rain: level wisps lying across the slopes. levels: [(y pt, depth pt, amount)]."""
    out = np.zeros(X.shape, np.float32)
    for yl, depth, amount in levels:
        wob = 3 * aniso(X, Y, 0.0, 60, 12, rng, octaves=2)
        band = np.exp(-((Y - yl - wob) / depth) ** 2)
        out = np.maximum(out, amount * band * smoothstep(-0.7, 0.9, aniso(X, Y, 0.02, 70, 2.6, rng)))
    return out


# MARK: The mountain (full size, on the band of rows it occupies)

def massif_study(W, rows, R, sky, rng):
    """Value, coverage, glow, stroke angle and stroke length of the massif (and, by the tarn, its near hills)."""
    L = G.look
    f = G.f
    x, X, Y = grid(rows, W, R)
    PX, PY = photo_x(X), photo_y(Y)
    MX, MY = X / f, Y / f                                   # mountain units: textures scale with the mountain
    tex = 1.0 if f <= 1.4 else 1.8                          # close to, the snow lies in smaller, more numerous patches
    TX, TY = MX * tex, MY * tex

    # The silhouette: the traced crest, crisp, with a little rock along it away from the summit.
    crest = massif_crest(x) + roughen(W, rng, 0.18 * f, 0.5 * R * f) * smoothstep(8 * f, 30 * f, np.abs(x - G.summit[0]))
    if f > 1.4:
        crest = crest + roughen(W, rng, 0.25, 0.25 * R) * smoothstep(3, 12, np.abs(x - G.summit[0]))
    massif = crest_cover(Y, crest, R)

    # The pyramid's planes (see LEFT_EDGE, HORNLI, NORTH): a partition that sums to one. The ridges are sharp high
    # up; below the shoulder's notch the Hörnli rounds off and its rock runs into the shoulder's snow.
    def across(keys):
        """Signed distance (mountain units, + to the right) from a ridge given as photo keys running down the face."""
        return (PX - keyed(PY, [(b, a) for a, b in keys])) * 0.29

    d_left, d_horn, d_north = across(LEFT_EDGE), across(HORNLI), across(NORTH)
    soften = smoothstep(750, 830, PY)
    wav = aniso(MX, MY, 1.0, 10, 2.5, rng, octaves=2)
    e_left = edge(d_left * f, R)
    e_horn = edge(d_horn * f, R) * (1 - soften) + smoothstep(-1.4, 1.4, d_horn + 0.9 * wav) * soften
    e_north = smoothstep(-2.5, 2.5, d_north + 1.6 * wav)
    e_horn = np.minimum(e_horn, e_left)
    e_north = np.minimum(e_north, e_horn)
    shade_f, lit_f, band_f, north_f = 1 - e_left, e_left - e_horn, e_horn - e_north, e_north
    foot = keyed(PX, FOOT) + 14 * aniso(MX, MY, 0.1, 30, 6, rng, octaves=2)
    low = smoothstep(foot - 10, foot + 22, PY).astype(np.float32)
    side = (smoothstep(452, 424, PX) * smoothstep(845, 885, PY)).astype(np.float32)   # far ridges left of the pyramid
    cap_y = keyed(PX, SUMMIT_CAP) + 5 * aniso(MX, MY, 0.2, 8, 3, rng, octaves=2)
    cap = smoothstep(cap_y - 5, cap_y + 7, PY)                           # 0 on the bare summit rock

    detail = 3 + int(f > 1.4)                               # one more octave when the mountain is painted large
    grain = aniso(MX, MY, 2.0, 4, 0.6, rng, octaves=detail - 1)
    # Snow on a steep face lies in patches drawn out along the ledges (tilted a little down to the right) and down the
    # gullies, in broad sheets where the face eases, with bare rock between; under each patch the rock step is in its
    # own shadow.
    ledges = aniso(TX, TY, 0.25, 10, 1.5, rng, octaves=detail)
    gullies = aniso(TX, TY, 1.95, 13, 1.3, rng, octaves=detail)
    broad = aniso(MX, MY, 1.2, 36, 14, rng, octaves=2)
    lie = 0.62 * ledges + 0.42 * gullies + 0.5 * broad
    run = aniso(TX, TY, 0.25, 18, 4, rng, octaves=2)
    rib = aniso(TX, TY, 1.95, 24, 2.0, rng, octaves=detail)
    step = max(1, int(round(0.9 * R * f)))
    lie_above = np.roll(lie, step, axis=0)
    under = smoothstep(0.15, 0.7, lie_above - lie) * smoothstep(-0.2, 0.3, lie_above)
    ledge = smoothstep(0.55, 0.85, ledges + 0.2 * run)                  # for the shaded faces' thin snow

    # The broad lit face: snow sheets high up, the patches thinning lower down where the rock takes over.
    toward = np.clip(d_left / np.maximum(d_left - d_horn, 1e-3), 0, 1)
    thresh = -0.25 + 0.55 * smoothstep(640, 900, PY)
    snow_l = smoothstep(thresh - 0.12, thresh + 0.12, lie) * cap
    snow_l = np.clip(snow_l * L["snow"], 0, 1)
    rock_l = 0.45 + 0.04 * grain + 0.07 * smoothstep(0.3, 1.3, rib) - 0.15 * under
    v_lit = rock_l + (0.97 - rock_l) * snow_l
    v_lit -= 0.05 * smoothstep(0.2, -0.4, lie - thresh) * snow_l          # the snow's own shading at its edges
    v_lit *= 1 - 0.12 * toward - 0.08 * smoothstep(700, 900, PY)
    v_lit += 0.05 * (1 - smoothstep(0, 1.2, d_left))                     # its lit edge along the left ridge
    lg_y, lg_x = np.gradient(gaussian_filter(lie, 0.8 * R * f))
    along_patch = np.where(np.hypot(lg_x, lg_y) > 1e-4, np.arctan2(lg_y, lg_x) + np.pi / 2, 1.95)
    # The shaded left face: dark rock in buttress ribs down the fall line, their left flanks catching the light, and
    # a little snow on the ledges.
    ribs_s = aniso(MX, MY, 2.15, 20, 1.7, rng)
    flank = np.gradient(gaussian_filter(ribs_s, 0.3 * R * f), axis=1) * R * f   # + on a rib's left flank
    v_shade = 0.21 + 0.03 * grain + 0.12 * smoothstep(0.15, 0.7, flank) * smoothstep(-0.5, 0.8, ribs_s)
    v_shade = v_shade + (0.44 - v_shade) * ledge * smoothstep(0.2, 1.2, run) * cap * 0.75 * L["snow"]
    v_shade += 0.04 * smoothstep(840, 960, PY) - 0.04 * (1 - smoothstep(0, 3.0, -d_left))
    # The dark band under the ridge from the summit to the shoulder; below the notch the ridge's rock, lightening as
    # it turns toward the shoulder.
    v_band = 0.25 + 0.03 * grain + (0.44 - 0.25) * ledge * 0.55 * cap
    v_band -= 0.04 * (1 - smoothstep(0, 2.0, d_horn)) * (1 - soften)
    v_band += 0.1 * smoothstep(0, 12, d_horn) * soften
    # The shoulder's snow: half-light by the ridge, full light further out, the strata and a few ribs showing.
    out_sh = smoothstep(-2, 18, d_north)
    v_north = 0.62 + 0.33 * out_sh + 0.025 * grain
    rock_n = smoothstep(0.85, 1.5, 0.7 * rib + 0.4 * run) * (1 - 0.6 * out_sh) * (1 - ledge)
    v_north = v_north + (0.42 - v_north) * rock_n - 0.06 * under * (1 - out_sh)

    # Below the pyramid: the glacier in broad swells round a few large islands of rock, then a band of cliffs, then
    # moraine in the mist. Left of the pyramid, the far ridges: snow, rock along their crests, paler.
    blob = aniso(MX, MY, 0.15, 44, 10, rng, octaves=2)
    crag = aniso(MX, MY, 1.0, 6, 1.2, rng, octaves=2)
    swell = aniso(MX, MY, 0.2, 30, 8, rng, octaves=2)
    island = smoothstep(1.0, 0.6, np.hypot((PX - 676) / 62, (PY - 950) / 17) + 0.35 * blob + 0.3 * crag)
    cliffs = (smoothstep(1012, 1036, PY + 14 * blob) * (1 - smoothstep(1100, 1124, PY + 14 * blob))
              * (1 - smoothstep(0.3, 1.1, aniso(MX, MY, 1.0, 10, 4, rng, octaves=2) + 0.4 * blob)))
    rock_low = np.maximum(np.maximum(smoothstep(1.05, 1.45, blob + 0.15 * crag), island), cliffs)
    v_low = 0.84 + 0.05 * swell - 0.24 * smoothstep(930, 1010, PY + 10 * blob)
    v_low = v_low + (0.32 - v_low) * rock_low
    v_low = v_low + (0.46 - v_low) * 0.7 * smoothstep(1070, 1168, PY)   # mist at the foot
    below = PY - photo_y(crest)[None, :]
    ridge_rock = smoothstep(-0.6, 0.4, 0.6 * crag + 0.5 * blob - 0.04 * below)
    v_side = 0.74 - 0.12 * smoothstep(940, 1040, PY) + 0.03 * grain
    v_side = v_side + (0.34 - v_side) * np.maximum(rock_low * 0.8, ridge_rock)
    v_side += 0.1 * (1 - smoothstep(0, 2.5 / 0.29, below)) * smoothstep(-0.3, 0.6, crag)   # its crest catches light
    v_side = v_side + (0.6 - v_side) * 0.2                              # further off, paler

    face = v_shade * shade_f + v_lit * lit_f + v_band * band_f + v_north * north_f
    pyramid = face * (1 - side) + v_side * side
    v_massif = pyramid * (1 - low) + v_low * low
    v_massif = v_massif * 0.94 + 0.6 * 0.06                            # the air between
    glow = ((lit_f * snow_l * smoothstep(0.8, 0.95, v_lit) + north_f * smoothstep(0.75, 0.95, v_north))
            * (1 - side) * (1 - low) + low * smoothstep(0.8, 0.92, v_low) * 0.6)
    # Alpenglow and first light: the shadow of the earth rising up the mountain; above it the rock and snow burn,
    # below it everything has gone into shade.
    if L["alpenglow"] is not None:
        line = L["alpenglow"] + 28 * aniso(MX, MY, 0.15, 26, 7, rng, octaves=3) + 0.12 * (PX - 648)
        sunlit = smoothstep(line + 26, line - 26, PY)
        v_massif = v_massif * (0.5 + 0.56 * sunlit) + 0.04 * sunlit
        glow = glow * sunlit + sunlit * smoothstep(0.45, 0.8, v_massif) * 0.6
    v_massif = v_massif * L["mountain"]
    glow = glow * massif
    # Strokes follow the forms: along the ledges where snow lies on them, down the fall line on rock, across the
    # slope on the snowfields; longer on the broad snow, shorter on the broken rock.
    fall = np.select([shade_f > 0.5, lit_f > 0.5, band_f > 0.5], [2.15, along_patch, 1.15], 0.62)
    angle = np.where(low > 0.5, 0.25 + 0.15 * swell, np.where(side > 0.5, 0.5 + 0.25 * crag, fall)).astype(np.float32)
    lengths = np.select([low > 0.5, north_f > 0.5], [1.4, 1.2], 0.9).astype(np.float32)

    V = sky * (1 - massif) + v_massif * massif
    cover = massif
    if G.lake:
        V, cover, glow, angle, lengths = tarn_hills(x, X, Y, R, rng, V, cover, glow, angle, lengths)
    return V.astype(np.float32), cover.astype(np.float32), glow.astype(np.float32), angle, lengths


def tarn_hills(x, X, Y, R, rng, V, cover, glow, angle, lengths):
    """The tarn's near hills, closer and coarser: the left spur of broken rock turned away from the light, with old
    snow in its hollows and a lit lip along its crest; the right bank of turf facing the light, darkening to the
    water; and the dark seam of moraine along the far shore."""
    s = G.f
    n = len(x)
    hl = pt_y(keyed(photo_x(x), LEFT_HILL)) + roughen(n, rng, 1.6 * s, 6 * R * s) + roughen(n, rng, 0.35, 0.3 * R)
    hr = pt_y(keyed(photo_x(x), RIGHT_HILL)) + roughen(n, rng, 1.2 * s, 8 * R * s) + roughen(n, rng, 0.25, 0.4 * R)
    left = crest_cover(Y, hl, R)
    right = crest_cover(Y, hr, R)
    below_l, below_r = Y - hl[None, :], Y - hr[None, :]
    knob = aniso(X, Y, 0.7, 7, 3, rng)
    facet = aniso(X, Y, 2.3, 5, 1.6, rng, octaves=2)
    grain = aniso(X, Y, 2.0, 4, 0.6, rng, octaves=2)
    v_left = 0.13 + 0.11 * smoothstep(0.2, 1.3, 0.6 * knob + 0.5 * facet) + 0.03 * grain
    v_left += 0.2 * smoothstep(1.35, 1.9, aniso(X, Y, 0.45, 9, 2.0, rng, octaves=2) + 0.3 * knob) * G.look["snow"]
    v_left += 0.12 * (1 - smoothstep(0, 1.0, below_l)) * smoothstep(-0.5, 0.8, facet)
    v_left -= 0.08 * smoothstep(G.water - 40, G.water, Y)
    turf = aniso(X, Y, -0.15, 12, 1.2, rng)
    v_right = 0.2 + 0.07 * smoothstep(-0.8, 1.2, turf) + 0.06 * smoothstep(0.4, 1.4, knob) + 0.02 * grain
    v_right += 0.1 * (1 - smoothstep(0, 5, below_r))
    v_right -= 0.1 * smoothstep(8, 40, below_r) * smoothstep(G.water - 45, G.water, Y)
    seam = G.water - 1.4 - 1.6 * smoothstep(-0.2, 1.5, roughen(n, rng, 1.0, 2.5 * R))
    shore = crest_cover(Y, seam, R)
    v_seam = 0.12 + 0.12 * smoothstep(1.1, 1.8, aniso(X, Y, 0.0, 3, 0.8, rng, octaves=2))
    k = G.look["ground_tone"]
    V = V * (1 - left) + v_left * k * left
    V = V * (1 - right) + v_right * k * right
    V = V * (1 - shore) + v_seam * k * shore
    hills = np.maximum(np.maximum(left, right), shore)
    glow = glow * (1 - hills)
    angle = np.where(hills > 0.5, np.where(left > 0.5, 0.55 + 0.35 * facet, -0.3 + 0.15 * turf), angle)
    lengths = np.where(hills > 0.5, 0.8, lengths)
    return V, np.maximum(cover, hills), glow, angle.astype(np.float32), lengths.astype(np.float32)


# MARK: The near ground, without the tarn (full size)

def ground_study(W, rows, R, V0, rng):
    """A meadow rolling across the foot of the mountain, a dark ridge or bank under the dock, and the larch and pine of
    the foreground, laid over V0 (the picture so far) on master rows `rows`. Returns value, coverage, angle,
    stroke length."""
    L = G.look
    x, X, Y = grid(rows, W, R)
    V = V0.copy()
    cover = np.zeros_like(V)
    angle = np.zeros_like(V)
    lengths = np.ones_like(V)
    grain = aniso(X, Y, 2.0, 4, 0.6, rng, octaves=2)
    k = L["ground_tone"]
    if L.get("meadow"):
        cm = keyed(x, L["meadow"]) + roughen(W, rng, 1.4, 10 * R) + roughen(W, rng, 0.3, 0.4 * R)
        m = crest_cover(Y, cm, R)
        depth = Y - cm[None, :]
        turf = aniso(X, Y, -0.1, 14, 1.3, rng)
        swale = aniso(X, Y, 0.05, 60, 14, rng, octaves=2)
        v_m = 0.27 + 0.06 * smoothstep(-0.8, 1.2, turf) + 0.09 * swale + 0.02 * grain
        v_m += 0.12 * (1 - smoothstep(0, 4, depth))                    # the lit lip of the rise
        v_m -= 0.16 * smoothstep(0, 160, depth)                        # into shade toward the viewer
        V = V * (1 - m) + v_m * k * m
        cover = np.maximum(cover, m)
        angle = np.where(m > 0.5, -0.06 + 0.12 * turf, angle)
        lengths = np.where(m > 0.5, 1.2, lengths)
    if L.get("ridge"):
        cr = keyed(x, L["ridge"]) + roughen(W, rng, 2.0, 12 * R) + roughen(W, rng, 0.4, 0.5 * R)
        r = crest_cover(Y, cr, R)
        knob = aniso(X, Y, -0.4, 8, 3, rng)
        v_r = 0.1 + 0.05 * smoothstep(0, 1.4, knob) + 0.09 * (1 - smoothstep(0, 2.5, Y - cr[None, :]))
        v_r -= 0.04 * smoothstep(0, 80, Y - cr[None, :])
        V = V * (1 - r) + v_r * k * r
        cover = np.maximum(cover, r)
        angle = np.where(r > 0.5, -0.35 + 0.3 * knob, angle)
        lengths = np.where(r > 0.5, 0.8, lengths)
    for spec_ in L.get("trees", ()):
        m, v_t = forest(W, rows, R, rng, **spec_)
        V = V * (1 - m) + v_t * k * m
        cover = np.maximum(cover, m)
        angle = np.where(m > 0.5, np.pi / 2, angle)
        lengths = np.where(m > 0.5, 0.55, lengths)
    return V.astype(np.float32), cover.astype(np.float32), angle.astype(np.float32), lengths.astype(np.float32)


def forest(W, rows, R, rng, kind, x, base, height, n, rise=0.0, tone=None):
    """A stand of trees on the near ground, drawn with Old Master's fir (om.fir): pines as dark ragged spires with a
    lit flank, larches lighter and feathered. x, base, height: (min, max) in pt; `rise` > 0 makes them taller toward
    max x, < 0 toward min x. Returns coverage and value on master rows `rows`."""
    h = rows.stop - rows.start
    k = 2
    img = Image.new("L", (W * k, h * k), 0)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        tx = rng.uniform(*x)
        t = (tx - x[0]) / max(1e-6, x[1] - x[0])
        grow = 1 + rise * (t - 0.5) * 2 if rise else 1
        hh = rng.uniform(*height) * max(0.25, grow)
        tb = rng.uniform(*base)
        pts = om.fir(tx * R, tb * R - rows.start, hh * R, rng)
        if kind == "larch":
            pts = [(px_ + (px_ - tx * R) * 0.15, py_) for px_, py_ in pts]   # a little fuller
        d.polygon([(px_ * k, py_ * k) for px_, py_ in pts], fill=255)
    m = np.asarray(img.resize((W, h), Image.LANCZOS), dtype=np.float32) / 255
    _, X, Y = grid(rows, W, R)
    # Break the clean outline into branch tips, and give the boughs their tiers and a lit flank toward the light.
    fine = aniso(X, Y, 0.35, 2.4, 0.7, rng, octaves=2)
    near = gaussian_filter(m, 0.45 * R)
    m = smoothstep(0.32, 0.68, near + 0.22 * fine * smoothstep(0.03, 0.3, near))
    boughs = smoothstep(0.2, 1.2, aniso(X, Y, 0.4 if kind == "pine" else 0.9, 4.5, 0.9, rng, octaves=2))
    rim = np.clip(-sobel(gaussian_filter(m, 0.6 * R), axis=1) / 4 * R * 0.6, 0, 1)   # the flank toward the light
    shade = np.clip(sobel(gaussian_filter(m, 1.2 * R), axis=1) / 4 * R * 0.6, 0, 1)  # the far flank
    if kind == "larch":
        base_v = tone if tone is not None else 0.16
        v = base_v + 0.06 * boughs + 0.14 * rim - 0.05 * shade
    else:
        base_v = tone if tone is not None else 0.07
        v = base_v + 0.045 * boughs + 0.16 * rim - 0.02 * shade
    return m, v.astype(np.float32)


# MARK: The painting

def paint(look, master_w):
    """The whole value study, painted. Returns value, glow and R (master px per pt)."""
    use(look)
    L = look
    W = int(round(master_w))
    H = int(round(W * DH / DW))
    R = W / DW
    rng = np.random.default_rng(L["seed"])

    # Sky, at half size.
    rs = R / 2
    ws, hs = W // 2, int(np.ceil(G.hs * rs))
    sky_v, sky_glow, sky_angle, sky_cloud, star_band = sky_study(ws, hs, rs, rng)
    rU = min(H, int(np.ceil(G.hs * R)))
    V_up = resize(sky_v, W, rU)
    glow_u = resize(sky_glow, W, rU)
    angle_u = resize_angle(sky_angle, W, rU)
    cloud_u = np.clip(resize(sky_cloud, W, rU), 0, 1)
    band_u = resize(star_band, W, rU) if star_band is not None else None
    land = np.zeros((rU, W), np.float32)
    lengths_u = (1.0 - 0.3 * cloud_u).astype(np.float32)               # shorter strokes round the billows
    print(f"  sky {ws}x{hs}")

    # The massif, on its band of rows.
    r0 = max(0, int((min(G.summit[1], float(massif_crest(np.array([0.0, DW])).min())) - 3) * R))
    rM = min(rU, int(np.ceil((G.water + 4) * R)))
    band = slice(r0, rM)
    mv, mcover, mglow, mangle, mlen = massif_study(W, range(r0, rM), R, V_up[band], rng)
    V_up[band] = mv
    land[band] = mcover
    glow_u[band] = glow_u[band] * (1 - mcover) + mglow
    angle_u[band] = np.where(mcover > 0.5, mangle, angle_u[band])
    lengths_u[band] = np.where(mcover > 0.5, mlen, lengths_u[band])
    del mv, mcover, mglow, mangle, mlen
    print("  massif")

    # The near ground (without the tarn).
    if not G.lake:
        tops = [min(y for _, y in L[key]) for key in ("meadow", "ridge") if L.get(key)]
        tops += [t["base"][0] - t["height"][1] * 1.3 for t in L.get("trees", ())]
        if tops:
            g0 = max(0, int((min(tops) - 6) * R))
            gb = slice(g0, rU)
            gv, gcover, gangle, glen = ground_study(W, range(g0, rU), R, V_up[gb], rng)
            V_up[gb] = gv
            land[gb] = np.maximum(land[gb], gcover)
            glow_u[gb] *= 1 - gcover
            angle_u[gb] = np.where(gcover > 0.5, gangle, angle_u[gb])
            lengths_u[gb] = np.where(gcover > 0.5, glen, lengths_u[gb])
            print("  ground")

    # Fog and mist, in front of the land: painted as sky.
    if L["fog"] is not None:
        fv, fc, fg, fa = fog_sea(ws, hs, rs, rng, L["fog"])
        fv, fc, fg, fa = resize(fv, W, rU), np.clip(resize(fc, W, rU), 0, 1), resize(fg, W, rU), resize_angle(fa, W, rU)
        V_up = V_up * (1 - fc) + fv
        glow_u = glow_u * (1 - fc) + fg * fc
        angle_u = np.where(fc > 0.5, fa, angle_u)
        land *= 1 - fc
        cloud_u = np.maximum(cloud_u, fc)
        lengths_u = np.where(fc > 0.5, 0.75, lengths_u).astype(np.float32)
    if L["mist"]:
        _, Xm, Ym = grid(range(0, rU // 4), W // 4, R / 4)
        mist = resize(mist_veil(Xm, Ym, rng, L["mist"]), W, rU)
        V_up = V_up + (0.66 * L["ground_tone"] + 0.1 - V_up) * mist
        land *= 1 - 0.7 * mist
        angle_u = np.where(mist > 0.3, 0.02, angle_u)

    # Paint the picture: sky strokes and land strokes each loaded from their own side of the skyline.
    solid = (land > 0.5).astype(np.float32)
    sky_field = within(V_up, 1 - solid, 1.2 * R)
    land_field = within(V_up, solid, 1.2 * R)
    wob = (0.35 - 0.27 * cloud_u).astype(np.float32)                    # open sky crossed, cloud followed
    sky_out = brush(sky_field, angle_u, rng, R, PASSES_SKY, 0.025, region=(land < 0.98).astype(np.float32),
                    lengths=lengths_u, wobble=wob)
    land_out = brush(land_field, angle_u, rng, R, PASSES_LAND, 0.04, region=land, lengths=lengths_u, wobble=0.12)
    P_up = sky_out * (1 - land) + land_out * land
    del sky_out, land_out, sky_field, land_field
    print("  painted")

    out = np.zeros((H, W), np.float32)
    study = np.zeros((H, W), np.float32)
    angle = np.zeros((H, W), np.float32)
    glow = np.zeros((H, W), np.float32)
    landmask = np.zeros((H, W), np.float32)
    out[:rU], study[:rU], angle[:rU], glow[:rU], landmask[:rU] = P_up, V_up, angle_u, glow_u, land
    openmask = np.zeros((H, W), np.float32)
    openmask[:rU] = (1 - land) * (1 - cloud_u)
    crowd = np.zeros((H, W), np.float32)
    if band_u is not None:
        crowd[:rU] = band_u
    if G.lake:
        tarn(out, study, angle, glow, landmask, P_up, glow_u, rU, R, rng)

    # The whole canvas: bristle marks, light on the stroke edges, the shadows glazed thin, chiaroscuro.
    out = gaussian_filter(out, 0.1 * R)
    soft = gaussian_filter(study, 0.5 * R)
    thick = 0.45 + 0.55 * smoothstep(0.2, 0.7, soft)                    # thin darks, thick lights
    out = soft + (out - soft) * thick
    out = out * (1 + mt.bristles(H, W, rng, angle, 0.012).astype(np.float32) * thick)
    g = gaussian_filter(out, 0.25 * R)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.1
    contrast, gamma, lift = L["key"]
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** gamma
    out = out + lift * smoothstep(0.55, 0.95, out) * (1 - out)
    glow = gaussian_filter(glow, 0.35 * R) * smoothstep(0.45, 0.85, out)
    sky_rows = np.zeros((H, 1), np.float32)
    sky_rows[:int(G.water * R) if G.lake else H] = 1
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - landmask) * 0.8 * sky_rows), 0, 1)
    after_paint(out, glow, openmask, crowd, landmask, R, rng)
    print("  finished")
    return out.astype(np.float32), glow.astype(np.float32), R


def tarn(out, study, angle, glow, landmask, P_up, glow_u, rU, R, rng):
    """The tarn: the painted picture mirrored in its level, the ripples pulling it sideways more and more toward the
    viewer, softened downward, darkening as the water looks less at the sky; thin wind lines; then the near shore of
    dark rock and turf, a few boulders and rushes; all repainted with level strokes."""
    H, W = out.shape
    rW = int(round(G.water * R))
    _, X, Y = grid(range(rW, H), W, R)
    xx = X[0]
    depth = Y - G.water
    rip = aniso(X, Y, 0.0, 80, 2.2, rng) * 0.75 + aniso(X, Y, 0.0, 24, 0.9, rng, octaves=2) * 0.25
    calm = smoothstep(-0.4, 0.8, aniso(X, Y, 0.0, 200, 9, rng, octaves=2))
    amp = (0.2 + 0.016 * depth) * (0.4 + 0.6 * calm)
    src_y = np.clip((2 * G.water - Y + 0.3 * amp * rip) * R - 0.5, 0, rU - 1)
    src_x = (X + amp * rip) * R - 0.5
    refl = map_coordinates(P_up, [src_y, src_x], order=1, mode="nearest").astype(np.float32)
    rglow = map_coordinates(glow_u, [src_y, src_x], order=1, mode="nearest").astype(np.float32)
    soft = [gaussian_filter1d(refl, s * R, axis=0) for s in (0.4, 1.4, 3.2)]
    k = np.clip(depth / 140, 0, 2)
    refl = np.where(k < 1, soft[0] * (1 - k) + soft[1] * k, soft[1] * (2 - k) + soft[2] * (k - 1))
    del soft
    refl = refl * 0.88
    fres = 0.08 + 0.62 * smoothstep(0, 260, depth)
    refl = refl + (0.1 * G.look["ground_tone"] - refl) * fres
    lines = Image.new("F", (W, H - rW), 0.0)
    ld = ImageDraw.Draw(lines)
    for _ in range(26):                                               # wind lines showing the sky
        yl, xl = rng.uniform(4, 240), rng.uniform(-60, DW)
        length = rng.uniform(50, 230)
        th = rng.uniform(0.35, 1.3) * (0.6 + yl / 240)
        n = 24
        top = [((xl + length * i / n) * R, (yl - th * np.sin(np.pi * i / n) / 2) * R) for i in range(n + 1)]
        bot = [((xl + length * i / n) * R, (yl + th * np.sin(np.pi * i / n) / 2) * R) for i in reversed(range(n + 1))]
        ld.polygon(top + bot, fill=float(rng.uniform(0.5, 1.0)))
    wind = np.clip(gaussian_filter(np.asarray(lines, dtype=np.float32), (0.25 * R, 1.5 * R)), 0, 1)
    refl = refl + (0.34 * G.look["ground_tone"] - refl) * 0.55 * wind
    rglow = rglow * 0.45 * (1 - fres) * (1 - wind)
    rangle = (0.05 * rip).astype(np.float32)

    sx = (keyed(xx, G.look["shore"]) + roughen(W, rng, 3.2, 9 * R) + roughen(W, rng, 1.0, 2 * R)
          + roughen(W, rng, 0.3, 0.3 * R))
    ground = crest_cover(Y, sx, R)
    knob = aniso(X, Y, -0.3, 6, 2.0, rng)
    v_ground = 0.1 + 0.05 * smoothstep(0, 1.5, knob) - 0.05 * smoothstep(760, 874, Y)
    v_ground += 0.07 * (1 - smoothstep(0, 5, Y - sx[None, :]))       # the lit lip of the bank
    stones = Image.new("F", (W, H - rW), 0.0)
    sd = ImageDraw.Draw(stones)
    lit_stones = Image.new("F", (W, H - rW), 0.0)
    sl = ImageDraw.Draw(lit_stones)
    o = rW / R
    for _ in range(16):
        bx = rng.uniform(0, DW)
        by = float(np.interp(bx, xx, sx)) + rng.uniform(-1.5, 3)
        bw, bh = rng.uniform(4, 13), rng.uniform(2.5, 6)
        sd.ellipse([(bx - bw / 2) * R, (by - bh - o) * R, (bx + bw / 2) * R, (by - o + bh * 0.25) * R], fill=1.0)
        sl.ellipse([(bx - bw * 0.2) * R, (by - bh - o) * R, (bx + bw * 0.45) * R, (by - bh * 0.55 - o) * R], fill=1.0)
    stone = gaussian_filter(np.asarray(stones), 0.3 * R)
    stone_lit = gaussian_filter(np.asarray(lit_stones), 0.5 * R) * stone
    ground_all = np.maximum(ground, stone)
    v_ground = (v_ground * (1 - stone) + (0.11 + 0.17 * stone_lit) * stone) * G.look["ground_tone"]
    reeds = Image.new("F", (W, H - rW), 0.0)
    rd = ImageDraw.Draw(reeds)
    for _ in range(70):                                               # rushes in the shallows on the right
        bx = rng.uniform(300, 400)
        by = float(np.interp(bx, xx, sx)) + rng.uniform(-2, 1)
        hgt = rng.uniform(6, 22) * (1.0 - abs(bx - 350) / 140)
        lean = rng.uniform(-0.25, 0.15)
        rd.line([(bx * R, (by - o) * R), ((bx + lean * hgt) * R, (by - hgt - o) * R)], fill=1.0,
                width=max(1, int(0.35 * R)))
        rd.line([(bx * R, (by - o) * R), ((bx + lean * hgt * 0.6) * R, (by + hgt * 0.5 - o) * R)], fill=0.45,
                width=max(1, int(0.35 * R)))
    reed = gaussian_filter(np.asarray(reeds), 0.2 * R)

    water_field = within(refl, 1 - (ground_all > 0.5).astype(np.float32), 1.2 * R)
    ground_field = within(v_ground, (ground_all > 0.5).astype(np.float32), 1.2 * R)
    gangle = (-0.25 + 0.15 * knob).astype(np.float32)
    water_out = brush(water_field, rangle, rng, R, PASSES_WATER, 0.025, region=(ground_all < 0.98).astype(np.float32),
                      wobble=0.03)
    ground_out = brush(ground_field, gangle, rng, R, PASSES_GROUND, 0.06, region=ground_all, wobble=0.25)
    lower = water_out * (1 - ground_all) + ground_out * ground_all
    out[rW:] = lower * (1 - reed * 0.8) + 0.07 * reed * 0.8
    study[rW:] = refl * (1 - ground_all) + v_ground * ground_all
    angle[rW:] = np.where(ground_all > 0.5, gangle, rangle)
    glow[rW:] = rglow * (1 - ground_all)
    landmask[rW:] = ground_all
    print("  tarn")


# MARK: After the paint: stars, shafts of light, glints, falling snow (in value, before the glaze)

def after_paint(out, glow, openmask, crowd, landmask, R, rng):
    L = G.look
    H, W = out.shape
    if "stars" in L["effects"]:
        n, lo = L["stars"]
        img = Image.new("F", (W, H), 0.0)
        d = ImageDraw.Draw(img)
        sky_h = int(G.water * R) if G.lake else int(L.get("star_floor", 520) * R)
        placed = tries = 0
        while placed < n and tries < n * 40:
            tries += 1
            x, y = rng.uniform(0, W - 1), rng.uniform(0, sky_h - 1)
            if openmask[int(y), int(x)] < 0.5 or rng.uniform() > 0.35 + 0.65 * crowd[int(y), int(x)]:
                continue
            b = rng.uniform(0, 1) ** 3.2
            r = (0.22 + 0.7 * b) * R
            d.ellipse([x - r, y - r, x + r, y + r], fill=float(lo + (1 - lo) * b))
            placed += 1
        s = np.asarray(img, dtype=np.float32)
        s = np.clip(gaussian_filter(s, 0.12 * R) + 0.35 * gaussian_filter(s, 1.0 * R), 0, 1) * openmask
        out[:] = out + (1 - out) * s
        glow[:] = np.maximum(glow, s)
    if "rays" in L["effects"]:
        sx, sy, spread = L["rays"]
        _, X, Y = grid(range(0, H // 4), W // 4, R / 4)
        a = np.arctan2(Y - sy, X - sx)
        shafts = smoothstep(0.55, 1.0, 0.5 + 0.5 * np.sin(a * 9 + 3.0 * np.sin(a * 4 + 1.3)))
        shafts *= 0.5 + 0.5 * smoothstep(-0.5, 1.0, aniso(X, Y, 1.4, 120, 16, rng, octaves=2))
        fall = smoothstep(0, 60, Y - sy) * np.exp(-(np.hypot(X - sx, Y - sy) / spread) ** 2)
        if G.lake:
            fall *= smoothstep(G.water + 4, G.water - 30, Y)
        veil = resize(gaussian_filter(shafts * fall, 2.5), W, H)
        out[:] = out + (0.9 - out) * 0.26 * veil
        glow[:] = np.maximum(glow, 0.3 * veil)
    if "glints" in L["effects"]:
        gx, gy0, gy1 = L["glints"]
        img = Image.new("F", (W, H), 0.0)
        d = ImageDraw.Draw(img)
        for _ in range(260):
            y = rng.uniform(gy0, gy1)
            x = gx + rng.normal(0, 4 + 0.16 * (y - gy0))
            ln = rng.uniform(1.5, 7) * (1.4 - (y - gy0) / max(1, gy1 - gy0))
            th = rng.uniform(0.25, 0.7)
            d.ellipse([(x - ln / 2) * R, (y - th / 2) * R, (x + ln / 2) * R, (y + th / 2) * R],
                      fill=float(rng.uniform(0.4, 1)))
        s = np.clip(gaussian_filter(np.asarray(img), 0.12 * R), 0, 1) * (1 - landmask)
        out[:] = out + (1 - out) * 0.8 * s
        glow[:] = np.maximum(glow, s)
    if "snow" in L["effects"]:
        # A veil of falling snow over the distance, then flakes: many small and sharp, a few large and soft near by.
        _, X, Y = grid(range(0, H // 4), W // 4, R / 4)
        haze = resize(0.5 + 0.5 * smoothstep(-1, 1, aniso(X, Y, 1.9, 60, 20, rng, octaves=2)), W, H)
        out[:] = out + (0.62 - out) * 0.16 * haze
        for count, size, blur, alpha in ((5200, (0.22, 0.55), 0.08, 0.7), (900, (0.6, 1.1), 0.25, 0.5),
                                         (36, (1.6, 2.6), 0.9, 0.28)):
            img = Image.new("F", (W, H), 0.0)
            d = ImageDraw.Draw(img)
            for _ in range(count):
                x, y = rng.uniform(0, W), rng.uniform(0, H)
                r = rng.uniform(*size) * R
                d.ellipse([x - 1.35 * r, y - r, x + 1.35 * r, y + r * 1.6], fill=float(rng.uniform(0.6, 1)))
            s = np.clip(gaussian_filter(np.asarray(img), blur * R), 0, 1)
            out[:] = out + (0.88 - out) * alpha * s
            glow[:] = np.maximum(glow, 0.3 * s)


# MARK: Glazes (CoverLight in Shared/CoverPainting.swift, plus the hours and palettes of the variants)

def mixs(a, b, t):
    return {k: a[k] * (1 - t) + b[k] * t for k in a}


def hexs(**kw):
    return {k: hexrgb(v) for k, v in kw.items()}


DAY = hexs(s0=0x2C1810, s1=0x1E100A, m0=0x8A5F47, m1=0x946A50, l0=0xEBD1B2, l1=0xF3E1C8, glow=0xF7CDA0)
DUSK = hexs(s0=0x2A130A, s1=0x1A0B05, m0=0x8F5134, m1=0x9A5C3B, l0=0xE9B185, l1=0xF0C49A, glow=0xF4A064)
NIGHT = hexs(s0=0x0E0805, s1=0x090503, m0=0x30221A, m1=0x372820, l0=0x7E6A57, l1=0x8C7762, glow=0xF3E6CC)
GRAY = hexs(s0=0x2A211B, s1=0x1E1814, m0=0x6E6157, m1=0x776A5F, l0=0xC2B6A7, l1=0xCFC4B6, glow=0xE6DACA)

# The hour: (stops, glow strength, air). morning, golden and night are CoverLight's own mixes.
HOURS = {
    "morning": (mixs(DAY, DUSK, 0.1), 0.815, 0.212),
    "midday": (dict(DAY, l0=hexrgb(0xF2E2CC), l1=hexrgb(0xF7EBDA), m0=hexrgb(0x93694F), m1=hexrgb(0x9C7358)), 0.7, 0.15),
    "golden": (mixs(DAY, DUSK, 0.7), 0.9, 0.28),
    "night": (NIGHT, 0.9, 0.24),
    "alpenglow": (hexs(s0=0x231210, s1=0x170A08, m0=0x6C3E33, m1=0x784739, l0=0xE8B19F, l1=0xEFC2B0, glow=0xF2A28E),
                  1.0, 0.3),
    "firstlight": (hexs(s0=0x170E0A, s1=0x100906, m0=0x4C3930, m1=0x554035, l0=0xD3B99F, l1=0xDCC4AB, glow=0xF6D3A4),
                   0.95, 0.22),
    "predawn": (mixs(NIGHT, DUSK, 0.3), 0.6, 0.18),
    "bluehour": (hexs(s0=0x100F10, s1=0x0B0A0B, m0=0x3A3735, m1=0x413D3A, l0=0x9E978F, l1=0xA9A299, glow=0xDDD6CB),
                 0.7, 0.2),
    "storm": (mixs(DAY, GRAY, 0.45), 0.95, 0.18),
    "snow": (GRAY, 0.4, 0.12),
    "wet": (mixs(DAY, GRAY, 0.2), 0.95, 0.24),
}
LUMA = np.array([0.299, 0.587, 0.114])


def palette(stops, name):
    """Shifts an hour's stops within the family: deep umber (darker, richer), pale ivory (a light-mode ground: the
    darks become warm taupe, the lights ivory) or charcoal (a near-monochrome nocturne)."""
    if name == "umber":
        out = {}
        for k, c in stops.items():
            lum = c @ LUMA
            c2 = np.clip(lum + (c - lum) * 1.2, 0, 1)
            out[k] = c2 ** (1.0 if k == "glow" else 1.08 if k[0] == "l" else 1.25)
        return out
    if name == "ivory":
        return hexs(s0=0x8F7A65, s1=0x7F6A56, m0=0xC7B096, m1=0xCEB79D, l0=0xF3E8D7, l1=0xF7EEE1, glow=0xF7DCC0)
    if name == "charcoal":
        return {k: (c @ LUMA) + (c - c @ LUMA) * (0.35 if k == "glow" else 0.12) for k, c in stops.items()}
    return stops


def glaze(value, glow, R, look):
    """The widgets' three-stop gradient map (shadow, warm mid, light, each a top-to-bottom gradient), the air and the
    glow round the light, then yellowed varnish deepening to the edges."""
    H, W = value.shape
    stops, strength, air = HOURS[look["time"]]
    air = air if look.get("air") is None else look["air"]
    st = palette(stops, look["palette"])
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    shadow = st["s0"] * (1 - t) + st["s1"] * t
    mid = st["m0"] * (1 - t) + st["m1"] * t
    hi = st["l0"] * (1 - t) + st["l1"] * t
    lo_a = np.clip(value * 2, 0, 1)[..., None]
    hi_a = np.clip(value * 2 - 1, 0, 1)[..., None]
    rgb = shadow + (mid - shadow) * lo_a
    rgb = rgb + (hi - rgb) * hi_a
    cx, cy, reach = look["glow_at"]
    y = ((np.arange(H) + 0.5) / R).astype(np.float32)[:, None]
    x = ((np.arange(W) + 0.5) / R).astype(np.float32)[None, :]
    dist = np.hypot(x - cx, y - cy)
    g = st["glow"]
    a_air = (air * np.interp(dist / (reach * 0.45), [0, 0.5, 1], [1, 0.25, 0])).astype(np.float32)[..., None]
    rgb = 1 - (1 - rgb) * (1 - g * a_air)                                   # screen
    a_glow = np.interp(dist / reach, [0, 0.5, 1], [1, 0.45, 0.12]).astype(np.float32)
    rgb = rgb + (g - rgb) * (glow * a_glow * strength)[..., None]
    # A slow glaze: the lights warmed unevenly toward peach, as a glaze settles in a painting.
    rng = np.random.default_rng(7)
    patch = resize(fbm(H // 16, W // 16, rng, base=3, octaves=3), W, H)
    if look["palette"] != "charcoal":
        warm = (0.035 * smoothstep(-0.5, 1.5, patch) * hi_a[..., 0])[..., None]
        rgb = rgb + (hexrgb(0xE9B79A) * (rgb.mean(axis=2, keepdims=True) / 0.8) - rgb) * warm
    # Varnish (CoverVarnish): a warm film, darkening toward the edges.
    s = look["varnish"]
    rgb = rgb + (hexrgb(0xC09050) - rgb) * 0.05 * s
    dv = np.hypot((x - DW / 2) * 1.15, (y - DH * 0.45) * 0.85)
    vign = (0.38 * s * smoothstep(150, 470, dv)).astype(np.float32)[..., None]
    edge_c = st["s1"] * 0.8 if look["palette"] == "ivory" else hexrgb(0x1E1006)
    rgb = rgb + (edge_c - rgb) * vign
    return np.clip(rgb, 0, 1).astype(np.float32)


def moon(rgb, R, look):
    """A young crescent (lit on the right, earthshine in the rest, a halo in the cloud, a thin veil drifting over it),
    and, over the tarn, its broken path of light on the water."""
    H, W, _ = rgb.shape
    stops, _, _ = HOURS[look["time"]]
    st = palette(stops, look["palette"])
    g = st["glow"]
    cx, cy, r, k = look["moon"]
    y = ((np.arange(H) + 0.5) / R).astype(np.float32)[:, None]
    x = ((np.arange(W) + 0.5) / R).astype(np.float32)[None, :]
    dx, dy = x - cx, y - cy
    dist = np.hypot(dx, dy)
    halo = np.interp(dist / r, [0.6, 2.5, 5.5, 9], [0.42, 0.2, 0.06, 0]).astype(np.float32)
    rgb = 1 - (1 - rgb) * (1 - g * halo[..., None])
    disc = smoothstep(r + 0.7 / R, r - 0.7 / R, dist)
    rgb = rgb + (hexrgb(0x4A3A2E) - rgb) * (0.1 * gaussian_filter(disc, 0.25 * R))[..., None]
    span = np.sqrt(np.clip(r * r - dy * dy, 0, None))
    crescent = smoothstep(k * span - 0.15, k * span + 0.15, dx) * disc
    size = int(np.ceil(2 * r * R))
    tex = mt.moon(size, size, 13)
    tex_full = np.zeros_like(rgb)
    x0, y0 = int(round((cx - r) * R)), int(round((cy - r) * R))
    tex_full[y0:y0 + size, x0:x0 + size] = tex[: H - y0, : W - x0]
    lit = tex_full * hexrgb(0xF6EBD6) * 0.55 + hexrgb(0xFBF4E6) * 0.45   # lifted toward moonlit cream
    if look["palette"] == "charcoal":
        lit = lit @ LUMA[:, None] * np.ones(3) * 0.9 + lit * 0.1
    bloom = (gaussian_filter(crescent, 0.12 * r * R) * 1.2 + gaussian_filter(crescent, 0.5 * r * R) * 0.9
             + gaussian_filter(crescent, 1.2 * r * R) * 0.5)
    rgb = 1 - (1 - rgb) * (1 - g * np.clip(bloom, 0, 1)[..., None] * 0.8)
    rgb = rgb + (lit - rgb) * crescent[..., None]
    veil = np.exp(-(((dx - 0.5 * r) / (2.1 * r)) ** 4) - ((dy - 0.5 * r) / (0.58 * r)) ** 2)
    rgb = rgb + (st["l0"] - rgb) * (0.45 * veil)[..., None]
    if look["ground"] == "lake":
        rng = np.random.default_rng(11)
        path = Image.new("F", (W, H), 0.0)
        pd = ImageDraw.Draw(path)
        water = look["summit"][1] + (1168.0 - SYP) * look["scale"]
        my = 2 * water - cy
        for _ in range(220):
            yy = rng.uniform(water + 2, 712)
            xx = cx + rng.normal(0, (3 + 0.12 * (yy - water)) * 0.45)
            near = np.exp(-((yy - my) / 70) ** 2)
            ln, th = rng.uniform(2, 8) * (0.6 + near), rng.uniform(0.3, 0.8)
            pd.ellipse([(xx - ln / 2) * R, (yy - th / 2) * R, (xx + ln / 2) * R, (yy + th / 2) * R],
                       fill=float(rng.uniform(0.25, 0.8) * (0.35 + 0.65 * near)))
        glit = gaussian_filter(np.asarray(path), 0.15 * R)
        rgb = 1 - (1 - rgb) * (1 - g * np.clip(glit, 0, 1)[..., None] * 0.55)
    return np.clip(rgb, 0, 1).astype(np.float32)


# MARK: The surface of an old canvas, at the screen's own pixels

def craquelure(w, h, ppt, seed, opacity):
    """CoverCraquelure: cracks on a jittered 7 pt grid, a dark hairline with a lit lower lip. Returns two masks."""
    rng = np.random.default_rng(seed)
    k = 2
    cell = 7 * ppt * k
    cols, rows = int(w * k / cell) + 2, int(h * k / (cell * 0.85)) + 2
    gx = (np.arange(cols)[None, :] - 0.5 + rng.uniform(-0.38, 0.38, (rows, cols))) * cell
    gy = (np.arange(rows)[:, None] - 0.5 + rng.uniform(-0.38, 0.38, (rows, cols))) * cell * 0.85
    dark = Image.new("L", (w * k, h * k), 0)
    lit = Image.new("L", (w * k, h * k), 0)
    dd, ld = ImageDraw.Draw(dark), ImageDraw.Draw(lit)
    off = (0.25 * ppt * k, 0.33 * ppt * k)
    lw_d, lw_l = max(1, int(round(0.3 * ppt * k))), max(1, int(round(0.25 * ppt * k)))
    for r in range(rows):
        for c in range(cols):
            for (r2, c2, p) in ((r, c + 1, 0.1), (r + 1, c, 0.18)):
                if r2 >= rows or c2 >= cols or rng.uniform() <= p:
                    continue
                a, b = (gx[r, c], gy[r, c]), (gx[r2, c2], gy[r2, c2])
                m = ((a[0] + b[0]) / 2 + rng.uniform(-1, 1) * cell * 0.14,
                     (a[1] + b[1]) / 2 + rng.uniform(-1, 1) * cell * 0.14)
                dd.line([a, m, b], fill=255, width=lw_d)
                ld.line([(p_[0] + off[0], p_[1] + off[1]) for p_ in (a, m, b)], fill=255, width=lw_l)
    dm = np.asarray(dark.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
    lm = np.asarray(lit.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
    return dm * 0.075 * opacity, lm * 0.035 * opacity


def weave(w, h, ppt, opacity=0.8):
    """CanvasWeave: the canvas under the paint, a faint woven grid with a 1.7 pt pitch."""
    def bands(n):
        sub = (np.arange(n * 8) + 0.5) / 8 / ppt          # 8 samples per pixel, in pt
        i = np.floor(sub / 1.7)
        return (sub - i * 1.7) < 0.5, i
    on_r, i_r = bands(h)
    dark_r = (on_r & (i_r % 2 == 0)).reshape(h, 8).mean(axis=1)
    lit_r = (on_r & (i_r % 2 == 1)).reshape(h, 8).mean(axis=1)
    on_c, _ = bands(w)
    col = on_c.reshape(w, 8).mean(axis=1)
    return (dark_r * 0.04 * opacity)[:, None], (lit_r * 0.015 * opacity)[:, None], (col * 0.03 * opacity)[None, :]


def finish(rgb_master, w, h, look):
    """The master filtered to a screen's pixels (scaled to cover, centred), then the canvas surface laid over it."""
    H, W, _ = rgb_master.shape
    s = max(w / W, h / H)
    sw, sh = int(round(W * s)), int(round(H * s))
    chans = [resize(rgb_master[..., i], sw, sh, Image.LANCZOS) for i in range(3)]
    x0, y0 = (sw - w) // 2, (sh - h) // 2
    rgb = np.stack([c[y0:y0 + h, x0:x0 + w] for c in chans], axis=2)
    ppt = 3.0   # both screens are 3x
    night = look["time"] in ("night", "predawn", "bluehour")
    seed = 6 if look is DEFAULT_NIGHT else 5 if look is DEFAULT else look["seed"] % 97
    dark, lit = craquelure(w, h, ppt, seed, 0.7 if night else 1.0)
    rgb = rgb + (hexrgb(0x0D0805) - rgb) * dark[..., None]
    rgb = rgb + (hexrgb(0xF1E3CC) - rgb) * lit[..., None]
    dr, lr, dc = weave(w, h, ppt)
    rgb = rgb * (1 - dr[..., None]) * (1 - dc[..., None])
    rgb = rgb + (hexrgb(0xF1D9A8) - rgb) * lr[..., None]
    if look.get("frame"):
        rgb = gilt_frame(rgb, ppt, look)
    return np.clip(rgb, 0, 1)


def gilt_frame(rgb, ppt, look):
    """A painted gilt frame round the screen's own rounded corners: a rounded moulding of gold leaf with a bright
    bead, a dark groove and a thin shadow cast onto the picture; and a brass plate engraved with the mountain's name."""
    h, w, _ = rgb.shape
    band, radius = 8.0 * ppt, 54.0 * ppt
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    qx = np.maximum(np.maximum(radius - xx, xx - (w - radius)), 0)
    qy = np.maximum(np.maximum(radius - yy, yy - (h - radius)), 0)
    inset = np.where((qx > 0) & (qy > 0), radius - np.hypot(qx, qy),
                     np.minimum(np.minimum(xx, w - xx), np.minimum(yy, h - yy)))   # inward from the rounded edge
    t = np.clip(inset / band, 0, 1.6)
    on = smoothstep(1.0 + 0.5 / band, 1.0 - 0.5 / band, t)
    rng = np.random.default_rng(look["seed"] + 1)
    brushed = resize(fbm(h // 6, w // 6, rng, base=40, octaves=3, stretch=4.0), w, h) * 0.5
    gild = hexrgb(0xF8E4BC) * (1 - yy / h)[..., None] + hexrgb(0xC68E55) * (yy / h)[..., None]
    mould = 0.62 + 0.38 * np.clip(np.sin(np.pi * np.clip(t, 0, 1)), 0, 1) ** 0.7
    mould += 0.25 * np.exp(-((t - 0.32) / 0.06) ** 2) - 0.35 * np.exp(-((t - 0.78) / 0.07) ** 2)
    frame = np.clip(gild * (mould + 0.06 * brushed)[..., None], 0, 1)
    frame = frame * (1 - 0.5 * np.exp(-((t - 0.98) / 0.05) ** 2))[..., None]
    shadow = np.exp(-np.clip(inset - band, 0, None) / (2.5 * ppt)) * (1 - on) * 0.45
    rgb = rgb * (1 - shadow[..., None]) + hexrgb(0x0D0805) * shadow[..., None]
    rgb = rgb * (1 - on[..., None]) + frame * on[..., None]
    if look.get("plate"):
        img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
        d = ImageDraw.Draw(img, "RGBA")
        pw, ph, cy = 150 * ppt, 21 * ppt, look["plate"] * ppt
        box = [w / 2 - pw / 2, cy - ph / 2, w / 2 + pw / 2, cy + ph / 2]
        d.rounded_rectangle([box[0] + 2, box[1] + 5, box[2] + 2, box[3] + 5], 3 * ppt, fill=(13, 8, 5, 110))
        grad = np.linspace(0, 1, int(ph))[:, None, None]
        brass = (hexrgb(0xEED39E) * (1 - grad) + hexrgb(0xA97A45) * grad) * np.ones((1, int(pw), 1))
        plate = Image.fromarray((np.clip(brass, 0, 1) * 255).astype(np.uint8), "RGB")
        mask = Image.new("L", plate.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, plate.size[0] - 1, plate.size[1] - 1], 3 * ppt, fill=255)
        img.paste(plate, (int(box[0]), int(box[1])), mask)
        d.rounded_rectangle(box, 3 * ppt, outline=(255, 240, 210, 150), width=2)
        d.rounded_rectangle([box[0] + 2.5 * ppt, box[1] + 2.5 * ppt, box[2] - 2.5 * ppt, box[3] - 2.5 * ppt], 2 * ppt,
                            outline=(90, 60, 30, 120), width=2)
        font = ImageFont.truetype(BASKERVILLE, int(11.5 * ppt), index=2)
        text = "Matterhorn · 14,692 ft"
        d.text((w / 2, cy + 1.6), text, font=font, fill=(255, 244, 220, 140), anchor="mm")
        d.text((w / 2, cy), text, font=font, fill=(58, 36, 20, 235), anchor="mm")
        rgb = np.asarray(img, dtype=np.float32) / 255
    return rgb


def save_png(path, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT)}: {rgb.shape[1]}x{rgb.shape[0]}, {os.path.getsize(path) / 1e6:.1f} MB")


# MARK: The looks

BASE = dict(
    title="", seed=2026,
    summit=(194.0, 300.0), scale=0.29,      # where the summit stands (pt) and pt per photo pixel
    ground="lake",                          # lake | land (meadow, ridge and trees as given)
    shore=[(-10, 708), (40, 722), (90, 734), (130, 730), (160, 741), (210, 748), (260, 746), (300, 738), (340, 733),
           (372, 729), (412, 724)],         # the tarn's near shore (pt)
    meadow=None, ridge=None, trees=(),      # the near ground without the tarn (pt keys; stands for forest())
    fog=None, fogtone=1.0,                  # top of a sea of cloud (pt) and its brightness
    mist=None,                              # low mist after rain: [(y, depth, amount)] in pt
    sky=(0.13, 0.58), breakglow=1.0, deep_right=0.07, canopy=0.035,
    light=(84.0, 382.0),                    # the luminous break in the sky
    sun=(-0.5, -0.62, 0.6),                 # light on the clouds
    clouds=(),                              # cumulus masses (centre x, base, width, height, billows, tone) in pt
    effects=(), banner=(230, -0.06), milkyway=0.18, stars=(900, 0.35), rays=None, glints=None,
    alpenglow=None,                         # photo y of the earth's shadow on the mountain
    snow=1.0, mountain=1.0, ground_tone=1.0,
    time="morning", palette="sepia", varnish=1.0,
    glow_at=(40.0, 330.0, 520.0),           # where the glow and the air come from (pt) and how far they reach
    moon=None,                              # (x, y, radius, terminator) in pt
    air=None,                               # the glow of the air round the light (None: the hour's own)
    key=(1.32, 1.08, 0.12),                 # contrast, gamma and lift of the lights
    frame=False, plate=None,
)

CANOPY = [(110, 96, 420, 120, 260, 0.34), (340, 80, 340, 100, 220, 0.3)]
TOP_ROW = CANOPY + [(206, 132, 230, 58, 160, 0.62), (30, 160, 210, 90, 220, 1.0), (382, 148, 160, 80, 180, 0.95)]
HORIZON = [(352, 484, 280, 165, 210, 0.7), (392, 476, 130, 66, 110, 1.0), (24, 489, 120, 40, 60, 0.9),
           (266, 486, 76, 22, 40, 0.85)]
SMALL_HORIZON = [(24, 489, 120, 34, 60, 0.9), (332, 487, 110, 26, 50, 0.85), (392, 486, 70, 18, 30, 0.8)]


def look(**kw):
    out = dict(BASE)
    out.update(kw)
    return out


DEFAULT = look(title="Morning gold", clouds=TOP_ROW + HORIZON)
DEFAULT_NIGHT = dict(DEFAULT, title="Moonlit", time="night", varnish=0.8, glow_at=(84.0, 382.0, 420.0),
                     moon=(84.0, 382.0, 11.0, 0.55))


def stands(larch=True):
    """The forest framing: tall pines at both sides rising toward the edges, a low dark wood across the foot of the
    picture under the dock, and larches standing out on the meadow."""
    out = [dict(kind="pine", x=(-40, 100), base=(850, 880), height=(260, 420), n=14, rise=-0.7),
           dict(kind="pine", x=(300, 440), base=(846, 876), height=(240, 400), n=14, rise=0.7),
           dict(kind="pine", x=(-20, 420), base=(870, 900), height=(120, 230), n=54)]
    if larch:
        out[:0] = [dict(kind="larch", x=(70, 160), base=(640, 700), height=(50, 100), n=6, rise=-0.5),
                   dict(kind="larch", x=(250, 340), base=(630, 690), height=(45, 95), n=6, rise=0.5)]
    return out


MEADOW = [(-10, 452), (60, 458), (130, 466), (200, 470), (270, 462), (340, 455), (412, 448)]
LOW_MEADOW = [(-10, 718), (80, 726), (180, 730), (260, 724), (340, 720), (412, 716)]

# (slug, look, description, best use). 01 and 02 are the default pair.
LOOKS = [
    ("01-morning-gold-lake", DEFAULT, "Morning gold over the Riffelsee: the default day wallpaper.", "both"),
    ("02-moonlit-lake", DEFAULT_NIGHT, "A young crescent over the tarn, the peak pale in the dark: the default night.",
     "lock"),
    ("03-alpenglow-lake", look(
        title="Alpenglow", air=0.1, time="alpenglow", alpenglow=830, clouds=SMALL_HORIZON, effects=("stars",),
        stars=(260, 0.25), sky=(0.1, 0.42), breakglow=0.5, light=(320.0, 330.0), glow_at=(194.0, 330.0, 300.0),
        key=(1.36, 1.1, 0.14), seed=303),
     "The summit burning rose while the valley and the tarn have gone into shadow.", "both"),
    ("04-alpenglow-close", look(
        title="Alpenglow, close", air=0.1, time="alpenglow", alpenglow=700, summit=(196.0, 286.0), scale=0.66,
        ground="land", fog=600, fogtone=0.62, clouds=[], sky=(0.1, 0.4), breakglow=0.4, light=(330.0, 300.0),
        glow_at=(196.0, 300.0, 260.0), effects=("stars",), stars=(220, 0.25), seed=404,
        ridge=[(-10, 790), (80, 800), (200, 812), (320, 804), (412, 792)]),
     "The pyramid large and burning in the last light above a sea of cloud already in shade.", "lock"),
    ("05-banner-cloud-close", look(
        title="Banner cloud, close", time="midday", summit=(168.0, 300.0), scale=0.62, ground="land", fog=620,
        fogtone=0.95, effects=("banner",), banner=(330, -0.05), clouds=[(380, 168, 160, 70, 140, 0.62)],
        sky=(0.2, 0.6), breakglow=0.6, light=(60.0, 380.0), glow_at=(60.0, 300.0, 520.0), seed=505,
        ridge=[(-10, 800), (120, 812), (260, 806), (412, 796)]),
     "The famous plume streaming off the summit to leeward, the peak close and the valley under cloud.", "lock"),
    ("06-banner-cloud-lake", look(
        title="Banner cloud, golden hour", time="golden", effects=("banner",), banner=(260, -0.04),
        clouds=SMALL_HORIZON + [(60, 150, 200, 60, 140, 0.8)], seed=606),
     "Golden hour on the tarn, the banner cloud trailing from the summit across the sky.", "both"),
    ("07-lenticular-forest", look(
        title="Lenticular cap", time="golden", ground="land", effects=("lenticular",), meadow=MEADOW,
        trees=stands(), clouds=SMALL_HORIZON[:1], sky=(0.16, 0.6), seed=707),
     "A smooth lenticular cap hovering on the summit at golden hour, larch and pine framing the meadow.", "both"),
    ("08-sea-of-cloud-first-light", look(
        title="First light, sea of cloud", time="firstlight", alpenglow=700, ground="land", fog=430,
        fogtone=0.8, clouds=[], sky=(0.1, 0.5), breakglow=0.7, light=(120.0, 400.0), glow_at=(194.0, 300.0, 320.0),
        effects=("stars",), stars=(160, 0.2), seed=808, ridge=[(-10, 812), (100, 820), (250, 826), (412, 810)]),
     "Only the summit catches the first light; the valleys lie under a sea of cloud.", "both"),
    ("09-storm-break-umber", look(
        title="Storm breaking", time="storm", palette="umber", sky=(0.1, 0.42), breakglow=1.3, light=(150.0, 250.0),
        clouds=[(40, 250, 300, 170, 300, 0.42), (330, 280, 320, 220, 320, 0.4), (200, 120, 460, 110, 240, 0.32),
                (380, 470, 200, 120, 200, 0.5)],
        effects=("rays",), rays=(150.0, 250.0, 520.0), glow_at=(150.0, 260.0, 520.0), key=(1.42, 1.1, 0.14),
        seed=909),
     "Heavy storm cloud in deep umber, light breaking through in shafts onto the peak and the tarn.", "both"),
    ("10-milky-way-charcoal", look(
        title="Milky Way", time="night", palette="charcoal", clouds=[], effects=("milkyway", "stars"),
        milkyway=0.3, stars=(1600, 0.3), sky=(0.07, 0.28), breakglow=0.2, canopy=0.0, glow_at=(200.0, 300.0, 500.0),
        varnish=0.8, mountain=0.78, seed=1010),
     "A charcoal nocturne: the Milky Way arching over the peak, stars on the still tarn.", "lock"),
    ("11-predawn-forest", look(
        title="Before dawn", time="predawn", ground="land", meadow=MEADOW, trees=stands(),
        clouds=SMALL_HORIZON[:2], effects=("stars",), stars=(500, 0.25), sky=(0.08, 0.4), breakglow=0.6,
        light=(330.0, 440.0), glow_at=(320.0, 420.0, 420.0), mountain=0.85, varnish=0.8, seed=1111),
     "The last stars over larch and pine, a pale glow behind the ridge, the peak waiting for the sun.", "both"),
    ("12-first-light-forest", look(
        title="First light", time="firstlight", alpenglow=710, ground="land", meadow=MEADOW, trees=stands(),
        clouds=[(330, 170, 200, 40, 120, 0.7)], sky=(0.1, 0.5), breakglow=0.6, glow_at=(194.0, 300.0, 300.0),
        seed=1212),
     "The first sun lighting only the summit while the meadow and forest are still in blue shadow.", "both"),
    ("13-midday-ivory-lake", look(
        title="Midday, ivory", time="midday", palette="ivory", clouds=TOP_ROW + SMALL_HORIZON,
        sky=(0.3, 0.7), breakglow=0.6, key=(1.2, 1.0, 0.1), varnish=0.6, seed=1313),
     "A light-mode wallpaper: bright midday in pale ivory and cream.", "home"),
    ("14-towering-cumulus-low", look(
        title="Towering cumulus", summit=(212.0, 606.0), scale=0.22, ground="land", meadow=LOW_MEADOW,
        trees=[dict(kind="pine", x=(-30, 80), base=(800, 840), height=(120, 210), n=10, rise=-0.8),
               dict(kind="pine", x=(320, 430), base=(796, 836), height=(110, 200), n=10, rise=0.8),
               dict(kind="larch", x=(60, 140), base=(792, 810), height=(50, 90), n=5, rise=-0.5)],
        clouds=[(110, 560, 260, 300, 340, 0.95), (330, 590, 230, 360, 360, 0.9), (210, 300, 300, 120, 220, 0.75),
                (60, 230, 200, 90, 160, 0.7), (360, 200, 160, 70, 130, 0.65)],
        sky=(0.14, 0.62), light=(210.0, 520.0), breakglow=0.6, glow_at=(120.0, 400.0, 600.0), seed=1414),
     "The peak low between the widgets, towering cumulus filling the sky above it.", "home"),
    ("15-tiny-peak-vast-sky", look(
        title="Under a vast sky", summit=(250.0, 690.0), scale=0.11, ground="land",
        ridge=[(-10, 742), (90, 752), (200, 758), (300, 752), (412, 744)],
        clouds=[(80, 250, 260, 120, 240, 0.85), (320, 330, 260, 150, 260, 0.95), (180, 480, 340, 170, 300, 0.85),
                (40, 620, 220, 90, 180, 0.8), (380, 650, 180, 80, 160, 0.75), (220, 120, 360, 60, 160, 0.6)],
        sky=(0.14, 0.62), light=(250.0, 600.0), breakglow=0.7, glow_at=(250.0, 560.0, 600.0), seed=1515),
     "The Matterhorn tiny on the horizon, a whole sky of cumulus above it.", "both"),
    ("16-falling-snow-forest", look(
        title="Falling snow", time="snow", ground="land", meadow=MEADOW, trees=stands(larch=False),
        clouds=[(100, 230, 420, 140, 260, 0.6), (320, 320, 400, 150, 260, 0.58), (200, 430, 440, 110, 240, 0.64)],
        effects=("snow",), sky=(0.32, 0.6), breakglow=0.3, canopy=0.02, key=(1.15, 1.05, 0.1), snow=1.3,
        glow_at=(200.0, 300.0, 600.0), seed=1616),
     "Snow falling through the forest, the peak softened in grey overcast.", "both"),
    ("17-clearing-rain-lake", look(
        title="Clearing after rain", time="wet",
        clouds=CANOPY + [(70, 168, 220, 76, 220, 0.8), (340, 214, 190, 64, 190, 0.72), (190, 270, 140, 40, 130, 0.85),
                         (390, 330, 120, 34, 100, 0.9)] + SMALL_HORIZON,
        mist=[(448.0, 12.0, 0.85), (472.0, 8.0, 0.75)], effects=("glints",), glints=(84.0, 492.0, 700.0),
        sky=(0.16, 0.62), breakglow=1.2, seed=1717),
     "Wet light after rain: breaking cloud, mist lying along the slopes, glints on the tarn.", "both"),
    ("18-blue-hour-lake", look(
        title="Blue hour", time="bluehour", clouds=SMALL_HORIZON, effects=("stars",), stars=(90, 0.2),
        sky=(0.12, 0.55), breakglow=0.5, light=(300.0, 450.0), glow_at=(300.0, 450.0, 400.0), varnish=0.8, seed=1818),
     "The cool hour after sunset: the tarn still, a first star, the peak grey against the afterglow.", "lock"),
    ("19-golden-hour-meadow-low", look(
        title="Golden hour, low", time="golden", summit=(212.0, 606.0), scale=0.22, ground="land",
        meadow=LOW_MEADOW, trees=[dict(kind="larch", x=(-20, 90), base=(796, 830), height=(100, 190), n=8, rise=-0.8),
                                  dict(kind="pine", x=(310, 430), base=(792, 830), height=(120, 220), n=10, rise=0.8),
                                  dict(kind="pine", x=(-30, 40), base=(820, 850), height=(180, 260), n=4)],
        clouds=[(90, 300, 240, 110, 220, 0.85), (330, 372, 220, 100, 200, 0.8), (210, 520, 280, 90, 220, 0.9)],
        sky=(0.16, 0.66), light=(80.0, 520.0), glow_at=(80.0, 520.0, 560.0), seed=1919),
     "Golden hour with the peak low between the widgets, larches lit at the edge of the meadow.", "home"),
    ("20-charcoal-moon-close", look(
        title="Nocturne, close", air=0.1, time="night", palette="charcoal", summit=(200.0, 300.0), scale=0.66,
        ground="land", fog=610, fogtone=0.55, clouds=[(60, 170, 220, 60, 160, 0.5)], sky=(0.1, 0.36),
        light=(76.0, 330.0), glow_at=(76.0, 330.0, 420.0), moon=(76.0, 330.0, 10.0, 0.55), effects=("stars",),
        stars=(260, 0.25), varnish=0.8, seed=2020, ridge=[(-10, 800), (150, 812), (300, 806), (412, 796)]),
     "A charcoal nocturne: the pyramid close under a crescent, cloud filling the valley.", "lock"),
    ("21-umber-towering-lake", look(
        title="Towering cumulus, umber", palette="umber", time="morning",
        clouds=[(335, 486, 280, 330, 380, 0.95), (55, 488, 200, 220, 280, 0.85), (200, 120, 420, 80, 200, 0.5)],
        sky=(0.12, 0.56), key=(1.4, 1.08, 0.14), seed=2121),
     "Deep umber: cumulus towering behind the peak and its reflection.", "both"),
    ("22-ivory-sea-of-cloud", look(
        title="Sea of cloud, ivory", time="midday", palette="ivory", ground="land", fog=440,
        clouds=[(300, 160, 200, 40, 120, 0.8)], sky=(0.34, 0.72), breakglow=0.6, key=(1.18, 0.98, 0.1), varnish=0.6,
        ridge=[(-10, 818), (130, 826), (280, 822), (412, 812)], seed=2222),
     "A light-mode wallpaper: the peak above a sea of cloud in ivory and cream.", "home"),
    ("23-gilt-frame-alpenglow", look(
        title="Alpenglow, gilt frame", air=0.1, time="alpenglow", alpenglow=830, clouds=SMALL_HORIZON,
        sky=(0.1, 0.42), breakglow=0.5, light=(320.0, 330.0), glow_at=(194.0, 330.0, 300.0), key=(1.36, 1.1, 0.14),
        frame=True, plate=818, seed=2323),
     "Alpenglow on the tarn in a painted gilt frame with an engraved plate: Matterhorn · 14,692 ft.", "lock"),
    ("24-starry-low", look(
        title="Stars over the low peak", time="night", summit=(212.0, 606.0), scale=0.22, ground="land",
        meadow=LOW_MEADOW, trees=[dict(kind="pine", x=(-30, 90), base=(800, 840), height=(130, 230), n=11, rise=-0.8),
                                  dict(kind="pine", x=(310, 430), base=(796, 836), height=(120, 220), n=10, rise=0.8)],
        clouds=[], effects=("milkyway", "stars"), milkyway=0.32, stars=(1500, 0.3), star_floor=700, sky=(0.06, 0.3),
        breakglow=0.25, canopy=0.0, glow_at=(212.0, 600.0, 520.0), mountain=0.85, varnish=0.8, seed=2424),
     "The Milky Way over the whole sky, the peak low between the widgets, pines black at the sides.", "home"),
]


# MARK: Previews

def sf(size, weight=400, width=100):
    f = ImageFont.truetype(SFNS, int(round(size)))
    try:
        f.set_variation_by_axes([width, min(96, max(17, size / 3)), 400, weight])
    except Exception:
        pass
    return f


def glass(img, box, radius, tint=(255, 255, 255, 46)):
    """A frosted glass shape (the dock, the search pill, the lock screen's buttons)."""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    region = img.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(24))
    region = Image.blend(region, Image.new("RGB", region.size, tint[:3]), tint[3] / 255)
    sheen = np.linspace(0.16, 0.0, region.size[1])[:, None, None] ** 1.5 / 0.16 ** 0.5   # across the top
    arr = np.asarray(region, dtype=np.float32)
    region = Image.fromarray(np.clip(arr + (255 - arr) * sheen, 0, 255).astype(np.uint8), "RGB")
    mask = Image.new("L", region.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, x1 - x0 - 1, y1 - y0 - 1], radius, fill=255)
    img.paste(region, (x0, y0), mask)
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius, outline=(255, 255, 255, 70), width=2)


def preview_home(wall):
    """The day wallpaper on the home screen with the Old Master Cover renders where iOS puts them."""
    img = Image.fromarray((wall * 255 + 0.5).astype(np.uint8), "RGB").convert("RGBA")
    w, h = img.size
    placed = [("day-large", 82, 270), ("quote-small", 82, 1474), ("day-small", 632, 1474)]
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    widgets = []
    for name, x, y in placed:
        wimg = Image.open(os.path.join(WIDGETS, name + ".png")).convert("RGBA")
        widgets.append((wimg, x, y))
        sh = Image.new("RGBA", wimg.size, (10, 6, 3, 0))
        sh.putalpha(wimg.split()[3].point(lambda v: int(v * 0.5)))
        shadow.alpha_composite(sh, (x, y + 18))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    for wimg, x, y in widgets:
        img.alpha_composite(wimg, (x, y))
    rgb = img.convert("RGB")
    d = ImageDraw.Draw(rgb, "RGBA")
    label = sf(13 * 3, 500)
    for wimg, x, y in widgets:
        cx, ty = x + wimg.size[0] / 2, y + wimg.size[1] + 40
        d.text((cx + 1, ty + 2), "Baroque", font=label, fill=(0, 0, 0, 90), anchor="mm")
        d.text((cx, ty), "Baroque", font=label, fill=(255, 255, 255, 235), anchor="mm")
    d.text((216, 98), "10:28", font=sf(17 * 3, 600), fill=(255, 255, 255, 255), anchor="mm")
    d.rounded_rectangle([1003, 80, 1072, 114], 10, outline=(255, 255, 255, 255), width=4)
    d.rounded_rectangle([1010, 87, 1065, 107], 6, fill=(255, 255, 255, 255))
    d.rounded_rectangle([1076, 90, 1081, 104], 2, fill=(255, 255, 255, 160))
    glass(rgb, (488, 2110, 718, 2196), 43)
    d = ImageDraw.Draw(rgb, "RGBA")
    d.ellipse([523, 2136, 547, 2160], outline=(255, 255, 255, 230), width=5)
    d.line([(544, 2157), (555, 2168)], fill=(255, 255, 255, 230), width=6)
    word = sf(15 * 3, 500)
    word = sf(15 * 3 * 122 / d.textlength("Search", font=word), 500)
    d.text((572, 2153), "Search", font=word, fill=(255, 255, 255, 235), anchor="lm")
    glass(rgb, (52, 2226, 1155, 2532), 120, (255, 255, 255, 22))
    path = os.path.join(OUT, "preview-home.png")
    rgb.save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT)}: {w}x{h}, {os.path.getsize(path) / 1e6:.1f} MB")


def peak_mask(w, h):
    """The default framing's mountain at a screen's pixels, down to where the hills close in: the lock screen's
    depth effect puts it in front of the clock."""
    use(DEFAULT)
    R = w / DW
    x = ((np.arange(w) + 0.5) / R).astype(np.float32)
    Y = ((np.arange(h) + 0.5) / R).astype(np.float32)[:, None]
    return crest_cover(Y, massif_crest(x), R) * (Y < 380)


def preview_lock(wall, peak):
    """The night wallpaper on the lock screen: date line and clock in SF, the clock's foot tucked behind the summit
    as iOS's depth effect does it."""
    img = Image.fromarray((wall * 255 + 0.5).astype(np.uint8), "RGB").convert("RGBA")
    w, h = img.size
    base = img.copy()
    p = 3.0
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((w / 2, 128 * p), "Tuesday, November 3", font=sf(21 * p, 590), fill=(255, 255, 255, 225), anchor="mm")
    clock = sf(200 * p, 600, 66)                    # SF condensed and tall, filling 150..322 pt down to the summit
    box = d.textbbox((0, 0), "10:28", font=clock, anchor="ls")
    tw, th = box[2] - box[0], box[3] - box[1]
    timg = Image.new("L", (tw + 40, th + 40), 0)
    ImageDraw.Draw(timg).text((20 - box[0], 20 - box[1]), "10:28", font=clock, fill=255, anchor="ls")
    target_h = (322 - 150) * p
    timg = timg.resize((int((tw + 40) * 300 * p / tw), int((th + 40) * target_h / th)), Image.LANCZOS)
    ox, oy = int(w / 2 - timg.size[0] / 2), int(150 * p - 20 * target_h / th)
    white = Image.new("RGBA", timg.size, (255, 255, 255, 0))
    white.putalpha(timg.point(lambda v: int(v * 0.93)))
    soft = Image.new("RGBA", timg.size, (20, 12, 6, 0))
    soft.putalpha(timg.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.25)))
    layer.alpha_composite(soft, (ox, oy + 4))
    layer.alpha_composite(white, (ox, oy))
    img.alpha_composite(layer)
    img.paste(base, (0, 0), Image.fromarray((np.clip(peak, 0, 1) * 255).astype(np.uint8), "L"))   # depth effect
    rgb = img.convert("RGB")
    for cx in (70 * p, (402 - 70) * p):
        glass(rgb, (cx - 25 * p, 787 * p - 25 * p, cx + 25 * p, 787 * p + 25 * p), 25 * p, (20, 14, 10, 80))
    d = ImageDraw.Draw(rgb, "RGBA")
    fx, fy = 70 * p, 787 * p
    d.rounded_rectangle([fx - 12, fy - 32, fx + 12, fy + 34], 8, outline=(255, 255, 255, 235), width=5)
    d.line([(fx - 12, fy - 12), (fx + 12, fy - 12)], fill=(255, 255, 255, 235), width=5)
    cx, cy = (402 - 70) * p, 787 * p
    d.rounded_rectangle([cx - 34, cy - 22, cx + 34, cy + 26], 9, outline=(255, 255, 255, 235), width=5)
    d.ellipse([cx - 12, cy - 10, cx + 12, cy + 14], outline=(255, 255, 255, 235), width=5)
    d.rounded_rectangle([cx - 14, cy - 30, cx + 10, cy - 22], 3, fill=(255, 255, 255, 235))
    d.rounded_rectangle([w / 2 - 67 * p, 862 * p, w / 2 + 67 * p, 867 * p], 3 * p, fill=(255, 255, 255, 235))
    path = os.path.join(OUT, "preview-lock.png")
    rgb.save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT)}: {w}x{h}, {os.path.getsize(path) / 1e6:.1f} MB")


def previews(which):
    """The previews, from the default pair already written to OUT."""
    w, h = SIZES[0]

    def load(name):
        path = os.path.join(OUT, f"baroque-matterhorn-{name}-{w}x{h}.png")
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255

    if "home" in which:
        preview_home(load("day"))
    if "lock" in which:
        preview_lock(load("night"), peak_mask(w, h))


# MARK: Variants

def contact_sheet(folder, entries):
    """All the variants as labelled thumbnails, six to a row."""
    tw, th, pad, cols = 240, 522, 18, 6
    rows = (len(entries) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + 64 + pad) + pad), (24, 16, 11))
    d = ImageDraw.Draw(sheet)
    font, small = sf(17, 600), sf(13, 400)
    for i, (slug, meta) in enumerate(entries):
        img = Image.open(os.path.join(folder, slug + ".png")).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = pad + (i % cols) * (tw + pad), pad + (i // cols) * (th + 64 + pad)
        sheet.paste(img, (x, y))
        num, rest = slug.split("-", 1)
        d.text((x, y + th + 8), f"{num}  {meta['title']}", font=font, fill=(241, 227, 204))
        d.text((x, y + th + 33), f"{rest}  ·  {meta['use']}", font=small, fill=(188, 169, 141))
    path = os.path.join(folder, "contact-sheet.jpg")
    sheet.save(path, quality=88)
    print(f"{os.path.relpath(path, ROOT)}: {sheet.size[0]}x{sheet.size[1]}")


def run_variants(names, scale):
    """Paints the variants named (by slug or number; all if none) to OUT/variants, then rewrites the sheet and json
    for every variant present there."""
    folder = os.path.join(OUT, "variants")
    os.makedirs(folder, exist_ok=True)
    wanted = [e for e in LOOKS if not names or e[0] in names or e[0].split("-")[0] in names]
    w, h = SIZES[0]
    shared = None
    for slug, lk, desc, use_ in wanted:
        print(slug)
        if lk is DEFAULT or lk is DEFAULT_NIGHT:
            shared = shared or paint(DEFAULT, VARIANT_W * scale)
            value, glow, R = shared
        else:
            value, glow, R = paint(lk, VARIANT_W * scale)
        rgb = glaze(value, glow, R, lk)
        if lk["moon"]:
            rgb = moon(rgb, R, lk)
        save_png(os.path.join(folder, slug + ".png"), finish(rgb, w, h, lk))
    entries = [(slug, {"slug": slug, "title": lk["title"], "description": desc, "use": use_})
               for slug, lk, desc, use_ in LOOKS if os.path.exists(os.path.join(folder, slug + ".png"))]
    with open(os.path.join(folder, "variants.json"), "w") as f:
        json.dump([m for _, m in entries], f, indent=2, ensure_ascii=False)
    contact_sheet(folder, entries)


# MARK: Main

def main():
    global OUT
    args = sys.argv[1:]
    if "--trace" in args:
        copy_trace(args[args.index("--trace") + 1])
        return
    scale = float(args[args.index("--draft") + 1]) if "--draft" in args else 1.0
    if "--out" in args:
        OUT = args[args.index("--out") + 1]
    flags = {a for a in args if a.startswith("--")}
    values = {args[args.index(k) + 1] for k in ("--draft", "--out") if k in args}
    names = [a for a in args if not a.startswith("--") and a not in values]
    os.makedirs(OUT, exist_ok=True)
    if "--previews-only" in flags:
        previews([a for a in names if a in ("home", "lock")] or ["home", "lock"])
        return
    if "--variants" in flags:
        run_variants(names, scale)
        return
    print(f"painting the defaults at {scale:g} x master ({int(round(MASTER_W * scale))} px wide)")
    value, glow, R = paint(DEFAULT, MASTER_W * scale)
    for lk, name in ((DEFAULT, "day"), (DEFAULT_NIGHT, "night")):
        rgb = glaze(value, glow, R, lk)
        if lk["moon"]:
            rgb = moon(rgb, R, lk)
        for w, h in SIZES:
            save_png(os.path.join(OUT, f"baroque-matterhorn-{name}-{w}x{h}.png"), finish(rgb, w, h, lk))
    if "--no-previews" not in flags:
        previews(["home", "lock"])


if __name__ == "__main__":
    main()
