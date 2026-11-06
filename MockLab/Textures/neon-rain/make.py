#!/usr/bin/env python3
"""Neon Rain textures. All are 1 px per point at (or under) the large widget size, so they stay inside
WidgetKit's image budget; the Swift code draws them at native size and crops for small and medium.

  grain.png    348x365  film grain around mid grey (drawn with .softLight): clumped luminance grain plus faint dye clouds
  mist.png     348x240  white billows, alpha only (tinted in Swift): rain mist and cloud caught on the peaks
  rock.png     348x220  wet mountainside relief around mid grey (drawn with .softLight inside the ridges): gullies, scree
  fog.png      348x365  condensation on the glass, white with alpha: breath fog creeping in from the frame, micro-beads
  asphalt.png  348x200  wet street around mid grey (drawn with .softLight): aggregate, tar seams and glints

Run from anywhere:  python3 MockLab/Textures/neon-rain/make.py      (deterministic: fixed seeds)
"""
import os
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def field(rng, h, w, sy, sx=None):
    """Smooth zero-mean noise with unit std; sx != sy stretches it."""
    sx = sy if sx is None else sx
    n = gaussian_filter(rng.standard_normal((h, w)), (sy, sx), mode="wrap")
    return n / (n.std() + 1e-9)


def save_grey(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(HERE, name), optimize=True)


def save_alpha(alpha, name, rgb=(255, 255, 255)):
    h, w = alpha.shape
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = rgb
    out[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(HERE, name), optimize=True)


def grain(w, h, seed):
    rng = np.random.default_rng(seed)
    fine = rng.standard_normal((h, w))
    clump = gaussian_filter(rng.standard_normal((h, w)), 0.7)
    clump /= clump.std() + 1e-9
    lum = 0.55 * fine + 0.65 * clump
    # Dye clouds: slow, faint variations per channel, the colour breathing of a fast stock pushed two stops.
    img = np.zeros((h, w, 3), np.float32)
    for c, amt in enumerate((5.0, 3.0, 6.0)):
        img[..., c] = 128 + lum * 22 + field(rng, h, w, 9) * amt
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(os.path.join(HERE, "grain.png"), optimize=True)


def mist(w, h, seed):
    rng = np.random.default_rng(seed)
    # Puffy, slow wisps: broad billows with a little drag, no hairlines.
    base = 0.6 * field(rng, h, w, 9, 24) + 0.32 * field(rng, h, w, 4.5, 10) + 0.12 * field(rng, h, w, 2.2, 4.5)
    a = np.clip((base + 0.2) / 2.0, 0, 1)
    a = a * a * (3 - 2 * a)
    # Feather every edge so a patch can be dropped anywhere without a seam.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fx = np.clip(np.minimum(xx, w - 1 - xx) / 60, 0, 1)
    fy = np.clip(np.minimum(yy, h - 1 - yy) / 45, 0, 1)
    save_alpha(a * (fx * fy) ** 1.5, "mist.png")


def rock(w, h, seed):
    rng = np.random.default_rng(seed)
    # Gullies run down the slope: noise stretched vertically, then sheared a little.
    g = field(rng, h, w, 9, 1.6)
    shear = np.zeros_like(g)
    for y in range(h):
        shear[y] = np.roll(g[y], int(y * 0.35))
    relief = 0.6 * shear + 0.3 * field(rng, h, w, 2.5) + 0.25 * field(rng, h, w, 0.8)
    gy, gx = np.gradient(gaussian_filter(relief, 0.8))
    shade = -(gx * 0.9 + gy * 0.4)
    shade /= np.abs(shade).std() + 1e-9
    v = 128 + shade * 20 + relief * 10
    # Wet glints: sparse bright specks on the ridges of the relief.
    glint = (rng.random((h, w)) > 0.993) & (shade > 0.6)
    v = v + gaussian_filter(glint.astype(np.float32), 0.6) * 160
    save_grey(v, "rock.png")


def fog(w, h, seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = xx / (w - 1) * 2 - 1, yy / (h - 1) * 2 - 1
    # Breath fog creeps in from the frame: nothing in the middle of the pane, thick at the corners and the sill.
    edge = np.clip(np.maximum(np.abs(nx), np.abs(ny)) ** 3 * 0.8 + np.clip(ny, 0, 1) ** 4 * 0.6, 0, 1)
    patch = np.clip(0.55 + 0.4 * field(rng, h, w, 16) + 0.2 * field(rng, h, w, 5), 0, 1)
    density = np.clip(edge * patch * 1.3, 0, 1)
    # Micro-beads where the fog is: tiny lit dots.
    beads = np.zeros((h, w), np.float32)
    n = int(w * h / 26)
    ys, xs = rng.integers(0, h, n), rng.integers(0, w, n)
    beads[ys, xs] = rng.uniform(0.2, 0.7, n)
    beads = gaussian_filter(beads, 0.6) * 2.0
    haze = gaussian_filter(density, 2.0)
    alpha = np.clip(haze * 0.75 + beads * density * 0.5, 0, 1)
    save_alpha(alpha, "fog.png")


def asphalt(w, h, seed):
    rng = np.random.default_rng(seed)
    agg = 0.5 * rng.standard_normal((h, w)) + 0.8 * field(rng, h, w, 0.7)
    tar = field(rng, h, w, 14, 40)
    v = 128 + agg * 14 + tar * 10
    # Tar seams: a couple of long, slightly wandering dark lines.
    for _ in range(3):
        y0 = rng.uniform(0.2, 0.9) * h
        slope = rng.uniform(-0.05, 0.05)
        xs = np.arange(w)
        ys = (y0 + slope * xs + 2.5 * np.sin(xs / rng.uniform(18, 40))).astype(int)
        ok = (ys >= 0) & (ys < h)
        line = np.zeros((h, w), np.float32)
        line[ys[ok], xs[ok]] = 1
        v -= gaussian_filter(line, 0.8) * 70
    glints = (rng.random((h, w)) > 0.996).astype(np.float32)
    v += gaussian_filter(glints, 0.5) * 220
    save_grey(v, "asphalt.png")


def main():
    grain(348, 365, 11)
    mist(348, 240, 12)
    rock(348, 220, 13)
    fog(348, 365, 14)
    asphalt(348, 200, 15)
    print("textures written to", HERE)


if __name__ == "__main__":
    main()
