#!/usr/bin/env python3
"""Old Master paint textures: original sublime mountain landscapes painted with the app's own brush method.

Each widget's ground is a value study (an old master's grisaille underpainting): towering cumulus modelled as
billows lit from the sky, layered ridges whose faces turn toward or away from the light, snow on the far peaks,
mist between the ranges and a dark foreground of rock and firs. The value field is then covered with the
strokes of scripts/make_textures.py (imported from its path, not copied): opaque strokes that follow the form
(round the billows, down the slopes, short dabs in the foreground), coarse to fine, then bristle marks and
impasto light on the stroke edges.

The widgets tint these at run time, so one canvas serves morning, dusk, night and grey weather:
  <name>-lo.png, <name>-hi.png
                        alpha = the lower and upper half of the painted value (0 shadow .. 1 light). SwiftUI lays
                        them, as template images, over the shadow colour in a warm mid colour and then the light
                        colour: an exact three-stop gradient map, chocolate to warm umber to cream.
  <name>-glow.png       alpha = the brightest lights only (cloud tops, lit snow). Tinted peach-gold near the sun,
                        amber at dusk, moonlight at night.

Paintings (1 px per point, the widget's own size):
  day-large 348x365, day-medium 348x164, day-small 164x164,
  quote-large 348x365, quote-medium 348x164, quote-small 164x164
Other textures:
  panel.jpg       330x240   the quiet dark-umber board under the type
  veil.png        348x220   rain: long soft strokes falling on a slant (alpha only)
  wallpaper.jpg   780x805   the board's home screen: a sepia Baroque cloudscape (not a widget texture)

Run from anywhere (deterministic):  python3 MockLab/Textures/old-master/make.py
Add --preview <folder> to also write colour previews of each painting there.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing scripts/make_textures.py must not leave a __pycache__ in scripts/

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, gaussian_filter1d, map_coordinates, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
spec = importlib.util.spec_from_file_location("make_textures", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

hexrgb, fbm, mix, smoothstep = mt.hexrgb, mt.fbm, mt.mix, mt.smoothstep


def save_alpha(name, a):
    """White with the given alpha (the widgets render these as template images)."""
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    img = Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA")
    img.save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def save_rgb(name, rgb, quality=88):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=quality, subsampling=0)
    print(f"{name}.jpg: {rgb.shape[1]}x{rgb.shape[0]}")


SS = 2  # paintings are painted at 2x and box-filtered down to 1 px per point, so every stroke edge is antialiased


def norm3(x, y, z):
    n = np.sqrt(x * x + y * y + z * z) + 1e-9
    return x / n, y / n, z / n


# MARK: Ridges

def crest(keys, seed, w, h, roughness=0.22, levels=5):
    """A crest line (y in px for every column): hand-placed key points (fractions of the painting) roughened by
    seeded midpoint displacement, the same construction as RidgeProfile in Shared/Landscape.swift."""
    rng = np.random.default_rng(seed)
    pts = [(x * w, y * h) for x, y in keys]
    amount = roughness
    for _ in range(levels):
        nxt = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            length = np.hypot(bx - ax, by - ay)
            nxt.append(((ax + bx) / 2 + rng.uniform(-1, 1) * length * 0.08,
                        (ay + by) / 2 + rng.uniform(-1, 1) * length * amount))
            nxt.append((bx, by))
        pts = nxt
        amount *= 0.62
    pts.sort()
    xs, ys = zip(*pts)
    return np.interp(np.arange(w) + 0.5, xs, ys)


def mountain(w, h, rng, cy, tone, light, snowline=None, gully=0.5, haze=0.0, haze_v=0.62, mist=None, contrast=1.0,
             snow_v=(0.36, 1.0), rim=0.0, shear=0.45):
    """One range: value, coverage, lit-snow amount and face lean (for the stroke directions).
    Each face turns left or right with the crest above it, read up a slant (so every summit's ridge runs down and
    away from the light, like a pyramid peak: a broad lit face and a narrow shaded one) and smoothed more the further
    down (so peaks spread into spurs). Rock ribs and couloirs run along the same slant; snow lies above the snowline,
    fills the couloirs below it and lets the steepest ribs show through. Lit by `light` (x, y, z; up is -y)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    depth = yy - cy[None, :]
    down = np.clip(depth, 0, None)
    cover = smoothstep(-0.8 * SS, 0.8 * SS, depth)
    levels = np.array([0, 3, 7, 14, 26, 45, 80, 140, 240], dtype=np.float64) * SS
    slopes = np.array([np.gradient(gaussian_filter1d(cy, 0.8 * SS + d * 0.45, mode="nearest")) for d in levels])
    di = np.interp(np.clip(depth, 0, levels[-1]), levels, np.arange(len(levels)))
    i0 = np.floor(di).astype(int)
    i1 = np.minimum(i0 + 1, len(levels) - 1)
    t = di - i0
    xs = np.clip(xx - shear * down, 0, w - 1)
    c0 = np.floor(xs).astype(int)
    c1 = np.minimum(c0 + 1, w - 1)
    ft = xs - c0
    sl = (slopes[i0, c0] * (1 - ft) + slopes[i0, c1] * ft) * (1 - t) + (slopes[i1, c0] * (1 - ft) + slopes[i1, c1] * ft) * t
    g = map_coordinates(fbm(h, w, rng, base=7, octaves=4, persistence=0.55, stretch=0.3), [yy, xs], order=1, mode="nearest")
    ribs = 1 - np.abs(np.tanh(g * 0.9))           # sharp rock ribs (1) between soft couloirs (0)
    rx = np.gradient(gaussian_filter(ribs, 0.9 * SS), axis=1) * SS
    nx = np.tanh(sl * 1.4) * 1.1 + gully * np.tanh(rx * 5)
    ny = -0.25 - 0.45 * smoothstep(0, 60 * SS, depth)
    nx, ny, nz = norm3(nx, ny, np.ones_like(nx) * 0.8)
    lx, ly, lz = norm3(*light)
    lam = nx * lx + ny * ly + nz * lz
    shade = np.clip(0.5 + 0.5 * lam, 0, 1) ** 1.5  # half-Lambert, deepened: lit planes and shadow planes, never flat
    shade *= 0.8 + 0.2 * ribs                      # couloirs sit in their own shadow
    v = tone * (1 - 0.75 * contrast + 1.5 * contrast * shade)
    snow_lit = np.zeros_like(v)
    if snowline is not None:
        line = snowline * h + 4 * SS * fbm(h, w, rng, base=6, octaves=2)
        snowy = smoothstep(line + 2.0 * SS, line - 2.0 * SS, yy) * (1 - 0.55 * smoothstep(0.82, 0.97, ribs) * (1 - shade))
        snowy = np.maximum(snowy, smoothstep(0.45, 0.15, ribs) * smoothstep(line + 22 * SS, line + 2 * SS, yy))
        snowy *= cover
        sv = (snow_v[0] + (snow_v[1] - snow_v[0]) * shade) * (0.9 + 0.1 * ribs)
        v = v + (sv - v) * snowy
        snow_lit = snowy * smoothstep(0.45, 0.85, shade)
    if rim:
        edge = smoothstep(0, 1.2 * SS, depth) * (1 - smoothstep(1.2 * SS, 3.5 * SS, depth))
        v = v + rim * edge * smoothstep(0.3, 0.8, shade)
    v = v * (1 - haze) + haze_v * haze
    if mist is not None:
        d0, d1, amount = mist
        v = v + (haze_v - v) * amount * smoothstep(d0 * SS, d1 * SS, depth)
    return v, cover, snow_lit, nx


def firs(w, h, rng, cy, height, spacing, coverage=0.75, scale=1.0):
    """Fir silhouettes standing on a crest: a 0..1 mask (drawn at 2x, then reduced, for soft painted edges)."""
    k = 2
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    spacing *= SS
    x = rng.uniform(0, spacing)
    while x < w:
        hh = rng.uniform(*height) * scale * SS
        if rng.uniform() < coverage:
            base = cy[int(min(w - 1, max(0, x)))] + 1.5 * SS
            d.polygon([(px * k, py * k) for px, py in fir(x, base, hh, rng)], fill=255)
        x += spacing * rng.uniform(0.55, 1.4)
    img = img.resize((w, h), Image.LANCZOS)
    return np.asarray(img, dtype=np.float64) / 255


def fir(x, base, h, rng):
    """A tall old-master fir: a ragged spire of drooping tiers on a short trunk."""
    tiers = 6
    w = h * rng.uniform(0.32, 0.42)
    top = base - h
    left, right = [], []
    for i in range(tiers + 1):
        f = i / tiers
        y = top + h * 0.88 * f
        half = w / 2 * (0.12 + 0.88 * f ** 0.9) * rng.uniform(0.8, 1.15)
        right.append((x + half, y))
        right.append((x + half * 0.45, y - h * 0.03))
        left.append((x - half * rng.uniform(0.85, 1.1), y))
        left.append((x - half * 0.45, y - h * 0.03))
    trunk = [(x + w * 0.05, base + h * 0.06), (x - w * 0.05, base + h * 0.06)]
    return [(x, top)] + right[1:] + trunk + list(reversed(left[1:]))


# MARK: Sky

def cumulus(w, h, rng, masses, sun, billow=1.0, flow=5.0):
    """Billowing cumulus: each mass is a dome of spherical billows (their heights maxed together), a few large ones
    for the body and smaller ones crowding the rim; lit half-Lambert from the light, darker in the belly, with
    silver linings near the sun. masses: [(cx, base y, width, height, billows)], fractions of the painting."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    Z = np.zeros((h, w))
    belly = np.zeros((h, w))
    dim = np.zeros((h, w))
    for mass in masses:
        cx, cy, mw, mh, n = mass[:5]
        darkness = mass[5] if len(mass) > 5 else 0.0
        cx, cy, mw, mh = cx * w, cy * h, mw * w, mh * h
        before = Z.copy()
        for i in range(n):
            u = rng.uniform(-1, 1)
            top = (1 - abs(u) ** 2.0) ** 0.7
            kind = rng.uniform()
            if kind < 0.3:       # body
                v = rng.uniform(0.1, 0.55) * top
                r = mw * rng.uniform(0.13, 0.2)
                u *= 0.7
            elif kind < 0.82:    # billows
                v = rng.uniform(0.3, 0.95) * top
                r = mw * rng.uniform(0.06, 0.11)
            else:                # small rim curls
                v = rng.uniform(0.6, 1.0) * top
                r = mw * rng.uniform(0.025, 0.05)
            px, py = cx + u * mw / 2, cy - v * mh
            r = min(r * billow, mh * 0.6)
            x0, x1 = int(max(0, px - r - 1)), int(min(w, px + r + 2))
            y0, y1 = int(max(0, py - r - 1)), int(min(h, py + r + 2))
            if x1 <= x0 or y1 <= y0:
                continue
            d2 = (xx[y0:y1, x0:x1] - px) ** 2 + (yy[y0:y1, x0:x1] - py) ** 2
            z = np.where(d2 < r * r, np.sqrt(np.clip(r * r - d2, 0, None)) + v * mh * 0.25, 0)
            Z[y0:y1, x0:x1] = np.maximum(Z[y0:y1, x0:x1], z)
        b = smoothstep(cy - mh * 0.5, cy + mh * 0.1, yy) * np.exp(-((xx - cx) / (mw * 0.65)) ** 2)
        belly = np.maximum(belly, b)
        if darkness:
            dim = np.where(Z > before, darkness, dim)
    cover = smoothstep(0.3 * SS, 3.5 * SS, Z)
    cover *= smoothstep(-1.2, 0.2, fbm(h, w, rng, base=14, octaves=3) + 2.4 * smoothstep(0, 6 * SS, Z) - 0.6)
    # The base dissolves into haze (sfumato); the tops stay drawn.
    cover *= 1 - 0.45 * belly * smoothstep(0.55, 1.0, belly)
    zs = gaussian_filter(Z, 3.0 * SS)
    gx = sobel(zs, axis=1) / 8
    gy = sobel(zs, axis=0) / 8
    nx, ny, nz = norm3(-gx, -gy, np.ones_like(gx) * 0.7)
    sx, sy = sun[0] * w, sun[1] * h
    dx, dy = sx - xx, sy - yy
    dist = np.hypot(dx, dy) + 1e-6
    lx, ly, lz = norm3(dx / dist * 0.6 - 0.25, dy / dist * 0.6 - 0.55, np.full_like(dx, 0.5))
    lam = nx * lx + ny * ly + nz * lz
    shade = np.clip(0.5 + 0.5 * lam, 0, 1) ** 1.8
    near = np.exp(-(dist / (0.5 * max(w, h))) ** 2)
    value = 0.24 + 0.74 * shade
    value *= 1 - 0.42 * belly * (1 - 0.5 * shade)
    value *= 1 - gaussian_filter(dim, 2.0 * SS)
    rim = cover * (1 - smoothstep(0.5 * SS, 7 * SS, Z)) * near
    value = np.clip(value + 0.3 * rim + 0.08 * near * shade, 0, 1)
    lit = cover * smoothstep(0.62, 0.95, shade) * (0.5 + 0.5 * near) * (1 - gaussian_filter(dim, 2.0 * SS)) ** 2
    zb = gaussian_filter(Z, flow * SS)
    tangent = np.arctan2(sobel(zb, axis=0), sobel(zb, axis=1)) + np.pi / 2
    return value, cover, lit, tangent, np.hypot(gx, gy)


def sky_field(w, h, rng, sun, horizon, dark_top=0.26, bright=0.8, low=0.64):
    """The open sky: dark overhead and in the upper corners, light toward the horizon and round the sun,
    with long level wisps (as in the shipped sky) and faint rays falling from the light."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    t = np.clip(yy / (horizon * h), 0, 1)
    v = dark_top + (low - dark_top) * t ** 0.9
    sx, sy = sun[0] * w, sun[1] * h
    dist = np.hypot(xx - sx, (yy - sy) * 1.2)
    v += (bright - low) * np.exp(-(dist / (0.36 * max(w, h))) ** 2) + 0.14 * np.exp(-(dist / (0.1 * max(w, h))) ** 2)
    corner = np.hypot((xx / w - 0.5) * 1.4, (yy / h) * 1.1)
    v -= 0.16 * smoothstep(0.45, 1.0, corner) * (1 - t)
    angle = 0.03 + 0.1 * fbm(h, w, rng, base=1.5, octaves=3, persistence=0.5)
    wisps = mt.lic(fbm(h, w, rng, base=7, octaves=3, persistence=0.5, stretch=2.5), angle, 18 * SS, step=1.0)
    wisps = wisps / (wisps.std() + 1e-9)
    v += 0.035 * wisps * (0.4 + 0.6 * t)
    a = np.arctan2(yy - sy, xx - sx)
    rays = 0.5 + 0.5 * np.sin(a * 23 + 2.5 * np.sin(a * 7 + 1.3))
    rays = smoothstep(0.55, 1.0, rays) * smoothstep(0, 0.2 * h, yy - sy) * np.exp(-(dist / (0.7 * max(w, h))) ** 2)
    v += 0.07 * rays
    return np.clip(v, 0, 1), angle


# MARK: A painting

def painting(w, h, seed, sun, horizon, clouds, ranges, foreground=None, trees=(), contrast=1.3, preview=None, name=""):
    """Composes a value study at SS times the widget's size, paints it, and filters it down to 1 px per point.
    Returns (value, glow) in 0..1. ranges: far to near, dicts for mountain(); foreground: the near range, drawn
    very dark; trees: [(range index, height range in pt, spacing in pt, coverage, value)]."""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    V, angle = sky_field(w, h, rng, sun, horizon)
    # Dark storm banks first, behind; the lit cumulus over them.
    glow = np.zeros((h, w))
    for layer in ([m for m in clouds if len(m) > 5], [m for m in clouds if len(m) <= 5]):
        if not layer:
            continue
        cv, ccover, clit, ctan, cmag = cumulus(w, h, rng, layer, sun)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit * 0.9
        angle = np.where(ccover > 0.3, ctan, angle)
    land = np.zeros((h, w))
    lean = np.zeros((h, w))
    crests = []
    allr = list(ranges) + ([foreground] if foreground else [])
    for i, r in enumerate(allr):
        r = dict(r)
        cy = crest(r.pop("keys"), r.pop("seed"), w, h, r.pop("roughness", 0.22))
        crests.append(cy)
        v, cover, snow_lit, nx = mountain(w, h, rng, cy, r.pop("tone"), r.pop("light", (-0.55, -0.6, 0.6)), **r)
        V = V + (v - V) * cover
        glow = glow * (1 - cover) + snow_lit * cover
        land = np.maximum(land, cover)
        lean = lean * (1 - cover) + nx * cover
    tree_mask = np.zeros((h, w))
    for which, height, spacing, coverage, tone in trees:
        m = firs(w, h, rng, crests[which], height, spacing, coverage)
        rimlight = np.clip(-sobel(gaussian_filter(m, 0.6 * SS), axis=1) / 4 * SS, 0, 1)  # the lit (left) edge of each tree
        V = V + (tone - V) * m + 0.10 * rimlight * (1 - m * 0.5)
        glow *= 1 - m
        land = np.maximum(land, m)
        tree_mask = np.maximum(tree_mask, m)
    # Strokes: round the billows in the cloud, level in open sky, down the slopes on land.
    land_angle = np.pi / 2 + 0.95 * np.clip(lean, -1, 1) + 0.15 * fbm(h, w, rng, base=6, octaves=2)
    angle = np.where(land > 0.5, land_angle, angle)
    k = pw * ph / (348 * 365)
    s = SS
    field = np.stack([V, V, V], axis=2)
    # Two angle fields: the sky passes use long strokes round the billows, the land passes short ones down the faces.
    sky_out = mt.paint(field, angle, rng, [(int(380 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                                           (int(1300 * k), (3 * s, 5.5 * s), (7 * s, 18 * s)),
                                           (int(2400 * k), (1.4 * s, 2.6 * s), (4 * s, 9 * s)),
                                           (int(3200 * k), (0.7 * s, 1.2 * s), (3 * s, 7 * s))], 0.03)
    land_out = mt.paint(field, angle, rng, [(int(500 * k), (4 * s, 8 * s), (6 * s, 14 * s)),
                                            (int(1600 * k), (2 * s, 4 * s), (4 * s, 9 * s)),
                                            (int(2400 * k), (1.2 * s, 2.2 * s), (2.5 * s, 6 * s)),
                                            (int(2600 * k), (0.7 * s, 1.1 * s), (2 * s, 4 * s))], 0.04)
    out = sky_out * (1 - land[..., None]) + land_out * land[..., None]
    out = gaussian_filter(out[..., 0], 0.4 * s)
    # The firs keep their drawing: laid back over the strokes, softly.
    out = out + (np.minimum(out, V) - out) * gaussian_filter(tree_mask, 0.5 * s) * 0.7
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.018))
    g = gaussian_filter(out, 0.7 * s)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.06 * s
    # A breath of the unpainted value back in, so the forms keep their drawing under the strokes.
    out = 0.82 * out + 0.18 * gaussian_filter(V, 0.8 * s)
    # Chiaroscuro: an S-curve, so the lights carry and the shadows go deep.
    out = np.clip(0.5 + (out - 0.5) * contrast, 0, 1) ** 1.08
    glow = gaussian_filter(glow, 0.7 * s) * smoothstep(0.45, 0.85, out)
    glow = np.clip(np.maximum(glow, smoothstep(0.80, 0.98, out) * (1 - land) * 0.8), 0, 1)
    out, glow = down(out), down(glow)
    if preview:
        write_preview(preview, name, out, glow)
    return out, glow


def down(a):
    """Box filter from SS times the size to 1 px per point."""
    h, w = a.shape[0] // SS, a.shape[1] // SS
    return a[:h * SS, :w * SS].reshape(h, SS, w, SS).mean(axis=(1, 3))


def write_preview(folder, name, value, glow):
    """Colour preview (day palette) of a painting, for checking the art without building Swift."""
    c0, c1, c2 = hexrgb(0x24170F), hexrgb(0xEEDDC2), hexrgb(0xF6CF98)
    rgb = mix(np.ones(value.shape + (3,)) * c0, np.ones(value.shape + (3,)) * c1, value)
    rgb = mix(rgb, np.ones(value.shape + (3,)) * c2, glow * 0.6)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize(
        (value.shape[1] * 2, value.shape[0] * 2), Image.BICUBIC).save(os.path.join(folder, f"pv-{name}.png"))


# MARK: The paintings
# Positions are fractions of the widget. Where the layouts put the panel (OMDay / OMQuote), the paint is
# covered, so the visible composition sits in the open space: the top band of the large widgets, the left
# column of the medium ones, the top of the small day and the sky over the small quote's caption.

def p(x, y):
    return (x, y)


FAR = dict(tone=0.4, snow_v=(0.36, 0.98), haze=0.04, haze_v=0.66, rim=0.14)
MID = dict(tone=0.27, haze=0.05, haze_v=0.62, roughness=0.3, contrast=1.0)
NEAR = dict(tone=0.16, contrast=0.7, roughness=0.35)


def rng_(d, **kw):
    out = dict(d)
    out.update(kw)
    return out


def day_large(pv):
    # Visible above the panel: y 0 .. 0.33. One snowy massif left of centre catches the light breaking behind it;
    # dark cloud closes the upper corners, a bright tower of cumulus stands on the right, firs line the near ridge.
    return painting(348, 365, 401, sun=(0.42, 0.06), horizon=0.25,
                    clouds=[(0.0, 0.11, 0.42, 0.14, 40, 0.55), (1.0, 0.1, 0.34, 0.12, 30, 0.5),
                            (0.83, 0.215, 0.38, 0.2, 80), (0.1, 0.215, 0.26, 0.1, 34, 0.15)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.235), p(0.1, 0.22), p(0.2, 0.19), p(0.29, 0.135), p(0.36, 0.1),
                                        p(0.42, 0.08), p(0.48, 0.105), p(0.55, 0.14), p(0.62, 0.165), p(0.7, 0.2),
                                        p(0.8, 0.215), p(1, 0.228)], seed=11, snowline=0.175, mist=(30, 62, 0.75)),
                        rng_(MID, keys=[p(0, 0.25), p(0.1, 0.242), p(0.2, 0.252), p(0.3, 0.236), p(0.42, 0.256),
                                        p(0.56, 0.244), p(0.7, 0.262), p(0.82, 0.246), p(0.92, 0.256), p(1, 0.25)],
                             seed=23, mist=(8, 24, 0.5)),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.27), p(0.08, 0.282), p(0.2, 0.296), p(0.4, 0.305), p(0.6, 0.3),
                                                p(0.8, 0.292), p(0.92, 0.282), p(1, 0.272)], seed=31),
                    trees=[(2, (8, 17), 5.0, 0.55, 0.07)], preview=pv, name="day-large")


def day_medium(pv):
    # Visible: the left column (x 0 .. 0.33) and the rims round the panel.
    return painting(348, 164, 403, sun=(0.15, 0.1), horizon=0.6,
                    clouds=[(0.0, 0.16, 0.22, 0.2, 26, 0.45), (0.09, 0.50, 0.26, 0.44, 64), (0.29, 0.36, 0.2, 0.3, 40), (0.7, 0.4, 0.5, 0.3, 50)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.62), p(0.05, 0.55), p(0.1, 0.4), p(0.15, 0.3), p(0.2, 0.41),
                                        p(0.26, 0.5), p(0.33, 0.58), p(0.5, 0.6), p(1, 0.62)], seed=41,
                             snowline=0.5, mist=(18, 40, 0.65)),
                        rng_(MID, keys=[p(0, 0.7), p(0.08, 0.66), p(0.17, 0.7), p(0.27, 0.65), p(0.36, 0.69),
                                        p(0.6, 0.68), p(1, 0.7)], seed=43, mist=(6, 20, 0.4)),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.78), p(0.06, 0.8), p(0.16, 0.84), p(0.26, 0.82),
                                                p(0.34, 0.86), p(1, 0.86)], seed=47),
                    trees=[(2, (12, 26), 6.0, 0.6, 0.07)], preview=pv, name="day-medium")


def day_small(pv):
    # Visible: y 0 .. 0.56 (the panel below). The date sits top left and the temperature top right, on the
    # darker cloud of the corners; the light breaks in the middle above the peak.
    return painting(164, 164, 405, sun=(0.5, 0.16), horizon=0.5,
                    clouds=[(0.02, 0.26, 0.62, 0.3, 44, 0.55), (0.98, 0.25, 0.62, 0.3, 44, 0.55),
                            (0.12, 0.47, 0.32, 0.14, 26), (0.88, 0.46, 0.32, 0.13, 24)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.5), p(0.15, 0.47), p(0.3, 0.42), p(0.42, 0.33), p(0.5, 0.27),
                                        p(0.58, 0.33), p(0.68, 0.38), p(0.8, 0.44), p(1, 0.48)], seed=51,
                             snowline=0.39, mist=(12, 26, 0.6)),
                        rng_(MID, keys=[p(0, 0.54), p(0.2, 0.52), p(0.38, 0.55), p(0.55, 0.5), p(0.7, 0.53),
                                        p(0.85, 0.5), p(1, 0.53)], seed=53),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.57), p(0.2, 0.59), p(0.5, 0.61), p(0.8, 0.59), p(1, 0.57)],
                                    seed=57),
                    trees=[(2, (8, 14), 5.0, 0.5, 0.07)], preview=pv, name="day-small")


def quote_large(pv):
    # Visible: y 0 .. about 0.5 (the label panel below; its top moves with the quote's length).
    return painting(348, 365, 407, sun=(0.64, 0.09), horizon=0.4,
                    clouds=[(0.04, 0.12, 0.36, 0.14, 36, 0.5), (0.98, 0.1, 0.3, 0.12, 30, 0.45),
                            (0.28, 0.33, 0.52, 0.27, 100), (0.88, 0.28, 0.34, 0.2, 60)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.40), p(0.14, 0.37), p(0.28, 0.33), p(0.4, 0.26), p(0.5, 0.21),
                                        p(0.56, 0.18), p(0.62, 0.23), p(0.7, 0.28), p(0.8, 0.33), p(0.9, 0.36),
                                        p(1, 0.37)], seed=61, snowline=0.3, mist=(30, 70, 0.7)),
                        rng_(MID, keys=[p(0, 0.43), p(0.1, 0.41), p(0.22, 0.44), p(0.36, 0.42), p(0.5, 0.45),
                                        p(0.68, 0.41), p(0.84, 0.44), p(1, 0.42)], seed=67, mist=(8, 30, 0.45)),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.38), p(0.06, 0.42), p(0.14, 0.47), p(0.26, 0.5),
                                                p(0.5, 0.52), p(0.8, 0.5), p(1, 0.48)], seed=71, tone=0.12),
                    trees=[(2, (14, 34), 7.0, 0.55, 0.06)], preview=pv, name="quote-large")


def quote_medium(pv):
    # Visible: the left column (x 0 .. 0.33).
    return painting(348, 164, 409, sun=(0.2, 0.12), horizon=0.6,
                    clouds=[(0.0, 0.1, 0.24, 0.14, 24, 0.5), (0.3, 0.34, 0.18, 0.24, 34), (0.7, 0.4, 0.5, 0.3, 50)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.6), p(0.06, 0.5), p(0.12, 0.44), p(0.19, 0.28), p(0.24, 0.36),
                                        p(0.3, 0.48), p(0.36, 0.56), p(0.6, 0.6), p(1, 0.62)], seed=81,
                             snowline=0.47, mist=(18, 40, 0.65)),
                        rng_(MID, keys=[p(0, 0.72), p(0.1, 0.68), p(0.2, 0.71), p(0.3, 0.66), p(0.4, 0.7),
                                        p(1, 0.7)], seed=83, mist=(6, 20, 0.4)),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.8), p(0.1, 0.84), p(0.2, 0.82), p(0.3, 0.86), p(1, 0.86)],
                                    seed=87),
                    trees=[(2, (12, 24), 6.0, 0.55, 0.07)], preview=pv, name="quote-medium")


def quote_small(pv):
    # The caption sits on the dark valley floor (y 0.6 .. 0.9); sky and peaks above it.
    return painting(164, 164, 411, sun=(0.42, 0.12), horizon=0.46,
                    clouds=[(0.0, 0.14, 0.4, 0.18, 26, 0.45), (1.0, 0.12, 0.36, 0.16, 24, 0.45),
                            (0.16, 0.34, 0.5, 0.3, 56), (0.88, 0.3, 0.4, 0.24, 44)],
                    ranges=[
                        rng_(FAR, keys=[p(0, 0.46), p(0.14, 0.42), p(0.3, 0.35), p(0.44, 0.26), p(0.52, 0.3),
                                        p(0.64, 0.37), p(0.78, 0.4), p(1, 0.44)], seed=91, snowline=0.36,
                             mist=(12, 26, 0.6)),
                        rng_(MID, keys=[p(0, 0.5), p(0.2, 0.48), p(0.4, 0.51), p(0.6, 0.47), p(0.8, 0.5), p(1, 0.48)],
                             seed=93),
                    ],
                    foreground=rng_(NEAR, keys=[p(0, 0.5), p(0.1, 0.54), p(0.3, 0.56), p(0.6, 0.57), p(0.9, 0.55),
                                                p(1, 0.53)], seed=97, tone=0.1),
                    trees=[(2, (10, 22), 6.0, 0.45, 0.06)], preview=pv, name="quote-small")


# MARK: Other textures

def panel(w, h, seed):
    """The quiet umber board: mt.panel's strokes, bristles and impasto, turned right down so the type rests on it."""
    rng = np.random.default_rng(seed)
    angle = 0.18 + 0.5 * np.tanh(1.5 * fbm(h, w, rng, base=2.0, octaves=2, persistence=0.4))
    a, b, c = hexrgb(0x42301F), hexrgb(0x3C2B1D), hexrgb(0x473322)
    rgb = mix(a, b, smoothstep(-1.4, 1.4, fbm(h, w, rng, base=3, octaves=4, persistence=0.5)))
    rgb = mix(rgb, c, 0.45 * smoothstep(0.5, 2.0, fbm(h, w, rng, base=2.5, octaves=3)))
    out = mt.paint(rgb, angle, rng, [(700, (8, 14), (24, 60)), (1400, (3, 6), (12, 30))], 0.022, hue=0.0015)
    out = gaussian_filter(out, (0.6, 0.6, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, 0.01))
    return mt.impasto(out, 0.22, blur=0.8)


def veil(w, h, seed):
    """Rain as a painter lays it: a few curtains of long soft strokes on a slant, hanging from the cloud and thinning
    toward the ground, with gaps between the showers."""
    rng = np.random.default_rng(seed)
    k = 2
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    slant = np.pi / 2 + 0.2
    for _ in range(int(520 * w * h / (348 * 220))):
        x, y = rng.uniform(-60, w), rng.uniform(-30, h)
        length = rng.uniform(30, 90)
        a = slant + rng.normal(0, 0.025)
        d.line([(x * k, y * k), ((x + np.cos(a) * length) * k, (y + np.sin(a) * length) * k)],
               fill=int(rng.uniform(70, 230)), width=int(rng.choice([2, 3, 3, 4, 5])))
    img = img.resize((w, h), Image.LANCZOS)
    a = gaussian_filter(np.asarray(img, dtype=np.float64) / 255, (1.4, 0.6))
    # Curtains: bands across the sky where the showers fall, leaning with the rain.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u = xx + (yy * np.cos(slant) / np.sin(slant))
    band = fbm(1, w * 2, rng, base=4, octaves=2)[0]
    curtains = smoothstep(-0.4, 0.9, np.interp(u % (w * 2), np.arange(w * 2), band))
    a *= 0.25 + 0.75 * curtains
    return np.clip(a / (np.percentile(a, 99.5) + 1e-9), 0, 1)


def wallpaper(w, h, seed):
    """The board's home screen: a Baroque sky of towering cloud in warm sepia, dark banks closing round a break of
    light, painted larger and looser than the widgets (it is not a widget texture). Painted at SS and filtered down."""
    pw, ph = w, h
    w, h = w * SS, h * SS
    rng = np.random.default_rng(seed)
    sun = (0.56, 0.36)
    V, angle = sky_field(w, h, rng, sun, 1.0, dark_top=0.3, bright=0.86, low=0.56)
    layers = [
        [(0.0, 0.36, 0.8, 0.42, 150, 0.42), (1.02, 0.28, 0.7, 0.36, 130, 0.38), (0.45, 1.12, 1.3, 0.5, 170, 0.4)],
        [(0.24, 0.66, 0.6, 0.36, 230), (0.86, 0.6, 0.5, 0.32, 190), (0.56, 0.98, 0.8, 0.3, 230),
         (0.6, 0.2, 0.36, 0.12, 80)],
    ]
    glow = np.zeros((h, w))
    for layer in layers:
        cv, ccover, clit, ctan, _ = cumulus(w, h, rng, layer, sun, billow=0.55, flow=16.0)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit
        angle = np.where(ccover > 0.3, ctan, angle)
    k = pw * ph / (348 * 365)
    s = SS * 1.5
    field = np.stack([V, V, V], axis=2)
    out = mt.paint(field, angle, rng, [(int(300 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                                       (int(700 * k), (3 * s, 5.5 * s), (7 * s, 18 * s))], 0.025)
    # Softer than the widgets (sfumato): the wallpaper only frames them.
    out = gaussian_filter(out[..., 0], 1.6 * SS)
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.02))
    g = gaussian_filter(out, 0.8 * SS)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.05 * SS
    out = 0.85 * out + 0.15 * gaussian_filter(V, SS)
    out = np.clip(0.5 + (out - 0.5) * 1.25, 0, 1)
    out, glow = down(out), down(glow)
    # Sepia gradient map: chocolate shadows, taupe, cream lights, a little peach in the brightest cloud.
    stops = [(0.0, 0x24150D), (0.28, 0x553A2A), (0.5, 0x8E6E58), (0.72, 0xC29E80), (0.9, 0xE5C6A6), (1.0, 0xF2DDC4)]
    rgb = np.zeros(out.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        t = np.clip((out - a0) / (a1 - a0), 0, 1)
        sel = (out >= a0) & (out <= a1)
        rgb[sel] = (hexrgb(c0) * (1 - t[..., None]) + hexrgb(c1) * t[..., None])[sel]
    rgb = mix(rgb, hexrgb(0xE9B79A), 0.28 * glow * smoothstep(0.55, 0.9, out))
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float64)
    vign = np.hypot((xx / pw - 0.5) * 1.2, (yy / ph - 0.5) * 1.0)
    return mt.shade(rgb, -0.3 * smoothstep(0.35, 0.85, vign))


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
        # Two halves of the value, for a three-stop gradient map at run time: shadow, warm mid, light.
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
        save_alpha(name + "-glow", glow)
    if not only or "panel" in only:
        save_rgb("panel", panel(330, 240, 421), quality=90)
    if not only or "veil" in only:
        save_alpha("veil", veil(348, 220, 423))
    if not only or "wallpaper" in only:
        save_rgb("wallpaper", wallpaper(780, 805, 425), quality=88)


if __name__ == "__main__":
    main()
