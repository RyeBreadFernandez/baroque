#!/usr/bin/env python3
"""Sun Arc scene: Mount Whitney and the Sierra crest from the Alabama Hills above Lone Pine, looking west in the early
light: the saw of the Whitney Needles and the summit block beside them, lit from the left, snow in their gullies;
the escarpment falling away below into shadow; the rounded granite boulder piles of the Alabama Hills dark in the
foreground, rising at both sides where the arc's feet stand; the sage flats below, the ground the temperature is set
on.

The crest is whitney.json, traced from the Bureau of Land Management's photograph (see SOURCE.md), at one scale:
CREST below only places and sizes it (never stretched). The arc's feet stand on the two cols either side of the
needles and the summit, so the whole massif is under the arc.

Run from anywhere (deterministic, no network):  python3 .../scenes/whitney/make.py [--preview <folder>]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter, gaussian_filter1d

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("ca_paint", os.path.join(os.path.dirname(HERE), "half-dome",
                                                                        "ca_paint.py"))
ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ca)
om, mt, SS, smoothstep, fbm = ca.om, ca.mt, ca.SS, ca.smoothstep, ca.fbm

PROFILE = ca.load(os.path.join(HERE, "whitney.json"))
ARC = (0.5, 0.57, 0.42, 0.45)            # scene.json: the feet on the cols either side of the massif
CREST = (247 / 348, 153.5 / 365, 52.5)    # Whitney's summit at (x, y) (fractions); its height above the north col, pt
LIGHT = (-0.5, -0.55, 0.65)              # early light from the left and in front, as in the photograph


def p(x, y):
    return (x, y)


def crest(c):
    """The Sierra crest on the traced skyline: Old Master's range, each spire's face toward the light lit and the
    other in shadow, bare granite with a little snow lodged on the ledges and in the gullies below the summits; the
    escarpment darkening into shadow below."""
    w, h, rng = c.w, c.h, c.rng
    sx, sy, height = CREST
    unit = height * SS
    cy = ca.crest(PROFILE["x"], PROFILE["y"], w, h, sx, sy, unit)
    v, cover, lit, nx = om.mountain(w, h, rng, cy, 0.44, LIGHT, gully=0.9, contrast=1.35, shear=0.12)
    depth = (c.yy - cy[None, :]) / unit
    # The pinnacles: each face takes its light from the slope of the crest straight above it, so every needle is
    # lit down its left flank and dark down its right, the line between them dropping from its tip.
    k = max(w, h) / unit
    wobble = 0.6 * SS * fbm(h, w, rng, base=6 * k, octaves=2, stretch=0.2)
    xs = np.clip(c.xx + wobble * depth * 4, 0, w - 1)
    top_slope = np.gradient(gaussian_filter1d(cy, 0.8 * SS))
    lean = np.tanh(np.interp(xs, np.arange(w), top_slope) * 2.2)          # < 0: the face rises to the right, lit
    granite = mt.lic(fbm(h, w, rng, base=40 * k, octaves=3, stretch=0.15), np.full((h, w), np.pi / 2), 6 * SS, step=1.0)
    granite = (granite - granite.mean()) / (granite.std() + 1e-9)
    spire = 0.5 - 0.3 * lean + 0.035 * granite
    spire = spire + 0.12 * smoothstep(0.12, 0.0, depth) * (lean < 0)       # the lit tips
    near_top = smoothstep(0.75, 0.15, depth)
    # A little snow lodged in the gullies just below the summits.
    gully = om.mountain(w, h, np.random.default_rng(722), cy, 1.0, LIGHT, snowline=sy + 0.1 * height / ca.H,
                        gully=0.8)[2]
    v = v + (0.86 - v) * 0.35 * np.clip(gully, 0, 1) * smoothstep(0.2, 0.5, depth) * smoothstep(1.0, 0.6, depth)
    v = v + (spire - v) * near_top
    nx = nx * (1 - near_top) + lean * near_top
    shade = smoothstep(0.45, 1.4, depth)                       # the escarpment below the summits, in shadow
    v = v * (1 - 0.6 * shade)
    lit = lit * (1 - shade)
    g = gaussian_filter(v, 0.6 * SS)
    edges = np.clip(np.abs(np.gradient(g, axis=1)) * 5, 0, 1) * smoothstep(0.6, 0.05, depth)
    c.add(np.clip(v, 0, 1), cover, lit=lit, lean=nx, keep=edges * 0.6)
    return cy


def foothills(c):
    """The lower escarpment and the alluvial fan under it: a hazed, darker range below the cols."""
    w, h = c.w, c.h
    ridge = om.crest([p(0, 0.61), p(0.2, 0.6), p(0.45, 0.615), p(0.7, 0.605), p(1, 0.61)], 811, w, h, 0.3)
    c.range(ridge, 0.2, LIGHT, gully=0.5, haze=0.06, haze_v=0.35, contrast=0.8)


def alabama_hills(c):
    """The boulder piles: a heap on each side, the arc's feet standing behind their crowns, a lower one in the
    middle; every stone rounded and dark, lit along its crown from the left, deep shadow in the joints."""
    w, h, rng = c.w, c.h, c.rng
    for keys, seed, x0, x1, size, depth in (
            ([p(-0.05, 0.56), p(0.04, 0.565), p(0.13, 0.59), p(0.24, 0.635), p(0.34, 0.665)], 821, -24, 124, (11, 19), 44),
            ([p(0.62, 0.665), p(0.74, 0.63), p(0.86, 0.586), p(0.95, 0.565), p(1.05, 0.56)], 823, 212, 372, (11, 19), 44),
            ([p(0.36, 0.66), p(0.44, 0.645), p(0.52, 0.65), p(0.6, 0.665)], 825, 122, 212, (6, 10), 20)):
        top = om.crest(keys, seed, w, h, 0.25)
        v, cover, lit, angle, joints = ca.boulders(c, top, x0 * SS, x1 * SS, rng, (size[0] * SS, size[1] * SS), 0.22,
                                                   light=(-0.45, -0.75, 0.5), lit_amount=0.3, depth=depth * SS,
                                                   grow=1.2, contrast=0.8, rim=1.0, cracks=0.8)
        c.add(v, cover, lit=lit, angle=angle, keep=joints * 0.8)


def flats(c):
    """Sage flats between the piles: dark scrub in rounded clumps."""
    w, h, rng = c.w, c.h, c.rng
    ground = om.crest([p(0, 0.69), p(0.2, 0.685), p(0.5, 0.675), p(0.8, 0.685), p(1, 0.69)], 831, w, h, 0.3)
    v = 0.13 + 0.03 * fbm(h, w, rng, base=20, octaves=3, stretch=3.0)
    clumps = mt.speckle(h, w, rng, 0.004, size=(1.5 * SS, 4 * SS))
    v = v - 0.05 * np.clip(clumps, 0, 1) + 0.04 * np.clip(np.roll(clumps, -2 * SS, axis=0) - clumps, 0, 1)
    c.add(np.clip(v, 0, 1), ca.below(ground, h, soft=3.0), angle=np.zeros((h, w)), ground=True)


def paint():
    c = ca.Canvas(721)
    c.sky(sun=(0.25, 0.08), horizon=0.5, dark_top=0.18, bright=0.6, low=0.56,
          clouds=[(-0.02, 0.1, 0.42, 0.12, 34, 0.55), (1.02, 0.12, 0.44, 0.12, 34, 0.5),
                  (0.1, 0.44, 0.2, 0.1, 26), (0.9, 0.42, 0.2, 0.1, 26)],
          calm=(0.5, 0.3, 0.32, 0.2, 0.55))
    crest(c)
    foothills(c)
    alabama_hills(c)
    flats(c)
    return c.finish(contrast=1.3, ground_dark=(0.58, 0.95, 0.45))


def main():
    pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    value, glow, land = paint()
    ca.write(HERE, value, glow, land)
    if pv:
        os.makedirs(pv, exist_ok=True)
        ca.preview(os.path.join(pv, "pv-whitney.png"), value, glow, ARC)


if __name__ == "__main__":
    main()
