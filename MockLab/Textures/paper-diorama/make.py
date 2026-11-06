#!/usr/bin/env python3
"""Paper Diorama textures: tileable cardstock fiber, centered on mid-gray so it can be laid over any
paper colour with a soft-light / overlay blend (gray = no change, light strands lift, dark pulp sinks).

    python3 make.py        -> fiber.png, fiber-b.png (256 x 256, drawn at 1 px per point and tiled)
                              tooth.png: white-based, for a multiply blend on cream and white stock,
                              where an overlay blend barely shows (dark pulp, strands and flecks only)

Everything is periodic (FFT-filtered noise, strands drawn with wrap-around), so the tiles repeat without seams.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
N = 256


def periodic_noise(rng, n, sigma):
    """Gaussian-filtered white noise via FFT, so it wraps seamlessly. Normalized to unit std."""
    white = rng.standard_normal((n, n))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * g))
    return out / (out.std() + 1e-9)


def strands(rng, n, count, ss=3):
    """Thin curved fibers drawn on a supersampled canvas with wrap-around. Returns -1..1 field."""
    big = n * ss
    light = Image.new("L", (big, big), 0)
    dark = Image.new("L", (big, big), 0)
    dl, dd = ImageDraw.Draw(light), ImageDraw.Draw(dark)
    for i in range(count):
        x, y = rng.uniform(0, big), rng.uniform(0, big)
        ang = rng.uniform(0, np.pi)
        length = rng.uniform(5, 26) * ss
        bend = rng.uniform(-0.09, 0.09)
        steps = 14
        pts = []
        for s in range(steps + 1):
            pts.append((x, y))
            ang += bend
            x += np.cos(ang) * length / steps
            y += np.sin(ang) * length / steps
        width = int(rng.choice([1, 1, 1, 2]) * ss * 0.55) or 1
        target = dl if i % 3 else dd  # two thirds of the strands catch the light
        val = int(rng.uniform(120, 255))
        for ox in (-big, 0, big):
            for oy in (-big, 0, big):
                target.line([(px + ox, py + oy) for px, py in pts], fill=val, width=width)
    light = light.resize((n, n), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.35))
    dark = dark.resize((n, n), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.45))
    return (np.asarray(light, np.float64) - 0.75 * np.asarray(dark, np.float64)) / 255.0


def fiber(seed):
    rng = np.random.default_rng(seed)
    pulp = periodic_noise(rng, N, 9.0) * 0.55 + periodic_noise(rng, N, 3.0) * 0.35
    grain = periodic_noise(rng, N, 0.7) * 0.30
    flecks = (rng.random((N, N)) > 0.9965).astype(np.float64)
    flecks = np.real(np.fft.ifft2(np.fft.fft2(flecks) * np.fft.fft2(np.pad(np.ones((2, 2)), ((0, N - 2), (0, N - 2))))))
    field = pulp * 14 + grain * 16 + strands(rng, N, 420) * 62 - flecks * 22
    img = np.clip(128 + field, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "L")


def tooth(seed):
    rng = np.random.default_rng(seed)
    pulp = np.clip(periodic_noise(rng, N, 7.0), -2.5, 2.5) * 3.2 + np.clip(periodic_noise(rng, N, 1.2), -3, 3) * 2.4
    s = strands(rng, N, 300)
    fibers = np.clip(-s, 0, None) * 70 + np.clip(s, 0, None) * 26     # both strand sets darken a little
    flecks = (rng.random((N, N)) > 0.997).astype(np.float64) * 34
    img = np.clip(246 - pulp - fibers - flecks, 150, 255).astype(np.uint8)
    return Image.fromarray(img, "L")


if __name__ == "__main__":
    fiber(7).save(os.path.join(HERE, "fiber.png"))
    fiber(23).save(os.path.join(HERE, "fiber-b.png"))
    tooth(41).save(os.path.join(HERE, "tooth.png"))
    print("wrote fiber.png, fiber-b.png, tooth.png")
