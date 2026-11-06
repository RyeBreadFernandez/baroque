#!/usr/bin/env python3
"""Sun Arc in another landscape: Mount Fuji over Lake Kawaguchi, the postcard view from the lake's north shore,
looking south-south-west. Left is east (dawn lights the left flank, the sun rises on the left), right is west.

The large Weather canvas (348 x 365 pt) as one grey value study, glazed at run time by the Cover's CoverLight:
  large-lo.png, large-hi.png   the lower and upper halves of the value
  large-glow.png               the brightest lights (the dawn-lit snow, cloud tops)
  large-front.png              the land (Fuji, the far shore, the lake), drawn again over the sun and the arc's feet
Data:
  fuji.json                    the skyline, traced from a photograph (see SOURCE.md) and normalised: the summit at
                               (0, 0), in units of Fuji's height above the lake's far shore in that photograph

Fuji is the traced skyline at one scale: its true, gentle slopes. The snow cap reaches about 0.4 units down, as in
the photograph (taken in January; Fuji's first lasting snow comes in October or November), a little higher out on
the flanks so the sun times at the arc's feet stay on dark ground. Those slopes set the framing: with the arc's feet
on the flanks, the summit can stand only about 65 pt above them, and the far shore and the dark water come low in
the canvas, under the cone's forested foot.

The shared painter (the Sun Arc canvas's machinery, generalised to layers) is world.py in this folder; the glencoe,
dolomites and tuscany scenes import it from here.

Run (deterministic, offline):  python3 MockLab/Textures/weather-sun-arc/scenes/fuji/make.py [--preview <png>]
Rebuild fuji.json from the full trace:  make.py --trace <trace.json>
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("sa_world", os.path.join(HERE, "world.py"))
world = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(world)
om, mt, SS = world.om, world.mt, world.SS
fbm, smoothstep = world.fbm, world.smoothstep

SKYLINE = os.path.join(HERE, "fuji.json")
META = {
    "peak": {"name": "Mount Fuji", "elevation_m": 3776},
    "view": "from the north shore of Lake Kawaguchi (Kawaguchi-ko, about 830 m), looking south-south-west",
    "source": {
        "photo": "File:Fuji Kawaguchi 460.JPG, Wikimedia Commons (20 January 2014)",
        "url": "https://commons.wikimedia.org/wiki/File:Fuji_Kawaguchi_460.JPG",
        "author": "Marion & Christoph Aistleitner",
        "licence": "CC0 1.0 (public domain dedication)",
        "use": "skyline only: for each column the first row that is not sky (3840 px wide copy), following a "
               "guide drawn by eye, outliers removed; no pixels kept",
    },
}
SHORE_PX = 925        # the drop from the summit to the lake's far shore in the photograph (3840 px wide copy)
AXIS_PX = -59         # the cone's axis, left of the highest point of the crater rim (photo px)


def trace(path):
    world.skyline_from_trace(path, SKYLINE, META, step=4, unit=SHORE_PX)


# The arc stays the Matterhorn's. Fuji: summit (x, y) fractions, and points per unit (its height above the far
# shore): 0.17 pt per photo px, so the flanks pass through the arc's feet and the shore lies at 0.83.
ARC = world.ARC
FRAME = (0.546, 0.397, 0.17 * SHORE_PX)


def cone(sk, w, h, sx, sy, S):
    """The volcano as a cone of revolution under the traced skyline: for every pixel its depth below the summit v
    (units), its longitude phi (0 facing the viewer, -pi/2 the left skyline, +pi/2 the right) and the slope angle
    alpha (radians from level), from how fast the traced flanks spread with depth."""
    x, y = sk.x, sk.y
    left, right = x <= 0, x >= 0
    lx, ly = x[left][::-1], np.maximum.accumulate(y[left][::-1])
    rx, ry = x[right], np.maximum.accumulate(y[right])
    depth = np.linspace(0, 2.0, 801)
    xl = np.interp(depth, ly, lx, right=np.nan)
    xr = np.interp(depth, ry, rx, right=np.nan)
    # past the traced ends, the flanks run on at their end slopes
    for arr, xs, ys in ((xl, lx, ly), (xr, rx, ry)):
        k = len(xs) - 1
        j = max(0, k - 12)
        slope = (xs[k] - xs[j]) / max(ys[k] - ys[j], 1e-6)
        bad = np.isnan(arr)
        arr[bad] = xs[k] + slope * (depth[bad] - ys[k])
    axis = AXIS_PX / SHORE_PX
    half = np.maximum((xr - xl) / 2, 1e-3)
    dr = np.gradient(gaussian_filter(half, 6), depth)
    alpha_d = np.arctan(1 / np.maximum(dr, 0.3))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u = (xx - sx * w) / S
    v = np.clip((yy - sy * h) / S, 0, 2.0)
    ul = np.interp(v, depth, xl)
    ur = np.interp(v, depth, xr)
    mid = (ul + ur) / 2 * 0.5 + axis * 0.5
    rr = np.maximum(np.where(u < mid, mid - ul, ur - mid), 1e-3)
    phi = np.arcsin(np.clip((u - mid) / rr, -1, 1))
    alpha = np.interp(v, depth, alpha_d)
    return u, v, phi, alpha


def fuji_layer(sk, frame):
    """Fuji lit at dawn from the left: the snow cap on the upper third, its foot torn into long fingers down the
    gullies (snow lies longer in them), dark ribs of rock through it; the left flank's snow in full light, the right
    flank's in cool half-shadow; below the snow the dark lava slopes and then the forest, hazing toward the foot."""
    sx, sy, size = frame

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        S = size * SS
        cy = sk.crest(w, h, sx, sy, S, ends="slope")
        cover = world.below(cy, h, 0.5)
        u, v, phi, alpha = cone(sk, w, h, sx, sy, S)
        nx = np.sin(alpha) * np.sin(phi)
        ny = -np.cos(alpha)
        nz = np.sin(alpha) * np.cos(phi)
        light = (-0.8, -0.35, 0.4)
        shade = world.lambert(nx, ny, nz, light, 1.3)
        # Fall-line noise: features long down the slope (in v) and narrow across it (in phi).
        nv, nphi = 64, 360
        tex = fbm(nv, nphi, rng, base=10, octaves=4, persistence=0.6, stretch=0.12)
        tex2 = fbm(nv, nphi, rng, base=22, octaves=3, persistence=0.5, stretch=0.1)
        cv = np.clip(v / 1.2, 0, 1) * (nv - 1)
        cp = (phi / np.pi + 0.5) * (nphi - 1)
        gully = map_coordinates(tex, [cv, cp], order=1, mode="nearest")
        rib = map_coordinates(tex2, [cv, cp], order=1, mode="nearest")
        # The snow cap: deeper on the right (north-west) flank, as in the photograph, its foot in fingers.
        broad = map_coordinates(fbm(nv, nphi, rng, base=4, octaves=2, stretch=0.3), [cv, cp], order=1, mode="nearest")
        line = (0.405 + 0.02 * np.sin(phi) - 0.09 * smoothstep(0.55, 0.95, np.abs(np.sin(phi)))
                + 0.035 * broad + 0.05 * np.clip(gully, -1.5, 2.5)
                + 0.01 * fbm(h, w, rng, base=40, octaves=2))
        snow = smoothstep(0.012, -0.012, v - line)
        rock = (smoothstep(0.7, 1.3, rib) * smoothstep(0.03, 0.12, v) * (0.5 + 0.5 * smoothstep(0.12, 0.34, v))
                * (0.6 + 0.4 * smoothstep(-0.3, 0.6, np.sin(phi))))
        snow = snow * (1 - 0.85 * rock)
        lit = shade
        snow_v = 0.44 + 0.54 * smoothstep(0.3, 0.8, lit)
        snow_v = snow_v - 0.06 * smoothstep(0.0, 1.0, gully) * (lit < 0.6)
        # Relief across the fall line: each rib lit on its left side, each gully shadowed on its right.
        relief = fbm(nv, nphi, rng, base=30, octaves=3, persistence=0.5, stretch=0.08)
        drel = np.gradient(gaussian_filter(relief, (0.5, 1.2)), axis=1)
        drel = drel / (drel.std() + 1e-9)
        rel = map_coordinates(drel, [cv, cp], order=1, mode="nearest")
        snow_v = snow_v - 0.1 * np.tanh(rel) * smoothstep(0.02, 0.1, v)
        # Lava and forest below: dark, ribbed down the fall line, lighter toward the lit flank, hazed at the foot.
        slope_v = 0.15 + 0.12 * lit + 0.025 * rib - 0.05 * smoothstep(0.42, 0.7, v)
        slope_v = slope_v + (0.30 - slope_v) * 0.35 * smoothstep(0.55, 0.95, v)   # haze over the forested foot
        value = slope_v + (snow_v - slope_v) * snow
        glow = snow * smoothstep(0.55, 0.9, lit)
        # stroke lean: down the fall line, out from the axis
        lean = -0.75 * np.sin(phi) * np.clip(1.4 - v, 0.3, 1)
        g = gaussian_filter(snow, 0.8 * SS)
        keep = np.clip(np.hypot(np.gradient(g, axis=0), np.gradient(g, axis=1)) * 2.2 * SS, 0, 1) * cover * 0.7
        return dict(value=value, cover=cover, glow=glow, lean=lean, keep=keep, crest=cy)
    return layer


def shore_layer(frame):
    """The lake's far shore under Fuji's forested foot: a band of dark rounded crowns (and the odd roof), lit a
    little from the left."""
    sx, sy, size = frame

    def layer(ctx):
        w, h, rng = ctx["w"], ctx["h"], ctx["rng"]
        base = (sy + size / world.H) * h  # the shore line (px)
        polys = []
        x = -5.0
        while x < w + 5:
            r = rng.uniform(2.0, 4.6) * SS
            top = base - rng.uniform(1.5, 5.5) * SS
            polys.append([(x + r * np.cos(t), top + r * 0.8 * np.sin(t) + r * 0.3) for t in np.linspace(np.pi, 2 * np.pi, 9)]
                         + [(x + r, base + 2 * SS), (x - r, base + 2 * SS)])
            x += r * rng.uniform(0.9, 1.6)
        m = world.draw_mask(w, h, polys)
        crest = np.full(w, base)
        m = np.maximum(m, world.below(crest - 1 * SS, h, 0.6))
        rim = np.clip(np.gradient(gaussian_filter(m, 0.6 * SS), axis=1) * 3 * SS, 0, 1)
        value = 0.1 + 0.05 * fbm(h, w, rng, base=30, octaves=3) + 0.12 * rim
        return dict(value=value, cover=m, crest=crest, tree=True)
    return layer


def large():
    sk = world.Skyline(SKYLINE)
    sx, sy, size = FRAME
    shore = (sy + size / world.H)
    return world.compose(348, 365, 701, sun=(0.36, 0.14), horizon=0.58,
                         sky=dict(dark_top=0.2, bright=0.6, low=0.58),
                         clouds=[(-0.02, 0.11, 0.42, 0.12, 34, 0.55), (1.02, 0.1, 0.44, 0.12, 34, 0.5),
                                 (0.1, 0.56, 0.2, 0.11, 30), (0.9, 0.565, 0.22, 0.13, 32)],
                         calm=(0.5, 0.32, 0.36, 0.24, 0.8),
                         layers=[fuji_layer(sk, FRAME), shore_layer(FRAME),
                                 world.water_layer(shore + 0.012, tone=0.22, ripple=0.05, reflect=0.5)],
                         ground_dark=(0.62, 1.0, 0.35))


if __name__ == "__main__":
    world.main(HERE, large, ARC, trace)
