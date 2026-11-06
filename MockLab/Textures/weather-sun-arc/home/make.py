#!/usr/bin/env python3
"""Sun Arc home screen: the paintings behind page two's small widgets and the home screen wallpaper.

Painted with Sun Arc's own arc_painting (MockLab/Textures/weather-sun-arc/make.py, imported from its path, not copied),
written like its canvases as alpha PNGs at 1 px per point and glazed at run time with CoverLight:

  forecast-small-lo/hi.png  164x164  a band of weather sky (a dark rain bank coming in from the west, a lit puff), a
                                     ridge of firs, then the dark ground the days are listed on.
  moon-small-lo/hi.png      164x164  a calm open sky for the painted moon, a low ridge of firs, the dark ground below.
  wallpaper.jpg             603x1311 the home screen (not a widget texture), after the user's Pinterest reference: a
                                     Baroque sky of towering sepia cloud, dark banks closing round breaks of warm light,
                                     painted loose and soft like Old Master's board wallpaper.
  wallpaper-calm.jpg        603x1311 the first, quieter version: a calm umber sky, dark banks at the top,
                                     a faint warm light low down (no lit cloud among the icons) and a far ridge of firs behind the dock, so the Sun
                                     Arc widget stays the one painting on the screen.

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/weather-sun-arc/home/make.py [names...]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing Sun Arc's make.py (and through it the Cover's, Old Master's and scripts/)

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("sa_make", os.path.join(os.path.dirname(HERE), "make.py"))
sa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sa)
om, mt = sa.om, sa.mt
p, r_, MID, NEAR = sa.p, sa.r_, sa.MID, sa.NEAR
smoothstep, hexrgb, mix = mt.smoothstep, mt.hexrgb, mt.mix


def save_alpha(name, a):
    a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.stack([np.full_like(a8, 255), a8], axis=2), "LA").save(os.path.join(HERE, name + ".png"), optimize=True)
    print(f"{name}.png: {a.shape[1]}x{a.shape[0]}")


def forecast_small():
    # The days are listed on the dark ground from 0.42 down; the headline sits on the sky band above it.
    band = 0.36
    value, glow, _ = sa.arc_painting(164, 164, 631, sun=(0.2, 0.05), horizon=band,
                                     sky=dict(dark_top=0.22, bright=0.5, low=0.46),
                                     clouds=[(1.05, 0.12, 0.55, 0.16, 26, 0.36), (0.78, 0.33, 0.2, 0.09, 14)],
                                     calm=(0.3, 0.18, 0.35, 0.2, 0.5), peak=None,
                                     mid=r_(MID, tone=0.2, keys=[p(0, band - 0.01), p(0.35, band - 0.02),
                                                                 p(0.7, band), p(1, band - 0.01)], seed=633, mist=None),
                                     near=r_(NEAR, tone=0.11, keys=[p(0, band + 0.05), p(0.5, band + 0.055),
                                                                    p(1, band + 0.045)], seed=635),
                                     trees=[(0, (5, 10), 4.5, 0.55, 0.06), (1, (8, 15), 6.0, 0.5, 0.05)],
                                     contrast=1.15, ground_dark=(band + 0.04, 0.9, 0.4))
    return value, glow


def moon_small():
    # Open sky down to 0.56 with the moon at the upper right; the words sit on the dark ground below the firs.
    band = 0.54
    value, glow, _ = sa.arc_painting(164, 164, 641, sun=(0.7, 0.3), horizon=band,
                                     sky=dict(dark_top=0.16, bright=0.5, low=0.44),
                                     clouds=[(-0.05, 0.16, 0.4, 0.1, 20, 0.34), (0.2, 0.5, 0.2, 0.07, 12)],
                                     calm=(0.66, 0.3, 0.36, 0.26, 0.6), peak=None,
                                     mid=r_(MID, tone=0.2, keys=[p(0, band - 0.02), p(0.4, band - 0.005),
                                                                 p(0.75, band - 0.02), p(1, band - 0.01)], seed=643, mist=None),
                                     near=r_(NEAR, tone=0.11, keys=[p(0, band + 0.05), p(0.5, band + 0.06),
                                                                    p(1, band + 0.05)], seed=645),
                                     trees=[(0, (5, 11), 4.5, 0.55, 0.06), (1, (8, 16), 6.0, 0.5, 0.05)],
                                     contrast=1.15, ground_dark=(band + 0.04, 0.95, 0.4))
    return value, glow


def baroque():
    # Old Master's wallpaper (old-master/make.py) recomposed for a tall phone screen: cloud everywhere, as in the
    # reference, the brightest break behind the middle of the screen, darker banks at the top (the status bar) and
    # the bottom (the dock), so the white labels read on it. Same sepia map, a little lower in key.
    w, h = 603, 1311
    pw, ph = w, h
    SS = om.SS
    w, h = w * SS, h * SS
    rng = np.random.default_rng(661)
    sun = (0.6, 0.42)
    V, angle = om.sky_field(w, h, rng, sun, 1.0, dark_top=0.28, bright=0.84, low=0.5)
    layers = [
        [(0.0, 0.18, 1.1, 0.22, 170, 0.34), (1.0, 0.34, 1.0, 0.24, 160, 0.36), (0.02, 0.64, 1.0, 0.24, 160, 0.38),
         (1.0, 0.84, 1.0, 0.26, 170, 0.35), (0.5, 1.08, 1.6, 0.26, 190, 0.33)],
        [(0.36, 0.42, 0.85, 0.2, 250), (0.86, 0.58, 0.75, 0.19, 230), (0.28, 0.8, 0.9, 0.2, 250),
         (0.72, 0.13, 0.65, 0.12, 170), (0.6, 1.0, 0.95, 0.15, 210)],
    ]
    glow = np.zeros((h, w))
    for layer in layers:
        cv, ccover, clit, ctan, _ = om.cumulus(w, h, rng, layer, sun, billow=0.55, flow=16.0)
        V = V + (cv - V) * ccover
        glow = glow * (1 - ccover) + clit
        angle = np.where(ccover > 0.3, ctan, angle)
    from scipy.ndimage import gaussian_filter, sobel
    k = pw * ph / (348 * 365)
    s = SS * 1.5
    field = np.stack([V, V, V], axis=2)
    out = mt.paint(field, angle, rng, [(int(300 * k), (6 * s, 11 * s), (14 * s, 34 * s)),
                                       (int(700 * k), (3 * s, 5.5 * s), (7 * s, 18 * s))], 0.025)
    out = gaussian_filter(out[..., 0], 1.6 * SS)
    out = out * (1 + mt.bristles(h, w, rng, angle, 0.02))
    g = gaussian_filter(out, 0.8 * SS)
    out = out - (sobel(g, axis=1) + sobel(g, axis=0)) * 0.05 * SS
    out = 0.85 * out + 0.15 * gaussian_filter(V, SS)
    out = np.clip(0.5 + (out - 0.5) * 1.25, 0, 1)
    out, glow = om.down(out), om.down(glow)
    out = out * 0.9  # a little lower in key than the board's, for the labels
    stops = [(0.0, 0x24150D), (0.28, 0x553A2A), (0.5, 0x8E6E58), (0.72, 0xC29E80), (0.9, 0xE5C6A6), (1.0, 0xF2DDC4)]
    rgb = np.zeros(out.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        t = np.clip((out - a0) / (a1 - a0), 0, 1)
        sel = (out >= a0) & (out <= a1)
        rgb[sel] = (hexrgb(c0) * (1 - t[..., None]) + hexrgb(c1) * t[..., None])[sel]
    rgb = mix(rgb, hexrgb(0xE9B79A), 0.28 * glow * smoothstep(0.55, 0.9, out))
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float64)
    vign = np.hypot((xx / pw - 0.5) * 1.2, (yy / ph - 0.5) * 0.8)
    rgb = mt.shade(rgb, -0.3 * smoothstep(0.35, 0.85, vign))
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, "wallpaper.jpg"), quality=90, subsampling=0)
    print(f"wallpaper.jpg: {pw}x{ph}")


def wallpaper():
    # Painted at 1.5 px per point of the iPhone 17 screen (402x874 pt) and enlarged at render time: it only frames the
    # widgets, so it is soft. Dark at the top (the status bar and the widget), a calm middle behind the icons, a warm
    # low light and a far ridge of firs behind the dock.
    w, h = 603, 1311
    value, glow, _ = sa.arc_painting(w, h, 651, sun=(0.62, 0.86), horizon=0.875,
                                     sky=dict(dark_top=0.12, bright=0.58, low=0.5),
                                     clouds=[(-0.1, 0.06, 0.7, 0.08, 60, 0.3), (1.1, 0.16, 0.7, 0.08, 60, 0.32)],
                                     calm=(0.5, 0.45, 0.6, 0.4, 0.75), peak=None,
                                     mid=r_(MID, tone=0.2, keys=[p(0, 0.87), p(0.3, 0.865), p(0.6, 0.875), p(1, 0.868)],
                                            seed=653, mist=None),
                                     near=r_(NEAR, tone=0.1, keys=[p(0, 0.9), p(0.5, 0.905), p(1, 0.898)], seed=655),
                                     trees=[(0, (6, 13), 5.0, 0.5, 0.06), (1, (10, 20), 7.0, 0.5, 0.05)],
                                     contrast=1.1, ground_dark=(0.89, 1.0, 0.5))
    # Low key: the icons' white labels read on every part of it.
    v = 0.05 + value * 0.7
    stops = [(0.0, 0x1A0F09), (0.28, 0x3E2A1E), (0.5, 0x6E5444), (0.72, 0xA88A70), (0.9, 0xD8B898), (1.0, 0xEBD3B8)]
    rgb = np.zeros(v.shape + (3,))
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        t = np.clip((v - a0) / (a1 - a0), 0, 1)
        sel = (v >= a0) & (v <= a1)
        rgb[sel] = (hexrgb(c0) * (1 - t[..., None]) + hexrgb(c1) * t[..., None])[sel]
    rgb = mix(rgb, hexrgb(0xE9B79A), 0.3 * glow * smoothstep(0.4, 0.75, v))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    vign = np.hypot((xx / w - 0.5) * 1.3, (yy / h - 0.5) * 0.9)
    rgb = mt.shade(rgb, -0.32 * smoothstep(0.3, 0.8, vign))
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, "wallpaper-calm.jpg"), quality=90, subsampling=0)
    print(f"wallpaper-calm.jpg: {w}x{h}")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, fn in {"forecast-small": forecast_small, "moon-small": moon_small}.items():
        if only and name not in only:
            continue
        value, _ = fn()
        save_alpha(name + "-lo", np.clip(value * 2, 0, 1))
        save_alpha(name + "-hi", np.clip(value * 2 - 1, 0, 1))
    if not only or "wallpaper-calm" in only:
        wallpaper()
    if not only or "wallpaper" in only:
        baroque()


if __name__ == "__main__":
    main()
