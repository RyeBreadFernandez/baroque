#!/usr/bin/env python3
"""Travertine: the stones and plaster for Baroque's travertine look (2026-11-04, after the user's Pinterest pin
215046950953591573: a home screen of travertine and olive-green stone tiles, terracotta and umber accents, raised
reliefs, a sunlit Mediterranean scene).

Every stone is one grey structure, coloured per material:
  - soft mottling and long horizontal bands, the way travertine is layered;
  - elongated pores along the bands, each a dark pit with a lit lower lip;
  - fine specks, a few hairline cracks, and grain.

  <stone>.jpg     900x900  travertine, olive, verde, terracotta, umber, tan (scaled to fill each tile)
  wallpaper.jpg   603x1311 the phone's wallpaper: warm taupe plaster, light from the upper left, the soft shadow of
                           an olive branch falling across it
  wall.jpg        1232x1300 the showcase's backdrop: cream plaster with olive-leaf shadows, as in the pin

Run from anywhere (deterministic, no network):  python3 MockLab/Textures/travertine/make.py [names...]
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location("mt", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)
fbm, smoothstep, hexrgb, mix = mt.fbm, mt.smoothstep, mt.hexrgb, mt.mix

# Material: (light, dark, pit) colours, how much of the mottling shows, lichen-like patches (verde, olive).
STONES = {
    "travertine": (0xF3EBDE, 0xDDCFB9, 0xB5A288, 0.6, 0.0),
    "olive": (0x6E7553, 0x50573C, 0x3B412D, 1.2, 0.5),
    "verde": (0x666C51, 0x454A35, 0x33382A, 1.3, 0.8),
    "terracotta": (0xA0664B, 0x7B4B36, 0x5A3527, 1.0, 0.2),
    "umber": (0x5E4A38, 0x3F3125, 0x2B2119, 1.0, 0.3),
    "moss": (0x66654A, 0x47462F, 0x35341F, 1.2, 0.5),
    "tan": (0xBE9470, 0x987053, 0x75523C, 1.0, 0.2),
}


def structure(n, seed):
    """The grey stone (0..1, mostly light) and its pit mask."""
    rng = np.random.default_rng(seed)
    mott = fbm(n, n, rng, base=3, octaves=5)
    bands = fbm(n, n, rng, base=5, octaves=4, stretch=7.0)
    tooth = fbm(n, n, rng, base=70, octaves=3)
    v = 0.62 + 0.07 * mott + 0.06 * bands + 0.025 * tooth
    # Pores: many small, long, thin voids along the bands.
    pores = fbm(n, n, rng, base=90, octaves=2, stretch=4.0)
    pits = smoothstep(1.7, 2.6, pores) * (0.4 + 0.6 * smoothstep(-0.6, 0.8, bands))
    # Specks.
    specks = np.zeros((n, n))
    ys, xs = rng.integers(0, n, 5000), rng.integers(0, n, 5000)
    specks[ys, xs] = rng.uniform(0.2, 1.0, 5000)
    specks = np.clip(gaussian_filter(specks, 0.6) * 4, 0, 1)
    pits = np.clip(pits + 0.5 * specks, 0, 1)
    # Hairline cracks: a few wandering walks.
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        a = rng.uniform(-0.4, 0.4) + (np.pi if rng.random() < 0.5 else 0)
        pts = [(x, y)]
        for _ in range(int(rng.uniform(40, 90))):
            a += rng.normal(0, 0.25)
            x, y = x + 6 * np.cos(a), y + 6 * np.sin(a)
            pts.append((x, y))
        d.line(pts, fill=int(rng.uniform(90, 160)), width=1)
    cracks = gaussian_filter(np.asarray(img, dtype=np.float64) / 255, 0.5)
    grain = gaussian_filter(rng.standard_normal((n, n)), 0.6)
    v = v - 0.05 * cracks + 0.018 * grain
    # The lit lower lip of each pit (light from the upper left).
    lip = np.clip(np.roll(np.roll(pits, 1, axis=0), 1, axis=1) - pits, 0, 1)
    return np.clip(v, 0, 1), pits, lip, mott


def stone(name, n=900):
    light, dark, pit, mottle, lichen = STONES[name]
    v, pits, lip, mott = structure(n, seed=sum(map(ord, name)) * 7)
    t = np.clip((v - 0.45) / 0.35, 0, 1)
    t = 0.5 + (t - 0.5) * mottle
    rgb = mix(np.ones((n, n, 3)) * hexrgb(dark), np.ones((n, n, 3)) * hexrgb(light), np.clip(t, 0, 1))
    if lichen:
        rng = np.random.default_rng(n + len(name))
        patch = smoothstep(0.6, 1.6, fbm(n, n, rng, base=5, octaves=5))
        rgb = mix(rgb, rgb * 0.82 + hexrgb(0x8A8A5E) * 0.18, lichen * patch)
    rgb = mix(rgb, np.ones((n, n, 3)) * hexrgb(pit), (0.5 if name == "travertine" else 0.75) * pits)
    rgb = np.clip(rgb + 0.06 * lip[..., None], 0, 1)
    save(rgb, name + ".jpg")


def leaf_shadow(w, h, seed, branches, blur):
    """Soft shadows of olive branches: stems with narrow leaves on both sides, drawn at 2x and blurred."""
    rng = np.random.default_rng(seed)
    k = 2
    img = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    for (x, y, a, length, leaf) in branches:
        x, y, a = x * w * k, y * h * k, np.radians(a)
        step = 6 * k
        steps = int(length * k / step)
        for i in range(steps):
            a += rng.normal(0, 0.04)
            nx, ny = x + step * np.cos(a), y + step * np.sin(a)
            d.line([(x, y), (nx, ny)], fill=255, width=2 * k)
            if i % 5 == 1 and i > 2:
                for side in ((-1,) if (i // 5) % 2 else (1,)):
                    la = a + side * rng.uniform(0.35, 0.65)
                    ll = rng.uniform(0.8, 1.25) * leaf * k
                    lw = ll * 0.14
                    cx, cy = x + np.cos(la) * ll * 0.55, y + np.sin(la) * ll * 0.55
                    # A narrow leaf as a rotated polygon.
                    pts = []
                    for s in np.linspace(0, 2 * np.pi, 24):
                        px, py = 0.5 * ll * np.cos(s), lw * np.sin(s) * (1 - 0.3 * np.cos(s))
                        pts.append((cx + px * np.cos(la) - py * np.sin(la), cy + px * np.sin(la) + py * np.cos(la)))
                    d.polygon(pts, fill=255)
            x, y = nx, ny
    m = np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
    return gaussian_filter(m, blur)


def plaster(w, h, base_light, base_dark, seed, light_from=(0.0, 0.0)):
    rng = np.random.default_rng(seed)
    mott = fbm(h, w, rng, base=4, octaves=6)
    fine = gaussian_filter(rng.standard_normal((h, w)), 0.8)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    lx, ly = light_from
    fall = np.hypot(xx / w - lx, (yy / h - ly) * h / w * 0.6)
    t = np.clip(0.75 - 0.35 * fall + 0.05 * mott, 0, 1)
    rgb = mix(np.ones((h, w, 3)) * hexrgb(base_dark), np.ones((h, w, 3)) * hexrgb(base_light), t)
    return np.clip(rgb + 0.012 * fine[..., None], 0, 1)


def wallpaper():
    w, h = 603, 1311
    rgb = plaster(w, h, 0xB8A58D, 0x8C7860, 61, light_from=(0.1, 0.0))
    sh = leaf_shadow(w, h, 62, [(1.05, 0.03, 148, 430, 62), (1.06, 0.2, 166, 300, 56)], blur=3.5)
    rgb = rgb * (1 - 0.16 * sh[..., None])
    save(rgb, "wallpaper.jpg")


def wall():
    w, h = 1232, 1300
    rgb = plaster(w, h, 0xF1EBE0, 0xD6CCBD, 71, light_from=(0.25, 0.0))
    sh = leaf_shadow(w, h, 72, [(1.03, -0.02, 142, 560, 84), (1.05, 0.16, 162, 380, 76), (-0.03, 0.99, -38, 420, 80)],
                     blur=4.5)
    rgb = rgb * (1 - 0.13 * sh[..., None])
    save(rgb, "wall.jpg")


def save(rgb, name):
    px = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, name), quality=90, subsampling=0)
    print(f"{name}: {px.shape[1]}x{px.shape[0]}")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name in STONES:
        if not only or name in only:
            stone(name)
    if not only or "wallpaper" in only:
        wallpaper()
    if not only or "wall" in only:
        wall()


if __name__ == "__main__":
    main()
