#!/usr/bin/env python3
"""Glass textures for the StainedGlass mock (grey, centred on mid-grey, drawn with an overlay blend).

streaky.png    swirled streaky glass: noise smeared along a curling flow field, plus thickness and seeds
hammered.png   hammered / seedy glass: a dimpled height map lit from the upper left, plus seeds
cathedral.png  pale rolled cathedral glass for the text panels: gentle ripples, a few seeds, faint streaks

Each is 360x380 px, near 1 px per point of the largest widget it is drawn into.
Run: python3 make.py   (numpy, scipy, Pillow)
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 360, 380
OUT = os.path.dirname(os.path.abspath(__file__))


def noise(rng, sigma, shape=(H, W)):
    n = ndimage.gaussian_filter(rng.standard_normal(shape), sigma, mode="wrap")
    return n / (n.std() + 1e-9)


def sample(img, x, y):
    return ndimage.map_coordinates(img, [y % H, x % W], order=1, mode="wrap")


def lic(src, angle, steps=28, step=0.9):
    """Line integral convolution: smears `src` along the flow field `angle`."""
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    acc = np.zeros_like(src)
    for sign in (1.0, -1.0):
        x, y = xx.copy(), yy.copy()
        for _ in range(steps):
            a = sample(angle, x, y)
            x += sign * np.cos(a) * step
            y += sign * np.sin(a) * step
            acc += sample(src, x, y)
    return acc / (2 * steps)


def shade(height, light=(-0.6, -0.8)):
    gy, gx = np.gradient(height)
    return -(gx * light[0] + gy * light[1])


def seeds(rng, count, rmin, rmax):
    """Bubbles: a dark core with a bright rim on the lit (upper left) side."""
    out = np.zeros((H, W))
    yy, xx = np.mgrid[0:H, 0:W]
    for _ in range(count):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(rmin, rmax)
        # elongated along a random direction, like stretched seeds in rolled glass
        a = rng.uniform(0, np.pi)
        stretch = rng.uniform(1.0, 2.2)
        x0, x1 = int(max(cx - r * 3 - 2, 0)), int(min(cx + r * 3 + 3, W))
        y0, y1 = int(max(cy - r * 3 - 2, 0)), int(min(cy + r * 3 + 3, H))
        if x1 <= x0 or y1 <= y0:
            continue
        dx = xx[y0:y1, x0:x1] - cx
        dy = yy[y0:y1, x0:x1] - cy
        u = (dx * np.cos(a) + dy * np.sin(a)) / stretch
        v = -dx * np.sin(a) + dy * np.cos(a)
        d = np.sqrt(u * u + v * v) / r
        core = np.clip(1 - d, 0, 1) ** 0.7
        rim = np.exp(-((d - 1.0) ** 2) / 0.08)
        side = np.clip((-dx * 0.6 - dy * 0.8) / (r * stretch + 1e-6), -1, 1)
        out[y0:y1, x0:x1] += -0.8 * core + rim * (0.55 + 0.6 * side)
    return out


def save(name, arr, contrast):
    a = arr - np.median(arr)
    a = a / (np.percentile(np.abs(a), 99) + 1e-9)
    img = np.clip(128 + a * contrast, 0, 255).astype(np.uint8)
    Image.fromarray(np.stack([img] * 3, axis=-1), "RGB").save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name, img.shape, img.min(), img.max())


def streaky():
    rng = np.random.default_rng(11)
    angle = 0.35 + 1.5 * noise(rng, 46) + 0.5 * noise(rng, 18)
    fine = ndimage.gaussian_filter(rng.standard_normal((H, W)), 0.6)
    fine += 2.2 * (rng.random((H, W)) > 0.985)  # sparse bright fibres become long streaks
    streak = lic(fine, angle)
    streak /= streak.std() + 1e-9
    thick = noise(rng, 34) + 0.5 * noise(rng, 12)
    s = seeds(rng, 70, 0.7, 2.0)
    save("streaky", 0.95 * streak + 0.55 * thick + 0.9 * s, 82)


def hammered():
    rng = np.random.default_rng(23)
    h = noise(rng, 4.5) + 0.6 * noise(rng, 2.2) + 0.8 * noise(rng, 14)
    lit = shade(h)
    lit /= lit.std() + 1e-9
    thick = noise(rng, 40)
    s = seeds(rng, 150, 0.6, 1.8)
    save("hammered", 0.85 * lit + 0.45 * thick + 1.0 * s, 74)


def cathedral():
    rng = np.random.default_rng(37)
    # rolled ripples: stretched noise, shaded, so the pale glass has a soft wavy surface
    ripple = ndimage.gaussian_filter(rng.standard_normal((H, W)), (9, 3.5), mode="wrap")
    ripple /= ripple.std() + 1e-9
    lit = shade(ripple * 6.0)
    lit /= lit.std() + 1e-9
    thick = noise(rng, 50)
    s = seeds(rng, 45, 0.6, 1.5)
    save("cathedral", 0.8 * lit + 0.6 * thick + 0.8 * s, 60)


if __name__ == "__main__":
    streaky()
    hammered()
    cathedral()
