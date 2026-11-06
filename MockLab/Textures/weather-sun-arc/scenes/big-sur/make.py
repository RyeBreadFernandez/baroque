#!/usr/bin/env python3
"""Sun Arc scene: Big Sur, Bixby Creek Bridge, from the turnout north of it on Highway 1, looking south in the late
light. The open-spandrel concrete arch leaps the dark mouth of Bixby Creek, its deck level with the sea's horizon;
the hills of Hurricane Point rise behind it in haze; the headland falls in cliffs to the cove; the Pacific is on the
right (west), where the sun goes down into the sea. The brush below, the canyon's shadow and the cove are the dark
ground the temperature is set on.

The hills' skyline, the bridge, the shore and the sea stack are big-sur.json, traced from Aaron Albrecht's
photograph (see SOURCE.md), all at one scale (SCALE below; never stretched). The arc's left foot stands on the
bridge deck, its right foot on the sea's horizon. The hills behind the bridge are a hazed middle distance: they are
drawn again in front of the arc only faintly (HAZE), so the gilt line reads down across them to the deck.

Run from anywhere (deterministic, no network):  python3 .../scenes/big-sur/make.py [--preview <folder>]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("ca_paint", os.path.join(os.path.dirname(HERE), "half-dome",
                                                                        "ca_paint.py"))
ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ca)
om, mt, SS, smoothstep, fbm = ca.om, ca.mt, ca.SS, ca.smoothstep, ca.fbm

DATA = ca.load(os.path.join(HERE, "big-sur.json"))
ARC = (0.5, 0.575, 0.42, 0.45)       # the Matterhorn's arc: the left foot on the deck, the right on the sea
SCALE = 0.27                         # points per photograph pixel
CROP_X = 235                         # the photograph's column at the canvas's left edge
HORIZON_PT = 208.0                   # where the sea's horizon (photo y 553) falls on the canvas
HAZE = 0.3                           # how far the hills above the horizon stand in front of the arc
LIGHT = (0.6, -0.5, 0.6)             # the late sun from the right, over the sea


def p(x, y):
    return (x, y)


def to_px(x, y):
    """Photograph pixels to canvas pixels (at SS)."""
    hz = DATA["trace"]["horizon"]
    return (np.asarray(x, float) - CROP_X) * SCALE * SS, (HORIZON_PT + (np.asarray(y, float) - hz) * SCALE) * SS


def hills(c):
    """Hurricane Point's hills and the headland under the traced skyline: brush-covered slopes turning to the light,
    hazed with distance; below the horizon the headland's cliffs and the canyon fall into shadow."""
    w, h, rng = c.w, c.h, c.rng
    sk = DATA["skyline"]
    xs, ys = to_px(np.arange(len(sk["y"])) * sk["step"] + sk["x0"], sk["y"])
    cy = np.interp(np.arange(w) + 0.5, xs, ys)
    hy = HORIZON_PT * SS
    shore = np.array(DATA["shore"], float)
    shore[:, 0] = np.convolve(np.pad(shore[:, 0], 2, mode="edge"), np.ones(5) / 5, "valid")   # a smooth shore
    sx_, sy_ = to_px(shore[:, 0], shore[:, 1])
    shore_x = np.interp(c.yy[:, 0], sy_, sx_, left=sx_[0], right=sx_[-1])[:, None]
    cy = np.where(c.xx[0] > shore_x[int(hy) + 2, 0] + 2 * SS, h * 2, cy)       # past the point: open sea
    v, cover, lit, nx = om.mountain(w, h, rng, cy, 0.32, LIGHT, gully=0.35, contrast=1.1, haze=0.12, haze_v=0.5,
                                    shear=1.1, mist=(30, 70, 0.3))
    yy, xx = c.yy, c.xx
    below_hz = smoothstep(hy - 1 * SS, hy + 1 * SS, yy)
    # Below the horizon: the headland's cliffs keep the range's own modelling, darkened; the canyon behind the
    # bridge (left of the headland) falls into deep shadow.
    canyon = 0.08 + 0.03 * fbm(h, w, rng, base=12, octaves=3)
    under = v * 0.75 + (canyon - v * 0.75) * smoothstep(0.5 * w, 0.4 * w, xx)
    v = v + (under - v) * below_hz
    land = smoothstep(shore_x + 1 * SS, shore_x - 1 * SS, xx) * below_hz + cover * (1 - below_hz)
    front = HAZE + (1 - HAZE) * below_hz
    c.add(np.clip(v, 0, 1), np.clip(land, 0, 1), lit=lit * (1 - below_hz) * 0.6, lean=nx, front=front)
    return shore_x


def sea(c, shore_x):
    """The Pacific right of the headland and in the cove: pale toward the horizon, darkening in; long swells, a path
    of light under the late sun, a quiet line of surf along the beach and at the sea stack."""
    w, h, rng = c.w, c.h, c.rng
    hy = HORIZON_PT * SS
    yy, xx = c.yy, c.xx
    v, cover, lit, angle = ca.water(c, hy, 0.06, 0.56, rng, glitter_x=0.94 * w, glitter=0.8)
    d = np.maximum(yy - hy, 0) / SS
    swell = np.sin(1 / (d + 3.0) * 260 + 1.6 * fbm(h, w, rng, base=3, octaves=2, stretch=4.0))
    v = v + 0.05 * swell * smoothstep(0, 4, d) * smoothstep(60, 20, d)
    v = v - 0.06 * smoothstep(3, 0.5, d) * smoothstep(-1, 1, d)
    # Surf along the shore under the cliffs, and round the sea stack.
    along = np.abs(xx - shore_x)
    surf = smoothstep(2.5 * SS, 0.5 * SS, along) * smoothstep(-0.5, 0.6, fbm(h, w, rng, base=30, octaves=2, stretch=0.4)) \
        * smoothstep(hy + 70 * SS, hy + 20 * SS, yy)                     # quiet, and only up in the cove
    stack = np.array(DATA["stack"], float)
    kx, ky = to_px(stack[:, 0], stack[:, 1])
    st_top = np.interp(xx[0], kx, ky, left=h * 2, right=h * 2)
    rock = smoothstep(-0.4 * SS, 0.4 * SS, yy - st_top[None, :]) * smoothstep(hy + 6 * SS, hy + 4 * SS, yy)
    ring = smoothstep(1.5 * SS, 0, np.abs(yy - (hy + 4.5 * SS))) * smoothstep(kx[0] - 4 * SS, kx[0], xx) \
        * smoothstep(kx[-1] + 4 * SS, kx[-1], xx)
    v = v + (0.7 - v) * np.maximum(surf, ring) * 0.7
    v = v + (0.12 - v) * rock
    lit = np.maximum(lit, np.maximum(surf, ring) * 0.5)
    c.add(np.clip(v, 0, 1), cover * smoothstep(shore_x - 1 * SS, shore_x + 1 * SS, xx), lit=lit, angle=angle)


def bridge(c):
    """The bridge: the traced concrete, pale in the late light, the deck's edge and the arch's rib lit, the
    spandrel columns and piers darkening down into the canyon's shadow; its drawing laid back crisp."""
    w, h, rng = c.w, c.h, c.rng
    b = DATA["bridge"]
    x0, y0 = to_px(b["x0"], b["y0"])
    m = ca.rle_mask(b, w, h, x0, y0, b["h"] * SCALE * SS)
    yy = c.yy
    hy = HORIZON_PT * SS
    depth = (yy - hy) / SS                                                 # points below the deck
    v = 0.86 - 0.004 * depth + 0.03 * fbm(h, w, rng, base=40, octaves=2, stretch=0.3)
    v = v - 0.3 * smoothstep(50, 70, depth)                                # its feet in the canyon's shadow
    # The near spans on the left stand in the hill's shadow below the deck (where the sunrise time is set).
    shade = smoothstep(80 * SS, 48 * SS, c.xx) * smoothstep(3.5, 5.5, depth)
    v = v * (1 - 0.6 * shade)
    # Lay the whole bridge back crisp, the dark gaps between its columns with it, so no stroke smears it.
    bx1, by1 = to_px(b["x0"] + b["w"], b["y0"] + b["h"])
    frame = smoothstep(x0 - 1, x0 + 2 * SS, c.xx) * smoothstep(bx1 + 1, bx1 - 2 * SS, c.xx) \
        * smoothstep(y0 - 1, y0 + 2 * SS, yy) * smoothstep(by1 + 1, by1 - 2 * SS, yy)
    c.add(np.clip(v, 0, 1), m, lit=0.5 * m * smoothstep(20, 0, depth), angle=np.full((h, w), np.pi / 2))
    c.keep = np.maximum(c.keep, frame * 0.9)


def brush(c):
    """The near slope of coastal brush along the bottom left, dark, in rough tufts."""
    w, h, rng = c.w, c.h, c.rng
    edge = om.crest([p(0, 0.69), p(0.15, 0.71), p(0.3, 0.74), p(0.45, 0.78), p(0.55, 0.84), p(0.62, 1.0)], 751, w, h,
                    0.25)
    v = 0.12 + 0.04 * fbm(h, w, rng, base=24, octaves=3, stretch=0.6)
    tufts = mt.speckle(h, w, rng, 0.006, size=(1.2 * SS, 3.5 * SS))
    v = v - 0.05 * np.clip(tufts, 0, 1) + 0.05 * np.clip(np.roll(tufts, -2 * SS, axis=0) - tufts, 0, 1)
    c.add(np.clip(v, 0, 1), ca.below(edge, h, soft=2.0), angle=np.full((h, w), -0.6), ground=True)


def paint():
    c = ca.Canvas(743)
    c.sky(sun=(0.86, 0.5), horizon=HORIZON_PT / ca.H, dark_top=0.18, bright=0.7, low=0.62,
          clouds=[(-0.02, 0.1, 0.42, 0.12, 34, 0.55), (1.02, 0.12, 0.44, 0.12, 34, 0.5),
                  (0.06, 0.36, 0.16, 0.07, 22), (0.96, 0.46, 0.18, 0.08, 22)],
          calm=(0.5, 0.3, 0.32, 0.2, 0.55))
    shore_x = hills(c)
    sea(c, shore_x)
    bridge(c)
    brush(c)
    return c.finish(contrast=1.3, ground_dark=(0.6, 0.95, 0.5))


def main():
    pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    value, glow, land = paint()
    ca.write(HERE, value, glow, land)
    if pv:
        os.makedirs(pv, exist_ok=True)
        ca.preview(os.path.join(pv, "pv-big-sur.png"), value, glow, ARC)


if __name__ == "__main__":
    main()
