#!/usr/bin/env python3
"""Sun Arc in another landscape: the Val d'Orcia, the cypress knoll of San Quirico d'Orcia (the "Cipressini"), a
ring of Italian cypresses on a low rise among rolling fields, ploughed in autumn, under a wide sky. No peak: the
hills and the cypresses are the subject. The afternoon sun is on the right (west), lighting the trees' right
sides and throwing their shadows to the left.

The large Weather canvas (348 x 365 pt) as one grey value study, glazed at run time by the Cover's CoverLight:
  large-lo.png, large-hi.png   the lower and upper halves of the value
  large-glow.png               the brightest lights (cloud tops, the far hill's crest, the cypresses' west rims)
  large-front.png              the land and the trees, drawn again over the sun and the arc's feet
Data:
  tuscany.json                 the skyline, traced from a photograph (see SOURCE.md) and normalised: the tallest
                               cypress's top at (0, 0), in units of its height above the knoll; with the tops of the
                               cypresses ("tops", the skyline's local highs) and the foot of the knoll under them

The far hills are the traced skyline at one scale, and each cypress is a crisp flame standing at its traced top (its
height from the top to the knoll), so the clump keeps its outline with sky between some of the trees. The ground
below the horizon is painted, not traced: the knoll, a swell on the right that carries the arc's right foot (in the
photograph the ground falls away there), one long rolling hill line with a white road winding over it, all
ploughed in furrows that follow the curve of the land, darkening to the ground the type sits on.

Shares the painter in ../fuji/world.py (the Sun Arc canvas's machinery, generalised to layers).

Run (deterministic, offline):  python3 MockLab/Textures/weather-sun-arc/scenes/tuscany/make.py [--preview <png>]
Rebuild tuscany.json from the full trace:  make.py --trace <trace.json> <tops.json>
"""
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("sa_world", os.path.join(os.path.dirname(HERE), "fuji", "world.py"))
world = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(world)
om, mt, SS = world.om, world.mt, world.SS
fbm, smoothstep = world.fbm, world.smoothstep

SKYLINE = os.path.join(HERE, "tuscany.json")
META = {
    "subject": {"name": "Cipressi di San Quirico d'Orcia (Val d'Orcia, Tuscany)"},
    "view": "the cypress knoll from the fields to its north-east, beside the road from San Quirico to Pienza",
    "source": {
        "photo": "File:San Quirico d'Orcia - cipressi di San Quirico d'Orcia - 202209290751.jpg, Wikimedia Commons "
                 "(4 September 2019)",
        "url": "https://commons.wikimedia.org/wiki/File:San_Quirico_d%27Orcia_-_cipressi_di_San_Quirico_d%27Orcia_-_202209290751.jpg",
        "author": "Federica.tamburini.75",
        "licence": "CC BY-SA 4.0",
        "use": "skyline only: for each column the first row that is not blue sky (3840 px wide copy); the cypress "
               "tops are the skyline's local highs; the knoll's foot drawn by eye; no pixels kept",
    },
}
TREE_PX = 487          # the tallest cypress, top to the knoll under it, in the photograph (3840 px wide copy)
CLUMP = (1360, 2470)   # the clump's columns in the photograph
KNOLL = [(1360, 1522), (1500, 1520), (1700, 1517), (1900, 1520), (2100, 1526), (2300, 1534), (2470, 1542)]
LONE = (1216, 1395, 1442)   # the lone cypress on the far hill: column, top, foot (photo px)


def trace(path, tops_path):
    with open(tops_path) as f:
        tops = [tuple(t) for t in json.load(f)]
    world.skyline_from_trace(path, SKYLINE, META, step=3, unit=TREE_PX,
                             lines={"tops": tops, "knoll": KNOLL, "lone": [LONE[:2], (LONE[0], LONE[2])]})


ARC = world.ARC
# The tallest top (x, y) fractions and points per unit: 0.15 pt per photo px, the clump centred under the crown, the
# far hill on the left at the arc's left foot.
FRAME = (0.596, 0.411, 0.15 * TREE_PX)
LIGHT = (0.75, -0.35, 0.45)   # from the right


def lines_mask(w, h, polylines, width, k=4):
    """Polylines (px) drawn crisp: antialiased at k times and reduced, never blurred."""
    from PIL import Image, ImageDraw
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    for pl in polylines:
        if len(pl) > 1:
            d.line([(x * k, y * k) for x, y in pl], fill=255, width=max(1, int(round(width * k))), joint="curve")
    return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255


def furrows(crest, h, step0, grow, count, x_ok=None):
    """Ploughed furrows under a crest: lines that follow the crest's curve, spaced wider as they come toward us."""
    w = len(crest)
    xs = np.arange(w) + 0.5
    lines, off = [], step0
    for _ in range(count):
        ys = crest + off
        keep = np.ones(w, bool) if x_ok is None else x_ok
        seg = [(x, y) for x, y, k in zip(xs[::3], ys[::3], keep[::3]) if k and y < h]
        lines.append(seg)
        off += step0 * grow
        step0 *= grow
    return lines


def field(ctx, crest, crest_light, base, light_x=None, furrow_dark=0.09, step0=1.6 * SS, x_ok=None):
    """A ploughed field below a crest: soft light along the crest fading down the face toward us, furrows that
    follow the curve of the land, and stroke directions along it. Returns value, stroke angle (h, w)."""
    w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
    yy = ctx["yy"]
    d = (yy - crest[None, :]) / SS
    lx = np.ones(w) if light_x is None else light_x
    v = base + crest_light * np.exp(-d / 3.0) * lx[None, :] + 0.25 * crest_light * np.exp(-d / 12.0) * lx[None, :]
    fm = lines_mask(w, h, furrows(crest, h, step0, 1.22, 14, x_ok), 0.55 * SS)
    v = v - furrow_dark * fm * np.exp(-d / 30.0)
    slope = np.gradient(gaussian_filter(crest, 2 * SS))
    angle = np.arctan(np.clip(slope, -0.6, 0.6))[None, :] * np.ones((h, 1)) + 0.03 * fbm(h, w, rng, base=6, octaves=2)
    return v, angle, fm


def hills_layer(sk):
    """The far hills: the traced line, running on behind the clump; ploughed land, the crest catching the afternoon
    light softly, the furrows following the slope."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        cy = sk.crest(w, h, sx, sy, S, ends="level")
        xs = np.arange(w) + 0.5
        kx, ky = zip(*sk.line("knoll", w, h, sx, sy, S))
        # behind the clump the far hill runs on, from where it disappears behind the trees on the left to where it
        # comes out on the right (the knoll and the trees stand in front of it)
        a, b = int(kx[0] - 2 * SS), int(kx[-1] + 2 * SS)
        inside = (xs >= a) & (xs <= b)
        t = smoothstep(a, b, xs)
        cy = np.where(inside, cy[a] + (cy[b] - cy[a]) * t, cy)
        cy = gaussian_filter(cy, 1.0 * SS)
        cover = world.below(cy, h, 0.5)
        v, angle, _ = field(ctx, cy, 0.3, 0.17, step0=1.3 * SS)
        d = (ctx["yy"] - cy[None, :]) / SS
        return dict(value=v - 0.05 * smoothstep(4, 16, d), cover=cover, glow=0.6 * np.exp(-d / 2.0) * cover * 0.4,
                    angle=angle, crest=cy)
    return layer


def flame(x, base, height, width, rng):
    """An Italian cypress as a crisp closed flame: narrow, widest a third of the way up, tapering to a drawn-out
    point, the outline a little irregular (tufts). Returns polygon points (px)."""
    n = 30
    left, right = [], []
    for i in range(n + 1):
        f = i / n
        prof = min(1.0, (f + 0.1) / 0.36) ** 0.5 * min(1.0, ((1 - f) / 0.68) ** 0.85)
        tuft = 1 + 0.12 * rng.uniform(-1, 1)
        y = base - f * height
        left.append((x - width / 2 * prof * tuft, y))
        right.append((x + width / 2 * prof * (1 + 0.12 * rng.uniform(-1, 1)), y))
    return right + [(x + rng.uniform(-0.3, 0.3), base - height * 1.01)] + list(reversed(left))


def cypresses_layer(sk):
    """The clump: Italian cypresses, each a crisp narrow flame standing at its traced top, with sky between some of
    them; dark green-black, a thin warm rim down the west (right) edge where the afternoon sun catches it, a few dark
    vertical strokes inside. And the lone cypress on the far hill."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        xs = np.arange(w) + 0.5
        yy, xx = ctx["yy"], ctx["xx"]
        kx, ky = zip(*sk.line("knoll", w, h, sx, sy, S))
        ground = np.interp(xs, kx, ky)
        tops = sk.line("tops", w, h, sx, sy, S)
        (lx, lt), (_, lb) = sk.line("lone", w, h, sx, sy, S)
        trees = [(tx, ty, float(np.interp(tx, xs, ground)) + 0.8 * SS) for tx, ty in tops]
        trees.append((lx, lt, lb))
        trees.sort(key=lambda t: t[1])                      # tallest first: the shorter stand in front
        cover = np.zeros((h, w))
        value = np.zeros((h, w))
        glow = np.zeros((h, w))
        keep = np.zeros((h, w))
        streak = world.streaks(h, w, rng, np.full((h, w), np.pi / 2), 0.12 * S, base=120)
        for i, (tx, ty, base) in enumerate(trees):
            height = base - ty
            width = height * rng.uniform(0.15, 0.19)
            poly = flame(tx, base, height, width, rng)
            m = world.draw_mask(w, h, [poly], k=4)
            # the west rim: the tree's right edge, a band about 0.7 pt wide
            shifted = np.zeros_like(m)
            r = max(1, int(round(1.2 * SS)))
            shifted[:, :-r] = m[:, r:]
            rim = np.clip(m - shifted, 0, 1)
            # dark vertical strokes inside, following the trunk's line
            strokes = []
            for _ in range(3):
                off = rng.uniform(-0.25, 0.2) * width
                y0 = ty + rng.uniform(0.15, 0.35) * height
                y1 = base - rng.uniform(0.05, 0.25) * height
                strokes.append([(tx + off + rng.uniform(-0.3, 0.3) * SS, yy_) for yy_ in np.linspace(y0, y1, 6)])
            sm = lines_mask(w, h, strokes, 0.5 * SS) * m
            tree_v = 0.09 + 0.025 * np.tanh(streak) - 0.05 * sm
            tree_v = tree_v + 0.48 * rim
            value = value * (1 - m) + tree_v * m
            glow = glow * (1 - m) + rim
            keep = np.maximum(keep * (1 - m), np.clip(rim + sm, 0, 1))
            cover = np.maximum(cover, m)
        ctx["rims"] = (glow, value)
        return dict(value=value, cover=cover, keep=keep, lean=np.zeros((h, w)), tree=True)
    return layer


def rims_layer():
    """The cypresses' west rims again, as a layer of their own, so their light is kept in the glow (glazed in the
    colour of the sun, warm) rather than cleared with the trees'."""
    def layer(ctx):
        rim, value = ctx["rims"]
        return dict(value=value, cover=rim, glow=np.ones_like(rim), keep=rim, lean=np.zeros_like(rim))
    return layer


def fields_layer(sk):
    """The ground below the horizon, ploughed for autumn, every field's furrows following the curve of the land:
    the knoll under the clump with soft light along its crest and the trees' shadows beyond it to the left; a swell
    on the right (painted, not traced: in the photograph the ground falls away there) that carries the arc's right
    foot; one long rolling hill line across the front, its crest softly lit, a white road winding over it toward the
    knoll; then the dark ground the type sits on."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        yy, xx = ctx["yy"], ctx["xx"]
        xs = np.arange(w) + 0.5
        X = xs / w
        kx, ky = zip(*sk.line("knoll", w, h, sx, sy, S))
        knoll = np.interp(xs, kx, ky)
        # The knoll: its crest under the trees, falling away to either side.
        k_line = gaussian_filter(knoll + 0.5 * SS + np.clip(kx[0] - xs, 0, None) * 0.32
                                 + np.clip(xs - kx[-1], 0, None) * 0.32, 1.0 * SS)
        k_cover = world.below(k_line, h, 0.5)
        side = smoothstep(kx[0] - 40 * SS, kx[0] + 10 * SS, xs) * smoothstep(kx[-1] + 40 * SS, kx[-1] - 10 * SS, xs)
        k_v, k_ang, _ = field(ctx, k_line, 0.5, 0.12, light_x=side * (0.6 + 0.4 * smoothstep(0.3, 0.7, X)), step0=1.4 * SS)
        # The trees' shadows, beyond the clump to the left, as long dark tongues across the far hill.
        shadows = np.zeros((h, w))
        left_end = kx[0]
        for tx, ty in sorted(sk.line("tops", w, h, sx, sy, S))[:6]:
            base = float(np.interp(tx, xs, knoll))
            height = base - ty
            u = (left_end - xx) / (height * 0.9) + (tx - left_end) / (height * 0.9)
            centre = base + 1.0 * SS - u * 3.0 * SS
            half = 1.4 * SS * (1 - 0.5 * u)
            shadows = np.maximum(shadows, smoothstep(1.0, 0.6, u) * smoothstep(0.0, 0.08, u)
                                 * smoothstep(half + 0.8 * SS, half, np.abs(yy - centre)) * (xx < left_end))
        # The swell on the right, nearly level at the horizon.
        swell = gaussian_filter(world.polyline_y([(0.55 * w, 0.66 * h), (0.68 * w, 0.615 * h), (0.76 * w, 0.585 * h),
                                                  (0.86 * w, 0.578 * h), (1.0 * w, 0.569 * h)], w), 4 * SS)
        s_cover = world.below(swell, h, 0.5) * smoothstep(0.5, 0.56, X)[None, :]
        s_v, s_ang, _ = field(ctx, swell, 0.16, 0.13, step0=1.5 * SS, x_ok=X > 0.56)
        # One long rolling hill line across the front.
        roll = world.polyline_y([(0, 0.648 * h), (0.14 * w, 0.638 * h), (0.3 * w, 0.652 * h), (0.5 * w, 0.672 * h),
                                 (0.68 * w, 0.66 * h), (0.84 * w, 0.642 * h), (1.0 * w, 0.65 * h)], w)
        roll = gaussian_filter(roll, 6 * SS)
        r_cover = world.below(roll, h, 0.5)
        r_v, r_ang, _ = field(ctx, roll, 0.48, 0.1, light_x=0.6 + 0.4 * X, step0=1.8 * SS)
        # Compose, back to front: the far hill (shadows only), the swell, the knoll, the rolling line.
        v = ctx["V"] * (1 - 0.65 * shadows)
        angle = np.zeros((h, w))
        cover = shadows.copy()
        for c, fv, fa in ((s_cover, s_v, s_ang), (k_cover, k_v, k_ang), (r_cover, r_v, r_ang)):
            v = v * (1 - c) + fv * c
            angle = np.where(c > 0.5, fa, angle)
            cover = np.maximum(cover, c)
        # A white road winding over the rolling line toward the knoll, narrowing as it goes.
        kfoot = float(np.interp(0.47 * w, xs, k_line))
        road = [(0.47 * w, kfoot + 2 * SS), (0.445 * w, kfoot + 5 * SS), (0.43 * w, 0.655 * h),
                (0.4 * w, 0.668 * h), (0.36 * w, 0.676 * h), (0.31 * w, 0.684 * h), (0.25 * w, 0.692 * h)]
        rm = np.zeros((h, w))
        for i, (a, b) in enumerate(zip(road, road[1:])):
            rm = np.maximum(rm, lines_mask(w, h, [[a, b]], (0.5 + 0.18 * i) * SS))
        fade = smoothstep(0.71 * h, 0.66 * h, yy)
        v = v + (0.4 - v) * rm * fade
        keep = np.clip(rm * fade, 0, 1)
        return dict(value=v, cover=cover, angle=angle, keep=keep, ground=True)
    return layer


def large():
    sk = world.Skyline(SKYLINE)
    return world.compose(348, 365, 731, sun=(0.68, 0.14), horizon=0.58,
                         sky=dict(dark_top=0.2, bright=0.6, low=0.6),
                         clouds=[(-0.02, 0.11, 0.42, 0.12, 34, 0.55), (1.02, 0.1, 0.44, 0.12, 34, 0.5),
                                 (0.08, 0.56, 0.17, 0.1, 28), (0.93, 0.545, 0.17, 0.1, 26)],
                         calm=(0.5, 0.3, 0.34, 0.22, 0.7),
                         layers=[hills_layer(sk), fields_layer(sk), cypresses_layer(sk), rims_layer()],
                         ground_dark=(0.68, 1.0, 0.45))


if __name__ == "__main__":
    world.main(HERE, large, ARC, trace)
