#!/usr/bin/env python3
"""Sun Arc in another landscape: Buachaille Etive Mor (Stob Dearg, 1,022 m) at the head of Glen Coe, the Highland
pyramid in its postcard view from the Kingshouse, across the River Etive and Rannoch Moor, looking south-west. Left
is south-east (the sun comes from the left, lighting the pyramid's left faces), right is north-west.

The large Weather canvas (348 x 365 pt) as one grey value study, glazed at run time by the Cover's CoverLight:
  large-lo.png, large-hi.png   the lower and upper halves of the value
  large-glow.png               the brightest lights (snow in the summit gullies, cloud tops)
  large-front.png              the land, drawn again over the sun and the arc's feet
  scene.json                   only if the arc moves (it does not: the Matterhorn's arc fits)
Data:
  glencoe.json                 the skyline, traced from a photograph (see SOURCE.md) and normalised: the summit at
                               (0, 0), in units of the summit's height above the flat of the moor in that photograph;
                               with two lines drawn by eye on the same photograph: where the pyramid's left ridge
                               passes in front of the far snowy top behind it, and where its right flank passes in
                               front of the far hill on the right

Shares the painter in ../fuji/world.py (the Sun Arc canvas's machinery, generalised to layers).

Run (deterministic, offline):  python3 MockLab/Textures/weather-sun-arc/scenes/glencoe/make.py [--preview <png>]
Rebuild glencoe.json from the full trace:  make.py --trace <trace.json>
"""
import importlib.util
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

SKYLINE = os.path.join(HERE, "glencoe.json")
META = {
    "peak": {"name": "Buachaille Etive Mor (Stob Dearg)", "elevation_m": 1022},
    "view": "from the Kingshouse, across the River Etive and Rannoch Moor, looking south-west",
    "source": {
        "photo": "File:Buachaille Etive Mor from Kingshouse Hotel.jpg, Wikimedia Commons (24 March 2007)",
        "url": "https://commons.wikimedia.org/wiki/File:Buachaille_Etive_Mor_from_Kingshouse_Hotel.jpg",
        "author": "jtweedie1976 (Flickr)",
        "licence": "CC BY 2.0",
        "use": "skyline only: for each column the first row that is not sky (1200 px wide copy), following a "
               "guide drawn by eye, outliers removed; two inner lines drawn by eye; no pixels kept",
    },
}
MOOR_PX = 389          # the drop from the summit to the flat of the moor in the photograph (1200 px wide copy)
LINES = {
    # the pyramid's left ridge, in front of the far snowy top behind it (photo px)
    "front_ridge": [(316, 324), (340, 314), (370, 306), (400, 294), (418, 286), (432, 278)],
    # the pyramid's right flank, in front of the far hill on the right
    "right_flank": [(1040, 366), (1060, 394), (1080, 406), (1100, 422), (1120, 434), (1140, 446), (1160, 454),
                    (1180, 462), (1200, 468)],
}


def trace(path):
    world.skyline_from_trace(path, SKYLINE, META, step=1, unit=MOOR_PX, lines=LINES)


ARC = world.ARC
# The summit (x, y) fractions and points per unit (its height over the moor): 0.365 pt per photo px, so the
# flanks pass through the arc's feet; the moor lies at 0.735, the river just under it.
FRAME = (0.559, 0.345, 0.365 * MOOR_PX)
LIGHT = (-0.62, -0.55, 0.55)   # from the left, as in the photograph


def crests(sk, w, h, S):
    sx, sy, _ = FRAME
    sky = sk.crest(w, h, sx, sy, S, ends="slope")
    xs = np.arange(w) + 0.5
    near = sky.copy()
    for name in ("front_ridge", "right_flank"):
        pts = sk.line(name, w, h, sx, sy, S)
        px, py = zip(*pts)
        inside = (xs >= min(px)) & (xs <= max(px))
        near = np.where(inside, np.maximum(near, np.interp(xs, px, py)), near)
    # past the right flank's last point, it runs on down at its own slope
    px, py = zip(*sk.line("right_flank", w, h, sx, sy, S))
    slope = (py[-1] - py[-3]) / (px[-1] - px[-3])
    near = np.where(xs > px[-1], np.maximum(near, py[-1] + slope * (xs - px[-1])), near)
    return sky, near


def far_layer(sk):
    """The far tops behind the pyramid: the snowy top behind its left ridge and the hill beyond its right flank,
    paler in the air between, snow on their crests, lit from the left."""
    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = FRAME[2] * SS
        sky, _ = crests(sk, w, h, S)
        v, cover, snow_lit, nx = om.mountain(w, h, rng, sky, 0.36, LIGHT, snowline=(FRAME[1] + 0.5 * FRAME[2] / world.H),
                                             gully=0.5, haze=0.15, haze_v=0.6, snow_v=(0.62, 0.98), rim=0.12)
        return dict(value=v, cover=cover, glow=snow_lit * 0.7, lean=nx, crest=sky)
    return layer


def buachaille_layer(sk):
    """The pyramid: the face toward the light (left of the ridge that runs down from the summit to the right) in
    sun, the north face beyond it in shadow; dark rhyolite buttresses fanning down from the summit, each lit on its
    left edge, with gullies between them where old snow lies under the summit; lower down the rock gives way to the
    moorland apron, in the shadow of a cloud, ribbed by burns."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        _, cy = crests(sk, w, h, S)
        cover = world.below(cy, h, 0.5)
        yy, xx = ctx["yy"], ctx["xx"]
        v_ = (yy - sy * h) / S                       # units below the summit
        u_ = (xx - sx * w) / S
        # The fall line fans out from the summit; buttresses and gullies run down it.
        fan = np.pi / 2 - 0.8 * np.tanh(u_ / np.maximum(v_ + 0.12, 0.12))
        rib = world.streaks(h, w, rng, fan, 0.16 * S, base=30)
        fine = world.streaks(h, w, rng, fan, 0.08 * S, base=80)
        # ledges across the crags, leaning a little
        ledge = world.oc.sheared_noise(h, w, rng, 16, 3.5, -0.2, sy * h, octaves=3)
        relief = sobel(gaussian_filter(rib, 1.2 * SS), axis=1)
        relief = np.tanh(-relief / (relief.std() + 1e-9))         # > 0 on the left (lit) edge of each buttress
        # Crags: a ridged height field, each facet turned to or from the light (the face is broken rock, not a
        # smooth cone), drawn out a little down the fall line.
        crag = 1 - np.abs(fbm(h, w, rng, base=16, octaves=5, persistence=0.55))
        crag = 0.6 * crag + 0.4 * world.mt.lic(crag, fan, 6 * SS, step=1.0) + 0.25 * np.tanh(ledge) * 0.3
        cg = gaussian_filter(crag, 0.9 * SS)
        gx, gy = sobel(cg, axis=1) * 1.6, sobel(cg, axis=0) * 1.6
        facet = world.lambert(-gx, -gy - 0.35, np.ones_like(gx) * 0.6, LIGHT, 1.4)
        # The shadow edge: the ridge from the summit down to the right (wandering a little).
        edge = 0.86 * v_ + 0.03 + 0.03 * fbm(h, w, rng, base=6, octaves=3)
        sun = smoothstep(0.02, -0.02, u_ - edge)
        lit_v = 0.25 + 0.3 * facet + 0.04 * relief + 0.03 * fine - 0.05 * smoothstep(0.6, 1.6, rib)
        shade_v = 0.15 + 0.14 * facet + 0.02 * relief - 0.03 * smoothstep(0.6, 1.6, rib)
        rock = shade_v + (lit_v - shade_v) * sun
        # Old snow in the gullies under the summit, more in the upper gullies, patchy.
        gully = smoothstep(0.15, 1.1, -rib + 0.6 * fbm(h, w, rng, base=60, octaves=2) + 0.6 * (facet - 0.5) * 2)
        reach = 0.32 + 0.08 * fbm(h, w, rng, base=14, octaves=2)
        snow = gully * smoothstep(reach, reach - 0.18, v_) * smoothstep(-0.01, 0.03, v_)
        # as in the photograph, the snow lies on the sunlit upper faces left of the summit, little on the right
        snow = np.clip(snow * 1.6, 0, 1) * (0.25 + 0.75 * sun) * smoothstep(0.12, -0.05, u_ - 0.25 * v_)
        snow_v = 0.62 + 0.32 * sun
        value = rock + (snow_v - rock) * snow
        # The apron: below about 0.55 units, moorland in the shadow of a cloud, ribbed by burns.
        foot = 0.52 + 0.05 * fbm(h, w, rng, base=10, octaves=3) + 0.03 * np.tanh(rib)
        moor = smoothstep(foot - 0.05, foot + 0.1, v_)
        moor_v = 0.17 + 0.03 * fine + 0.03 * relief - 0.08 * smoothstep(0.6, 1.0, v_)
        value = value + (moor_v - value) * moor
        glow = snow * sun
        lean = np.clip(-0.9 * np.tanh(u_ / np.maximum(v_ + 0.12, 0.12)), -1, 1)
        sg = gaussian_filter(sun, 0.6 * SS)
        keep = (np.clip(np.hypot(*np.gradient(sg)) * 3 * SS, 0, 1) * smoothstep(0.6, 0.3, v_)
                + 0.35 * np.clip(np.abs(relief) - 0.6, 0, 1) * smoothstep(0.5, 0.15, v_))
        return dict(value=value, cover=cover, glow=glow, lean=lean, keep=np.clip(keep, 0, 1) * cover, crest=cy)
    return layer


def moor_layer():
    """The flat of Rannoch Moor at the pyramid's foot, peat and heather in long level strokes, dark."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        top = (sy + 1.0 * size / world.H) * h
        line = top + 1.2 * SS * fbm(1, w, rng, base=8, octaves=3)[0]
        cover = world.below(line, h, 0.8)
        yy = ctx["yy"]
        v = 0.17 + 0.04 * fbm(h, w, rng, base=12, octaves=3, stretch=6.0) - 0.06 * smoothstep(top, top + 20 * SS, yy)
        angle = 0.05 * fbm(h, w, rng, base=3, octaves=2)
        return dict(value=v, cover=cover, angle=angle, crest=line, ground=True)
    return layer


def river_layer():
    """The River Etive winding across the moor: a band of still dark water catching a little of the sky."""
    sx, sy, size = FRAME

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        top = (sy + 1.13 * size / world.H) * h
        xs = np.arange(w) / w
        upper = top + (6 * np.sin(xs * 5.2 + 0.4) + 3 * np.sin(xs * 13 + 1.1)) * SS
        lower = upper + (9 + 4 * np.sin(xs * 7.1 + 2.0)) * SS
        yy = ctx["yy"]
        band = world.below(upper, h, 0.6) * (1 - world.below(lower, h, 0.6))
        glint = smoothstep(1.0, 2.4, fbm(h, w, rng, base=16, octaves=3, stretch=10.0))
        v = 0.24 + 0.14 * glint - 0.06 * smoothstep(0, 1, (yy - upper[None, :]) / (lower - upper)[None, :])
        return dict(value=v, cover=band, angle=0.02 * np.ones((h, w)), ground=True)
    return layer


def bank_layer():
    """The near bank: tussock grass and heather, dark, in short upright strokes."""
    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        top = 0.86 * h
        xs = np.arange(w) / w
        line = top + (5 * np.sin(xs * 4.0 + 0.7) + 2 * np.sin(xs * 17)) * SS + 2 * SS * fbm(1, w, rng, base=30, octaves=2)[0]
        cover = world.below(line, h, 0.6)
        v = 0.12 + 0.05 * fbm(h, w, rng, base=40, octaves=3, stretch=0.3)
        angle = np.pi / 2 + 0.25 * fbm(h, w, rng, base=20, octaves=2)
        return dict(value=v, cover=cover, angle=angle, crest=line, ground=True)
    return layer


def large():
    sk = world.Skyline(SKYLINE)
    return world.compose(348, 365, 711, sun=(0.3, 0.12), horizon=0.58,
                         sky=dict(dark_top=0.2, bright=0.62, low=0.6),
                         clouds=[(-0.02, 0.12, 0.44, 0.13, 36, 0.55), (1.02, 0.1, 0.46, 0.13, 36, 0.5),
                                 (0.0, 0.6, 0.16, 0.1, 26), (0.8, 0.565, 0.13, 0.08, 24)],
                         calm=(0.5, 0.3, 0.34, 0.22, 0.75),
                         layers=[far_layer(sk), buachaille_layer(sk), moor_layer(), river_layer(), bank_layer()],
                         ground_dark=(0.6, 1.0, 0.45))


if __name__ == "__main__":
    world.main(HERE, large, ARC, trace)
