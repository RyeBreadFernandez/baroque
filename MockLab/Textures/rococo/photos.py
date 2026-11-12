#!/usr/bin/env python3
"""The user's outdoor photographs repainted as Hubert Robert or Fragonard might have: in the colours of The Bathing Pool
and The Swing, laid in with oil strokes, under a varnish (2026-11-04: "try to turn my outdoor photography into this
style as well").

For each photograph:
  1. its colours are moved toward the paintings' (the mean and spread of each channel in Lab, two thirds of the way),
     its highlights eased and its shadows deepened, as an old canvas holds them;
  2. it is repainted with strokes that follow its forms (the direction of least change, from the structure tensor;
     level strokes where it is flat, as Robert lays in a sky): broad strokes everywhere, then smaller ones, then fine
     ones only where there is detail;
  3. the paint gets its bristle marks and ridges lit from the upper left, a canvas weave, a warm varnish and darker
     corners.

Writes photos/<name>.jpg (long side 1400). The photographs to repaint, and where they are, come from
photos.local.json next to this file (git-ignored; start it from photos.local.example.json). The sources stay where
they are; nothing leaves this machine.
Run (deterministic, no network; about a minute a photograph):
    python3 MockLab/Textures/rococo/photos.py [names...]
"""
import importlib.util
import json
import math
import os
import sys

sys.dont_write_bytecode = True

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location("mt", os.path.join(ROOT, "scripts", "make_textures.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)
gaussian_filter = mt.gaussian_filter

# Which photographs to repaint and where they are is the author's own business: it's read from photos.local.json next
# to this file, which git ignores, so none of their folder or file names are published. photos.local.example.json
# shows its shape; the names are the ones scripts/export_rococo_textures.py cuts (PHOTOS there).
LOCAL = os.path.join(HERE, "photos.local.json")
LONG = 1400
STRENGTH = 0.66           # how far toward the painting's colours


def load(path, long=LONG):
    im = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    k = long / max(im.size)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    return np.asarray(im, dtype=np.float32) / 255


def lab_stats(rgb):
    lab = cv2.cvtColor(rgb.astype(np.float32), cv2.COLOR_RGB2Lab).reshape(-1, 3)
    return lab.mean(axis=0), lab.std(axis=0)


def palette():
    """The colour of the two landscapes the user sent, The Bathing Pool and The Swing, together (make.py writes both)."""
    both = [load(os.path.join(HERE, name), long=800).reshape(-1, 3) for name in ("bathing-pool.jpg", "the-swing.jpg")]
    return lab_stats(np.concatenate(both)[None])


def toward(rgb, target, strength):
    lab = cv2.cvtColor(rgb.astype(np.float32), cv2.COLOR_RGB2Lab)
    mean, std = lab.reshape(-1, 3).mean(axis=0), lab.reshape(-1, 3).std(axis=0)
    tmean, tstd = target
    moved = (lab - mean) / (std + 1e-6) * tstd + tmean
    # Keep some of the photograph's own light: move the lightness less than the colour.
    w = np.array([strength * 0.6, strength, strength], dtype=np.float32)
    out = cv2.cvtColor((lab * (1 - w) + moved * w).astype(np.float32), cv2.COLOR_Lab2RGB)
    return np.clip(out, 0, 1)


def old_light(rgb):
    """Eased highlights, deeper shadows, a little warmth in the middle values."""
    lum = rgb.mean(axis=2, keepdims=True)
    curve = np.clip(lum, 1e-4, 1)
    shaped = 0.94 * curve ** 1.12 + 0.02
    out = rgb * (shaped / curve)
    warm = np.array([1.04, 1.0, 0.92]) ** (4 * lum * (1 - lum))
    return np.clip(out * warm, 0, 1)


def directions(rgb):
    """Stroke angles along the forms, level where the picture is flat, and how much detail each place holds."""
    g = gaussian_filter(rgb.mean(axis=2), 2.0).astype(np.float32)
    gx, gy = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3)
    jxx, jyy, jxy = (gaussian_filter(a, 6) for a in (gx * gx, gy * gy, gx * gy))
    along = 0.5 * np.arctan2(2 * jxy, jxx - jyy) + np.pi / 2
    tr = jxx + jyy
    coherence = np.sqrt((jxx - jyy) ** 2 + 4 * jxy ** 2) / (tr + 1e-6)
    strength = np.sqrt(tr)
    strength = strength / (np.percentile(strength, 98) + 1e-6)
    w = np.clip(coherence * np.clip(strength * 3, 0, 1), 0, 1)
    level = 0.05
    angle = np.arctan2(w * np.sin(along) + (1 - w) * math.sin(level), w * np.cos(along) + (1 - w) * math.cos(level))
    detail = np.clip(gaussian_filter(np.hypot(gx, gy), 1.5) / (np.percentile(np.hypot(gx, gy), 97) + 1e-6), 0, 1)
    return angle, detail


def strokes(img, field, angle, rng, count, widths, lengths, jitter, weight=None):
    """Lays `count` strokes onto img (PIL), each the colour of the field where it starts and following `angle`;
    with `weight`, starting where the weight is high."""
    h, w, _ = field.shape
    d = ImageDraw.Draw(img)
    if weight is None:
        xs, ys = rng.uniform(0, w, count), rng.uniform(0, h, count)
    else:
        p = weight.ravel() / weight.sum()
        idx = rng.choice(p.size, count, p=p)
        ys, xs = idx // w + rng.uniform(0, 1, count), idx % w + rng.uniform(0, 1, count)
    for x, y in zip(xs, ys):
        c = field[int(y) % h, int(x) % w] * (1 + rng.normal(0, jitter)) + rng.normal(0, 0.006, 3)
        col = tuple(int(v) for v in np.clip(c, 0, 1) * 255)
        width = rng.uniform(*widths)
        n = int(rng.uniform(*lengths) / 2)
        pts, px, py = [(x, y)], x, y
        # Each stroke runs both ways from where it starts, so it sits centred on its colour.
        sign = 1 if rng.random() < 0.5 else -1
        for _ in range(n):
            a = angle[int(py) % h, int(px) % w]
            px += sign * math.cos(a) * 2
            py += sign * math.sin(a) * 2
            if not (0 <= px < w and 0 <= py < h):
                break
            # Stop at an edge: a stroke shouldn't drag one colour across another.
            if np.abs(field[int(py), int(px)] - field[int(y) % h, int(x) % w]).sum() > 0.22:
                break
            pts.append((px, py))
        d.line(pts, fill=col, width=max(1, int(round(width))), joint="curve")
        r = width / 2
        for ex, ey in (pts[0], pts[-1]):
            d.ellipse([ex - r, ey - r * 0.8, ex + r, ey + r * 0.8], fill=col)


def weave(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return 0.5 * np.sin(xx * 2 * np.pi / 3.2) * np.sin(yy * 2 * np.pi / 3.4)


def sources():
    """{name: the photograph's path}, from photos.local.json. Stops with what to do when it's missing or malformed."""
    where = os.path.relpath(LOCAL)
    if not os.path.exists(LOCAL):
        sys.exit(f"No {where} yet. Copy photos.local.example.json (in the same folder) to photos.local.json and\n"
                 "list your own photographs in it: \"pictures\" is the folder they're in (~/Pictures if left out), and\n"
                 "\"photos\" gives each name its path inside that folder. Git ignores the file, so your folder and file\n"
                 "names stay on this Mac.")
    try:
        with open(LOCAL) as f:
            local = json.load(f)
        pictures = os.path.expanduser(local.get("pictures", "~/Pictures"))
        return {str(name): os.path.join(pictures, os.path.expanduser(path)) for name, path in local["photos"].items()}
    except (ValueError, KeyError, AttributeError, TypeError) as e:
        sys.exit(f"{where} isn't shaped like photos.local.example.json ({e!r}).")


def paint(name, target, path):
    rgb = load(path)
    rgb = old_light(toward(rgb, target, STRENGTH))
    h, w, _ = rgb.shape
    rng = np.random.default_rng(sum(map(ord, name)))
    angle, detail = directions(rgb)
    field = gaussian_filter(rgb, (1.2, 1.2, 0))
    # The ground: the picture itself, softened, so no canvas shows between strokes.
    canvas = Image.fromarray((gaussian_filter(rgb, (4, 4, 0)) * 255).astype(np.uint8))
    area = h * w
    k = LONG / 1400
    strokes(canvas, gaussian_filter(rgb, (5, 5, 0)), angle, rng, area // 260, (12 * k, 20 * k), (24 * k, 60 * k), 0.03)
    strokes(canvas, gaussian_filter(rgb, (2.5, 2.5, 0)), angle, rng, area // 70, (6 * k, 10 * k), (12 * k, 30 * k), 0.035)
    strokes(canvas, field, angle, rng, area // 40, (2.5 * k, 5 * k), (6 * k, 16 * k), 0.03, weight=detail ** 1.5 + 0.02)
    strokes(canvas, rgb, angle, rng, area // 90, (1.5 * k, 2.5 * k), (4 * k, 9 * k), 0.02, weight=detail ** 3 + 0.002)
    out = np.asarray(canvas, dtype=np.float64) / 255
    out = gaussian_filter(out, (0.5, 0.5, 0))
    out = mt.shade(out, mt.bristles(h, w, rng, angle, 0.011))
    out = mt.impasto(out, 0.9, blur=0.8)
    out = out * (1 + 0.012 * weave(h, w)[..., None])
    # Varnish: a warm glaze, stronger in the lights; the corners darkened as on an old canvas.
    lum = out.mean(axis=2, keepdims=True)
    out = out * (1 - 0.1 * lum) + np.array([0.98, 0.9, 0.7]) * 0.1 * lum
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    out = out * (1 - 0.28 * np.clip(r - 0.55, 0, 1) ** 1.6)[..., None]
    os.makedirs(os.path.join(HERE, "photos"), exist_ok=True)
    px = (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(px, "RGB").save(os.path.join(HERE, "photos", name + ".jpg"), quality=92, subsampling=0)
    print(f"photos/{name}.jpg: {w}x{h}")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    photos = sources()
    unknown = [name for name in only if name not in photos]
    if unknown:
        sys.exit(f"Not in {os.path.relpath(LOCAL)}: {', '.join(unknown)}")
    chosen = {name: path for name, path in photos.items() if not only or name in only}
    missing = [path for path in chosen.values() if not os.path.isfile(path)]
    if missing:
        sys.exit("These photographs aren't there (check photos.local.json):\n  " + "\n  ".join(missing))
    target = palette()
    for name, path in chosen.items():
        paint(name, target, path)


if __name__ == "__main__":
    main()
