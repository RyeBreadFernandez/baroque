#!/usr/bin/env python3
"""Sun Arc scene: Joshua Tree at evening. A tall Joshua tree stands under the arc's crown, its arms raised and every
arm ending in a spiky rosette, black against the afterglow and rim-lit on its edges; heaps of rounded monzogranite
boulders lie along the horizon where the arc's feet stand; more Joshua trees stand out on the flat; the dark desert
floor below is the ground the temperature is set on.

Every tree is a silhouette traced from a public-domain National Park Service photograph and the boulders' skyline
from another (joshua-tree.json; see SOURCE.md); each is scaled uniformly (never stretched).

Run from anywhere (deterministic, no network):  python3 .../scenes/joshua-tree/make.py [--preview <folder>]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("ca_paint", os.path.join(os.path.dirname(HERE), "half-dome",
                                                                        "ca_paint.py"))
ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ca)
om, mt, SS, smoothstep, fbm = ca.om, ca.mt, ca.SS, ca.smoothstep, ca.fbm

DATA = ca.load(os.path.join(HERE, "joshua-tree.json"))
ARC = (0.5, 0.575, 0.42, 0.45)              # the Matterhorn's arc: the feet on the boulder piles
LIGHT = (0.5, -0.55, 0.6)                   # the afterglow, from the upper right
GROUND = 0.6                                # the desert floor's far edge (fraction), under the piles
# Trees: (name, left x pt, top y pt, height pt). The hero stands on the floor in front of the piles; the others are
# further out on the flat, their feet hidden in the scrub.
TREES = [("hero", 104, 78, 156), ("pair", 226, 168, 50), ("small", 64, 188, 26), ("cluster", 204, 194, 20)]
# Boulder piles: (first unit, last unit of the traced skyline, its left x pt, base y pt, pile height pt)
PILES = [(0.0, 6.4, -18, 218, 40), (0.0, 2.6, 252, 209, 34)]


def p(x, y):
    return (x, y)


def far_range(c):
    """The Little San Bernardino Mountains far off along the horizon, low and hazed."""
    w, h = c.w, c.h
    ridge = om.crest([p(0, 0.575), p(0.2, 0.568), p(0.4, 0.574), p(0.62, 0.565), p(0.8, 0.562), p(1, 0.57)],
                     911, w, h, 0.2)
    c.range(ridge, 0.3, LIGHT, gully=0.3, haze=0.45, haze_v=0.42, contrast=0.5)


def piles(c):
    """The boulder heaps along the horizon, on the traced skyline: rounded stones, dark, their crowns catching the
    afterglow."""
    w, h, rng = c.w, c.h, c.rng
    px, py = np.array(DATA["piles"]["x"]), np.array(DATA["piles"]["y"])
    for u0, u1, x0, base, height in PILES:
        sel = (px >= u0) & (px <= u1)
        xs = (x0 + (px[sel] - u0) * height) * SS
        top = np.interp(np.arange(w) + 0.5, xs, base * SS + py[sel] * height * SS, left=h * 2, right=h * 2)
        top = np.minimum(top, base * SS)
        span = (xs[0], xs[-1])
        v, cover, lit, angle, joints = ca.boulders(c, top, span[0], span[1], rng, (3 * SS, 7 * SS), 0.24,
                                                   light=LIGHT, lit_amount=0.4, depth=height * 0.9 * SS, grow=1.3,
                                                   contrast=0.9, rim=0.9)
        c.add(v, cover, lit=lit, angle=angle, keep=joints * 0.6)


def floor(c):
    """The desert floor: dark scrub in rounded clumps, darkening toward the viewer."""
    w, h, rng = c.w, c.h, c.rng
    edge = om.crest([p(0, GROUND), p(0.5, GROUND + 0.006), p(1, GROUND)], 921, w, h, 0.05)
    v = 0.16 + 0.03 * fbm(h, w, rng, base=20, octaves=3, stretch=3.0)
    clumps = mt.speckle(h, w, rng, 0.005, size=(1.2 * SS, 3.5 * SS))
    v = v - 0.06 * np.clip(clumps, 0, 1) + 0.05 * np.clip(np.roll(clumps, -2 * SS, axis=0) - clumps, 0, 1)
    c.add(np.clip(v, 0, 1), ca.below(edge, h), angle=np.zeros((h, w)), ground=True)


def joshua_trees(c):
    """The traced Joshua trees: black against the sky, rim-lit along the edges that face the afterglow, the bark of
    trunk and arms in a few vertical strokes."""
    w, h, rng = c.w, c.h, c.rng
    for name, x0, y0, height in TREES:
        m = ca.rle_mask(DATA["trees"][name], w, h, x0 * SS, y0 * SS, height * SS)
        near = height / TREES[0][3]
        rim = np.clip(sobel(gaussian_filter(m, 0.5 * SS), axis=1) / 4 * SS, 0, 1)        # the edge toward the right
        top_rim = np.clip(-sobel(gaussian_filter(m, 0.5 * SS), axis=0) / 4 * SS, 0, 1)   # and the upper edges
        bark = mt.lic(fbm(h, w, rng, base=60, octaves=2, stretch=0.2), np.full((h, w), np.pi / 2), 4 * SS, step=1.0)
        v = 0.05 + 0.08 * (1 - near) + 0.015 * bark + (0.2 + 0.08 * (1 - near)) * np.maximum(rim, 0.5 * top_rim)
        # The silhouette is the drawing: laid back crisp over the strokes, so no arm or rosette is smeared away.
        c.add(np.clip(v, 0, 1), m, lit=0.3 * rim * m, angle=np.full((h, w), np.pi / 2) + 0.1 * bark, tree=True,
              keep=np.clip(m * 1.2, 0, 1))


def paint():
    c = ca.Canvas(761)
    c.sky(sun=(0.62, 0.58), horizon=0.58, dark_top=0.16, bright=0.7, low=0.62,
          clouds=[(-0.02, 0.1, 0.42, 0.12, 34, 0.55), (1.02, 0.12, 0.44, 0.12, 34, 0.5),
                  (0.06, 0.5, 0.18, 0.08, 24), (0.94, 0.5, 0.18, 0.08, 24)],
          calm=(0.5, 0.3, 0.32, 0.2, 0.55))
    far_range(c)
    piles(c)
    floor(c)
    joshua_trees(c)
    return c.finish(contrast=1.3, ground_dark=(0.6, 0.95, 0.45))


def main():
    pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    value, glow, land = paint()
    ca.write(HERE, value, glow, land)
    if pv:
        os.makedirs(pv, exist_ok=True)
        ca.preview(os.path.join(pv, "pv-joshua-tree.png"), value, glow, ARC)


if __name__ == "__main__":
    main()
