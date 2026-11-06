#!/usr/bin/env python3
"""Celestial textures: navy lacquer painted with a swirling night sky, concentric-brushed brass for the instrument
rims, and the board's wallpaper.

Painted with the app's brush (scripts/make_textures.py, imported from its path: fbm, paint, lic, bristles, impasto,
speckle). The engraving itself (rings, ticks, the Matterhorn, the sun and moon, the type) is drawn by SwiftUI as
vectors so it stays crisp; these files are only the materials under it.

  lacquer-large.png   348x365  navy lacquer ground of the large widget: strokes laid along swirling flow lines (the
  lacquer-medium.png  348x164  way the painted night skies on the Pinterest boards curl), ultramarine and teal washes,
  lacquer-small.png   164x164  painted stars, a little tarnish at the edges. Also the to-do card's ground.
  brass.png           336x336  a brass disc brushed in circles about its centre, with a faint bow-tie sheen and spots of
                               patina; SwiftUI cuts the rims (and the medium dial's flat base) out of it and lights the
                               bevels itself.
  wallpaper.jpg       780x805  the board: a darker painted sky, denser stars, a band of nebula.

All widget textures are 1 px per point (WidgetKit refuses oversized images). Deterministic, no network:
    python3 MockLab/Textures/weather-celestial/make.py
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing scripts/make_textures.py must leave no __pycache__

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, sobel

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
spec = importlib.util.spec_from_file_location("make_textures", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)
fbm, smoothstep, hexrgb, mix, shade = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix, mt.shade


def save_rgb(name, rgb, jpeg=False):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    path = os.path.join(HERE, name)
    if jpeg:
        img.save(path, quality=90, optimize=True)
    else:
        img.save(path, optimize=True)
    print(f"{name}: {rgb.shape[1]}x{rgb.shape[0]}")


def flow_angle(h, w, rng, base, wobble=0.25):
    """Stroke directions along the contours of a smooth field, so the strokes curl round its blobs (a painted
    night sky), with a little wobble so no two curls match."""
    psi = gaussian_filter(fbm(h, w, rng, base=base, octaves=3, persistence=0.45), 1.5)
    gy, gx = np.gradient(psi)
    return np.arctan2(gy, gx) + np.pi / 2 + wobble * fbm(h, w, rng, base=base * 2, octaves=2)


def stars(h, w, rng, density, scale=1.0):
    """Painted stars: many pin points, fewer soft larger ones with a halo. Returns (mask 0..1, warmth 0..1)."""
    small = mt.speckle(h, w, rng, density, (0.35 * scale, 0.7 * scale))
    big = mt.speckle(h, w, rng, density * 0.08, (0.8 * scale, 1.3 * scale))
    halo = gaussian_filter(big, 2.2 * scale) * 2.5
    mask = np.clip(0.75 * small + big + 0.35 * halo, 0, 1)
    warmth = smoothstep(-0.5, 1.0, fbm(h, w, rng, base=5, octaves=2))
    return mask, warmth


def lacquer(w, h, seed, dark=0.0):
    """Navy lacquer, painted: a navy field with ultramarine and teal washes, covered in strokes along swirling flow
    lines, bristle marks and lit paint edges, painted stars, and edges dulled with tarnish."""
    rng = np.random.default_rng(seed)
    s = max(w, h) / 348
    deep, mid, ultra, teal, violet = (hexrgb(x) for x in (0x09122B, 0x112149, 0x1E3A7A, 0x15405A, 0x241F4C))
    rgb = mix(deep, mid, smoothstep(-1.3, 1.3, fbm(h, w, rng, base=2.2, octaves=4, persistence=0.5)))
    rgb = mix(rgb, ultra, 0.55 * smoothstep(0.3, 1.9, fbm(h, w, rng, base=2.0, octaves=3)))
    rgb = mix(rgb, teal, 0.40 * smoothstep(0.5, 2.0, fbm(h, w, rng, base=2.6, octaves=3)))
    rgb = mix(rgb, violet, 0.30 * smoothstep(0.6, 2.0, fbm(h, w, rng, base=1.8, octaves=2)))
    angle = flow_angle(h, w, rng, base=2.4)
    out = mt.paint(rgb, angle, rng, [(int(520 * s * s), (6, 12), (22, 60)),
                                     (int(1300 * s * s), (2.5, 5.5), (10, 28))], 0.07, hue=0.006)
    out = gaussian_filter(out, (0.45, 0.45, 0))
    out = shade(out, mt.bristles(h, w, rng, angle, 0.035))
    out = mt.impasto(out, 1.0, blur=0.7)
    # Stars, painted into the lacquer (pale gold to cool white).
    mask, warmth = stars(h, w, rng, 0.0020)
    star = mix(np.ones((h, w, 3)) * hexrgb(0xDCE4F2), np.ones((h, w, 3)) * hexrgb(0xF3DFAE), warmth)
    out = mix(out, star, 0.85 * mask)
    # Tarnish at the edges: the lacquer dulls and browns a little where hands don't polish it.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    edge = smoothstep(0.75, 1.35, r) * (0.7 + 0.3 * fbm(h, w, rng, base=4, octaves=3))
    out = mix(out, hexrgb(0x1A1A24), 0.45 * edge)
    out = shade(out, -0.25 * edge - dark)
    return out


def brass(n, seed):
    """A brass disc brushed in circles about its centre: fine circular scratches, broader rings where the polish ran
    unevenly, a bow-tie sheen across the light from the upper left, and patina (dark olive-brown spots with a little
    verdigris) gathered toward the rim."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    dx, dy = xx - (n - 1) / 2, yy - (n - 1) / 2
    r = np.hypot(dx, dy) / (n / 2)
    th = np.arctan2(dy, dx)
    scratches = mt.lic(rng.standard_normal((n, n)), th + np.pi / 2, 18, step=1.0)
    scratches /= scratches.std()
    # Rings: 1-D noise in the radius.
    grid = np.linspace(0, 1.5, 400)
    rings = gaussian_filter(rng.standard_normal(400), 2.0)
    rings = np.interp(r, grid, rings / rings.std())
    light = np.deg2rad(-135)  # the upper left (y down)
    sheen = np.cos(th - light) ** 2
    sheen = sheen ** 3
    value = 0.50 + 0.07 * scratches + 0.06 * rings + 0.28 * sheen + 0.05 * fbm(n, n, rng, base=3, octaves=3)
    # Value to brass: deep bronze, brass, gold, pale highlight.
    stops = [(0.0, 0x3E2A10), (0.35, 0x7A5824), (0.55, 0xAA8240), (0.75, 0xD7B36C), (0.95, 0xF4DDA2)]
    v = np.clip(value, 0, 1)
    out = np.zeros((n, n, 3))
    for (a, ca), (b, cb) in zip(stops[:-1], stops[1:]):
        t = np.clip((v - a) / (b - a), 0, 1)[..., None]
        inside = ((v >= a) & (v <= b))[..., None] if b < 0.95 else (v >= a)[..., None]
        out = np.where(inside, hexrgb(ca) * (1 - t) + hexrgb(cb) * t, out)
    out = np.where((v < stops[0][0])[..., None], hexrgb(stops[0][1]), out)
    # Patina.
    spots = smoothstep(0.9, 2.0, fbm(n, n, rng, base=7, octaves=4)) * (0.5 + 0.5 * smoothstep(0.75, 1.0, r))
    out = mix(out, hexrgb(0x3B3622), 0.55 * spots)
    verd = smoothstep(1.3, 2.3, fbm(n, n, rng, base=9, octaves=3)) * smoothstep(0.85, 1.0, r)
    out = mix(out, hexrgb(0x5C7563), 0.35 * verd)
    pits = mt.speckle(n, n, rng, 0.0015, (0.4, 0.9))
    out = mix(out, hexrgb(0x2A1D0C), 0.5 * pits)
    return out


def wallpaper(w, h, seed):
    """The board: a darker painted night than the widgets (so they stand out), denser stars, and a slanting band of
    nebula, the strokes curling along the band."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    deep, mid, ultra, teal = (hexrgb(x) for x in (0x050A19, 0x0B1531, 0x1A2F63, 0x123448))
    rgb = mix(deep, mid, smoothstep(-1.2, 1.5, fbm(h, w, rng, base=2.0, octaves=4)))
    band = np.exp(-(((yy - 0.55 * h) + 0.42 * (xx - 0.5 * w)) / (0.22 * h)) ** 2)
    band *= 0.6 + 0.4 * smoothstep(-1, 1.5, fbm(h, w, rng, base=3, octaves=4))
    rgb = mix(rgb, ultra, 0.55 * band)
    rgb = mix(rgb, teal, 0.35 * band * smoothstep(0.0, 1.5, fbm(h, w, rng, base=4, octaves=3)))
    angle = 0.5 * flow_angle(h, w, rng, base=2.0) + 0.5 * (-0.4)
    out = mt.paint(rgb, angle, rng, [(2600, (8, 16), (30, 90)), (6000, (3, 7), (14, 36))], 0.07, hue=0.006)
    out = gaussian_filter(out, (0.6, 0.6, 0))
    out = shade(out, mt.bristles(h, w, rng, angle, 0.03))
    out = mt.impasto(out, 0.9, blur=0.8)
    mask, warmth = stars(h, w, rng, 0.0016 * (1 + 1.5 * 0.5), scale=1.0)
    mask = np.clip(mask * (0.6 + 0.8 * band), 0, 1)
    star = mix(np.ones((h, w, 3)) * hexrgb(0xD8E2F4), np.ones((h, w, 3)) * hexrgb(0xF3DFAE), warmth)
    out = mix(out, star, 0.8 * mask)
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    return shade(out, -0.35 * smoothstep(0.6, 1.45, r))


def main():
    save_rgb("lacquer-large.png", lacquer(348, 365, 11))
    save_rgb("lacquer-medium.png", lacquer(348, 164, 12))
    save_rgb("lacquer-small.png", lacquer(164, 164, 13))
    save_rgb("brass.png", brass(336, 21))
    save_rgb("wallpaper.jpg", wallpaper(780, 805, 31), jpeg=True)


if __name__ == "__main__":
    main()
