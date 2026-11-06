#!/usr/bin/env python3
"""Sun Arc scene: Half Dome from Glacier Point, looking northeast up Tenaya Canyon, the view on every postcard. The
dome stands in profile with its visor under the arc's crown: its sheer northwest face is lit and falls straight down,
and its rounded back curves away to the right. Clouds Rest's long slab rises behind it on the left. The arc's left
foot stands on Clouds Rest's slope and its right foot on the dome's flank, both at the horizon. Tenaya Canyon in
shadow and the dark firs of Glacier Point's rim below are the ground the temperature is set on.

The dome and its skyline are half-dome.json, traced from el ui's photograph from Glacier Point (see SOURCE.md), at
one scale: DOME below only places and sizes it (never stretched). Lit as in the photograph, from the upper left.

Run from anywhere (deterministic, no network):  python3 .../scenes/half-dome/make.py [--preview <folder>]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("ca_paint", os.path.join(HERE, "ca_paint.py"))
ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ca)
om, mt, SS, smoothstep, fbm = ca.om, ca.mt, ca.SS, ca.smoothstep, ca.fbm

PROFILE = ca.load(os.path.join(HERE, "half-dome.json"))
ARC = (0.5, 0.575, 0.42, 0.45)         # the Matterhorn's arc (no scene.json)
# The framing: the arc's left foot on Clouds Rest's slope and its right foot on the dome's right flank, both where the
# traced skyline crosses the photograph's row 900 (columns 1658 and 2997), a point or two above the feet. So the scale
# is 292 pt / 1339 px = 0.218 pt per px, the visor stands under the arc's crown and the summit right of it.
DOME = (221.0 / 348, 141.2 / 365, 94.55)  # the summit at (x, y) (fractions) and the dome's height in points
LIGHT = (-0.55, -0.6, 0.6)             # from the upper left, as in the photograph: the face lit, the back turning away


def p(x, y):
    return (x, y)


def half_dome(c):
    """Everything under the traced skyline: the far ridges, Clouds Rest and the dome (its lit face, the dark streak
    down it, the rounded back in sheets of granite), then the forested shoulder at the dome's foot."""
    w, h, rng = c.w, c.h, c.rng
    sx, sy, height = DOME
    unit = height * SS
    xx, yy = c.xx, c.yy
    X, Y = sx * w, sy * h
    u, v = (xx - X) / unit, (yy - Y) / unit
    cy = ca.crest(PROFILE["x"], PROFILE["y"], w, h, sx, sy, unit)
    k = max(w, h) / unit
    grain = fbm(h, w, rng, base=30 * k, octaves=3)

    # Far ridges and Clouds Rest: Old Master's range on the traced crest, lit from the left. Clouds Rest's slab is
    # pale; the forested far ridges darker and hazed; Tenaya Canyon's shadow deepens toward the dome's foot.
    notch = ca.place([PROFILE["face_lower_left"][0]], w, h, sx, sy, unit)[0]
    rest = smoothstep(0.8, 0.62, (cy - Y) / unit)[None, :] * smoothstep(notch[0] + 30 * SS, notch[0], xx)
    base, cover, base_lit, nx = om.mountain(w, h, rng, cy, 0.48, LIGHT, gully=0.55, haze=0.25, haze_v=0.5, contrast=0.8)
    far = om.mountain(w, h, rng, cy, 0.22, LIGHT, gully=0.3, haze=0.12, haze_v=0.42, contrast=0.7)[0]
    value = far + (base - far) * rest
    slabs = mt.lic(fbm(h, w, rng, base=8 * k, octaves=3, stretch=3.0), np.full((h, w), 0.45), 12 * SS, step=1.0)
    value = value + 0.03 * rest * (slabs - slabs.mean()) / (slabs.std() + 1e-9)
    canyon = smoothstep(0.75, 1.25, v) * smoothstep(-2.6, -1.2, u)          # Tenaya Canyon's shadow
    value = value * (1 - 0.45 * canyon)
    lit = base_lit * rest * (1 - canyon)
    lean = nx

    # The dome: the polygon of its outline (skyline from the notch to its right foot, the edge against the forest
    # below that, the lower edge of the face on the left), under the traced skyline.
    sky_pts = [(px, py) for px, py in zip(PROFILE["x"], PROFILE["y"])
               if PROFILE["face_lower_left"][0][0] <= px <= PROFILE["dome_right"][0][0]]
    outline = [(px, py - 0.3) for px, py in sky_pts] + PROFILE["dome_right"] + \
        [(PROFILE["dome_right"][-1][0], 2.5), (PROFILE["face_lower_left"][-1][0], 2.5)] + PROFILE["face_lower_left"][::-1]
    dome = ca.polygon(ca.place(outline, w, h, sx, sy, unit), w, h) * ca.below(cy, h)
    face_r = ca.line_x(ca.place(PROFILE["face_right"], w, h, sx, sy, unit), h)[:, None]
    right_edge = ca.line_x(ca.place([(px, py) for px, py in sky_pts if px > 0.3] + PROFILE["dome_right"], w, h,
                                    sx, sy, unit), h)[:, None]
    face_l = ca.line_x(ca.place(PROFILE["face_left"], w, h, sx, sy, unit), h)[:, None]
    soft = 0.8 * SS
    face = smoothstep(3 * SS, -3 * SS, xx - face_r)      # the face turns into the dome's curve, not at an edge
    lower = smoothstep(soft, -soft, xx - face_l)          # below the notch, left of the face: broken rock
    across = np.clip((xx - face_r) / np.maximum(right_edge - face_r, 1), 0, 1)     # 0 at the face, 1 at the far limb
    depth = (yy - cy[None, :]) / unit
    # The face: lit granite falling straight down, streaked by water; the great dark streak; darker at its foot.
    streak = mt.lic(fbm(h, w, rng, base=10 * k, octaves=4, stretch=0.1), np.full((h, w), np.pi / 2),
                    max(8, int(0.3 * unit)), step=1.0)
    streak = (streak - streak.mean()) / (streak.std() + 1e-9)
    s0, s1 = PROFILE["streak"]
    wob = 0.012 * np.sin(v * 7 + 1.0) + 0.007 * np.sin(v * 19 + 0.3)        # the streak wavers a little
    taper = np.interp(v, [0.0, 0.12, 0.5, 1.0, 1.4], [0.3, 0.9, 0.75, 0.55, 0.3])  # and narrows toward its ends
    mid_s, half_s = (s0 + s1) / 2 + wob, (s1 - s0) / 2 * taper
    band = smoothstep(half_s + 0.02, half_s - 0.01, np.abs(u - mid_s)) * smoothstep(0.04, 0.16, v)
    face_v = 0.78 + 0.05 * streak + 0.02 * grain - 0.34 * band * (0.75 + 0.25 * streak) - 0.22 * smoothstep(0.8, 1.6, v)
    face_v = face_v - 0.08 * smoothstep(0.06, 0.0, (xx - face_l) / unit)          # the profile edge turns away
    # Below the notch, left of the face: broken, half-shadowed rock with one pale pillar along its left edge.
    left_edge = ca.line_x(ca.place(PROFILE["face_lower_left"], w, h, sx, sy, unit), h)[:, None]
    pillar = smoothstep(0.12, 0.02, (xx - left_edge) / unit)
    lower_v = 0.42 + 0.06 * fbm(h, w, rng, base=16 * k, octaves=3, stretch=0.3) + 0.14 * pillar - 0.15 * smoothstep(0.8, 1.5, v)
    # The back: a dome turning away from the light, in exfoliating sheets parallel to its skyline.
    sheets = np.sin((depth * 6.5 + 0.35 * fbm(h, w, rng, base=4 * k, octaves=2)) * np.pi)
    # Model the back as a dome: its surface turns from facing up and left at the crown over the face to facing
    # right at the far limb, and down the sides; lit half-Lambert from the upper left, so it reads round.
    theta = np.clip(across, 0, 1) * 1.45
    tilt = smoothstep(0.0, 0.9, depth)                                          # 0 at the crown, 1 down the side
    nx_, ny_, nz_ = om.norm3(np.sin(theta) * (0.35 + 0.65 * tilt), -(1 - tilt) * 0.9 - 0.15,
                             np.cos(theta) * (0.4 + 0.6 * tilt) + 0.2)
    lx_, ly_, lz_ = om.norm3(*LIGHT)
    lam = np.clip(nx_ * lx_ + ny_ * ly_ + nz_ * lz_, -1, 1)
    back_v = 0.2 + 0.66 * np.clip(0.5 + 0.5 * lam, 0, 1) ** 1.6 - 0.08 * smoothstep(0.75, 1.0, sheets)
    # Below the level of the arc's feet the dome's flank sinks into its own shadow, toward the forest at its foot.
    back_v = back_v * (1 - 0.6 * smoothstep(0.62, 0.95, v) * smoothstep(0.3, 0.7, across))
    back_v = back_v + 0.02 * grain - 0.15 * smoothstep(0.8, 1.4, v)
    rim = smoothstep(2.2 * SS, 0.6 * SS, yy - cy[None, :]) * smoothstep(0.95, 0.5, across) * (1 - face)
    back_v = back_v + (0.8 - back_v) * 0.7 * rim                              # the crown of the dome catches the light
    dome_v = back_v + (face_v - back_v) * face
    dome_v = dome_v + (lower_v - dome_v) * lower
    value = value + (dome_v - value) * dome
    lit = lit * (1 - dome) + dome * (face * smoothstep(0.7, 0.85, face_v) + (1 - face) * smoothstep(0.62, 0.72, back_v))
    slope = np.gradient(gaussian_filter(cy, 3 * SS)) / SS
    along = np.arctan(np.clip(slope, -4, 4))[None, :] + 0.03 * grain       # strokes follow the sheets
    angle = np.where(dome > 0.5, np.where(face > 0.5, np.pi / 2, along), np.pi / 2 + 0.95 * np.clip(lean, -1, 1))
    line = 1.0 * SS
    keep = (0.25 * smoothstep(line, 0, np.abs(xx - face_r)) * smoothstep(0.3, 0.5, v) * smoothstep(1.2, 0.8, v)
            + 0.8 * band * smoothstep(0.2, 0.5, band) * (1 - band) * 4
            + 0.6 * smoothstep(0.75, 1.0, sheets) * (1 - face) * smoothstep(0.05, 0.15, depth) + 0.8 * rim) * dome
    c.add(np.clip(value, 0, 1), cover, lit=lit, angle=angle, keep=np.clip(keep, 0, 1))

    # The forested shoulder in front of the dome's foot.
    shoulder = ca.line_y(ca.place(PROFILE["shoulder"], w, h, sx, sy, unit), w)
    shoulder = np.where(xx[0] < ca.place(PROFILE["shoulder"], w, h, sx, sy, unit)[0, 0], h * 2, shoulder)
    c.range(shoulder, 0.2, LIGHT, gully=0.3, contrast=0.6)
    c.firs(np.minimum(shoulder, h * 2), (3, 6), 2.2, 0.7, 0.14, rim=0.08)


def foreground(c):
    """Glacier Point's rim: a dark ridge of firs across the bottom of the picture."""
    w, h = c.w, c.h
    near = om.crest([p(0, 0.63), p(0.15, 0.655), p(0.35, 0.7), p(0.55, 0.725), p(0.75, 0.73), p(0.9, 0.71),
                     p(1, 0.69)], 731, w, h, 0.18)
    c.range(near, 0.11, LIGHT, gully=0.25, contrast=0.45)
    c.firs(near, (10, 26), 5.5, 0.6, 0.07)
    c.ground = np.maximum(c.ground, ca.below(near, h))


def paint():
    c = ca.Canvas(701)
    c.sky(sun=(0.32, 0.1), horizon=0.56, dark_top=0.16, bright=0.55, low=0.5,
          clouds=[(-0.02, 0.1, 0.42, 0.12, 34, 0.55), (1.02, 0.12, 0.44, 0.12, 34, 0.5),
                  (0.07, 0.48, 0.18, 0.1, 26), (0.95, 0.52, 0.2, 0.13, 30)],
          calm=(0.5, 0.3, 0.32, 0.2, 0.55))
    half_dome(c)
    foreground(c)
    return c.finish(contrast=1.3, ground_dark=(0.56, 0.92, 0.5))


def main():
    pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    value, glow, land = paint()
    ca.write(HERE, value, glow, land)
    if pv:
        os.makedirs(pv, exist_ok=True)
        ca.preview(os.path.join(pv, "pv-half-dome.png"), value, glow, ARC)


if __name__ == "__main__":
    main()
