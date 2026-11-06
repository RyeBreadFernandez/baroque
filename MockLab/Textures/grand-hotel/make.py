#!/usr/bin/env python3
"""Grand Hotel paint textures: the hotel palette laid down with the app's own brush method.

Every texture is painted by the functions in scripts/make_textures.py (imported from its path, not copied): a soft
colour field covered with opaque strokes that follow a direction field, coarse to fine, then bristle marks and impasto
light on the stroke edges. Only the colours and stroke directions are new, so the brushwork matches the shipped
espresso panel, copper pebbles, sky and ridges.

Colour textures (JPEG, about 1 px per point of the largest surface that uses them):
  velvet.jpg      360x260  raspberry velvet, strokes running down the folds (valance, curtains, stamp panel, banners)
  cream.jpg       330x260  cream card stock (the register, the stamp, notices)
  lilac.jpg       330x220  lilac card (chapter cards)
  mint.jpg        330x80   mint enamel (the pigeonhole cabinet, the wainscot)
  plum.jpg        120x120  bellboy-purple lacquer (the barometer face)
  brass.jpg       80x80    polished brass (keys, the bell, bezels, pebbles)
  raspberry.jpg   80x80    raspberry enamel (wax seals, late chips)
  wall.jpg        350x170  pink striped lobby wallpaper, painted stripe by stripe

Relief overlays (PNG with alpha, light and dark brushwork only):
  sky-relief.png    370x390  the shipped PaintSky strokes (same seed), shadows in lavender, lights in cream-pink
  ridge-relief.png  370x390  the shipped PaintRidge strokes (same seed), shadows in plum, lights in blush
  facade.png        200x130  small plaster dabs for the hotel's walls

Run from anywhere (deterministic):  python3 MockLab/Textures/grand-hotel/make.py
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True  # importing scripts/make_textures.py must not leave a __pycache__ in scripts/

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
spec = importlib.util.spec_from_file_location("make_textures", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

hexrgb, fbm, mix, smoothstep = mt.hexrgb, mt.fbm, mt.mix, mt.smoothstep


def save(name, img):
    px = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    if img.shape[2] == 4:
        Image.fromarray(px, "RGBA").save(os.path.join(HERE, name + ".png"), optimize=True)
        ext = "png"
    else:
        Image.fromarray(px, "RGB").save(os.path.join(HERE, name + ".jpg"), quality=90, subsampling=0)
        ext = "jpg"
    print(f"{name}.{ext}: {img.shape[1]}x{img.shape[0]}")


# MARK: Colour boards

def board(w, h, seed, colors, s=1.0, relief=1.2, bristle=0.03):
    """Adapted from mt.panel (its impasto is tuned for dark espresso and too loud on pale card): the same diagonal
    strokes, bristles and impasto, with the impasto and bristle strength as parameters."""
    rng = np.random.default_rng(seed)
    angle = 0.25 + 0.8 * np.tanh(1.5 * fbm(h, w, rng, base=2.0, octaves=2, persistence=0.4))
    a, b, c, olive = (hexrgb(x) for x in colors)
    rgb = mix(a, b, smoothstep(-1.4, 1.4, fbm(h, w, rng, base=3, octaves=4, persistence=0.5)))
    rgb = mix(rgb, c, 0.5 * smoothstep(0.5, 2.0, fbm(h, w, rng, base=2.5, octaves=3)))
    rgb = mix(rgb, olive, 0.35 * smoothstep(0.6, 2.0, fbm(h, w, rng, base=2, octaves=2)))
    out = mt.paint(rgb, angle, rng, [(int(700 * s * s), (7 * s, 13 * s), (20 * s, 46 * s)),
                                     (int(1500 * s * s), (3 * s, 6 * s), (10 * s, 24 * s))], 0.07, hue=0.004)
    out = gaussian_filter(out, (0.5 * s, 0.5 * s, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, bristle))
    return mt.impasto(out, relief, blur=0.7 * s)


def metal(w, h, seed, colors):
    """Adapted from mt.copper (its colours are fixed): small dabs over a mottled field, light impasto."""
    lo, hi, glint = (hexrgb(c) for c in colors)
    rng = np.random.default_rng(seed)
    angle = 0.6 + 0.7 * fbm(h, w, rng, base=2, octaves=2)
    rgb = mix(lo, hi, smoothstep(-1.5, 1.5, fbm(h, w, rng, base=2.5, octaves=4)))
    rgb = mix(rgb, glint, 0.35 * smoothstep(0.6, 2.0, fbm(h, w, rng, base=3, octaves=2)))
    out = mt.paint(rgb, angle, rng, [(160, (3, 6), (6, 14)), (260, (1.5, 3), (4, 9))], 0.06, hue=0.005)
    out = gaussian_filter(out, (0.45, 0.45, 0))
    return mt.impasto(out, 0.45, blur=0.6)


def velvet(w, h, seed):
    """Raspberry velvet: long strokes down the folds, a darker gather every so often, sheen on the bellies."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    angle = np.pi / 2 + 0.12 * fbm(h, w, rng, base=2.5, octaves=2)
    folds = 0.5 + 0.5 * np.sin(xx / w * np.pi * 2 * 9 + 1.2 * fbm(h, w, rng, base=2, octaves=2))
    rgb = mix(hexrgb(0x7E1D3E), hexrgb(0xB3375E), smoothstep(0.05, 0.85, folds))
    rgb = mix(rgb, hexrgb(0xD0587D), 0.45 * smoothstep(0.75, 1.0, folds))
    rgb = mix(rgb, hexrgb(0x8E2448), 0.3 * smoothstep(-0.2, 1.6, fbm(h, w, rng, base=3, octaves=3)))
    out = mt.paint(rgb, angle, rng, [(520, (6, 11), (30, 80)), (1300, (2.5, 5), (14, 36))], 0.06, hue=0.004)
    out = gaussian_filter(out, (0.5, 0.5, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, 0.035))
    return mt.impasto(out, 0.9, blur=0.7)


def wallpaper(w, h, seed, stripe=14):
    """Lobby wallpaper: blush and rose stripes, each painted down with the brush."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    angle = np.pi / 2 + 0.06 * fbm(h, w, rng, base=2, octaves=2)
    band = ((xx // stripe) % 2).astype(np.float64)
    rgb = mix(hexrgb(0xF7C8D3), hexrgb(0xE496AD), band)
    rgb = mix(rgb, hexrgb(0xF9D3DC), 0.35 * smoothstep(0.4, 1.8, fbm(h, w, rng, base=3, octaves=3)))
    out = mt.paint(rgb, angle, rng, [(500, (3, 5), (24, 70)), (1200, (1.5, 2.5), (10, 28))], 0.03, hue=0.003)
    out = gaussian_filter(out, (0.45, 0.45, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, 0.03))
    return mt.impasto(out, 0.45, blur=0.6)


# MARK: Relief overlays

def recolour(rel, dark, light_cool, light_warm, dark_gain=1.0, light_gain=1.0):
    """mt.relief paints near-black shadows and grey-green to gold lights; swap in the hotel's colours."""
    rgb, a = rel[..., :3], rel[..., 3]
    lum = rgb.mean(axis=2)
    is_dark = lum < 0.2
    cool, warm = mt.hexrgb(0xC9D5CA), mt.hexrgb(0xF3D8A4)
    t = np.clip((rgb[..., 0] - cool[0]) / (warm[0] - cool[0]), 0, 1)
    light = mix(np.ones(rgb.shape) * hexrgb(light_cool), np.ones(rgb.shape) * hexrgb(light_warm), t)
    out_rgb = np.where(is_dark[..., None], hexrgb(dark), light)
    out_a = np.clip(np.where(is_dark, a * dark_gain, a * light_gain), 0, 1)
    return np.concatenate([out_rgb, out_a[..., None]], axis=2)


def facade(w, h, seed):
    """Small upright plaster dabs, like a scenic painter's wall: mt.stroke_relief with short near-vertical strokes."""
    rng = np.random.default_rng(seed)
    angle = np.pi / 2 + 0.5 * np.tanh(1.5 * fbm(h, w, rng, base=3, octaves=2))
    return mt.stroke_relief(w, h, rng, angle, 0.06, [(500, (3, 6), (6, 14)), (1100, (1.5, 3), (4, 9))],
                            jitter=0.06, blur=0.45, bristle=0.006, edge=0.08)


def main():
    save("velvet", velvet(360, 260, 101))
    save("cream", board(330, 260, 103, (0xFAEFDD, 0xF0DDC4, 0xFFF9F0, 0xF6DCD3), s=1.3, relief=0.2, bristle=0.012))
    save("lilac", board(330, 220, 107, (0xE1D5F2, 0xCCBDE5, 0xEEE6F9, 0xE3CBE6), s=1.3, relief=0.2, bristle=0.012))
    save("mint", board(330, 80, 109, (0xB9E2CF, 0x9CCFB8, 0xD3F0E3, 0xA8D6CF), relief=0.35, bristle=0.018))
    save("plum", board(120, 120, 113, (0x4C2453, 0x3A1A42, 0x5E3166, 0x452047)))
    save("brass", metal(80, 80, 127, (0x9C7430, 0xD3AA55, 0xF0D486)))
    save("raspberry", metal(80, 80, 131, (0x8A2246, 0xBF4168, 0xE07D9A)))
    save("wall", wallpaper(350, 170, 137))
    save("sky-relief", recolour(mt.sky(370, 390, 5), 0x6B5A98, 0xF4F0FA, 0xFFEFE4, dark_gain=1.0, light_gain=1.6))
    save("ridge-relief", recolour(mt.ridge(370, 390, 8), 0x3E1F48, 0xFBF2F8, 0xFFEADF, dark_gain=1.25, light_gain=1.5))
    save("facade", recolour(facade(200, 130, 139), 0x7A3A5E, 0xFFF2EC, 0xFFE6D2, dark_gain=0.9))


if __name__ == "__main__":
    main()
