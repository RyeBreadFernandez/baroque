#!/usr/bin/env python3
"""Raster textures for the Woodblock mock (ukiyo-e print look).

Outputs (all about 1 px per point of where they are drawn, so WidgetKit accepts them):
  washi.png    348x365 RGB   cream kozo paper: mottled body, long fibers, a few dark inclusions
  grain_a.png  348x365 L     wood-block grain around 50% gray (for soft-light): flowing grain lines,
                             uneven ink density and faint baren rubbing swirls
  grain_b.png  348x365 L     a second block: different seed, tighter grain, slight tilt
  fibers.png   348x365 RGBA  pale paper fibers on transparency, laid over the printed ink so paper shows through

Run: python3 make.py   (numpy, scipy, Pillow)
"""
import os
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 348, 365
SS = 3  # supersampling for drawn fibers


def smooth_noise(rng, h, w, sigma):
    n = rng.standard_normal((h, w))
    n = ndimage.gaussian_filter(n, sigma, mode="wrap")
    n -= n.mean()
    n /= (np.abs(n).max() + 1e-9)
    return n


def draw_fibers(rng, count, length, width, shade_fn, size=(W, H), alpha=True):
    """Curved fibers drawn on a supersampled RGBA canvas, returned downsampled."""
    w, h = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.uniform(-20, w + 20), rng.uniform(-20, h + 20)
        ang = rng.uniform(0, np.pi * 2)
        L = rng.uniform(*length) * SS
        steps = max(4, int(L / (4 * SS)))
        curl = rng.normal(0, 0.10)
        pts = [(x, y)]
        for _ in range(steps):
            ang += curl + rng.normal(0, 0.12)
            x += np.cos(ang) * L / steps
            y += np.sin(ang) * L / steps
            pts.append((x, y))
        col = shade_fn(rng)
        d.line(pts, fill=col, width=max(1, int(rng.uniform(*width) * SS)), joint="curve")
    return img.resize(size, Image.LANCZOS)


def washi():
    rng = np.random.default_rng(11)
    base = np.array([241, 231, 208], dtype=np.float64)  # washi cream
    # cloudy formation of the sheet: thicker and thinner pulp
    cloud = 0.6 * smooth_noise(rng, H, W, 18) + 0.4 * smooth_noise(rng, H, W, 5)
    fine = smooth_noise(rng, H, W, 0.8)
    img = np.ones((H, W, 3)) * base
    img += cloud[..., None] * np.array([7, 8, 10])
    img += fine[..., None] * 5
    pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")
    # long pale kozo fibers and a few tan ones
    pale = draw_fibers(rng, 620, (14, 80), (0.4, 0.9),
                       lambda r: (255, 253, 244, int(r.uniform(90, 190))))
    tan = draw_fibers(rng, 160, (8, 40), (0.3, 0.6),
                      lambda r: (176, 150, 112, int(r.uniform(40, 95))))
    pil = Image.alpha_composite(pil, pale)
    pil = Image.alpha_composite(pil, tan)
    # rare bark inclusions: short dark slivers, drawn supersampled
    bark = draw_fibers(rng, 22, (1.5, 5), (0.5, 1.0),
                       lambda r: (128, 100, 72, int(r.uniform(70, 140))))
    pil = Image.alpha_composite(pil, bark)
    pil.convert("RGB").save(os.path.join(HERE, "washi.png"), optimize=True)


def grain(seed, period, tilt, name):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    # flowing grain: rings of a plank cut along the trunk, bent by low-frequency warps and a knot
    warp = 10 * smooth_noise(rng, H, W, 40) + 3 * smooth_noise(rng, H, W, 10)
    kx, ky = rng.uniform(0.2, 0.8) * W, rng.uniform(0.2, 0.8) * H
    knot = 14 * np.exp(-(((xx - kx) / 26) ** 2 + ((yy - ky) / 12) ** 2))
    phase = (yy + xx * tilt + warp + knot) / period
    rings = 0.5 + 0.5 * np.sin(2 * np.pi * phase)
    rings = rings ** 3  # thin dark late-wood lines
    # fine fibre streaks along the grain
    streak = rng.standard_normal((H, W))
    streak = ndimage.gaussian_filter(streak, (0.5, 7))
    streak /= np.abs(streak).max()
    # ink density: patches where the block took less ink, plus baren rubbing swirls
    blot = smooth_noise(rng, H, W, 14)
    r = np.hypot(xx - W * 0.5, yy - H * 0.55)
    swirl = 0.5 + 0.5 * np.sin(r / 2.3 + 3 * smooth_noise(rng, H, W, 25))
    swirl *= np.clip(smooth_noise(rng, H, W, 30) + 0.3, 0, 1)
    v = 0.5 - 0.20 * rings + 0.14 * streak + 0.16 * blot + 0.05 * (swirl - 0.5)
    # starved specks: tiny spots where paper shows through the ink
    speck = (rng.random((H, W)) > 0.9988).astype(np.float64)
    speck = ndimage.gaussian_filter(speck, 0.9) * 5
    v += np.clip(speck, 0, 0.22)
    v = np.clip(v, 0, 1)
    Image.fromarray((v * 255).astype(np.uint8), "L").save(os.path.join(HERE, name), optimize=True)


def fibers():
    rng = np.random.default_rng(29)
    img = draw_fibers(rng, 380, (12, 60), (0.3, 0.7),
                      lambda r: (250, 244, 228, int(r.uniform(60, 140))))
    img = img.filter(ImageFilter.GaussianBlur(0.2))
    img.save(os.path.join(HERE, "fibers.png"), optimize=True)


if __name__ == "__main__":
    washi()
    grain(5, 6.5, 0.04, "grain_a.png")
    grain(17, 4.6, -0.07, "grain_b.png")
    fibers()
    for n in ["washi.png", "grain_a.png", "grain_b.png", "fibers.png"]:
        im = Image.open(os.path.join(HERE, n))
        print(n, im.size, im.mode)
