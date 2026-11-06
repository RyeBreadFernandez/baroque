#!/usr/bin/env python3
"""Generates the painted textures in Shared/PaintTextures.xcassets and the app-only ones in
Baroque/Assets.xcassets. Deterministic (fixed seeds), so rerunning gives the same images.

Everything is laid down as brush strokes: a soft colour field is covered with opaque strokes that follow
a direction field, coarse to fine, each one picking up the colour under where it starts plus a little
jitter, the way paint is dragged across a board. Fine bristle marks and lighting on the stroke edges
(impasto) are added on top, so the paint itself has relief.

Two kinds of output:
  * colour textures (JPEG): the espresso panel, copper pebbles, the moon;
  * relief overlays (PNG with alpha): light and dark brushwork only, laid over colours that SwiftUI
    picks at run time (the sky changes with the time of day, ridges per layer).

Widget textures are kept near 1 pixel per point: WidgetKit refuses to archive widgets whose images are
too large. Needs numpy, scipy, Pillow:
    python3 scripts/make_textures.py
"""
import json, os, shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates, sobel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "Shared", "PaintTextures.xcassets")
APP = os.path.join(ROOT, "Baroque", "Assets.xcassets")


def hexrgb(h):
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], dtype=np.float64) / 255.0


def noise_layer(h, w, cells, rng, stretch=1.0):
    """Smooth value noise with about `cells` features across the longer side."""
    gh = max(3, int(round(cells * h / max(h, w))) + 3)
    gw = max(3, int(round(cells * w / max(h, w) / stretch)) + 3)
    g = rng.standard_normal((gh, gw)).astype(np.float32)
    return np.asarray(Image.fromarray(g, mode="F").resize((w, h), Image.BICUBIC), dtype=np.float64)


def fbm(h, w, rng, base=3.0, octaves=5, persistence=0.55, lacunarity=2.0, stretch=1.0):
    out = np.zeros((h, w))
    amp, cells = 1.0, base
    for _ in range(octaves):
        out += amp * noise_layer(h, w, cells, rng, stretch)
        amp *= persistence
        cells *= lacunarity
    out -= out.mean()
    return out / (out.std() + 1e-9)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def shade(rgb, amount):
    """Multiplies brightness by (1 + amount); amount is a per-pixel field."""
    return np.clip(rgb * (1 + amount)[..., None], 0, 1)


def speckle(h, w, rng, density, size=(0.6, 1.6)):
    """Sparse soft dots as a 0..1 mask."""
    img = Image.new("F", (w, h), 0.0)
    d = ImageDraw.Draw(img)
    for _ in range(int(h * w * density)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(*size)
        d.ellipse([x - r, y - r * rng.uniform(0.6, 1.0), x + r, y + r], fill=float(rng.uniform(0.5, 1.0)))
    return gaussian_filter(np.asarray(img, dtype=np.float64), 0.35)


# MARK: Brushwork

def lic(field, angle, length, step=0.8):
    """Smears `field` along the direction field `angle` (radians)."""
    h, w = field.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    acc, wsum = field.copy(), 1.0
    for sign in (1, -1):
        x, y = xx.copy(), yy.copy()
        for i in range(1, length + 1):
            a = map_coordinates(angle, [y % h, x % w], order=1, mode="wrap")
            x += sign * np.cos(a) * step
            y += sign * np.sin(a) * step
            wt = 0.5 + 0.5 * np.cos(np.pi * i / (length + 1))
            acc += wt * map_coordinates(field, [y % h, x % w], order=1, mode="wrap")
            wsum += wt
    return acc / wsum


def paint(field, angle, rng, passes, jitter, hue=0.0):
    """Covers `field` (h, w, 3 in 0..1) with opaque strokes that follow `angle`, coarse to fine.
    passes: [(count, (min width, max width), (min length, max length))] in pixels."""
    h, w, _ = field.shape
    img = Image.fromarray((np.clip(field, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for count, (w0, w1), (l0, l1) in passes:
        for _ in range(count):
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            c = field[int(y) % h, int(x) % w] * (1 + rng.normal(0, jitter)) + rng.normal(0, hue, 3)
            col = tuple(int(v) for v in np.clip(c, 0, 1) * 255)
            width = rng.uniform(w0, w1)
            pts = [(x, y)]
            px, py = x, y
            for _ in range(int(rng.uniform(l0, l1) / 2)):
                a = angle[int(py) % h, int(px) % w]
                px += np.cos(a) * 2
                py += np.sin(a) * 2
                pts.append((px, py))
            d.line(pts, fill=col, width=max(1, int(round(width))), joint="curve")
            r = width / 2
            for ex, ey in (pts[0], pts[-1]):
                d.ellipse([ex - r, ey - r * 0.8, ex + r, ey + r * 0.8], fill=col)
    return np.asarray(img, dtype=np.float64) / 255


def bristles(h, w, rng, angle, amount):
    """Fine parallel marks left by the bristles, along the strokes."""
    b = lic(rng.standard_normal((h, w)), angle, 7, step=0.8)
    return amount * b / b.std()


def impasto(rgb, strength, blur=0.7):
    """Light from the upper left on the ridges of paint at each stroke's edge."""
    g = gaussian_filter(rgb.mean(axis=2), blur)
    return shade(rgb, -(sobel(g, axis=1) + sobel(g, axis=0)) * strength)


def relief(value, warm, light_alpha=0.5, dark_alpha=0.6):
    """Relief overlay: light paint (cool to warm) where value > 0, dark where < 0, alpha by strength."""
    k = 1.0 / (np.percentile(np.abs(value), 99) + 1e-9)
    up = np.clip(value * k, 0, 1)
    down = np.clip(-value * k, 0, 1)
    light = mix(np.ones(value.shape + (3,)) * hexrgb(0xC9D5CA), np.ones(value.shape + (3,)) * hexrgb(0xF3D8A4), warm)
    rgb = np.where((value >= 0)[..., None], light, hexrgb(0x05080A))
    alpha = np.where(value >= 0, up * light_alpha, down * dark_alpha)
    return np.concatenate([rgb, alpha[..., None]], axis=2)


def stroke_relief(w, h, rng, angle, tone_amp, passes, jitter, blur, bristle, edge):
    tone = 0.5 + tone_amp * fbm(h, w, rng, base=2.5, octaves=4, persistence=0.5)
    warm = smoothstep(-0.3, 1.5, fbm(h, w, rng, base=2.0, octaves=3))
    out = paint(np.stack([tone, warm, np.zeros_like(tone)], axis=2), angle, rng, passes, jitter)
    out = gaussian_filter(out, (blur, blur, 0))
    lum = out[..., 0]
    g = gaussian_filter(lum, 0.7)
    value = lum - 0.5 + bristles(h, w, rng, angle, bristle) - (sobel(g, axis=1) + sobel(g, axis=0)) * edge
    return relief(value, np.clip(out[..., 1], 0, 1))


# MARK: Textures

def sky(w, h, seed, s=1.0):
    """A painted sky: soft wisps of cloud dragged along nearly level strokes, over faint brushwork."""
    rng = np.random.default_rng(seed)
    angle = 0.02 + 0.12 * fbm(h, w, rng, base=1.5, octaves=3, persistence=0.5)
    wisps = lic(fbm(h, w, rng, base=7, octaves=3, persistence=0.5, stretch=2.5), angle, int(26 * s), step=1.0)
    wisps = wisps / wisps.std()
    wisps *= 0.5 + 0.5 * smoothstep(-1, 1.2, fbm(h, w, rng, base=2, octaves=2))
    # Strokes of nearly equal value, so only their edges and bristle marks show.
    tone = 0.5 + 0.01 * fbm(h, w, rng, base=3, octaves=3)
    out = paint(np.stack([tone, tone, tone], axis=2), angle, rng,
                [(int(420 * s * s), (10 * s, 18 * s), (40 * s, 100 * s)),
                 (int(900 * s * s), (4 * s, 9 * s), (16 * s, 44 * s))], 0.025)
    out = gaussian_filter(out[..., 0], 0.7 * s)
    strokes = (out - 0.5) + bristles(h, w, rng, angle, 0.003) - (sobel(out, axis=1) + sobel(out, axis=0)) * 0.05
    value = 0.65 * wisps + 0.3 * strokes / strokes.std()
    value = np.sign(value) * np.abs(value) ** 1.3  # keep the quiet areas quiet
    warm = smoothstep(-0.3, 1.5, fbm(h, w, rng, base=2.0, octaves=3))
    return relief(value, warm, light_alpha=0.36, dark_alpha=0.38)


def ridge(w, h, seed):
    """Strokes down the slopes, in zones that lean left and zones that lean right."""
    rng = np.random.default_rng(seed)
    lean = np.tanh(2.5 * fbm(h, w, rng, base=3.5, octaves=2, persistence=0.4))
    angle = 0.55 * lean + 0.1 * fbm(h, w, rng, base=6, octaves=2)
    return stroke_relief(w, h, rng, angle, 0.05,
                         [(900, (5, 10), (14, 34)), (1800, (2.5, 5), (8, 18))],
                         jitter=0.05, blur=0.6, bristle=0.006, edge=0.09)


def panel(w, h, seed, s=1.0, colors=(0x3D2D21, 0x2D2219, 0x4A3829, 0x3A3826)):
    """Espresso-brown painted board for the task slabs and the app's rows."""
    rng = np.random.default_rng(seed)
    angle = 0.25 + 0.8 * np.tanh(1.5 * fbm(h, w, rng, base=2.0, octaves=2, persistence=0.4))
    a, b, c, olive = (hexrgb(x) for x in colors)
    rgb = mix(a, b, smoothstep(-1.4, 1.4, fbm(h, w, rng, base=3, octaves=4, persistence=0.5)))
    rgb = mix(rgb, c, 0.5 * smoothstep(0.5, 2.0, fbm(h, w, rng, base=2.5, octaves=3)))
    rgb = mix(rgb, olive, 0.35 * smoothstep(0.6, 2.0, fbm(h, w, rng, base=2, octaves=2)))
    out = paint(rgb, angle, rng, [(int(700 * s * s), (7 * s, 13 * s), (20 * s, 46 * s)),
                                  (int(1500 * s * s), (3 * s, 6 * s), (10 * s, 24 * s))], 0.07, hue=0.004)
    out = gaussian_filter(out, (0.5 * s, 0.5 * s, 0))
    out = shade(out, bristles(h, w, rng, angle, 0.03))
    return impasto(out, 1.2, blur=0.7 * s)


def copper(w, h, seed):
    rng = np.random.default_rng(seed)
    angle = 0.6 + 0.7 * fbm(h, w, rng, base=2, octaves=2)
    rgb = mix(hexrgb(0xB36D45), hexrgb(0x8C4B2E), smoothstep(-1.5, 1.5, fbm(h, w, rng, base=2.5, octaves=4)))
    rgb = mix(rgb, hexrgb(0xD49565), 0.35 * smoothstep(0.6, 2.0, fbm(h, w, rng, base=3, octaves=2)))
    out = paint(rgb, angle, rng, [(160, (3, 6), (6, 14)), (260, (1.5, 3), (4, 9))], 0.06, hue=0.005)
    out = gaussian_filter(out, (0.45, 0.45, 0))
    return impasto(out, 0.45, blur=0.6)


def moon(w, h, seed):
    """Pale gold disc with darker seas, laid in with small loose dabs."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    angle = 0.8 * fbm(h, w, rng, base=2.5, octaves=2) * np.pi
    rgb = mix(hexrgb(0xF6E6BF), hexrgb(0xE6CD98), smoothstep(-1.5, 1.5, fbm(h, w, rng, base=3, octaves=5)))
    rgb = mix(rgb, hexrgb(0xC4A675), 0.6 * smoothstep(0.3, 1.6, fbm(h, w, rng, base=2.2, octaves=3, persistence=0.5)))
    out = paint(rgb, angle, rng, [(240, (4, 7), (6, 14)), (520, (2, 3.5), (4, 9))], 0.04, hue=0.003)
    out = gaussian_filter(out, (0.5, 0.5, 0))
    out = mix(out, hexrgb(0xAD9064), 0.4 * speckle(h, w, rng, 0.0012, (1.2, 3.2)))
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    return shade(out, -0.25 * smoothstep(0.5, 1.0, r))  # limb darkening


# MARK: Output

def write(catalog, name, img):
    folder = os.path.join(catalog, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        os.remove(os.path.join(folder, f))
    px = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    if img.shape[2] == 4:
        filename = name + ".png"
        Image.fromarray(px, "RGBA").save(os.path.join(folder, filename), optimize=True)
    else:
        filename = name + ".jpg"
        Image.fromarray(px, "RGB").save(os.path.join(folder, filename), quality=90, subsampling=0)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": filename, "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print(f"{name}: {img.shape[1]}x{img.shape[0]}")


def main():
    # The stone textures this replaced.
    old = os.path.join(ROOT, "Shared", "StoneTextures.xcassets")
    if os.path.isdir(old):
        shutil.rmtree(old)
    for name in ("AppTravertine", "AppWalnut"):
        path = os.path.join(APP, name + ".imageset")
        if os.path.isdir(path):
            shutil.rmtree(path)

    os.makedirs(SHARED, exist_ok=True)
    with open(os.path.join(SHARED, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    # Widget textures, about 1 px per point of the largest widget that uses them.
    write(SHARED, "PaintSky", sky(370, 390, 5))
    write(SHARED, "PaintRidge", ridge(370, 390, 8))
    write(SHARED, "PaintPanel", panel(330, 250, 7))
    write(SHARED, "PaintCopper", copper(80, 80, 9))
    write(SHARED, "PaintMoon", moon(120, 120, 13))
    # App-only textures can be full resolution.
    write(APP, "AppSky", sky(1000, 2000, 61, s=2.4))
    write(APP, "AppPanel", panel(900, 1300, 67, s=2.4))


if __name__ == "__main__":
    main()
